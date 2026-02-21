import { PrismaClient } from "@prisma/client";

type PrismaGlobal = typeof globalThis & {
  __prisma?: PrismaClient;
};

const globalForPrisma = globalThis as PrismaGlobal;
const databaseUrl = process.env.DATABASE_URL;

if (!databaseUrl) {
  throw new Error(
    "[worker] Missing required env DATABASE_URL. Set DATABASE_URL before starting worker."
  );
}

export const prisma =
  globalForPrisma.__prisma ??
  new PrismaClient({
    datasources: {
      db: {
        url: databaseUrl
      }
    }
  });

if (process.env.NODE_ENV !== "production") {
  globalForPrisma.__prisma = prisma;
}
