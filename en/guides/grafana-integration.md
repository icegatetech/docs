---
title: Grafana Integration
description: Set up Grafana to query logs, traces, and metrics from IceGate
---

# Grafana Integration

This guide covers connecting Grafana to all three {{product_name}} query APIs: Loki (logs), Tempo (traces), and Prometheus (metrics).

## Prerequisites

- {{product_name}} Query service running (see [Installation](../getting-started/installation.md))
- Grafana 10+ ([grafana.com/oss](https://grafana.com/oss/grafana/))

## Verify Query Service Health

Before configuring Grafana, verify that the Query service is ready:

```bash
# Check Loki API (port 3100)
curl http://localhost:3100/ready

# Check Tempo API (port 3200)
curl http://localhost:3200/ready

# Check Prometheus API (port 9090)
curl http://localhost:9090/-/ready
```

All endpoints should return HTTP 200.

## Add Data Sources

### Loki Data Source (Logs)

{{product_name}} implements the Grafana Loki API on port **3100**.

1. Go to **Connections** > **Data sources** > **Add data source**
2. Select **Loki**
3. Configure:
   - **URL:** `http://icegate-query:3100`
   - Under **HTTP Headers**, add:
     - Header: `X-Scope-OrgID`
     - Value: your tenant ID (e.g., `default`)
4. Click **Save & Test**

#### Provisioning YAML

```yaml
# grafana/provisioning/datasources/icegate-loki.yaml
apiVersion: 1
datasources:
  - name: IceGate Logs
    type: loki
    access: proxy
    url: http://icegate-query:3100
    jsonData:
      httpHeaderName1: X-Scope-OrgID
    secureJsonData:
      httpHeaderValue1: default
    isDefault: true
```

### Tempo Data Source (Traces)

{{product_name}} implements the Grafana Tempo API on port **3200**.

{% note warning %}

The Tempo API provides basic trace retrieval and search. TraceQL support is planned for future releases.

{% endnote %}

1. Go to **Connections** > **Data sources** > **Add data source**
2. Select **Tempo**
3. Configure:
   - **URL:** `http://icegate-query:3200`
   - Under **HTTP Headers**, add:
     - Header: `X-Scope-OrgID`
     - Value: your tenant ID
4. Click **Save & Test**

#### Provisioning YAML

```yaml
# grafana/provisioning/datasources/icegate-tempo.yaml
apiVersion: 1
datasources:
  - name: IceGate Traces
    type: tempo
    access: proxy
    url: http://icegate-query:3200
    jsonData:
      httpHeaderName1: X-Scope-OrgID
      tracesToLogs:
        datasourceUid: icegate-loki
        tags: ['service.name']
        mappedTags: [{ key: 'service.name', value: 'service_name' }]
        mapTagNamesEnabled: true
        filterByTraceID: true
        filterBySpanID: false
    secureJsonData:
      httpHeaderValue1: default
    uid: icegate-tempo
```

### Prometheus Data Source (Metrics)

{{product_name}} implements the Grafana Prometheus API on port **9090**.

{% note warning %}

The Prometheus query API is currently under development. Metadata endpoints (labels, series) are available, but PromQL queries are not yet supported. Use the Loki API with LogQL metric queries as an alternative for log-based metrics.

{% endnote %}

1. Go to **Connections** > **Data sources** > **Add data source**
2. Select **Prometheus**
3. Configure:
   - **URL:** `http://icegate-query:9090`
   - Under **HTTP Headers**, add:
     - Header: `X-Scope-OrgID`
     - Value: your tenant ID
4. Click **Save & Test**

#### Provisioning YAML

```yaml
# grafana/provisioning/datasources/icegate-prometheus.yaml
apiVersion: 1
datasources:
  - name: IceGate Metrics
    type: prometheus
    access: proxy
    url: http://icegate-query:9090
    jsonData:
      httpHeaderName1: X-Scope-OrgID
    secureJsonData:
      httpHeaderValue1: default
    uid: icegate-prometheus
```

## Complete Provisioning Example

Deploy all three data sources at once:

```yaml
# grafana/provisioning/datasources/icegate.yaml
apiVersion: 1
datasources:
  - name: IceGate Logs
    type: loki
    access: proxy
    url: http://icegate-query:3100
    jsonData:
      httpHeaderName1: X-Scope-OrgID
    secureJsonData:
      httpHeaderValue1: default
    isDefault: true
    uid: icegate-loki

  - name: IceGate Traces
    type: tempo
    access: proxy
    url: http://icegate-query:3200
    jsonData:
      httpHeaderName1: X-Scope-OrgID
      tracesToLogs:
        datasourceUid: icegate-loki
        tags: ['service.name']
        mappedTags: [{ key: 'service.name', value: 'service_name' }]
        mapTagNamesEnabled: true
        filterByTraceID: true
    secureJsonData:
      httpHeaderValue1: default
    uid: icegate-tempo

  - name: IceGate Metrics
    type: prometheus
    access: proxy
    url: http://icegate-query:9090
    jsonData:
      httpHeaderName1: X-Scope-OrgID
    secureJsonData:
      httpHeaderValue1: default
    uid: icegate-prometheus
```

## Cross-Signal Navigation

### Logs to Traces

{{product_name}} stores `trace_id` and `span_id` fields in log records. Configure Grafana to link from log lines to traces:

1. In the Loki data source settings, go to **Derived fields**
2. Add a derived field:
   - **Name:** `TraceID`
   - **Regex:** `"trace_id":"([a-fA-F0-9]+)"`
   - **URL:** (leave empty)
   - **Internal link:** Enable, select `IceGate Traces`

Now clicking a trace ID in log results opens the trace view.

### Traces to Logs

In the Tempo data source settings, the `tracesToLogs` configuration (shown in the provisioning YAML above) adds a "Logs for this span" button to the trace view.

## Multi-Tenant Configuration

For environments with multiple tenants, configure separate data sources per tenant:

```yaml
apiVersion: 1
datasources:
  - name: Logs (Team A)
    type: loki
    access: proxy
    url: http://icegate-query:3100
    jsonData:
      httpHeaderName1: X-Scope-OrgID
    secureJsonData:
      httpHeaderValue1: team-a

  - name: Logs (Team B)
    type: loki
    access: proxy
    url: http://icegate-query:3100
    jsonData:
      httpHeaderName1: X-Scope-OrgID
    secureJsonData:
      httpHeaderValue1: team-b
```

For dynamic per-user tenancy, see [Multi-Tenancy](multi-tenancy.md#per-user-tenancy).

## Dashboard Examples

### Log Explorer Dashboard

Create a dashboard with three panels:

1. **Logs panel** — shows raw log entries:
   - Query: `{service_name="my-service"}`
   - Visualization: Logs

2. **Error rate time series** — tracks error frequency:
   - Query: `sum by (service_name) (rate({severity_text="ERROR"}[5m]))`
   - Visualization: Time series

3. **Log volume stat** — shows total log count:
   - Query: `sum(count_over_time({service_name="my-service"}[1h]))`
   - Visualization: Stat

### Trace Explorer

1. Navigate to **Explore** > select **IceGate Traces**
2. Search by service name: enter `service.name=my-service` in the tags field
3. Filter by minimum duration: set `minDuration` to `100ms`
4. Click a trace to view its span waterfall

## Using IceGate as a Drop-In for Existing Grafana

If you have an existing Grafana setup with Loki, you can point it at {{product_name}} by changing only the data source URL:

1. Go to **Connections** > **Data sources**
2. Edit your existing Loki data source
3. Change **URL** from your Loki instance to `http://icegate-query:3100`
4. Add the `X-Scope-OrgID` header if not already present
5. Click **Save & Test**

Your existing dashboards, alerting rules, and saved queries will continue to work because {{product_name}} implements the same Loki API.

{% note info %}

LogQL metric queries (`rate()`, `count_over_time()`, `sum by()`, etc.) are supported. See the [LogQL implementation status](querying.md) for the full compatibility matrix.

{% endnote %}

## Port Reference

| API | Port | Grafana Data Source Type | Status |
|-----|------|--------------------------|--------|
| Loki (logs) | 3100 | Loki | Fully implemented |
| Tempo (traces) | 3200 | Tempo | Basic retrieval and search (TraceQL planned) |
| Prometheus (metrics) | 9090 | Prometheus | Metadata only (PromQL planned) |

## Next Steps

- Learn [LogQL querying](querying.md) for advanced log analysis
- Explore [cross-signal correlation](../cookbooks/observability-correlation.md) across logs and traces
- Set up [multi-tenancy](multi-tenancy.md) for team isolation
