import { requireProfile } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import AdminUserRolePanel from "@/components/ui/admin-user-role-panel";

export const dynamic = "force-dynamic";

type ProfileListRow = {
  id: string;
  full_name: string | null;
  role: "owner" | "staff" | "viewer";
  created_at: string;
};

export default async function AdminUsersPage() {
  const profile = await requireProfile("owner");
  const supabase = await createClient();

  const { data, error } = await supabase
    .from("profiles")
    .select("id,full_name,role,created_at")
    .eq("tenant_id", profile.tenant_id)
    .order("created_at", { ascending: false });

  return (
    <div className="grid">
      <section className="card">
        <h2>Access Scope</h2>
        <p>Tenant: {profile.tenant_id}</p>
        <p>Role: {profile.role}</p>
      </section>
      {error ? (
        <section className="card">
          <h2>Query Error</h2>
          <p>{error.message}</p>
        </section>
      ) : (
        <AdminUserRolePanel currentUserId={profile.id} rows={(data || []) as ProfileListRow[]} />
      )}
    </div>
  );
}
