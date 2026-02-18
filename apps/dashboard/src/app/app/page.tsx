import { requireProfile } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function TenantOverviewPage() {
  const profile = await requireProfile("viewer");
  const supabase = await createClient();

  const [{ count: deviceCount }, { count: telemetryCount }, { data: latestTelemetry }] = await Promise.all([
    supabase
      .from("devices")
      .select("id", { count: "exact", head: true })
      .eq("tenant_id", profile.tenant_id),
    supabase
      .from("telemetry")
      .select("id", { count: "exact", head: true })
      .eq("tenant_id", profile.tenant_id),
    supabase
      .from("telemetry")
      .select("topic,payload_text,ingested_at")
      .eq("tenant_id", profile.tenant_id)
      .order("ingested_at", { ascending: false })
      .limit(1)
  ]);

  const latest = latestTelemetry?.[0];

  return (
    <div className="grid">
      <section className="card">
        <h2>Device Count</h2>
        <p>{deviceCount ?? 0}</p>
      </section>
      <section className="card">
        <h2>Telemetry Rows</h2>
        <p>{telemetryCount ?? 0}</p>
      </section>
      <section className="card">
        <h2>Latest Telemetry</h2>
        {latest ? (
          <>
            <p><strong>Topic:</strong> {latest.topic}</p>
            <p><strong>At:</strong> {latest.ingested_at}</p>
            <pre style={{ whiteSpace: "pre-wrap" }}>{latest.payload_text}</pre>
          </>
        ) : (
          <p>No telemetry yet for this tenant.</p>
        )}
      </section>
    </div>
  );
}
