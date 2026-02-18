import { NextResponse } from "next/server";

export async function POST() {
  const res = NextResponse.json({ ok: true });
  for (const name of ["sb-access-token", "sb-refresh-token"]) {
    res.cookies.set(name, "", {
      httpOnly: true,
      secure: true,
      sameSite: "lax",
      path: "/",
      maxAge: 0
    });
  }
  return res;
}
