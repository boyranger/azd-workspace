export function getSupabaseCookieOptions() {
  const forceInsecure = process.env.SUPABASE_COOKIE_SECURE === "false";
  return {
    secure: forceInsecure ? false : process.env.NODE_ENV === "production",
    sameSite: "lax" as const,
    path: "/"
  };
}
