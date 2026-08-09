#!/usr/bin/env node
/**
 * Post-build SEO pass over ./build.
 *
 * Diplodoc emits per-page canonical and en/fr/ru hreflang alternates, but it does
 * not emit a sitemap and leaves the root redirect stub bare. Both gaps are load-
 * bearing here:
 *
 *   - The language switcher renders as a <button>, not an <a>, so nothing on the
 *     site links to /fr/index.html or /ru/index.html. Ahrefs reports both as
 *     "Canonical URL has no incoming internal links" and a crawler that starts at
 *     the root has no path into the FR or RU trees at all. The sitemap is what
 *     makes those 56 pages discoverable.
 *   - The root stub is the entry point for anyone typing the bare domain, and it
 *     shipped with no canonical, no hreflang and no description.
 *
 * Run after `yfm`; see the `build` script in package.json.
 */
import {readdirSync, readFileSync, statSync, writeFileSync} from 'node:fs';
import {join, relative, sep} from 'node:path';

const SITE = 'https://docs.icegate.tech';
const BUILD = 'build';
const LANGS = ['en', 'fr', 'ru'];
const DEFAULT_LANG = 'en';

// Shown when someone shares or searches the bare domain. The stub has no body
// copy of its own for a search engine to fall back on.
const ROOT_DESCRIPTION =
  'Documentation for IceGate, an open-source observability data lake engine — install, query, and operate it on Apache Iceberg, Arrow and Parquet.';

const xmlEscape = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

function htmlFiles(dir) {
  const out = [];
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) out.push(...htmlFiles(full));
    else if (entry.endsWith('.html')) out.push(full);
  }
  return out;
}

// Group pages by their path within a language dir, so the same article across
// en/fr/ru becomes one <url> entry carrying every translation as an alternate.
const pages = new Map();
for (const lang of LANGS) {
  for (const file of htmlFiles(join(BUILD, lang))) {
    const key = relative(join(BUILD, lang), file).split(sep).join('/');
    if (!pages.has(key)) pages.set(key, new Map());
    pages.get(key).set(lang, `${SITE}/${lang}/${key}`);
  }
}

const urls = [...pages.entries()]
  .sort(([a], [b]) => a.localeCompare(b))
  .flatMap(([, byLang]) => {
    // Every translation gets its own <url>, each repeating the full alternate set
    // including itself — that is what the hreflang sitemap spec requires, and it
    // is the point of the exercise: only a URL that appears as a <loc> is
    // actually submitted for crawling. Listing just the en URL and demoting fr/ru
    // to annotations would leave both trees as undiscoverable as they are today.
    const alternates = LANGS.filter((l) => byLang.has(l)).map(
      (l) => `    <xhtml:link rel="alternate" hreflang="${l}" href="${xmlEscape(byLang.get(l))}"/>`,
    );
    if (byLang.has(DEFAULT_LANG)) {
      alternates.push(
        `    <xhtml:link rel="alternate" hreflang="x-default" href="${xmlEscape(byLang.get(DEFAULT_LANG))}"/>`,
      );
    }
    const annotations = alternates.join('\n');
    return LANGS.filter((l) => byLang.has(l)).map(
      (l) => `  <url>\n    <loc>${xmlEscape(byLang.get(l))}</loc>\n${annotations}\n  </url>`,
    );
  });

writeFileSync(
  join(BUILD, 'sitemap.xml'),
  `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">
${urls.join('\n')}
</urlset>
`,
);

// The root stub is a 0-second meta refresh to /en/index.html. Google treats that
// as a redirect, so the canonical names the target rather than the stub itself.
const rootPath = join(BUILD, 'index.html');
let root = readFileSync(rootPath, 'utf8');
if (root.includes('rel="canonical"')) {
  console.warn('postbuild: build/index.html already has a canonical — leaving it alone');
} else {
  const head = LANGS.map(
    (l) => `        <link rel="alternate" hreflang="${l}" href="${SITE}/${l}/index.html"/>`,
  ).join('\n');
  root = root.replace(
    '</title>',
    `</title>
        <link rel="canonical" href="${SITE}/${DEFAULT_LANG}/index.html"/>
${head}
        <link rel="alternate" hreflang="x-default" href="${SITE}/${DEFAULT_LANG}/index.html"/>
        <meta name="description" content="${ROOT_DESCRIPTION.replace(/"/g, '&quot;')}">`,
  );
  writeFileSync(rootPath, root);
}

// x-default tells Google which translation to serve a searcher whose language
// matches none of en/fr/ru. Diplodoc emits the three alternates but not this one.
let patched = 0;
for (const lang of LANGS) {
  for (const file of htmlFiles(join(BUILD, lang))) {
    const html = readFileSync(file, 'utf8');
    if (html.includes('hreflang="x-default"')) continue;
    // Reuse Diplodoc's own en alternate verbatim, so x-default resolves against
    // the page's <base href> exactly like the alternate it was copied from.
    const enAlternate = html.match(/<link rel="alternate" href="([^"]*)" hreflang="en" \/>/);
    if (!enAlternate) continue;
    writeFileSync(
      file,
      html.replace(
        enAlternate[0],
        `${enAlternate[0]}\n        <link rel="alternate" href="${enAlternate[1]}" hreflang="x-default" />`,
      ),
    );
    patched++;
  }
}

console.log(
  `postbuild: sitemap.xml with ${urls.length} urls, root stub canonicalised, x-default added to ${patched} pages`,
);
