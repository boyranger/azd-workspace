export type UserRole = "owner" | "staff" | "viewer";

export const roleWeight: Record<UserRole, number> = {
  owner: 3,
  staff: 2,
  viewer: 1
};

export function hasMinimumRole(currentRole: UserRole, minimumRole: UserRole): boolean {
  return roleWeight[currentRole] >= roleWeight[minimumRole];
}
