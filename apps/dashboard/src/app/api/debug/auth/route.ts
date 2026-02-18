import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { cookies } from "next/headers";

export async function GET() {
  const cookieStore = await cookies();
  const cookieNames = cookieStore.getAll().map((c) => c.name);

  const supabase = await createClient();

  const { data: sessionData, error: sessionError } = await supabase.auth.getSession();

  const {
    data: { user },
    error: userError
  } = await supabase.auth.getUser();

  if (userError) {
    return NextResponse.json(
      {
        ok: false,
        stage: "getUser",
        error: userError.message,
        cookieNames,
        hasSbCookie: cookieNames.some((n) => n.startsWith("sb-")),
        session: sessionData.session
          ? {
              userId: sessionData.session.user.id,
              expiresAt: sessionData.session.expires_at
            }
          : null,
        sessionError: sessionError?.message ?? null
      },
      { status: 500 }
    );
  }

  if (!user) {
    return NextResponse.json(
      {
        ok: false,
        stage: "auth",
        error: "No active session",
        cookieNames,
        hasSbCookie: cookieNames.some((n) => n.startsWith("sb-")),
        session: sessionData.session
          ? {
              userId: sessionData.session.user.id,
              expiresAt: sessionData.session.expires_at
            }
          : null,
        sessionError: sessionError?.message ?? null
      },
      { status: 401 }
    );
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("id, tenant_id, role, full_name")
    .eq("id", user.id)
    .maybeSingle();

  return NextResponse.json({
    ok: true,
    cookieNames,
    hasSbCookie: cookieNames.some((n) => n.startsWith("sb-")),
    user: { id: user.id, email: user.email },
    profile,
    profileError: profileError?.message ?? null,
    session: sessionData.session
      ? {
          userId: sessionData.session.user.id,
          expiresAt: sessionData.session.expires_at
        }
      : null,
    sessionError: sessionError?.message ?? null
  });
}
