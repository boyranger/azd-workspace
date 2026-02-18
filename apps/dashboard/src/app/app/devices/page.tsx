import { requireProfile } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function TenantDevicesPage() {
  const profile = await requireProfile("viewer");
  const supabase = await createClient();

  const { data: devices } = await supabase
    .from("devices")
    .select("id,name,device_code,status,last_seen_at")
    .eq("tenant_id", profile.tenant_id)
    .order("created_at", { ascending: false })
    .limit(50);

  return (
    <section className="card">
      <h2>My Devices</h2>
      {!devices || devices.length === 0 ? (
        <p>No devices found.</p>
      ) : (
        <table style={{ width: "100%", borderCollapse: "collapse" }}>
          <thead>
            <tr>
              <th align="left">Name</th>
              <th align="left">Code</th>
              <th align="left">Status</th>
              <th align="left">Last Seen</th>
            </tr>
          </thead>
          <tbody>
            {devices.map((d) => (
              <tr key={d.id}>
                <td>{d.name}</td>
                <td>{d.device_code}</td>
                <td>{d.status}</td>
                <td>{d.last_seen_at || "-"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </section>
  );
}
