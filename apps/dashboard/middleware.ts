import { NextRequest, NextResponse } from "next/server";
import { updateSession } from "@/lib/supabase/middleware";

export async function middleware(req: NextRequest) {
  const res = await updateSession(req);

  const pathname = req.nextUrl.pathname;
  const protectedPath = pathname.startsWith("/admin") || pathname.startsWith("/app");

  if (!protectedPath) {
    return res;
  }

  const hasAuthCookie = req.cookies.getAll().some((c) => c.name.startsWith("sb-"));
  if (!hasAuthCookie) {
    return NextResponse.redirect(new URL("/login", req.url));
  }

  return res;
}

export const config = {
  matcher: ["/admin/:path*", "/app/:path*"]
};
