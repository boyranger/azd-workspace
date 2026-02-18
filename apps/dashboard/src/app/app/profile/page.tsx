import { requireProfile } from "@/lib/auth/session";
import ChangePasswordForm from "@/components/ui/change-password-form";

export const dynamic = "force-dynamic";

export default async function ProfilePage() {
  const profile = await requireProfile("viewer");

  return (
    <div style={{ display: "grid", gap: 16 }}>
      <section className="card">
        <h2>Profile</h2>
        <p><strong>User ID:</strong> {profile.id}</p>
        <p><strong>Full name:</strong> {profile.full_name || "-"}</p>
        <p><strong>Role:</strong> {profile.role}</p>
        <p><strong>Tenant:</strong> {profile.tenant_id}</p>
      </section>
      <ChangePasswordForm />
    </div>
  );
}
