import { randomUUID } from "node:crypto";
import { Prisma } from "@prisma/client";
import { prisma } from "./prisma.js";

type IngestEvent = {
  deviceId: string;
  payload: unknown;
};

async function ingestTelemetry(event: IngestEvent): Promise<void> {
  const device = await prisma.mqttDevice.findUnique({
    where: { deviceId: event.deviceId },
    select: {
      deviceId: true,
      connected: true,
      user: {
        select: {
          tenantId: true
        }
      }
    }
  });

  if (!device || !device.connected) {
    console.log("Device not found or inactive");
    return;
  }
  const tenantId = device.user.tenantId;

  await prisma.telemetry.create({
    data: {
      id: randomUUID(),
      tenantId,
      deviceId: device.deviceId,
      payload: event.payload as Prisma.InputJsonValue,
      timestamp: new Date()
    }
  });
}

async function main(): Promise<void> {
  // Integration point: wire this to MQTT message callback in runtime service.
  const testDeviceId = process.env.TEST_DEVICE_ID;
  if (!testDeviceId) {
    await prisma.$queryRaw`select 1`;
    console.log("[worker] started (db ok, no TEST_DEVICE_ID provided)");
    return;
  }

  await ingestTelemetry({
    deviceId: testDeviceId,
    payload: process.env.TEST_PAYLOAD_JSON ?? "{\"status\":\"ok\"}"
  });
  console.log("[worker] ingest ok");
}

main()
  .catch((error: unknown) => {
    console.error("[worker] fatal error", error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
