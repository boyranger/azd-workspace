import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

const ALLOWED_ROLES = new Set(["owner", "staff", "viewer"] as const);
type Role = "owner" | "staff" | "viewer";

async function requireOwner() {
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

  if (!profile || profile.role !== "owner") {
    return { error: NextResponse.json({ error: "Forbidden" }, { status: 403 }) };
  }

  return { supabase, userId: user.id, profile };
}

export async function PATCH(
  req: Request,
  context: { params: Promise<{ id: string }> }
) {
  const auth = await requireOwner();
  if ("error" in auth) {
    return auth.error;
  }

  const { id: targetUserId } = await context.params;
  const body = (await req.json().catch(() => ({}))) as { role?: string };
  const role = body.role;

  if (!role || !ALLOWED_ROLES.has(role as Role)) {
    return NextResponse.json({ error: "Invalid role" }, { status: 400 });
  }

  if (targetUserId === auth.userId) {
    return NextResponse.json({ error: "Cannot update current user role" }, { status: 400 });
  }

  const { data: target, error: targetErr } = await auth.supabase
    .from("profiles")
    .select("id,tenant_id,role")
    .eq("id", targetUserId)
    .single();

  if (targetErr || !target) {
    return NextResponse.json({ error: "Target profile not found" }, { status: 404 });
  }

  if (target.tenant_id !== auth.profile.tenant_id) {
    return NextResponse.json({ error: "Cross-tenant update is not allowed" }, { status: 403 });
  }

  const { error: updateErr } = await auth.supabase
    .from("profiles")
    .update({ role })
    .eq("id", targetUserId)
    .eq("tenant_id", auth.profile.tenant_id);

  if (updateErr) {
    return NextResponse.json({ error: updateErr.message }, { status: 500 });
  }

  return NextResponse.json({ ok: true, id: targetUserId, role });
}
