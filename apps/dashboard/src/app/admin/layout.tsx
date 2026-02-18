import { requireProfile } from "@/lib/auth/session";
import LogoutButton from "@/components/ui/logout-button";

export const dynamic = "force-dynamic";

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const profile = await requireProfile("staff");

  return (
    <main>
      <div className="topbar">
        <h1>Admin Panel</h1>
        <nav>
          <a href="/admin">Overview</a> | <a href="/admin/devices">Devices</a> | <a href="/admin/ingest">Ingest</a> |{" "}
          <a href="/admin/alerts">Alerts</a>
          {profile.role === "owner" ? (
            <>
              {" "}
              | <a href="/admin/users">Users</a>
            </>
          ) : null}{" "}
          | <a href="/app">Tenant App</a>
        </nav>
        <LogoutButton />
      </div>
      <p>
        Signed in as <strong>{profile.full_name || profile.id}</strong> ({profile.role})
      </p>
      {children}
    </main>
  );
}
