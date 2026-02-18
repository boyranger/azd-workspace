import { randomBytes, scryptSync, timingSafeEqual } from "crypto";

const SCRYPT_N = 16384;
const SCRYPT_R = 8;
const SCRYPT_P = 1;
const KEYLEN = 64;

export function generateSecret(length = 24): string {
  return randomBytes(length).toString("base64url").slice(0, length);
}

export function hashSecret(secret: string): string {
  const salt = randomBytes(16);
  const derived = scryptSync(secret, salt, KEYLEN, {
    N: SCRYPT_N,
    r: SCRYPT_R,
    p: SCRYPT_P
  });
  return [
    "scrypt",
    String(SCRYPT_N),
    String(SCRYPT_R),
    String(SCRYPT_P),
    salt.toString("base64url"),
    derived.toString("base64url")
  ].join("$");
}

export function verifySecret(secret: string, hashed: string): boolean {
  const parts = hashed.split("$");
  if (parts.length !== 6 || parts[0] !== "scrypt") {
    return false;
  }

  const [, n, r, p, saltB64, keyB64] = parts;
  const salt = Buffer.from(saltB64, "base64url");
  const expected = Buffer.from(keyB64, "base64url");

  const actual = scryptSync(secret, salt, expected.length, {
    N: Number(n),
    r: Number(r),
    p: Number(p)
  });

  return timingSafeEqual(actual, expected);
}

export function generateDeviceCode(prefix = "dev"): string {
  const token = randomBytes(6).toString("hex");
  return `${prefix}_${token}`;
}
