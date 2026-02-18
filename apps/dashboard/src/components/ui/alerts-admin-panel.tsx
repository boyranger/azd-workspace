"use client";

import { FormEvent, useState } from "react";

type Metric = "telemetry_last_5m" | "telemetry_last_1h" | "ingest_per_min";
type Operator = "gt" | "gte" | "lt" | "lte" | "eq";

type AlertRow = {
  id: string;
  name: string;
  metric: Metric;
  operator: Operator;
  threshold: number;
  enabled: boolean;
  created_at: string;
};

type Props = {
  rows: AlertRow[];
};

export default function AlertsAdminPanel({ rows }: Props) {
  const [items, setItems] = useState(rows);
  const [name, setName] = useState("");
  const [metric, setMetric] = useState<Metric>("telemetry_last_5m");
  const [operator, setOperator] = useState<Operator>("gt");
  const [threshold, setThreshold] = useState("0");
  const [loading, setLoading] = useState(false);
  const [evalLoading, setEvalLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);

  async function createAlert(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setInfo(null);
    setLoading(true);

    const res = await fetch("/api/admin/alerts", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        name,
        metric,
        operator,
        threshold: Number(threshold),
        enabled: true
      })
    });

    const payload = (await res.json().catch(() => ({}))) as { error?: string; alert?: AlertRow };
    setLoading(false);

    if (!res.ok || !payload.alert) {
      setError(payload.error || "Failed to create alert");
      return;
    }

    setItems((prev) => [payload.alert as AlertRow, ...prev]);
    setName("");
    setThreshold("0");
  }

  async function toggleEnabled(id: string, enabled: boolean) {
    setError(null);
    setInfo(null);
    const res = await fetch(`/api/admin/alerts/${id}`, {
      method: "PATCH",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ enabled: !enabled })
    });
    const payload = (await res.json().catch(() => ({}))) as { error?: string; alert?: AlertRow };
    if (!res.ok || !payload.alert) {
      setError(payload.error || "Failed to update alert");
      return;
    }
    setItems((prev) => prev.map((it) => (it.id === id ? (payload.alert as AlertRow) : it)));
  }

  async function removeAlert(id: string) {
    setError(null);
    setInfo(null);
    const res = await fetch(`/api/admin/alerts/${id}`, { method: "DELETE" });
    const payload = (await res.json().catch(() => ({}))) as { error?: string };
    if (!res.ok) {
      setError(payload.error || "Failed to delete alert");
      return;
    }
    setItems((prev) => prev.filter((it) => it.id !== id));
  }

  async function evaluateAlerts() {
    setError(null);
    setInfo(null);
    setEvalLoading(true);
    const res = await fetch("/api/admin/alerts/evaluate", { method: "POST" });
    const payload = (await res.json().catch(() => ({}))) as {
      error?: string;
      events_created?: number;
      rules_evaluated?: number;
    };
    setEvalLoading(false);
    if (!res.ok) {
      setError(payload.error || "Failed to evaluate alerts");
      return;
    }
    setInfo(`Evaluated ${payload.rules_evaluated ?? 0} rules, created ${payload.events_created ?? 0} events.`);
  }

  return (
    <div className="grid">
      <section className="card">
        <h2>Create Alert</h2>
        <button type="button" onClick={evaluateAlerts} disabled={evalLoading} style={{ marginBottom: 12 }}>
          {evalLoading ? "Evaluating..." : "Run Evaluate Now"}
        </button>
        <form onSubmit={createAlert} style={{ display: "grid", gap: 8, maxWidth: 520 }}>
          <label>
            Name
            <input value={name} onChange={(e) => setName(e.target.value)} required />
          </label>
          <label>
            Metric
            <select value={metric} onChange={(e) => setMetric(e.target.value as Metric)}>
              <option value="telemetry_last_5m">telemetry_last_5m</option>
              <option value="telemetry_last_1h">telemetry_last_1h</option>
              <option value="ingest_per_min">ingest_per_min</option>
            </select>
          </label>
          <label>
            Operator
            <select value={operator} onChange={(e) => setOperator(e.target.value as Operator)}>
              <option value="gt">gt</option>
              <option value="gte">gte</option>
              <option value="lt">lt</option>
              <option value="lte">lte</option>
              <option value="eq">eq</option>
            </select>
          </label>
          <label>
            Threshold
            <input type="number" step="any" value={threshold} onChange={(e) => setThreshold(e.target.value)} required />
          </label>
          <button type="submit" disabled={loading}>
            {loading ? "Saving..." : "Create alert"}
          </button>
        </form>
        {error ? <p style={{ color: "crimson" }}>{error}</p> : null}
        {info ? <p style={{ color: "green" }}>{info}</p> : null}
      </section>

      <section className="card">
        <h2>Alert Rules</h2>
        {items.length === 0 ? (
          <p>No alerts yet.</p>
        ) : (
          <table style={{ width: "100%", borderCollapse: "collapse" }}>
            <thead>
              <tr>
                <th align="left">Name</th>
                <th align="left">Expression</th>
                <th align="left">Enabled</th>
                <th align="left">Action</th>
              </tr>
            </thead>
            <tbody>
              {items.map((row) => (
                <tr key={row.id}>
                  <td>{row.name}</td>
                  <td>
                    {row.metric} {row.operator} {row.threshold}
                  </td>
                  <td>{row.enabled ? "yes" : "no"}</td>
                  <td style={{ display: "flex", gap: 8 }}>
                    <button type="button" onClick={() => toggleEnabled(row.id, row.enabled)}>
                      {row.enabled ? "Disable" : "Enable"}
                    </button>
                    <button type="button" onClick={() => removeAlert(row.id)}>
                      Delete
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>
    </div>
  );
}
