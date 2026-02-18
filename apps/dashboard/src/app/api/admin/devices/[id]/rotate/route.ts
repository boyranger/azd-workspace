import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { generateSecret, hashSecret } from "@/lib/security/credentials";

async function requireOwnerProfile() {
  const supabase = await createClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) {
    return { error: NextResponse.json({ error: "Unauthorized" }, { status: 401 }) };
  }

  const { data: profile } = await supabase
    .from("profiles")
    .select("id,tenant_id,role")
    .eq("id", user.id)
    .single();

  if (!profile) {
    return { error: NextResponse.json({ error: "Profile not found" }, { status: 403 }) };
  }

  if (profile.role !== "owner") {
    return { error: NextResponse.json({ error: "Only owner can rotate credentials" }, { status: 403 }) };
  }

  return { supabase, profile };
}

export async function POST(
  _req: Request,
  context: { params: Promise<{ id: string }> }
) {
  const auth = await requireOwnerProfile();
  if ("error" in auth) {
    return auth.error;
  }

  const { id: deviceId } = await context.params;

  const { data: device, error: findError } = await auth.supabase
    .from("devices")
    .select("id,tenant_id,mqtt_username")
    .eq("id", deviceId)
    .eq("tenant_id", auth.profile.tenant_id)
    .single();

  if (findError || !device) {
    return NextResponse.json({ error: "Device not found" }, { status: 404 });
  }

  const plainPassword = generateSecret(28);
  const passwordHash = hashSecret(plainPassword);

  const { error: updateError } = await auth.supabase
    .from("devices")
    .update({ mqtt_password_hash: passwordHash })
    .eq("id", deviceId)
    .eq("tenant_id", auth.profile.tenant_id);

  if (updateError) {
    return NextResponse.json({ error: updateError.message }, { status: 500 });
  }

  return NextResponse.json({
    ok: true,
    credentials: {
      mqtt_username: device.mqtt_username,
      mqtt_password: plainPassword
    }
  });
}
