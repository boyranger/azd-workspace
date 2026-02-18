import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { hasMinimumRole, UserRole } from "@/lib/auth/roles";

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

export async function GET() {
  const auth = await requireTenantProfile("staff");
  if ("error" in auth) {
    return auth.error;
  }

  const now = Date.now();
  const last5m = new Date(now - 5 * 60 * 1000).toISOString();
  const last1h = new Date(now - 60 * 60 * 1000).toISOString();

  const [{ count: count5m }, { count: count1h }, { data: latestRows, error: latestErr }] = await Promise.all([
    auth.supabase
      .from("telemetry")
      .select("id", { count: "exact", head: true })
      .eq("tenant_id", auth.profile.tenant_id)
      .gte("ingested_at", last5m),
    auth.supabase
      .from("telemetry")
      .select("id", { count: "exact", head: true })
      .eq("tenant_id", auth.profile.tenant_id)
      .gte("ingested_at", last1h),
    auth.supabase
      .from("telemetry")
      .select("id,device_id,topic,qos,retain,ingested_at,payload_text")
      .eq("tenant_id", auth.profile.tenant_id)
      .order("ingested_at", { ascending: false })
      .limit(20)
  ]);

  if (latestErr) {
    return NextResponse.json({ error: latestErr.message }, { status: 500 });
  }

  const latest = (latestRows || []).map((row) => ({
    ...row,
    payload_preview: typeof row.payload_text === "string" ? row.payload_text.slice(0, 160) : ""
  }));
  const telemetryLast5m = count5m ?? 0;
  const telemetryLast1h = count1h ?? 0;
  const health =
    telemetryLast5m > 0 ? "healthy" : telemetryLast1h > 0 ? "degraded" : "stale";
  const lastIngestedAt = latestRows?.[0]?.ingested_at ?? null;

  return NextResponse.json({
    ok: true,
    tenant_id: auth.profile.tenant_id,
    health,
    window: {
      last_5m_start: last5m,
      last_1h_start: last1h
    },
    counts: {
      telemetry_last_5m: telemetryLast5m,
      telemetry_last_1h: telemetryLast1h
    },
    last_ingested_at: lastIngestedAt,
    latest
  });
}
