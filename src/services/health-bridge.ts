import type { HealthSnapshot } from '@/types/app';

function emptyHealthSnapshot(): HealthSnapshot {
  const end = new Date();
  const start = new Date(end.getTime() - 48 * 60 * 60 * 1000);
  return {
    source: 'manual',
    available: false,
    startDate: start.toISOString(),
    endDate: end.toISOString(),
    sleepHours: 0,
    steps: 0,
    exerciseMinutes: 0,
    standMinutes: 0,
    distanceKilometers: 0,
    workoutCount: 0,
    workoutMinutes: 0,
    lastUpdated: end.toISOString(),
  };
}

export function healthKitAvailable() {
  return false;
}

export async function requestHealthAccess() {
  return false;
}

export async function readHealthSnapshot() {
  return emptyHealthSnapshot();
}
