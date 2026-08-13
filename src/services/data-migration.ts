import { createInitialData } from '@/constants/seed-data';
import { dateKey } from '@/lib/date';
import type { AccentTheme, AppData, AppLanguage, AppSettings, CanvasTheme, CoachMode, FontScaleMode, SubscriptionTier, ThemeMode, UserProfile, VisualEnergy } from '@/types/app';

interface LegacyDeepProfile {
  fixedSchedule?: string;
  currentRoutines?: string;
  habitsToBuild?: string;
  habitsToReduce?: string;
  energyPattern?: string;
  peakFocusWindow?: string;
  responsibilities?: string;
  healthAndRecovery?: string;
  procrastinationTriggers?: string;
  planningPreferences?: string;
  lifeDump?: string;
}

type LegacyProfile = Partial<UserProfile> & { deepProfile?: LegacyDeepProfile };
type LegacySettings = Partial<Omit<AppSettings, 'coachMode'>> & { coachMode?: CoachMode | 'no-excuses' };

const LEGACY_DEMO_IDS = new Set(['plan-today', 'goal-primary', 'habit-plan', 'habit-move', 'memory-start']);
const TIERS: SubscriptionTier[] = ['free', 'plus', 'pro', 'max'];
const THEMES: ThemeMode[] = ['light', 'dark', 'system'];
const LANGUAGES: AppLanguage[] = ['en', 'ru'];
const ACCENTS: AccentTheme[] = ['crimson', 'ocean', 'violet', 'forest', 'sunset', 'blossom', 'sky', 'lavender', 'mint', 'amber'];
const CANVASES: CanvasTheme[] = ['paper', 'blush', 'mist', 'sage', 'lavender', 'midnight'];
const VISUAL_ENERGY: VisualEnergy[] = ['calm', 'balanced', 'vivid'];
const FONT_SCALES: FontScaleMode[] = ['compact', 'standard', 'large'];

function text(value: unknown) {
  return typeof value === 'string' ? value.trim() : '';
}

function combineLegacyDescription(profile: LegacyProfile) {
  if (text(profile.selfDescription)) return text(profile.selfDescription);
  const deep = profile.deepProfile;
  if (!deep) return '';
  return [
    text(deep.lifeDump),
    text(deep.responsibilities) ? `Responsibilities: ${text(deep.responsibilities)}` : '',
    text(deep.healthAndRecovery) ? `Recovery: ${text(deep.healthAndRecovery)}` : '',
    text(deep.habitsToBuild) ? `Habits to build: ${text(deep.habitsToBuild)}` : '',
    text(deep.habitsToReduce) ? `Habits to reduce: ${text(deep.habitsToReduce)}` : '',
  ]
    .filter(Boolean)
    .join('\n');
}

function migrateProfile(raw: LegacyProfile | undefined, initial: UserProfile): UserProfile {
  const profile = raw ?? {};
  const deep = profile.deepProfile;
  return {
    ...initial,
    name: text(profile.name),
    email: text(profile.email) || undefined,
    category: profile.category ?? initial.category,
    primaryGoal: text(profile.primaryGoal),
    goalWhy: text(profile.goalWhy),
    struggle: text(profile.struggle) || text(deep?.procrastinationTriggers),
    wakeTime: text(profile.wakeTime) || initial.wakeTime,
    sleepTime: text(profile.sleepTime) || initial.sleepTime,
    chronotype: profile.chronotype ?? initial.chronotype,
    discipline: profile.discipline ?? initial.discipline,
    excuses: Array.isArray(profile.excuses) ? profile.excuses.filter((item): item is string => typeof item === 'string') : [],
    fixedCommitments: text(profile.fixedCommitments) || text(deep?.fixedSchedule),
    currentHabits:
      text(profile.currentHabits) ||
      [text(deep?.currentRoutines), text(deep?.habitsToBuild)].filter(Boolean).join('\n'),
    productiveHours:
      text(profile.productiveHours) ||
      [text(deep?.peakFocusWindow), text(deep?.energyPattern)].filter(Boolean).join(' · '),
    planningPreferences: text(profile.planningPreferences) || text(deep?.planningPreferences),
    selfDescription: combineLegacyDescription(profile),
    bodyRhythmEnabled: Boolean(profile.bodyRhythmEnabled),
    cycleStartDate: text(profile.cycleStartDate),
    cycleLengthDays: Math.max(20, Math.min(45, Number(profile.cycleLengthDays) || initial.cycleLengthDays)),
    cyclePeriodDays: Math.max(2, Math.min(10, Number(profile.cyclePeriodDays) || initial.cyclePeriodDays)),
    aiSummary: text(profile.aiSummary) || undefined,
    onboardingCompleted: Boolean(profile.onboardingCompleted),
    createdAt: text(profile.createdAt) || initial.createdAt,
  };
}

function migrateSettings(raw: LegacySettings | undefined, initial: AppSettings, schemaVersion: number): AppSettings {
  const settings = raw ?? {};
  const legacyMode = settings.coachMode;
  const coachMode: CoachMode = legacyMode === 'no-excuses' ? 'aggressive' : legacyMode ?? initial.coachMode;
  const requestedTheme = THEMES.includes(settings.theme as ThemeMode) ? (settings.theme as ThemeMode) : initial.theme;
  return {
    coachMode,
    accountability: settings.accountability ?? initial.accountability,
    language: LANGUAGES.includes(settings.language as AppLanguage) ? (settings.language as AppLanguage) : initial.language,
    theme: schemaVersion < 3 && requestedTheme === 'system' ? 'light' : requestedTheme,
    accentTheme: ACCENTS.includes(settings.accentTheme as AccentTheme) ? (settings.accentTheme as AccentTheme) : initial.accentTheme,
    canvasTheme: CANVASES.includes(settings.canvasTheme as CanvasTheme) ? (settings.canvasTheme as CanvasTheme) : initial.canvasTheme,
    visualEnergy: VISUAL_ENERGY.includes(settings.visualEnergy as VisualEnergy) ? (settings.visualEnergy as VisualEnergy) : initial.visualEnergy,
    fontScale: FONT_SCALES.includes(settings.fontScale as FontScaleMode) ? (settings.fontScale as FontScaleMode) : initial.fontScale,
    notificationsEnabled: settings.notificationsEnabled ?? initial.notificationsEnabled,
    taskReminders: settings.taskReminders ?? initial.taskReminders,
    eveningReview: settings.eveningReview ?? initial.eveningReview,
    quietHoursStart: text(settings.quietHoursStart) || initial.quietHoursStart,
    quietHoursEnd: text(settings.quietHoursEnd) || initial.quietHoursEnd,
    autoLearn: settings.autoLearn ?? initial.autoLearn,
    safeMode: settings.safeMode ?? initial.safeMode,
    calendarSyncEnabled: settings.calendarSyncEnabled ?? initial.calendarSyncEnabled,
    calendarWriteBackEnabled: settings.calendarWriteBackEnabled ?? initial.calendarWriteBackEnabled,
    remindersSyncEnabled: settings.remindersSyncEnabled ?? initial.remindersSyncEnabled,
    autoCalendarReplan: settings.autoCalendarReplan ?? initial.autoCalendarReplan,
    healthSyncEnabled: settings.healthSyncEnabled ?? initial.healthSyncEnabled,
    healthPlanningEnabled: settings.healthPlanningEnabled ?? initial.healthPlanningEnabled,
  };
}

/** Converts older snapshots without carrying obsolete provider, key or voice settings. */
export function mergePersistedData(raw: Partial<AppData>): AppData {
  const initial = createInitialData();
  const schemaVersion = typeof raw.schemaVersion === 'number' ? raw.schemaVersion : 0;
  const plans = Array.isArray(raw.plans) ? raw.plans.filter((plan) => !LEGACY_DEMO_IDS.has(plan.id)) : [];
  const goals = Array.isArray(raw.goals) ? raw.goals.filter((goal) => !LEGACY_DEMO_IDS.has(goal.id)) : [];
  const habits = Array.isArray(raw.habits) ? raw.habits.filter((habit) => !LEGACY_DEMO_IDS.has(habit.id)) : [];
  const memories = Array.isArray(raw.memories) ? raw.memories.filter((memory) => !LEGACY_DEMO_IDS.has(memory.id)) : [];
  const removedDemoProgress =
    (raw.plans?.length ?? 0) !== plans.length ||
    (raw.goals?.length ?? 0) !== goals.length ||
    (raw.habits?.length ?? 0) !== habits.length ||
    (raw.memories?.length ?? 0) !== memories.length;
  const achievements = Array.isArray(raw.achievements)
    ? initial.achievements.map((template) => {
        const saved = raw.achievements?.find((achievement) => achievement.id === template.id);
        if (!saved || removedDemoProgress) return template;
        return { ...template, ...saved };
      })
    : initial.achievements;
  const usage = raw.usage?.date === dateKey()
    ? {
        date: dateKey(),
        coachMessages: Number(raw.usage.coachMessages) || 0,
        plansBuilt: Number(raw.usage.plansBuilt) || 0,
        rescues: Number(raw.usage.rescues) || 0,
      }
    : initial.usage;
  const subscription = TIERS.includes(raw.subscription as SubscriptionTier)
    ? (raw.subscription as SubscriptionTier)
    : initial.subscription;
  const activePlanId = text(raw.activePlanId);

  return {
    schemaVersion: initial.schemaVersion,
    profile: migrateProfile(raw.profile as LegacyProfile | undefined, initial.profile),
    settings: migrateSettings(raw.settings as LegacySettings | undefined, initial.settings, schemaVersion),
    subscription,
    plans,
    goals,
    habits,
    memories,
    messages: Array.isArray(raw.messages) && raw.messages.length ? raw.messages : initial.messages,
    reviews: Array.isArray(raw.reviews) ? raw.reviews : [],
    achievements,
    events: Array.isArray(raw.events) ? raw.events.slice(-400) : [],
    horizonPlans: Array.isArray(raw.horizonPlans) ? raw.horizonPlans : [],
    inbox: Array.isArray(raw.inbox) ? raw.inbox : [],
    notes: Array.isArray(raw.notes) ? raw.notes : [],
    workouts: Array.isArray(raw.workouts) ? raw.workouts : [],
    healthSnapshots: Array.isArray(raw.healthSnapshots) ? raw.healthSnapshots.slice(0, 30) : [],
    usage,
    activePlanId: activePlanId && plans.some((plan) => plan.id === activePlanId) ? activePlanId : undefined,
  };
}
