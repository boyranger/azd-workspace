import datetime as dt
import json
import logging
import os
import re
import ssl
import threading
import time
import uuid
from typing import Any, Dict, List

import azure.functions as func
import paho.mqtt.client as mqtt
import psycopg
from psycopg import sql

app = func.FunctionApp()


def _env_bool(name: str, default: bool = False) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


def _collect_mqtt_messages() -> List[Dict[str, Any]]:
    host = os.getenv("MQTT_BROKER_HOST", "")
    port = int(os.getenv("MQTT_BROKER_PORT", "8883"))
    username = os.getenv("MQTT_BROKER_USERNAME", "")
    password = os.getenv("MQTT_BROKER_PASSWORD", "")
    topic = os.getenv("MQTT_TOPIC_FILTER", "#")
    client_id = f"azfunc-ingest-{uuid.uuid4().hex[:12]}"
    window_seconds = int(os.getenv("MQTT_INGEST_WINDOW_SECONDS", "20"))
    use_tls = _env_bool("MQTT_USE_TLS", True)
    tls_insecure = _env_bool("MQTT_TLS_INSECURE", True)
    ca_cert_path = os.getenv("MQTT_CA_CERT_PATH", "")

    if not host:
        raise ValueError("MQTT_BROKER_HOST is required")

    messages: List[Dict[str, Any]] = []
    lock = threading.Lock()
    connected = threading.Event()

    def on_connect(client: mqtt.Client, _userdata: Any, _flags: Dict[str, Any], rc: int, _props: Any = None) -> None:
        if rc == 0:
            connected.set()
            client.subscribe(topic)
        else:
            logging.error("MQTT connect failed rc=%s", rc)

    def on_message(_client: mqtt.Client, _userdata: Any, msg: mqtt.MQTTMessage) -> None:
        payload_text = msg.payload.decode("utf-8", errors="replace")
        record = {
            "received_at": dt.datetime.now(dt.timezone.utc).isoformat(),
            "topic": msg.topic,
            "payload": payload_text,
            "qos": msg.qos,
            "retain": bool(msg.retain),
        }
        with lock:
            messages.append(record)

    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=client_id)
    client.on_connect = on_connect
    client.on_message = on_message

    if username:
        client.username_pw_set(username=username, password=password)

    if use_tls:
        if ca_cert_path:
            client.tls_set(ca_certs=ca_cert_path)
        elif tls_insecure:
            client.tls_set(cert_reqs=ssl.CERT_NONE)
            client.tls_insecure_set(True)
        else:
            client.tls_set()

    client.connect(host, port, keepalive=30)
    client.loop_start()

    try:
        if not connected.wait(timeout=10):
            raise TimeoutError("MQTT connect timeout")
        time.sleep(max(window_seconds, 1))
    finally:
        client.loop_stop()
        client.disconnect()

    return messages


def _send_to_supabase(records: List[Dict[str, Any]]) -> None:
    if not records:
        return

    database_url = os.getenv("EXTERNAL_DATABASE_CONNECTION_STRING", "")
    table_name = os.getenv("SUPABASE_TELEMETRY_TABLE", "telemetry")
    if not database_url:
        raise ValueError("EXTERNAL_DATABASE_CONNECTION_STRING is required")
    if not re.fullmatch(r"[a-zA-Z_][a-zA-Z0-9_]*", table_name):
        raise ValueError("SUPABASE_TELEMETRY_TABLE has invalid format")

    create_stmt = sql.SQL(
        """
        create table if not exists {} (
          id bigserial primary key,
          received_at timestamptz not null,
          topic text not null,
          payload_text text not null,
          payload_json jsonb null,
          qos int not null default 0,
          retain boolean not null default false,
          ingested_at timestamptz not null default now()
        )
        """
    ).format(sql.Identifier(table_name))

    insert_stmt = sql.SQL(
        """
        insert into {} (received_at, topic, payload_text, payload_json, qos, retain)
        values (%s, %s, %s, %s::jsonb, %s, %s)
        """
    ).format(sql.Identifier(table_name))

    rows = []
    for record in records:
        payload_text = str(record.get("payload", ""))
        try:
            payload_json = json.dumps(json.loads(payload_text), ensure_ascii=True)
        except Exception:
            payload_json = None
        rows.append(
            (
                record.get("received_at"),
                str(record.get("topic", "")),
                payload_text,
                payload_json,
                int(record.get("qos", 0)),
                bool(record.get("retain", False)),
            )
        )

    with psycopg.connect(database_url) as conn:
        with conn.cursor() as cur:
            cur.execute(create_stmt)
            cur.executemany(insert_stmt, rows)
        conn.commit()


@app.timer_trigger(schedule="0 */1 * * * *", arg_name="timer", run_on_startup=False, use_monitor=False)
def mqtt_ingest(timer: func.TimerRequest) -> None:
    start = dt.datetime.now(dt.timezone.utc).isoformat()
    logging.info("mqtt_ingest started at %s", start)

    try:
        rows = _collect_mqtt_messages()
        if not rows:
            logging.info("mqtt_ingest: no message collected in this window")
            return

        _send_to_supabase(rows)
        logging.info("mqtt_ingest: pushed %s records to supabase", len(rows))

    except Exception as ex:
        logging.exception("mqtt_ingest failed: %s", ex)
        raise
