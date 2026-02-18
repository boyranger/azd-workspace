"use client";

import { useState } from "react";

type DeviceRow = {
  id: string;
  name: string;
  device_code: string;
  status: string;
  last_seen_at: string | null;
  mqtt_username: string;
};

type Props = {
  role: "owner" | "staff" | "viewer";
  devices: DeviceRow[];
};

export default function DeviceAdminPanel({ role, devices }: Props) {
  const [name, setName] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [credential, setCredential] = useState<{ mqtt_username: string; mqtt_password: string } | null>(null);

  async function createDevice() {
    setBusy(true);
    setError(null);
    setCredential(null);
    try {
      const res = await fetch("/api/admin/devices", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name })
      });
      const payload = await res.json();
      if (!res.ok) {
        setError(payload.error || "Failed creating device");
        return;
      }
      setCredential(payload.credentials);
      setName("");
      window.location.reload();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setBusy(false);
    }
  }

  async function rotate(id: string) {
    setBusy(true);
    setError(null);
    setCredential(null);
    try {
      const res = await fetch(`/api/admin/devices/${id}/rotate`, { method: "POST" });
      const payload = await res.json();
      if (!res.ok) {
        setError(payload.error || "Failed rotating credentials");
        return;
      }
      setCredential(payload.credentials);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="card">
      <h2>Device Management</h2>
      <p>Role: <strong>{role}</strong></p>

      {role === "staff" || role === "owner" ? (
        <div style={{ display: "flex", gap: 8, marginBottom: 16 }}>
          <input
            placeholder="Device name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            disabled={busy}
          />
          <button onClick={createDevice} disabled={busy || !name.trim()}>
            Create Device
          </button>
        </div>
      ) : null}

      {credential ? (
        <div className="card" style={{ borderColor: "#0d5c63", marginBottom: 16 }}>
          <strong>New Credential (save now)</strong>
          <p>Username: <code>{credential.mqtt_username}</code></p>
          <p>Password: <code>{credential.mqtt_password}</code></p>
        </div>
      ) : null}

      {error ? <p style={{ color: "crimson" }}>{error}</p> : null}

      {!devices.length ? (
        <p>No devices.</p>
      ) : (
        <table style={{ width: "100%", borderCollapse: "collapse" }}>
          <thead>
            <tr>
              <th align="left">Name</th>
              <th align="left">Code</th>
              <th align="left">MQTT User</th>
              <th align="left">Status</th>
              <th align="left">Last Seen</th>
              <th align="left">Action</th>
            </tr>
          </thead>
          <tbody>
            {devices.map((d) => (
              <tr key={d.id}>
                <td>{d.name}</td>
                <td>{d.device_code}</td>
                <td>{d.mqtt_username}</td>
                <td>{d.status}</td>
                <td>{d.last_seen_at || "-"}</td>
                <td>
                  {role === "owner" ? (
                    <button onClick={() => rotate(d.id)} disabled={busy}>Rotate</button>
                  ) : (
                    <span style={{ opacity: 0.7 }}>Owner only</span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </section>
  );
}
