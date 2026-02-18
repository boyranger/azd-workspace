import { requireProfile } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function AdminOverviewPage() {
  const profile = await requireProfile("staff");
  const supabase = await createClient();

  const [{ count: deviceCount }, { count: telemetryCount }] = await Promise.all([
    supabase
      .from("devices")
      .select("id", { count: "exact", head: true })
      .eq("tenant_id", profile.tenant_id),
    supabase
      .from("telemetry")
      .select("id", { count: "exact", head: true })
      .eq("tenant_id", profile.tenant_id)
  ]);

  return (
    <div className="grid">
      <section className="card">
        <h2>Tenant</h2>
        <p>{profile.tenant_id}</p>
      </section>
      <section className="card">
        <h2>Devices</h2>
        <p>{deviceCount ?? 0}</p>
      </section>
      <section className="card">
        <h2>Telemetry Rows</h2>
        <p>{telemetryCount ?? 0}</p>
      </section>
    </div>
  );
}
