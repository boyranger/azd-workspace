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

export async function PATCH(
  req: Request,
  context: { params: Promise<{ id: string }> }
) {
  const auth = await requireTenantProfile("staff");
  if ("error" in auth) {
    return auth.error;
  }

  const { id } = await context.params;

  const body = (await req.json().catch(() => ({}))) as {
    name?: string;
    metric?: string;
    operator?: string;
    threshold?: number;
    enabled?: boolean;
  };

  const patch: Record<string, unknown> = {};

  if (typeof body.name === "string") {
    const name = body.name.trim();
    if (!name) {
      return NextResponse.json({ error: "name cannot be empty" }, { status: 400 });
    }
    patch.name = name;
  }

  if (typeof body.metric === "string") {
    const metric = body.metric.trim();
    if (!ALLOWED_METRICS.has(metric)) {
      return NextResponse.json({ error: "invalid metric" }, { status: 400 });
    }
    patch.metric = metric;
  }

  if (typeof body.operator === "string") {
    const operator = body.operator.trim();
    if (!ALLOWED_OPERATORS.has(operator)) {
      return NextResponse.json({ error: "invalid operator" }, { status: 400 });
    }
    patch.operator = operator;
  }

  if (body.threshold !== undefined) {
    const threshold = Number(body.threshold);
    if (!Number.isFinite(threshold)) {
      return NextResponse.json({ error: "threshold must be a number" }, { status: 400 });
    }
    patch.threshold = threshold;
  }

  if (typeof body.enabled === "boolean") {
    patch.enabled = body.enabled;
  }

  if (Object.keys(patch).length === 0) {
    return NextResponse.json({ error: "no valid field to update" }, { status: 400 });
  }

  const { data, error } = await auth.supabase
    .from("alerts")
    .update(patch)
    .eq("id", id)
    .eq("tenant_id", auth.profile.tenant_id)
    .select("id,name,metric,operator,threshold,enabled,created_at")
    .single();

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  return NextResponse.json({ ok: true, alert: data });
}

export async function DELETE(
  _req: Request,
  context: { params: Promise<{ id: string }> }
) {
  const auth = await requireTenantProfile("staff");
  if ("error" in auth) {
    return auth.error;
  }

  const { id } = await context.params;

  const { error } = await auth.supabase
    .from("alerts")
    .delete()
    .eq("id", id)
    .eq("tenant_id", auth.profile.tenant_id);

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  return NextResponse.json({ ok: true });
}
