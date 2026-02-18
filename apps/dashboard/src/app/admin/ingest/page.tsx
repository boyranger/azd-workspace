import { requireProfile } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function AdminIngestPage() {
  const profile = await requireProfile("staff");
  const supabase = await createClient();

  const now = Date.now();
  const last5m = new Date(now - 5 * 60 * 1000).toISOString();
  const last1h = new Date(now - 60 * 60 * 1000).toISOString();

  const [{ count: count5m }, { count: count1h }, { data: latestRows }] = await Promise.all([
    supabase
      .from("telemetry")
      .select("id", { count: "exact", head: true })
      .eq("tenant_id", profile.tenant_id)
      .gte("ingested_at", last5m),
    supabase
      .from("telemetry")
      .select("id", { count: "exact", head: true })
      .eq("tenant_id", profile.tenant_id)
      .gte("ingested_at", last1h),
    supabase
      .from("telemetry")
      .select("id,topic,device_id,ingested_at,payload_text")
      .eq("tenant_id", profile.tenant_id)
      .order("ingested_at", { ascending: false })
      .limit(20)
  ]);

  const telemetry5m = count5m ?? 0;
  const telemetry1h = count1h ?? 0;
  const perMinuteEstimate = Math.round(telemetry5m / 5);
  const latestIngestedAt = latestRows?.[0]?.ingested_at || null;
  const health =
    telemetry5m > 0 ? "healthy" : telemetry1h > 0 ? "degraded" : "stale";

  return (
    <div className="grid">
      <section className="card">
        <h2>Ingest Throughput</h2>
        <p>Tenant: {profile.tenant_id}</p>
        <p>
          Health:{" "}
          <strong
            style={{
              color: health === "healthy" ? "green" : health === "degraded" ? "darkorange" : "crimson"
            }}
          >
            {health}
          </strong>
        </p>
        <p>Last ingested at: {latestIngestedAt ? new Date(latestIngestedAt).toLocaleString() : "-"}</p>
        <p>Telemetry last 5m: {telemetry5m}</p>
        <p>Telemetry last 1h: {telemetry1h}</p>
        <p>Estimated/min (5m window): {perMinuteEstimate}</p>
      </section>

      <section className="card">
        <h2>Recent Ingest Events</h2>
        {!latestRows || latestRows.length === 0 ? (
          <p>No telemetry rows found.</p>
        ) : (
          <table style={{ width: "100%", borderCollapse: "collapse" }}>
            <thead>
              <tr>
                <th align="left">Ingested At</th>
                <th align="left">Device</th>
                <th align="left">Topic</th>
                <th align="left">Payload</th>
              </tr>
            </thead>
            <tbody>
              {latestRows.map((row) => (
                <tr key={row.id}>
                  <td>{new Date(row.ingested_at).toLocaleString()}</td>
                  <td>{row.device_id || "-"}</td>
                  <td>{row.topic}</td>
                  <td>{(row.payload_text || "").slice(0, 120)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>
    </div>
  );
}
