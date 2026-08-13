import { dateKey } from '@/lib/date';
import type { AppData } from '@/types/app';

/**
 * A genuinely empty account. Nothing here is counted as user progress.
 * This prevents demo plans, streaks and achievements from leaking into a new
 * account while still giving the coach a single neutral welcome message.
 */
export function createInitialData(): AppData {
  const now = new Date().toISOString();
  return {
    schemaVersion: 6,
    profile: {
      name: '',
      category: 'custom',
      primaryGoal: '',
      goalWhy: '',
      struggle: '',
      wakeTime: '08:00',
      sleepTime: '23:00',
      chronotype: 'balanced',
      discipline: 3,
      excuses: [],
      fixedCommitments: '',
      currentHabits: '',
      productiveHours: '',
      planningPreferences: '',
      selfDescription: '',
      bodyRhythmEnabled: false,
      cycleStartDate: '',
      cycleLengthDays: 28,
      cyclePeriodDays: 5,
      onboardingCompleted: false,
      createdAt: now,
    },
    settings: {
      coachMode: 'soft',
      accountability: 'balanced',
      language: 'en',
      theme: 'light',
      accentTheme: 'crimson',
      canvasTheme: 'paper',
      visualEnergy: 'balanced',
      fontScale: 'standard',
      notificationsEnabled: false,
      taskReminders: true,
      eveningReview: true,
      quietHoursStart: '22:00',
      quietHoursEnd: '07:30',
      autoLearn: true,
      safeMode: true,
      calendarSyncEnabled: false,
      calendarWriteBackEnabled: false,
      remindersSyncEnabled: false,
      autoCalendarReplan: true,
      healthSyncEnabled: false,
      healthPlanningEnabled: false,
    },
    subscription: 'free',
    plans: [],
    goals: [],
    habits: [],
    memories: [],
    messages: [
      {
        id: 'coach-welcome',
        role: 'assistant',
        content: 'Tell me what is happening today. I will turn it into one clear next move.',
        createdAt: now,
        mode: 'soft',
      },
    ],
    reviews: [],
    achievements: [
      {
        id: 'achievement-first-plan',
        title: 'Day architect',
        description: 'Build your first realistic day.',
        icon: 'scope',
        progress: 0,
        target: 1,
      },
      {
        id: 'achievement-comeback',
        title: 'Comeback',
        description: 'Rebuild a disrupted day and complete the next action.',
        icon: 'figure.walk',
        progress: 0,
        target: 1,
      },
      {
        id: 'achievement-streak',
        title: 'Seven honest days',
        description: 'Complete at least one real action on seven different days.',
        icon: 'moon.zzz.fill',
        progress: 0,
        target: 7,
      },
    ],
    events: [],
    horizonPlans: [],
    inbox: [],
    notes: [],
    workouts: [],
    healthSnapshots: [],
    usage: { date: dateKey(), coachMessages: 0, plansBuilt: 0, rescues: 0 },
  };
}
