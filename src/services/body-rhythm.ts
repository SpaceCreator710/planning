import type { UserProfile } from '@/types/app';

export interface BodyRhythm {
  day: number;
  phase: 'reset' | 'build' | 'peak' | 'restore';
  guidance: string;
}

export function bodyRhythmForProfile(profile: UserProfile, now = new Date()): BodyRhythm | undefined {
  if (!profile.bodyRhythmEnabled || !/^\d{4}-\d{2}-\d{2}$/.test(profile.cycleStartDate)) return undefined;
  const start = new Date(`${profile.cycleStartDate}T12:00:00`);
  if (Number.isNaN(start.getTime())) return undefined;
  const length = Math.max(20, Math.min(45, profile.cycleLengthDays || 28));
  const elapsed = Math.floor((new Date(now.getFullYear(), now.getMonth(), now.getDate(), 12).getTime() - start.getTime()) / 86_400_000);
  const normalized = ((elapsed % length) + length) % length;
  const day = normalized + 1;
  if (day <= profile.cyclePeriodDays) return { day, phase: 'reset', guidance: 'Consider lower load, more recovery margin and shorter focus blocks.' };
  if (day <= Math.floor(length * 0.45)) return { day, phase: 'build', guidance: 'A steady build window: protect learning and progressive work.' };
  if (day <= Math.floor(length * 0.6)) return { day, phase: 'peak', guidance: 'If energy agrees, place one demanding or social task here.' };
  return { day, phase: 'restore', guidance: 'Reduce overbooking and leave a larger buffer around the must-win.' };
}
