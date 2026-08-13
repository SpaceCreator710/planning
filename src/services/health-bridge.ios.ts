import CapacityHealth from '../../modules/capacity-health';

import type { HealthSnapshot } from '@/types/app';

export function healthKitAvailable() {
  return CapacityHealth.isAvailable();
}

export async function requestHealthAccess() {
  return CapacityHealth.requestAuthorization();
}

export async function readHealthSnapshot(): Promise<HealthSnapshot> {
  const end = new Date();
  const start = new Date(end.getTime() - 48 * 60 * 60 * 1000);
  const snapshot = await CapacityHealth.readSnapshot(start.toISOString(), end.toISOString());
  return { ...snapshot, source: 'apple-health' };
}
