# Production Deployment Guide with OpenTelemetry

This guide covers deploying XiansAi Server in production with full observability using OpenTelemetry Collector.

## Architecture

```
┌─────────────────┐
│  XiansAi.Server │
│   (Port 5001)   │
└────────┬────────┘
         │ OTLP
         │ (port 4317)
         ▼
┌─────────────────────┐
│  OTEL Collector     │
│   (Port 4317/4318)  │
└──┬────────┬─────┬───┘
   │        │     │
   ▼        ▼     ▼
┌─────┐ ┌─────┐ ┌──────┐
│Prom │ │Jaeger│ │Grafana│
│8889 │ │ 4317│ │ Cloud │
└─────┘ └─────┘ └──────┘
```

## Quick Start

### 1. Create Production Environment File

```bash
cd community-edition

# Copy the example file
cp server/.env.production.example server/.env.production

# Edit with your values
nano server/.env.production
```

### 2. Configure OpenTelemetry

In `server/.env.production`:

```bash
# Enable OpenTelemetry
OpenTelemetry__Enabled=true
OpenTelemetry__ServiceName=XiansAi.Server
OpenTelemetry__OtlpEndpoint=http://otel-collector:4317
```

### 3. Deploy with OTEL Collector

```bash
# Basic production setup (Server + MongoDB + OTEL Collector)
docker-compose -f docker-compose.production.yml up -d

# With Prometheus and Grafana
docker-compose -f docker-compose.production.yml --profile monitoring up -d
```

### 4. Access Services

- **XiansAi Server**: http://localhost:5001
- **Prometheus** (if enabled): http://localhost:9090
- **Grafana** (if enabled): http://localhost:3000
- **OTEL Collector Metrics**: http://localhost:8888/metrics

## OTEL Collector Configuration

The collector is configured in `otel/otel-collector-config.yaml`.

### Default Exporters

By default, the collector exports to:
1. **Debug** - Console output for troubleshooting
2. **Prometheus** - Exposes metrics on port 8889

### Enable Additional Exporters

#### Option 1: Grafana Cloud

1. Get your API key from Grafana Cloud
2. Edit `otel/otel-collector-config.yaml`:
   ```yaml
   exporters:
     otlp/grafana:
       endpoint: tempo-prod-01-us-central-0.grafana.net:443
       headers:
         authorization: Basic ${env:GRAFANA_CLOUD_API_KEY}
   ```
3. Add to pipelines:
   ```yaml
   service:
     pipelines:
       traces:
         exporters: [debug, prometheus, otlp/grafana]
       metrics:
         exporters: [debug, prometheus, otlp/grafana]
   ```
4. Set environment variable:
   ```bash
   # In .env or docker-compose.production.yml
   GRAFANA_CLOUD_API_KEY=your-api-key-here
   ```

#### Option 2: Jaeger (Self-hosted)

1. Edit `otel/otel-collector-config.yaml`:
   ```yaml
   exporters:
     otlp/jaeger:
       endpoint: jaeger:4317
       tls:
         insecure: true
   ```
2. Add to traces pipeline:
   ```yaml
   service:
     pipelines:
       traces:
         exporters: [debug, prometheus, otlp/jaeger]
   ```
3. Deploy Jaeger:
   ```bash
   docker run -d --name jaeger \
     --network xians-production-network \
     -p 16686:16686 \
     -p 4317:4317 \
     jaegertracing/all-in-one:latest
   ```

#### Option 3: Generic OTLP Endpoint (Honeycomb, Lightstep, etc.)

1. Edit `otel/otel-collector-config.yaml`:
   ```yaml
   exporters:
     otlphttp:
       endpoint: ${env:OTLP_HTTP_ENDPOINT}
       headers:
         authorization: Bearer ${env:OTLP_HTTP_AUTH_TOKEN}
   ```
2. Set environment variables:
   ```bash
   OTLP_HTTP_ENDPOINT=https://api.honeycomb.io
   OTLP_HTTP_AUTH_TOKEN=your-api-key
   ```

## Prometheus + Grafana Setup

### Start with Monitoring Stack

```bash
docker-compose -f docker-compose.production.yml --profile monitoring up -d
```

### Access Grafana

1. Open http://localhost:3000
2. Login: `admin` / `admin` (change on first login)
3. Add Prometheus data source:
   - URL: `http://prometheus:9090`
   - Save & Test

### Import Dashboards

1. In Grafana, go to **Dashboards** → **Import**
2. Enter dashboard IDs:
   - **ASP.NET Core**: 10915
   - **OpenTelemetry**: 15983
   - **.NET Runtime**: 12486

## Security Considerations

### 1. Disable Debug Exporter

In production, remove or comment out the debug exporter:

```yaml
# exporters:
#   debug:
#     verbosity: normal
```

### 2. Enable Authentication

For Prometheus and Grafana, use strong passwords:

```yaml
# In docker-compose.production.yml
environment:
  - GF_SECURITY_ADMIN_PASSWORD=strong-password-here
```

### 3. Use TLS

For external exporters, always use TLS:

```yaml
exporters:
  otlp/grafana:
    tls:
      insecure: false  # Require TLS
```

## Monitoring the OTEL Collector

### Health Check

```bash
curl http://localhost:8888/
```

### Collector Metrics

```bash
# View collector's own metrics
curl http://localhost:8888/metrics
```

### Logs

```bash
docker logs xians-otel-collector
```

## Scaling Considerations

### Collector Resource Limits

Adjust in `docker-compose.production.yml`:

```yaml
deploy:
  resources:
    limits:
      memory: 1G  # Increase for high-volume
    reservations:
      memory: 512M
```

### Batch Size

Adjust in `otel/otel-collector-config.yaml`:

```yaml
processors:
  batch:
    send_batch_size: 2048  # Increase for efficiency
    send_batch_max_size: 4096
```

### Multiple Collectors

For high availability, deploy multiple collectors behind a load balancer:

```bash
# Point server to load balancer
OpenTelemetry__OtlpEndpoint=http://collector-lb:4317
```

## Troubleshooting

### No telemetry in backends

1. **Check collector logs**:
   ```bash
   docker logs xians-otel-collector
   ```

2. **Verify server is sending data**:
   ```bash
   docker logs xians-server-prod | grep OpenTelemetry
   # Should see: [OpenTelemetry] OpenTelemetry enabled - exporting to http://otel-collector:4317
   ```

3. **Test OTLP endpoint**:
   ```bash
   # From server container
   docker exec xians-server-prod curl -v http://otel-collector:4317
   ```

### High memory usage

1. **Enable memory limiter**:
   ```yaml
   processors:
     memory_limiter:
       limit_mib: 512
   ```

2. **Reduce batch size**:
   ```yaml
   processors:
     batch:
       send_batch_size: 512
   ```

### Slow export

1. **Increase batch timeout**:
   ```yaml
   processors:
     batch:
       timeout: 5s  # Reduce from 10s
   ```

2. **Check exporter health**:
   ```bash
   # Check if Prometheus is reachable
   docker exec xians-otel-collector wget -O- http://prometheus:9090/-/healthy
   ```

## Cost Optimization

### Sampling

For high-volume applications, enable sampling:

```yaml
processors:
  probabilistic_sampler:
    sampling_percentage: 10  # Sample 10% of traces

service:
  pipelines:
    traces:
      processors: [probabilistic_sampler, batch]
```

### Tail Sampling

Keep all error traces, sample success traces:

```yaml
processors:
  tail_sampling:
    policies:
      - name: errors
        type: status_code
        status_code: {status_codes: [ERROR]}
      - name: slow
        type: latency
        latency: {threshold_ms: 1000}
      - name: random
        type: probabilistic
        probabilistic: {sampling_percentage: 5}
```

## Backup Configuration

Always keep backups of:
1. `otel/otel-collector-config.yaml`
2. `server/.env.production`
3. `docker-compose.production.yml`

## Next Steps

1. ✅ Configure your observability backends
2. ✅ Set up alerting in Prometheus/Grafana
3. ✅ Create custom dashboards
4. ✅ Configure sampling for cost optimization
5. ✅ Set up log aggregation (optional)

## Resources

- [OTEL Collector Docs](https://opentelemetry.io/docs/collector/)
- [Prometheus Configuration](https://prometheus.io/docs/prometheus/latest/configuration/configuration/)
- [Grafana Docs](https://grafana.com/docs/)





