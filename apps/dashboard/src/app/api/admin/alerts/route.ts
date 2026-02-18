import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { hasMinimumRole, UserRole } from "@/lib/auth/roles";

const ALLOWED_METRICS = new Set(["telemetry_last_5m", "telemetry_last_1h", "ingest_per_min"]);
const ALLOWED_OPERATORS = new Set(["gt", "gte", "lt", "lte", "eq"]);

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

  const { data, error } = await auth.supabase
    .from("alerts")
    .select("id,name,metric,operator,threshold,enabled,created_at")
    .eq("tenant_id", auth.profile.tenant_id)
    .order("created_at", { ascending: false });

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  return NextResponse.json({ ok: true, alerts: data || [] });
}

export async function POST(req: Request) {
  const auth = await requireTenantProfile("staff");
  if ("error" in auth) {
    return auth.error;
  }

  const body = (await req.json().catch(() => ({}))) as {
    name?: string;
    metric?: string;
    operator?: string;
    threshold?: number;
    enabled?: boolean;
  };

  const name = body.name?.trim();
  const metric = body.metric?.trim();
  const operator = body.operator?.trim();
  const threshold = Number(body.threshold);
  const enabled = body.enabled ?? true;

  if (!name) {
    return NextResponse.json({ error: "name is required" }, { status: 400 });
  }

  if (!metric || !ALLOWED_METRICS.has(metric)) {
    return NextResponse.json({ error: "invalid metric" }, { status: 400 });
  }

  if (!operator || !ALLOWED_OPERATORS.has(operator)) {
    return NextResponse.json({ error: "invalid operator" }, { status: 400 });
  }

  if (!Number.isFinite(threshold)) {
    return NextResponse.json({ error: "threshold must be a number" }, { status: 400 });
  }

  const { data, error } = await auth.supabase
    .from("alerts")
    .insert({
      tenant_id: auth.profile.tenant_id,
      name,
      metric,
      operator,
      threshold,
      enabled
    })
    .select("id,name,metric,operator,threshold,enabled,created_at")
    .single();

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  return NextResponse.json({ ok: true, alert: data });
}
