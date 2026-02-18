import { requireProfile } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import AlertsAdminPanel from "@/components/ui/alerts-admin-panel";

export const dynamic = "force-dynamic";

type AlertRow = {
  id: string;
  name: string;
  metric: "telemetry_last_5m" | "telemetry_last_1h" | "ingest_per_min";
  operator: "gt" | "gte" | "lt" | "lte" | "eq";
  threshold: number;
  enabled: boolean;
  created_at: string;
};

export default async function AdminAlertsPage() {
  const profile = await requireProfile("staff");
  const supabase = await createClient();

  const [{ data, error }, { data: events, error: eventsError }] = await Promise.all([
    supabase
      .from("alerts")
      .select("id,name,metric,operator,threshold,enabled,created_at")
      .eq("tenant_id", profile.tenant_id)
      .order("created_at", { ascending: false }),
    supabase
      .from("alert_events")
      .select("id,alert_id,message,triggered_at")
      .eq("tenant_id", profile.tenant_id)
      .order("triggered_at", { ascending: false })
      .limit(20)
  ]);

  return (
    <div className="grid">
      <section className="card">
        <h2>Alerts</h2>
        <p>Tenant: {profile.tenant_id}</p>
        <p>Role: {profile.role}</p>
      </section>
      {error ? (
        <section className="card">
          <h2>Query Error</h2>
          <p>{error.message}</p>
        </section>
      ) : (
        <AlertsAdminPanel rows={(data || []) as AlertRow[]} />
      )}
      {eventsError ? (
        <section className="card">
          <h2>Events Error</h2>
          <p>{eventsError.message}</p>
        </section>
      ) : (
        <section className="card">
          <h2>Recent Alert Events</h2>
          {!events || events.length === 0 ? (
            <p>No alert events yet.</p>
          ) : (
            <table style={{ width: "100%", borderCollapse: "collapse" }}>
              <thead>
                <tr>
                  <th align="left">Triggered At</th>
                  <th align="left">Alert ID</th>
                  <th align="left">Message</th>
                </tr>
              </thead>
              <tbody>
                {events.map((evt) => (
                  <tr key={evt.id}>
                    <td>{new Date(evt.triggered_at).toLocaleString()}</td>
                    <td>{evt.alert_id}</td>
                    <td>{evt.message}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </section>
      )}
    </div>
  );
}
