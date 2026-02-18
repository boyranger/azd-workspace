import { requireProfile } from "@/lib/auth/session";
import LogoutButton from "@/components/ui/logout-button";

export const dynamic = "force-dynamic";

export default async function TenantLayout({ children }: { children: React.ReactNode }) {
  const profile = await requireProfile("viewer");

  return (
    <main>
      <div className="topbar">
        <h1>Tenant Dashboard</h1>
        <nav>
          <a href="/app">Overview</a> | <a href="/app/devices">Devices</a> | <a href="/app/profile">Profile</a> | <a href="/admin">Admin</a>
        </nav>
        <LogoutButton />
      </div>
      <p>
        Tenant: <strong>{profile.tenant_id}</strong> | Role: <strong>{profile.role}</strong>
      </p>
      {children}
    </main>
  );
}
