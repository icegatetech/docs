workspace "IceGate" "Observability Data Lake Engine" {

    !identifiers hierarchical

    configuration {
        scope softwaresystem
    }

    model {
        # External actors and systems
        otelCollector = softwareSystem "OpenTelemetry Collector / SDK" "Instrumented applications and collectors sending telemetry over OTLP" "External"
        grafana = softwareSystem "Grafana" "Dashboards over the Loki and Tempo APIs, with trace-to-logs correlation" "External"
        sqlClients = softwareSystem "BI and SQL Clients" "JDBC, ODBC and ADBC clients (DBeaver, Superset, Tableau, dbt) using Arrow Flight SQL" "External"
        prometheusServer = softwareSystem "Prometheus" "Scrapes the services' own metrics endpoints" "External"
        tracingBackend = softwareSystem "Tracing Backend" "Jaeger or any OTLP endpoint receiving IceGate's own traces" "External"
        trino = softwareSystem "Trino" "Legacy SQL analytics; reads Iceberg only through an external REST catalog" "External"
        pricingFeeds = softwareSystem "LLM Pricing Feeds" "OpenRouter and LiteLLM rate cards crawled into icegate.prices" "External"

        # IceGate system
        icegate = softwareSystem "IceGate" "Observability data lake engine storing logs, spans, events, metrics and LLM operations in Apache Iceberg" {

            # ---------------------------------------------------------------
            # Services (deployable binaries)
            # ---------------------------------------------------------------
            ingestService = container "Ingest Service" "Receives OTLP, writes the Parquet WAL, and shifts WAL segments into Iceberg" "Rust / Axum / Tonic" {
                otlpHttpHandler = component "OTLP HTTP Handler" "Receives OTLP over HTTP/protobuf on :4318 and reports partial success" "Axum"
                otlpGrpcHandler = component "OTLP gRPC Handler" "Receives OTLP over gRPC on :4317 and reports partial success" "Tonic"
                recordTransformer = component "Record Transformer" "Converts OTLP logs, spans, metrics and LLM operations into Arrow RecordBatches" "Rust / Arrow"
                walWriter = component "WAL Writer" "Sorts batches by the table sort order and submits them to the queue" "Rust"
                shiftPlanner = component "Shift Planner" "Groups WAL segments into per-table shift plans and schedules them as jobs" "Rust / jobmanager"
                shiftExecutor = component "Shift Executor" "K-way merges sorted WAL row groups into Iceberg data files" "Rust / Parquet"
                commitRunner = component "Commit Runner" "Commits shifted data files as an Iceberg snapshot carrying the WAL offset" "Rust / Iceberg"
            }

            queryService = container "Query Service" "Loki, Prometheus, Tempo and Arrow Flight SQL APIs over the merged WAL and Iceberg view" "Rust / Axum / Tonic / DataFusion" {
                lokiApi = component "Loki API" "LogQL query and label endpoints on :3100" "Axum"
                prometheusApi = component "Prometheus API" "PromQL routes on :9090; handlers still return 501 Not Implemented" "Axum"
                tempoApi = component "Tempo API" "TraceQL search and trace-by-id endpoints on :3200" "Axum"
                flightSqlServer = component "Flight SQL Server" "Read-only Arrow Flight SQL on :8815; tenant taken from x-scope-orgid" "Tonic / Arrow Flight SQL"
                logqlEngine = component "LogQL Parser and Planner" "Parses LogQL and lowers it into DataFusion plans" "Rust"
                traceqlEngine = component "TraceQL Parser and Planner" "Parses TraceQL and lowers it into DataFusion plans" "Rust"
                tenantCatalog = component "Tenant Catalog" "Enforces row-level tenant_id and hides the column from SQL sessions" "Rust"
                queryEngine = component "Query Engine" "DataFusion session whose catalog provider merges WAL segments with Iceberg tables at the committed WAL offset" "DataFusion"
            }

            maintainService = container "Maintain Service" "Schema migrations plus long-running compaction, orphan GC and pricing jobs" "Rust / CLI / jobmanager" {
                migrator = component "Schema Migrator" "Creates the Iceberg tables (maintain migrate create)" "Rust / Iceberg"
                dataCompactor = component "Data Compactor" "Rewrites small Parquet data files into fewer, larger sorted ones" "Rust / jobmanager"
                manifestCompactor = component "Manifest Compactor" "Rewrites fragmented Iceberg manifests" "Rust / Iceberg"
                orphanGc = component "Orphan GC" "Deletes objects the current table metadata no longer references, past a grace period" "Rust / jobmanager"
                pricingCrawler = component "Pricing Crawler" "Crawls LLM rate cards and appends changed rates to icegate.prices" "Rust / reqwest"
            }

            # ---------------------------------------------------------------
            # Libraries linked into the services
            # ---------------------------------------------------------------
            s3Catalog = container "S3 Catalog" "Iceberg catalog held in a root.json object updated by compare-and-swap. Default backend, linked into every service, optionally served standalone as an Iceberg REST API on :8181" "Rust Library / Axum" "Library" {
                catalogRestApi = component "Catalog REST API" "Iceberg REST /v1 config, namespace and table endpoints" "Axum"
                catalogService = component "Catalog Service" "iceberg::Catalog implementation over the root.json state" "Rust"
                catalogCache = component "Cached Storage" "Conditional-read root cache plus an LRU of immutable table metadata" "Rust"
                catalogStorage = component "S3 Catalog Storage" "Conditional reads and CAS writes of catalog objects, with retries" "Rust / AWS SDK"
            }

            queueLib = container "Queue Library" "Durable Parquet WAL on object storage with exactly-once, offset-ordered writes" "Rust Library" "Library" {
                queueChannel = component "Write Channel" "Bounded channel that sheds load with a retryable 429 instead of buffering to OOM" "Rust / Tokio"
                queueAccumulator = component "Accumulator" "Batches rows until the flush size or interval is reached" "Rust"
                queueWriter = component "Queue Writer" "Writes Parquet segments with If-None-Match for exactly-once semantics" "Rust / Parquet"
                queueReader = component "Queue Reader" "Reads Parquet segments and caches parsed metadata" "Rust / Parquet"
            }

            commonLib = container "Common Library" "Table schemas, catalog and storage builders, foyer read cache, sort-merge primitives, memory-pressure guard, metrics and tracing" "Rust Library" "Library"

            # ---------------------------------------------------------------
            # Object storage
            # ---------------------------------------------------------------
            queueStorage = container "Queue Storage (WAL)" "Parquet WAL segments, reclaimed by an object lifecycle rule rather than deleted by IceGate" "RustFS / S3" "Database"
            icebergStorage = container "Iceberg Storage" "Iceberg data files, manifests and table metadata" "RustFS / S3" "Database"
            catalogStore = container "Catalog Store" "Catalog state: root.json on S3 by default, or an external Nessie, AWS Glue or S3 Tables catalog" "S3 / Nessie / Glue / S3 Tables" "Catalog"
            jobStore = container "Job State Store" "jobmanager job and task state for shift, compaction, GC and pricing" "RustFS / S3" "Database"
        }

        # Relationships - external to IceGate
        otelCollector -> icegate.ingestService "Sends OTLP logs, spans and metrics" "HTTP :4318 / gRPC :4317"
        grafana -> icegate.queryService "Queries logs and traces, tenant from X-Scope-OrgID" "HTTP :3100 / :3200"
        sqlClients -> icegate.queryService "Runs read-only SQL" "Arrow Flight SQL :8815"

        # The same edges at component granularity, so the component and dynamic
        # views show where a request actually lands. Structurizr keeps the
        # container-level relationship above for the container and context
        # views rather than drawing a second arrow.
        otelCollector -> icegate.ingestService.otlpHttpHandler "Sends OTLP data" "HTTP :4318"
        otelCollector -> icegate.ingestService.otlpGrpcHandler "Sends OTLP data" "gRPC :4317"
        grafana -> icegate.queryService.lokiApi "Queries logs" "HTTP :3100"
        grafana -> icegate.queryService.tempoApi "Queries traces" "HTTP :3200"
        sqlClients -> icegate.queryService.flightSqlServer "Runs read-only SQL" "Arrow Flight SQL :8815"
        prometheusServer -> icegate.ingestService "Scrapes metrics" "HTTP :9091"
        prometheusServer -> icegate.queryService "Scrapes metrics" "HTTP :9091"
        prometheusServer -> icegate.maintainService "Scrapes metrics" "HTTP :9091"
        trino -> icegate.catalogStore "Reads table metadata (REST catalog only)" "Iceberg REST"
        trino -> icegate.icebergStorage "Reads data files" "S3"

        # Relationships - IceGate to external
        icegate.ingestService -> tracingBackend "Exports its own traces" "OTLP"
        icegate.queryService -> tracingBackend "Exports its own traces" "OTLP"
        icegate.maintainService -> tracingBackend "Exports its own traces" "OTLP"
        icegate.maintainService -> pricingFeeds "Fetches LLM rate cards" "HTTPS"

        # Relationships - services to libraries
        icegate.ingestService -> icegate.queueLib "Writes and reads WAL segments" "Rust API"
        icegate.ingestService -> icegate.s3Catalog "Loads and commits table metadata" "Rust API"
        icegate.ingestService -> icegate.commonLib "Schemas, storage, sort-merge, memory guard" "Rust API"

        icegate.queryService -> icegate.queueLib "Reads WAL segments" "Rust API"
        icegate.queryService -> icegate.s3Catalog "Loads table metadata" "Rust API"
        icegate.queryService -> icegate.commonLib "Schemas, cached storage, memory guard" "Rust API"

        icegate.maintainService -> icegate.s3Catalog "Creates tables and commits snapshots" "Rust API"
        icegate.maintainService -> icegate.commonLib "Schemas, storage, manifest scan, sort-merge" "Rust API"

        # Relationships - services to storage
        icegate.ingestService -> icegate.icebergStorage "Writes shifted data files" "S3"
        icegate.ingestService -> icegate.jobStore "Persists shift job state" "S3"
        icegate.queryService -> icegate.icebergStorage "Reads data files through the foyer cache" "S3"
        icegate.maintainService -> icegate.icebergStorage "Rewrites and deletes data files" "S3"
        icegate.maintainService -> icegate.jobStore "Persists compaction, GC and pricing job state" "S3"

        icegate.queueLib -> icegate.queueStorage "Reads and writes Parquet segments" "S3"
        icegate.s3Catalog -> icegate.catalogStore "Reads and CAS-writes catalog state" "S3"

        # Component relationships - Ingest Service
        icegate.ingestService.otlpHttpHandler -> icegate.ingestService.recordTransformer "Decoded OTLP request" "Rust"
        icegate.ingestService.otlpGrpcHandler -> icegate.ingestService.recordTransformer "Decoded OTLP request" "Rust"
        icegate.ingestService.recordTransformer -> icegate.ingestService.walWriter "RecordBatch per signal" "Rust"
        icegate.ingestService.walWriter -> icegate.queueLib.queueChannel "Submits sorted row groups" "Rust API"
        icegate.ingestService.shiftPlanner -> icegate.queueLib.queueReader "Lists WAL segments and their bounds" "Rust API"
        icegate.ingestService.shiftPlanner -> icegate.jobStore "Persists plan and shift tasks" "S3"
        icegate.ingestService.shiftPlanner -> icegate.ingestService.shiftExecutor "Shift tasks" "Rust"
        icegate.ingestService.shiftExecutor -> icegate.queueLib.queueReader "Reads sorted row groups" "Rust API"
        icegate.ingestService.shiftExecutor -> icegate.icebergStorage "Writes Iceberg data files" "S3"
        icegate.ingestService.shiftExecutor -> icegate.ingestService.commitRunner "Written data files" "Rust"
        icegate.ingestService.commitRunner -> icegate.s3Catalog.catalogService "Commits a snapshot with the WAL offset" "Rust API"

        # Component relationships - Queue Library
        icegate.queueLib.queueChannel -> icegate.queueLib.queueAccumulator "Write requests" "Rust"
        icegate.queueLib.queueAccumulator -> icegate.queueLib.queueWriter "Flushed batches" "Rust"
        icegate.queueLib.queueWriter -> icegate.queueStorage "Writes Parquet segments" "S3"
        icegate.queueLib.queueReader -> icegate.queueStorage "Reads Parquet segments" "S3"

        # Component relationships - Query Service
        icegate.queryService.lokiApi -> icegate.queryService.logqlEngine "LogQL query" "Rust"
        icegate.queryService.tempoApi -> icegate.queryService.traceqlEngine "TraceQL query" "Rust"
        icegate.queryService.flightSqlServer -> icegate.queryService.tenantCatalog "SQL statement and tenant" "Rust"
        icegate.queryService.logqlEngine -> icegate.queryService.queryEngine "DataFusion plan" "Rust"
        icegate.queryService.traceqlEngine -> icegate.queryService.queryEngine "DataFusion plan" "Rust"
        icegate.queryService.tenantCatalog -> icegate.queryService.queryEngine "Tenant-scoped session" "Rust"
        icegate.queryService.queryEngine -> icegate.queueLib.queueReader "Reads WAL segments past the committed offset" "Rust API"
        icegate.queryService.queryEngine -> icegate.s3Catalog.catalogService "Loads table metadata" "Rust API"
        icegate.queryService.queryEngine -> icegate.icebergStorage "Reads data files" "S3"

        # Component relationships - Maintain Service
        icegate.maintainService.migrator -> icegate.s3Catalog.catalogService "Creates the icegate tables" "Rust API"
        icegate.maintainService.migrator -> icegate.icebergStorage "Writes initial table metadata" "S3"
        icegate.maintainService.dataCompactor -> icegate.icebergStorage "Rewrites small data files" "S3"
        icegate.maintainService.dataCompactor -> icegate.s3Catalog.catalogService "Commits rewrite snapshots" "Rust API"
        icegate.maintainService.dataCompactor -> icegate.jobStore "Persists compaction job state" "S3"
        icegate.maintainService.manifestCompactor -> icegate.icebergStorage "Rewrites manifests" "S3"
        icegate.maintainService.manifestCompactor -> icegate.s3Catalog.catalogService "Commits rewritten manifests" "Rust API"
        icegate.maintainService.orphanGc -> icegate.s3Catalog.catalogService "Reads the referenced file set" "Rust API"
        icegate.maintainService.orphanGc -> icegate.icebergStorage "Lists and deletes unreferenced objects" "S3"
        icegate.maintainService.orphanGc -> icegate.jobStore "Persists GC job state" "S3"
        icegate.maintainService.pricingCrawler -> pricingFeeds "Fetches rate cards" "HTTPS"
        icegate.maintainService.pricingCrawler -> icegate.s3Catalog.catalogService "Appends changed rates to icegate.prices" "Rust API"
        icegate.maintainService.pricingCrawler -> icegate.jobStore "Persists crawler job state" "S3"

        # Component relationships - S3 Catalog
        icegate.s3Catalog.catalogRestApi -> icegate.s3Catalog.catalogService "Catalog operations" "Rust"
        icegate.s3Catalog.catalogService -> icegate.s3Catalog.catalogCache "Loads and saves catalog state" "Rust"
        icegate.s3Catalog.catalogCache -> icegate.s3Catalog.catalogStorage "Conditional reads, CAS writes" "Rust"
        icegate.s3Catalog.catalogStorage -> icegate.catalogStore "root.json and table metadata" "S3"
    }

    views {
        systemContext icegate "SystemContext" "System Context diagram" {
            include *
            autoLayout
        }

        container icegate "Containers" "Container diagram" {
            include *
            autoLayout
        }

        component icegate.ingestService "IngestComponents" "Ingest Service components" {
            include *
            autoLayout
        }

        component icegate.queryService "QueryComponents" "Query Service components" {
            include *
            autoLayout
        }

        component icegate.queueLib "QueueComponents" "Queue Library components" {
            include *
            autoLayout
        }

        component icegate.maintainService "MaintainComponents" "Maintain Service components" {
            include *
            autoLayout
        }

        component icegate.s3Catalog "CatalogComponents" "S3 Catalog components" {
            include *
            autoLayout
        }

        # Process views. Each renders as a UML sequence diagram rather than the
        # default numbered box layout — `plantuml.sequenceDiagram` is what
        # switches the exporter over, and the box layout turns into unreadable
        # long-arc spaghetti once a flow passes ten steps. `autoLayout` stays as
        # the fallback for anyone who turns the property off.
        # A dynamic view may reuse a model relationship with a step-specific
        # description, but the relationship itself must already exist in the
        # model — the DSL fails the build otherwise.
        dynamic icegate.ingestService "IngestionFlow" "Ingestion: from an OTLP request to a committed Iceberg snapshot" {
            otelCollector -> icegate.ingestService.otlpHttpHandler "Posts an OTLP export request"
            icegate.ingestService.otlpHttpHandler -> icegate.ingestService.recordTransformer "Decoded resource/scope/record tree"
            icegate.ingestService.recordTransformer -> icegate.ingestService.walWriter "One Arrow RecordBatch per signal"
            icegate.ingestService.walWriter -> icegate.queueLib.queueChannel "Row groups sorted by the table sort order"
            icegate.queueLib.queueChannel -> icegate.queueLib.queueAccumulator "Write request, or a retryable 429 when full"
            icegate.queueLib.queueAccumulator -> icegate.queueLib.queueWriter "Batch, at the flush size or interval"
            icegate.queueLib.queueWriter -> icegate.queueStorage "Writes the segment with If-None-Match, then the request is acknowledged"
            icegate.ingestService.shiftPlanner -> icegate.queueLib.queueReader "Lists segments past the last committed offset"
            icegate.ingestService.shiftPlanner -> icegate.jobStore "Claims a shift task by compare-and-swap"
            icegate.ingestService.shiftPlanner -> icegate.ingestService.shiftExecutor "Dispatches the shift task"
            icegate.ingestService.shiftExecutor -> icegate.queueLib.queueReader "Reads the task's sorted row groups"
            icegate.ingestService.shiftExecutor -> icegate.icebergStorage "Writes k-way merged Iceberg data files"
            icegate.ingestService.shiftExecutor -> icegate.ingestService.commitRunner "Hands over the written data files"
            icegate.ingestService.commitRunner -> icegate.s3Catalog.catalogService "Commits a snapshot recording the WAL offset"
            autoLayout
            properties {
                "plantuml.sequenceDiagram" "true"
            }
        }

        dynamic icegate.queryService "QueryFlow" "Query: from a LogQL request to a merged WAL and Iceberg result" {
            grafana -> icegate.queryService.lokiApi "Sends a LogQL range query with X-Scope-OrgID"
            icegate.queryService.lokiApi -> icegate.queryService.logqlEngine "Raw LogQL expression"
            icegate.queryService.logqlEngine -> icegate.queryService.queryEngine "Parsed AST, lowered to a DataFusion plan"
            icegate.queryService.queryEngine -> icegate.s3Catalog.catalogService "Loads the current table metadata"
            icegate.s3Catalog.catalogService -> icegate.s3Catalog.catalogCache "Requests the catalog root"
            icegate.s3Catalog.catalogCache -> icegate.s3Catalog.catalogStorage "Conditional read; Not Modified serves the cached root"
            icegate.s3Catalog.catalogStorage -> icegate.catalogStore "Reads root.json and table metadata"
            icegate.queryService.queryEngine -> icegate.icebergStorage "Scans matching data files through the foyer cache"
            icegate.queryService.queryEngine -> icegate.queueLib.queueReader "Reads WAL segments past the committed offset"
            icegate.queueLib.queueReader -> icegate.queueStorage "Reads segments; merged with the Iceberg side"
            autoLayout
            properties {
                "plantuml.sequenceDiagram" "true"
            }
        }

        # The three loops below are independent and run on their own schedules;
        # the step numbers order each loop, not the loops against each other.
        # Structurizr's parallel-block syntax is deliberately not used: the
        # PlantUML exporters flatten it to duplicate step numbers with no
        # visual grouping, which reads as a single pipeline — worse than
        # naming the loop in every step description.
        dynamic icegate.maintainService "MaintenanceFlow" "Maintenance: a one-shot migration, then three job loops on independent schedules" {
            icegate.maintainService.migrator -> icegate.s3Catalog.catalogService "Migration (one-shot): creates the icegate tables"
            icegate.maintainService.dataCompactor -> icegate.jobStore "Compaction loop: claims a task by compare-and-swap"
            icegate.maintainService.dataCompactor -> icegate.icebergStorage "Compaction loop: rewrites small data files into larger sorted ones"
            icegate.maintainService.dataCompactor -> icegate.s3Catalog.catalogService "Compaction loop: commits a rewrite snapshot"
            icegate.maintainService.manifestCompactor -> icegate.icebergStorage "Compaction loop: repacks fragmented manifests"
            icegate.maintainService.manifestCompactor -> icegate.s3Catalog.catalogService "Compaction loop: commits the rewritten manifest list"
            icegate.maintainService.orphanGc -> icegate.jobStore "GC loop: claims a sweep task"
            icegate.maintainService.orphanGc -> icegate.s3Catalog.catalogService "GC loop: reads the set of referenced files"
            icegate.maintainService.orphanGc -> icegate.icebergStorage "GC loop: deletes unreferenced objects past the grace period"
            icegate.maintainService.pricingCrawler -> icegate.jobStore "Pricing loop: claims a crawl task"
            icegate.maintainService.pricingCrawler -> pricingFeeds "Pricing loop: fetches the OpenRouter and LiteLLM rate cards"
            icegate.maintainService.pricingCrawler -> icegate.s3Catalog.catalogService "Pricing loop: appends changed rates to icegate.prices"
            autoLayout
            properties {
                "plantuml.sequenceDiagram" "true"
            }
        }

        styles {
            element "Software System" {
                background #1168bd
                color #ffffff
            }
            element "External" {
                background #999999
                color #ffffff
            }
            element "Container" {
                background #438dd5
                color #ffffff
            }
            element "Component" {
                background #85bbf0
                color #000000
            }
            element "Library" {
                shape Component
            }
            element "Database" {
                shape Cylinder
            }
            element "Catalog" {
                shape Pipe
            }
        }
    }
}
