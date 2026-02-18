import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { hasMinimumRole, UserRole } from "@/lib/auth/roles";
import { generateDeviceCode, generateSecret, hashSecret } from "@/lib/security/credentials";

async function requireTenantProfile(minRole: UserRole) {
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

  if (!hasMinimumRole(profile.role as UserRole, minRole)) {
    return { error: NextResponse.json({ error: "Forbidden" }, { status: 403 }) };
  }

  return { supabase, profile };
}

export async function POST(req: Request) {
  const auth = await requireTenantProfile("staff");
  if ("error" in auth) {
    return auth.error;
  }

  const body = (await req.json().catch(() => ({}))) as {
    name?: string;
    deviceCode?: string;
  };

  const name = body.name?.trim();
  if (!name) {
    return NextResponse.json({ error: "name is required" }, { status: 400 });
  }

  const deviceCode = (body.deviceCode?.trim() || generateDeviceCode()).toLowerCase();
  const mqttUsername = `mqtt_${deviceCode}`;
  const plainPassword = generateSecret(28);
  const passwordHash = hashSecret(plainPassword);

  const { data, error } = await auth.supabase
    .from("devices")
    .insert({
      tenant_id: auth.profile.tenant_id,
      name,
      device_code: deviceCode,
      mqtt_username: mqttUsername,
      mqtt_password_hash: passwordHash,
      status: "active"
    })
    .select("id,tenant_id,name,device_code,mqtt_username,status,created_at")
    .single();

  if (error) {
    const code = error.code === "23505" ? 409 : 500;
    return NextResponse.json({ error: error.message }, { status: code });
  }

  return NextResponse.json({
    device: data,
    credentials: {
      mqtt_username: mqttUsername,
      mqtt_password: plainPassword
    }
  });
}
