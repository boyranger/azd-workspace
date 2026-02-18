# Azure Function: MQTT Ingest

Timer-triggered Azure Function (every minute) that:
1. Connects to MQTT broker for short ingest window.
2. Buffers messages in memory.
3. Inserts batch directly to Supabase PostgreSQL.

## Required App Settings

- `MQTT_BROKER_HOST`
- `MQTT_BROKER_PORT` (default `8883`)
- `MQTT_BROKER_USERNAME`
- `MQTT_BROKER_PASSWORD`
- `MQTT_TOPIC_FILTER` (default `#`)
- `EXTERNAL_DATABASE_CONNECTION_STRING`

## Optional App Settings

- `MQTT_USE_TLS` (`true`/`false`, default `true`)
- `MQTT_TLS_INSECURE` (`true`/`false`, default `true`)
- `MQTT_CA_CERT_PATH` (for trusted CA file on runtime)
- `MQTT_INGEST_WINDOW_SECONDS` (default `20`)
- `SUPABASE_TELEMETRY_TABLE` (default `telemetry`)
- `DB_MAX_RETRIES` (default `3`)
- `DB_RETRY_BASE_SECONDS` (default `1`, exponential backoff)

## Reliability Behavior

- Batch-level dedup in memory by deterministic `dedup_key` (SHA-256).
- DB-level dedup via unique index `dedup_key` + `ON CONFLICT DO NOTHING`.
- DB write retries with exponential backoff for transient `psycopg` errors.
