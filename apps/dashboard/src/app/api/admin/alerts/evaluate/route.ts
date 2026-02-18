import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { hasMinimumRole, UserRole } from "@/lib/auth/roles";

type Metric = "telemetry_last_5m" | "telemetry_last_1h" | "ingest_per_min";
type Operator = "gt" | "gte" | "lt" | "lte" | "eq";

type AlertRow = {
  id: string;
  name: string;
  metric: Metric;
  operator: Operator;
  threshold: number;
};

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

function compare(actual: number, operator: Operator, threshold: number): boolean {
  if (operator === "gt") return actual > threshold;
  if (operator === "gte") return actual >= threshold;
  if (operator === "lt") return actual < threshold;
  if (operator === "lte") return actual <= threshold;
  return actual === threshold;
}

export async function POST() {
  const auth = await requireTenantProfile("staff");
  if ("error" in auth) {
    return auth.error;
  }

  const now = Date.now();
  const last5m = new Date(now - 5 * 60 * 1000).toISOString();
  const last1h = new Date(now - 60 * 60 * 1000).toISOString();

  const [{ count: count5m }, { count: count1h }, { data: rules, error: rulesErr }] = await Promise.all([
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
      .from("alerts")
      .select("id,name,metric,operator,threshold")
      .eq("tenant_id", auth.profile.tenant_id)
      .eq("enabled", true)
  ]);

  if (rulesErr) {
    return NextResponse.json({ error: rulesErr.message }, { status: 500 });
  }

  const metrics: Record<Metric, number> = {
    telemetry_last_5m: count5m ?? 0,
    telemetry_last_1h: count1h ?? 0,
    ingest_per_min: Math.round((count5m ?? 0) / 5)
  };

  const events: Array<{ alert_id: string; message: string }> = [];
  const evaluated = (rules || []) as AlertRow[];
  const dedupSince = new Date(now - 5 * 60 * 1000).toISOString();

  for (const rule of evaluated) {
    const actual = metrics[rule.metric];
    if (!compare(actual, rule.operator, Number(rule.threshold))) {
      continue;
    }

    const { count: recentEventCount } = await auth.supabase
      .from("alert_events")
      .select("id", { count: "exact", head: true })
      .eq("tenant_id", auth.profile.tenant_id)
      .eq("alert_id", rule.id)
      .gte("triggered_at", dedupSince);

    if ((recentEventCount ?? 0) > 0) {
      continue;
    }

    events.push({
      alert_id: rule.id,
      message: `[${rule.name}] ${rule.metric} ${rule.operator} ${rule.threshold} (actual=${actual})`
    });
  }

  if (events.length > 0) {
    const { error: insertErr } = await auth.supabase.from("alert_events").insert(
      events.map((e) => ({
        alert_id: e.alert_id,
        tenant_id: auth.profile.tenant_id,
        message: e.message
      }))
    );

    if (insertErr) {
      return NextResponse.json({ error: insertErr.message }, { status: 500 });
    }
  }

  return NextResponse.json({
    ok: true,
    metrics,
    rules_evaluated: evaluated.length,
    events_created: events.length
  });
}
