import { requireProfile } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import DeviceAdminPanel from "@/components/ui/device-admin-panel";

export const dynamic = "force-dynamic";

export default async function AdminDevicesPage() {
  const profile = await requireProfile("staff");
  const supabase = await createClient();

  const { data: devices } = await supabase
    .from("devices")
    .select("id,name,device_code,mqtt_username,status,last_seen_at")
    .eq("tenant_id", profile.tenant_id)
    .order("created_at", { ascending: false })
    .limit(100);

  return <DeviceAdminPanel role={profile.role} devices={devices || []} />;
}
