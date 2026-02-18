import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { UserRole, hasMinimumRole } from "@/lib/auth/roles";

export type UserProfile = {
  id: string;
  tenant_id: string;
  role: UserRole;
  full_name: string | null;
};

export async function requireProfile(minimumRole: UserRole): Promise<UserProfile> {
  const supabase = await createClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const { data: profile } = await supabase
    .from("profiles")
    .select("id, tenant_id, role, full_name")
    .eq("id", user.id)
    .single();

  if (!profile) {
    redirect("/unauthorized");
  }

  const role = profile.role as UserRole;
  if (!hasMinimumRole(role, minimumRole)) {
    redirect("/unauthorized");
  }

  return {
    id: profile.id,
    tenant_id: profile.tenant_id,
    role,
    full_name: profile.full_name
  };
}
