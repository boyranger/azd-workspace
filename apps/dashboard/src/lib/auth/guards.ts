import { NextRequest } from "next/server";
import { UserRole, hasMinimumRole } from "@/lib/auth/roles";

export function getRoleFromRequest(req: NextRequest): UserRole {
  const role = req.cookies.get("role")?.value;
  if (role === "owner" || role === "staff" || role === "viewer") {
    return role;
  }
  return "viewer";
}

export function isAllowed(req: NextRequest, minimumRole: UserRole): boolean {
  const role = getRoleFromRequest(req);
  return hasMinimumRole(role, minimumRole);
}
