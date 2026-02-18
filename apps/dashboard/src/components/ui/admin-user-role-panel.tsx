"use client";

import { useState } from "react";

type Role = "owner" | "staff" | "viewer";

type ProfileRow = {
  id: string;
  full_name: string | null;
  role: Role;
  created_at: string;
};

type Props = {
  currentUserId: string;
  rows: ProfileRow[];
};

export default function AdminUserRolePanel({ currentUserId, rows }: Props) {
  const [items, setItems] = useState(rows);
  const [savingId, setSavingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState<string | null>(null);

  async function updateRole(id: string, role: Role) {
    setError(null);
    setOk(null);
    setSavingId(id);

    const res = await fetch(`/api/admin/users/${id}/role`, {
      method: "PATCH",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ role })
    });

    const payload = (await res.json().catch(() => ({}))) as { error?: string; ok?: boolean };
    setSavingId(null);

    if (!res.ok) {
      setError(payload.error || "Failed to update role");
      return;
    }

    setItems((prev) => prev.map((it) => (it.id === id ? { ...it, role } : it)));
    setOk("Role updated");
  }

  return (
    <section className="card">
      <h2>Tenant Users</h2>
      <p>Owner dapat mengubah role user dalam tenant yang sama.</p>
      {error ? <p style={{ color: "crimson" }}>{error}</p> : null}
      {ok ? <p style={{ color: "green" }}>{ok}</p> : null}
      <table style={{ width: "100%", borderCollapse: "collapse" }}>
        <thead>
          <tr>
            <th align="left">User</th>
            <th align="left">Role</th>
            <th align="left">Created</th>
            <th align="left">Action</th>
          </tr>
        </thead>
        <tbody>
          {items.map((row) => (
            <tr key={row.id}>
              <td>{row.full_name || row.id}</td>
              <td>{row.role}</td>
              <td>{new Date(row.created_at).toLocaleString()}</td>
              <td>
                {row.id === currentUserId ? (
                  <em>Current user</em>
                ) : (
                  <div style={{ display: "flex", gap: 8 }}>
                    <button
                      type="button"
                      disabled={savingId === row.id || row.role === "viewer"}
                      onClick={() => updateRole(row.id, "viewer")}
                    >
                      Viewer
                    </button>
                    <button
                      type="button"
                      disabled={savingId === row.id || row.role === "staff"}
                      onClick={() => updateRole(row.id, "staff")}
                    >
                      Staff
                    </button>
                    <button
                      type="button"
                      disabled={savingId === row.id || row.role === "owner"}
                      onClick={() => updateRole(row.id, "owner")}
                    >
                      Owner
                    </button>
                  </div>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}
