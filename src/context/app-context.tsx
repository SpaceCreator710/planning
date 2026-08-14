import React, { createContext, useCallback, useEffect, useMemo, useRef, useState } from 'react';

import { createInitialData } from '@/constants/seed-data';
import { subscriptionPlans } from '@/constants/subscriptions';
import { useAuth } from '@/context/auth-context';
import { appStorage } from '@/lib/app-storage';
import { dateKey, minutesToTime, timeToMinutes } from '@/lib/date';
import { supabase } from '@/lib/supabase';
import {
  analyzeProfileWithAI,
  generateCoachReplyWithAI,
  generateDayPlanWithAI,
  generateHorizonPlanWithAI,
  preserveCompletedTasks,
  replanDayWithAI,
  toMemoryFacts,
  type CoachAction,
  type AIResult,
  type ProfileAnalysis,
} from '@/services/ai-client';
import { capacityFromHealth } from '@/services/capacity-twin';
import { mergePersistedData } from '@/services/data-migration';
import { createManualTask, recurringTasksForDate } from '@/services/plan-engine';
import type {
  AppData,
  AppNote,
  AppSettings,
  BehaviorEventType,
  CoachContext,
  CoachMessage,
  CapacitySignal,
  DailyReview,
  Goal,
  Habit,
  HorizonPlan,
  HealthSnapshot,
  InboxTask,
  MemoryFact,
  PlanBuildInput,
  PlannerMode,
  PlanningHorizon,
  RescueInput,
  SubscriptionTier,
  Task,
  UserProfile,
  WorkoutSession,
} from '@/types/app';

const STORAGE_KEY = 'ai-plan-your-day:data:v3';
const PREVIOUS_STORAGE_KEY = 'ai-plan-your-day:data:v2';
const FIRST_STORAGE_KEY = 'ai-plan-your-day:data:v1';
const RECOVERY_KEY = 'ai-plan-your-day:recovery:v3';
const RECOVERY_WINDOW_MS = 7 * 24 * 60 * 60 * 1000;

type SyncStatus = 'local' | 'syncing' | 'synced' | 'error';

interface ActionResult<T = undefined> {
  ok: boolean;
  reason?: 'limit' | 'missing-plan' | 'invalid' | 'locked';
  value?: T;
  fallback?: boolean;
  warning?: string;
}

interface OnboardingResult {
  analysis: ProfileAnalysis;
  starterPlan?: AppData['plans'][number];
}

interface RecoverySnapshot {
  expiresAt: number;
  data: AppData;
  capacitySignal?: CapacitySignal;
}

interface CalendarImportOptions {
  replaceExternalRange?: {
    startDate: string;
    endDate: string;
    sources: Task['externalSource'][];
  };
}

interface AppContextValue {
  data: AppData;
  capacitySignal?: CapacitySignal;
  activePlan?: AppData['plans'][number];
  hydrated: boolean;
  syncStatus: SyncStatus;
  hasRecoveryBackup: boolean;
  updateProfile: (profile: Partial<UserProfile>) => void;
  completeOnboarding: (
    profile: Partial<UserProfile>,
    coaching?: Pick<AppSettings, 'coachMode' | 'accountability'>,
  ) => Promise<ActionResult<OnboardingResult>>;
  updateSettings: (settings: Partial<AppSettings>) => void;
  setSubscription: (tier: SubscriptionTier) => void;
  buildPlan: (input: PlanBuildInput) => Promise<ActionResult<AppData['plans'][number]>>;
  rescuePlan: (input: RescueInput) => Promise<ActionResult<AppData['plans'][number]>>;
  toggleTask: (taskId: string) => void;
  startTask: (taskId: string) => void;
  skipTask: (taskId: string, reason?: string) => void;
  editTask: (taskId: string, changes: Partial<Task>) => void;
  deleteTask: (taskId: string) => void;
  duplicateTask: (taskId: string) => void;
  duplicateDay: (sourceDate: string, targetDate: string) => boolean;
  moveTask: (taskId: string, direction: -1 | 1) => void;
  addManualTask: (title: string, durationMinutes?: number) => void;
  importCalendarTasks: (tasks: Task[], options?: CalendarImportOptions) => number;
  applyCapacitySignal: (signal?: CapacitySignal, snapshot?: HealthSnapshot) => void;
  setPlannerMode: (mode: PlannerMode) => void;
  sendCoachMessage: (content: string) => Promise<ActionResult<CoachMessage>>;
  buildHorizonPlan: (horizon: PlanningHorizon, objective: string) => Promise<ActionResult<HorizonPlan>>;
  addInboxTask: (title: string) => void;
  removeInboxTasks: (ids: string[], planned?: boolean) => void;
  addNote: (title: string, body: string, source?: AppNote['source']) => string | undefined;
  updateNote: (noteId: string, title: string, body: string) => void;
  deleteNote: (noteId: string) => void;
  planNote: (noteId: string) => void;
  addWorkoutSession: (session: Omit<WorkoutSession, 'id'>) => void;
  addGoal: (goal: Pick<Goal, 'title' | 'why' | 'category'>) => void;
  updateGoalProgress: (goalId: string, progress: number) => void;
  toggleMilestone: (goalId: string, milestoneId: string) => void;
  addHabit: (title: string) => void;
  toggleHabitToday: (habitId: string) => void;
  addMemory: (fact: string, category?: MemoryFact['category']) => void;
  toggleMemory: (memoryId: string) => void;
  deleteMemory: (memoryId: string) => void;
  addReview: (review: Omit<DailyReview, 'id' | 'date'>) => void;
  resetData: () => Promise<void>;
  restoreLastReset: () => Promise<boolean>;
}

const AppContext = createContext<AppContextValue | null>(null);

function withFreshUsage(data: AppData): AppData {
  if (data.usage.date === dateKey()) return data;
  return { ...data, usage: { date: dateKey(), coachMessages: 0, plansBuilt: 0, rescues: 0 } };
}

function appendEvent(data: AppData, type: BehaviorEventType, detail: string): AppData {
  const event = { id: `event-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`, type, detail, createdAt: new Date().toISOString() };
  return { ...data, events: [...data.events, event].slice(-400) };
}

function cloudSafeSnapshot(data: AppData): AppData {
  return { ...data, healthSnapshots: [] };
}

function coachContext(data: AppData, activePlan?: AppData['plans'][number], capacitySignal?: CapacitySignal): CoachContext {
  const memoryDays = subscriptionPlans[data.subscription].limits.memoryDays;
  const cutoff = Date.now() - memoryDays * 24 * 60 * 60 * 1000;
  return {
    profile: data.profile,
    settings: data.settings,
    activePlan,
    memories: data.memories.filter((memory) => memory.enabled && new Date(memory.createdAt).getTime() >= cutoff),
    messages: data.messages.filter((message) => new Date(message.createdAt).getTime() >= cutoff).slice(-20),
    goals: data.goals,
    habits: data.habits,
    reviews: data.reviews.filter((review) => new Date(`${review.date}T12:00:00`).getTime() >= cutoff),
    events: data.events.filter((event) => new Date(event.createdAt).getTime() >= cutoff),
    inbox: data.inbox,
    capacitySignal: data.settings.healthPlanningEnabled ? capacitySignal : undefined,
  };
}

function resultFromAI<T>(result: AIResult<T>): ActionResult<T> {
  return { ok: true, value: result.value, fallback: result.fallback, warning: result.warning };
}

function isActionDate(value: string) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const parsed = new Date(`${value}T12:00:00`);
  const distance = Math.abs(parsed.getTime() - Date.now());
  return Number.isFinite(parsed.getTime()) && distance <= 400 * 86_400_000;
}

function sectionForStart(startTime: string | undefined, fallback: Task['section'] = 'day'): Task['section'] {
  if (!startTime) return fallback;
  const minute = timeToMinutes(startTime);
  if (minute < 720) return 'morning';
  if (minute < 1020) return 'day';
  if (minute < 1320) return 'evening';
  return 'night';
}

function planShell(date: string, task: Task): AppData['plans'][number] {
  return {
    id: `plan-coach-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
    date,
    title: 'AI-scheduled day',
    style: 'realistic',
    mode: 'ai-plan',
    energy: 3,
    intention: task.title,
    tasks: [task],
    createdAt: new Date().toISOString(),
    planScore: 0,
  };
}

function applyCoachActions(current: AppData, actions: CoachAction[]) {
  let next = current;
  for (const action of actions.slice(0, 5)) {
    if (action.type === 'create_task') {
      const title = action.title.trim();
      if (!title) continue;
      const targetDate = isActionDate(action.date) ? action.date : dateKey();
      const task = createManualTask(title, targetDate);
      const startTime = action.startTime || undefined;
      const durationMinutes = action.durationMinutes;
      const created: Task = {
        ...task,
        source: 'ai',
        startTime,
        endTime: startTime ? minutesToTime(timeToMinutes(startTime) + durationMinutes) : undefined,
        durationMinutes,
        section: sectionForStart(startTime, task.section),
        category: action.category,
      };
      const target = next.plans.find((plan) => plan.date === targetDate);
      const plan = target ? { ...target, tasks: [...target.tasks, created] } : planShell(targetDate, created);
      next = appendEvent({
        ...next,
        plans: [plan, ...next.plans.filter((item) => item.id !== plan.id && item.date !== targetDate)].slice(0, 180),
        activePlanId: targetDate === dateKey() ? plan.id : next.activePlanId,
      }, 'task-added', `AI action: ${title}; ${targetDate}; ${startTime || 'anytime'}`);
      continue;
    }

    const sourcePlan = next.plans.find((plan) => plan.tasks.some((task) => task.id === action.taskId));
    const existing = sourcePlan?.tasks.find((task) => task.id === action.taskId);
    if (!sourcePlan || !existing) continue;
    if (action.type === 'delete_task') {
      next = appendEvent({
        ...next,
        plans: next.plans.map((plan) => ({ ...plan, tasks: plan.tasks.filter((task) => task.id !== existing.id) })),
      }, 'task-deleted', `AI action: ${existing.title}`);
      continue;
    }
    if (action.type === 'complete_task' || action.type === 'skip_task') {
      const complete = action.type === 'complete_task';
      const plans = next.plans.map((plan) => ({
        ...plan,
        tasks: plan.tasks.map((task) => task.id === existing.id
          ? { ...task, status: complete ? ('completed' as const) : ('skipped' as const), completedAt: complete ? new Date().toISOString() : undefined, skippedReason: complete ? undefined : 'Skipped through AI coach' }
          : task),
      }));
      const completedDates = new Set(plans.flatMap((plan) => plan.tasks).filter((task) => task.status === 'completed').map((task) => task.planDate));
      const honestDays = Math.min(7, completedDates.size);
      const achievements = complete
        ? next.achievements.map((achievement) => {
            if (achievement.id === 'achievement-comeback' && sourcePlan.rescuedAt) return { ...achievement, progress: 1, unlockedAt: achievement.unlockedAt ?? new Date().toISOString() };
            if (achievement.id === 'achievement-streak') return { ...achievement, progress: honestDays, unlockedAt: honestDays >= achievement.target ? achievement.unlockedAt ?? new Date().toISOString() : achievement.unlockedAt };
            return achievement;
          })
        : next.achievements;
      next = appendEvent({
        ...next,
        plans,
        achievements,
      }, complete ? 'task-completed' : 'task-skipped', `AI action: ${existing.title}`);
      continue;
    }

    const targetDate = isActionDate(action.date) ? action.date : existing.planDate;
    const startTime = action.startTime || existing.startTime;
    const durationMinutes = action.durationMinutes || existing.durationMinutes;
    const updated: Task = {
      ...existing,
      title: action.title.trim() || existing.title,
      planDate: targetDate,
      startTime,
      endTime: startTime ? minutesToTime(timeToMinutes(startTime) + durationMinutes) : undefined,
      durationMinutes,
      section: sectionForStart(startTime, existing.section),
      category: action.category,
    };
    let plans = next.plans.map((plan) => ({ ...plan, tasks: plan.tasks.filter((task) => task.id !== existing.id) }));
    const target = plans.find((plan) => plan.date === targetDate);
    const plan = target ? { ...target, tasks: [...target.tasks, updated] } : planShell(targetDate, updated);
    plans = [plan, ...plans.filter((item) => item.id !== plan.id && item.date !== targetDate)];
    next = appendEvent({ ...next, plans: plans.slice(0, 180), activePlanId: targetDate === dateKey() ? plan.id : next.activePlanId }, 'task-edited', `AI action: ${existing.title} → ${updated.title}; ${targetDate}`);
  }
  return next;
}

function calculateHabitStreak(dates: string[]) {
  const completed = new Set(dates);
  let cursor = new Date();
  if (!completed.has(dateKey(cursor))) cursor.setDate(cursor.getDate() - 1);
  let streak = 0;
  while (completed.has(dateKey(cursor))) {
    streak += 1;
    cursor.setDate(cursor.getDate() - 1);
  }
  return streak;
}

function withRecurringTasks(current: AppData) {
  const today = dateKey();
  const due = recurringTasksForDate(current.plans, today);
  if (!due.length) return current;
  const todayPlan = current.plans.find((plan) => plan.date === today);
  const existing = new Set(todayPlan?.tasks.map((task) => `${task.title.trim().toLocaleLowerCase()}|${task.recurrence ?? 'none'}`));
  const missing = due.filter((task) => !existing.has(`${task.title.trim().toLocaleLowerCase()}|${task.recurrence ?? 'none'}`));
  if (!missing.length) return current;
  if (todayPlan) {
    return appendEvent({
      ...current,
      plans: current.plans.map((plan) => plan.id === todayPlan.id ? { ...plan, tasks: [...plan.tasks, ...missing] } : plan),
    }, 'task-added', `Recurring: ${missing.map((task) => task.title).join('; ')}`);
  }
  const plan = {
    id: `recurring-plan-${Date.now()}`,
    date: today,
    title: 'Recurring day',
    style: 'realistic' as const,
    mode: 'ai-plan' as const,
    energy: 3 as const,
    intention: missing[0].title,
    tasks: missing,
    createdAt: new Date().toISOString(),
    planScore: 0,
  };
  return appendEvent({ ...current, plans: [plan, ...current.plans].slice(0, 180), activePlanId: plan.id }, 'task-added', `Recurring: ${missing.map((task) => task.title).join('; ')}`);
}

export function AppProvider({ children }: React.PropsWithChildren) {
  const { session } = useAuth();
  const [data, setData] = useState<AppData>(() => createInitialData());
  const [hydrated, setHydrated] = useState(false);
  const [syncStatus, setSyncStatus] = useState<SyncStatus>('local');
  const [hasRecoveryBackup, setHasRecoveryBackup] = useState(false);
  const cloudLoadedFor = useRef<string | undefined>(undefined);
  const capacitySignal = useMemo(() => {
    const latest = data.healthSnapshots[0];
    return latest ? capacityFromHealth(latest) : undefined;
  }, [data.healthSnapshots]);

  useEffect(() => {
    let active = true;
    void (async () => {
      try {
        const [savedV3, savedV2, savedV1, recovery] = await Promise.all([
          appStorage.getItem(STORAGE_KEY),
          appStorage.getItem(PREVIOUS_STORAGE_KEY),
          appStorage.getItem(FIRST_STORAGE_KEY),
          appStorage.getItem(RECOVERY_KEY),
        ]);
        if (!active) return;
        const saved = savedV3 || savedV2 || savedV1;
        if (saved) setData(withRecurringTasks(mergePersistedData(JSON.parse(saved) as Partial<AppData>)));
        if (recovery) {
          const parsed = JSON.parse(recovery) as RecoverySnapshot;
          if (parsed.expiresAt > Date.now()) setHasRecoveryBackup(true);
          else await appStorage.removeItem(RECOVERY_KEY);
        }
      } catch {
        // A corrupt local snapshot should never block opening a clean account.
      } finally {
        if (active) setHydrated(true);
      }
    })();
    return () => {
      active = false;
    };
  }, []);

  useEffect(() => {
    if (!hydrated) return;
    appStorage.setItem(STORAGE_KEY, JSON.stringify(data)).catch(() => undefined);
  }, [data, hydrated]);

  useEffect(() => {
    const userId = session?.user.id;
    if (!userId || !supabase || !hydrated || cloudLoadedFor.current === userId) return;
    cloudLoadedFor.current = userId;
    setSyncStatus('syncing');
    void (async () => {
      try {
        const { data: row, error } = await supabase.from('app_snapshots').select('data').eq('user_id', userId).maybeSingle();
        if (error) throw error;
        if (row?.data) {
          setData((current) => ({
            ...withRecurringTasks(mergePersistedData(row.data as Partial<AppData>)),
            healthSnapshots: current.healthSnapshots,
          }));
        }
        setSyncStatus('synced');
      } catch {
        setSyncStatus('error');
      }
    })();
  }, [session?.user.id, hydrated, data.subscription]);

  useEffect(() => {
    const userId = session?.user.id;
    if (!userId || !supabase || !hydrated || cloudLoadedFor.current !== userId) return;
    const timeout = setTimeout(() => {
      setSyncStatus('syncing');
      void (async () => {
        try {
          const { error } = await supabase!.from('app_snapshots').upsert({ user_id: userId, data: cloudSafeSnapshot(data), updated_at: new Date().toISOString() });
          if (error) throw error;
          setSyncStatus('synced');
        } catch {
          setSyncStatus('error');
        }
      })();
    }, 900);
    return () => clearTimeout(timeout);
  }, [data, session?.user.id, hydrated]);

  const activePlan = useMemo(
    () => data.plans.find((plan) => plan.id === data.activePlanId) ?? data.plans.find((plan) => plan.date === dateKey()),
    [data.activePlanId, data.plans],
  );

  const updateProfile = useCallback((profile: Partial<UserProfile>) => {
    setData((current) => ({ ...current, profile: { ...current.profile, ...profile } }));
  }, []);

  const completeOnboarding = useCallback(
    async (
      profile: Partial<UserProfile>,
      coaching?: Pick<AppSettings, 'coachMode' | 'accountability'>,
    ): Promise<ActionResult<OnboardingResult>> => {
      const firstRun = !data.profile.onboardingCompleted;
      const completeProfile = { ...data.profile, ...profile, onboardingCompleted: true };
      const completeSettings = { ...data.settings, ...coaching };
      const primaryGoal: Goal | undefined = completeProfile.primaryGoal
        ? {
            id: `goal-onboarding-${Date.now()}`,
            title: completeProfile.primaryGoal,
            why: completeProfile.goalWhy || 'Chosen during onboarding.',
            category: completeProfile.category === 'fitness' ? 'fitness' : completeProfile.category === 'study' ? 'study' : 'focus',
            progress: 0,
            milestones: [],
            archived: false,
          }
        : undefined;
      const nextGoals = primaryGoal
        ? [primaryGoal, ...data.goals.filter((goal) => goal.title.toLowerCase() !== completeProfile.primaryGoal.toLowerCase())]
        : data.goals;
      const onboardingData: AppData = {
        ...data,
        profile: completeProfile,
        settings: completeSettings,
        goals: nextGoals,
      };
      const starterInput: PlanBuildInput = {
        brainDump: completeProfile.primaryGoal,
        mustWin: completeProfile.primaryGoal,
        fixedCommitments: completeProfile.fixedCommitments,
        energy: 3,
        style: 'realistic',
      };
      const hasProfileSignal = Boolean([
        completeProfile.primaryGoal,
        completeProfile.selfDescription,
        completeProfile.struggle,
        completeProfile.fixedCommitments,
        completeProfile.currentHabits,
        completeProfile.productiveHours,
        completeProfile.planningPreferences,
      ].some((value) => value.trim()));
      const [analysis, starterPlanResult] = await Promise.all([
        hasProfileSignal
          ? analyzeProfileWithAI(completeProfile, completeSettings.language)
          : Promise.resolve({
              value: {
                summary: 'Setup was skipped. The planner will learn from the first real plan, edits and completed actions.',
                planningRules: ['Start with one honest priority.', 'Adapt the plan from real behavior instead of assumptions.'],
                risks: ['There is not enough personal context yet; recommendations will begin conservatively.'],
                suggestedHabits: [],
              },
              fallback: false,
              warning: undefined,
            }),
        firstRun && completeProfile.primaryGoal.trim()
          ? generateDayPlanWithAI(starterInput, coachContext(onboardingData, undefined, capacitySignal))
          : Promise.resolve(undefined),
      ]);
      const now = new Date().toISOString();
      const rawAnalysisMemories: Pick<MemoryFact, 'category' | 'fact' | 'confidence'>[] = hasProfileSignal
        ? [
            ...(completeProfile.primaryGoal ? [{ category: 'goal' as const, fact: `Primary goal: ${completeProfile.primaryGoal}`, confidence: 1 }] : []),
            ...analysis.value.planningRules.map((fact) => ({ category: 'preference' as const, fact, confidence: analysis.fallback ? 0.55 : 0.82 })),
            ...analysis.value.risks.map((fact) => ({ category: 'blocker' as const, fact, confidence: analysis.fallback ? 0.5 : 0.78 })),
          ]
        : [];
      const analysisMemories: MemoryFact[] = rawAnalysisMemories.map((item, index) => ({
        id: `memory-onboarding-${Date.now()}-${index}`,
        category: item.category,
        fact: item.fact,
        source: 'coach',
        confidence: item.confidence,
        enabled: true,
        createdAt: now,
        updatedAt: now,
      }));
      setData((current) => ({
        ...appendEvent(current, 'profile-analyzed', `${completeProfile.primaryGoal}; ${analysis.value.planningRules.length} planning rules`),
        profile: { ...completeProfile, aiSummary: analysis.value.summary },
        settings: completeSettings,
        goals: primaryGoal
          ? [primaryGoal, ...current.goals.filter((goal) => goal.title.toLowerCase() !== completeProfile.primaryGoal.toLowerCase())]
          : current.goals,
        memories: [...current.memories, ...analysisMemories].slice(-200),
        plans: starterPlanResult
          ? [starterPlanResult.value, ...current.plans.filter((plan) => plan.date !== starterPlanResult.value.date)].slice(0, 180)
          : current.plans,
        activePlanId: starterPlanResult?.value.id ?? current.activePlanId,
      }));
      return {
        ok: true,
        value: { analysis: analysis.value, starterPlan: starterPlanResult?.value },
        fallback: analysis.fallback || Boolean(starterPlanResult?.fallback),
        warning: [analysis.warning, starterPlanResult?.warning].filter(Boolean).join(' · ') || undefined,
      };
    },
    [capacitySignal, data],
  );

  const updateSettings = useCallback((settings: Partial<AppSettings>) => {
    setData((current) => {
      const updated = { ...current, settings: { ...current.settings, ...settings } };
      const meaningful = settings.coachMode
        ? `Coach mode: ${settings.coachMode}`
        : settings.accountability
          ? `Accountability: ${settings.accountability}`
          : settings.autoLearn !== undefined
            ? `Auto-learn: ${settings.autoLearn ? 'on' : 'off'}`
            : '';
      return meaningful ? appendEvent(updated, 'memory-updated', meaningful) : updated;
    });
  }, []);

  const setSubscription = useCallback((subscription: SubscriptionTier) => {
    setData((current) => appendEvent({ ...current, subscription }, 'subscription-changed', subscription));
  }, []);

  const buildPlanAction = useCallback(
    async (input: PlanBuildInput): Promise<ActionResult<AppData['plans'][number]>> => {
      const fresh = withFreshUsage(data);
      if (fresh.usage.plansBuilt >= subscriptionPlans[fresh.subscription].limits.plansPerDay) return { ok: false, reason: 'limit' };
      const result = await generateDayPlanWithAI(input, coachContext(fresh, activePlan, capacitySignal));
      const plan = input.plannerMode === 'day-chain' && activePlan
        ? preserveCompletedTasks(activePlan, result.value)
        : result.value;
      setData((current) => {
        const normalized = withFreshUsage(current);
        const next = appendEvent(normalized, 'plan-built', `${plan.title}: ${plan.tasks.length} scheduled actions`);
        return {
          ...next,
          plans: [plan, ...next.plans.filter((item) => item.date !== plan.date)].slice(0, 180),
          activePlanId: plan.id,
          usage: { ...next.usage, plansBuilt: next.usage.plansBuilt + 1 },
          achievements: next.achievements.map((achievement) =>
            achievement.id === 'achievement-first-plan'
              ? { ...achievement, progress: 1, unlockedAt: achievement.unlockedAt ?? new Date().toISOString() }
              : achievement,
          ),
        };
      });
      return resultFromAI({ ...result, value: plan });
    },
    [activePlan, capacitySignal, data],
  );

  const rescuePlanAction = useCallback(
    async (input: RescueInput): Promise<ActionResult<AppData['plans'][number]>> => {
      if (!activePlan) return { ok: false, reason: 'missing-plan' };
      const fresh = withFreshUsage(data);
      if (fresh.usage.rescues >= subscriptionPlans[fresh.subscription].limits.rescuesPerDay) return { ok: false, reason: 'limit' };
      const result = await replanDayWithAI(activePlan, input, coachContext(fresh, activePlan, capacitySignal));
      const plan = result.value;
      setData((current) => {
        const normalized = withFreshUsage(current);
        const next = appendEvent(normalized, 'plan-replanned', `${input.reason}; ${input.availableMinutes} usable minutes; energy ${input.energy}/5`);
        return {
          ...next,
          plans: [plan, ...next.plans.filter((item) => item.date !== plan.date)].slice(0, 180),
          activePlanId: plan.id,
          usage: { ...next.usage, rescues: next.usage.rescues + 1 },
        };
      });
      return resultFromAI(result);
    },
    [activePlan, capacitySignal, data],
  );

  const updateTask = useCallback((taskId: string, updater: (task: Task) => Task, eventType: BehaviorEventType, detail: (task: Task) => string) => {
    setData((current) => {
      const target = current.plans.flatMap((plan) => plan.tasks).find((task) => task.id === taskId);
      const updated = {
        ...current,
        plans: current.plans.map((plan) => ({ ...plan, tasks: plan.tasks.map((task) => (task.id === taskId ? updater(task) : task)) })),
      };
      return target ? appendEvent(updated, eventType, detail(target)) : updated;
    });
  }, []);

  const toggleTask = useCallback((taskId: string) => {
    setData((current) => {
      const plan = current.plans.find((item) => item.tasks.some((task) => task.id === taskId));
      const task = plan?.tasks.find((item) => item.id === taskId);
      if (!plan || !task) return current;
      const completing = task.status !== 'completed';
      const plans = current.plans.map((item) => ({
        ...item,
        tasks: item.tasks.map((candidate) =>
          candidate.id === taskId
            ? {
                ...candidate,
                status: completing ? ('completed' as const) : ('pending' as const),
                completedAt: completing ? new Date().toISOString() : undefined,
              }
            : candidate,
        ),
      }));
      const completedDates = new Set(
        plans
          .flatMap((item) => item.tasks)
          .filter((item) => item.status === 'completed')
          .map((item) => item.planDate),
      );
      const honestDays = Math.min(7, completedDates.size);
      const achievements = current.achievements.map((achievement) => {
        if (achievement.id === 'achievement-comeback' && completing && plan.rescuedAt) {
          return { ...achievement, progress: 1, unlockedAt: achievement.unlockedAt ?? new Date().toISOString() };
        }
        if (achievement.id === 'achievement-streak') {
          return {
            ...achievement,
            progress: honestDays,
            unlockedAt: honestDays >= achievement.target ? achievement.unlockedAt ?? new Date().toISOString() : achievement.unlockedAt,
          };
        }
        return achievement;
      });
      return appendEvent(
        { ...current, plans, achievements },
        completing ? 'task-completed' : 'task-reopened',
        `${task.title}; ${task.category}; ${task.durationMinutes} minutes`,
      );
    });
  }, []);

  const startTask = useCallback(
    (taskId: string) => updateTask(taskId, (task) => ({ ...task, status: 'active' }), 'task-started', (task) => task.title),
    [updateTask],
  );

  const skipTask = useCallback(
    (taskId: string, reason = 'Not right for today') =>
      updateTask(taskId, (task) => ({ ...task, status: 'skipped', skippedReason: reason }), 'task-skipped', (task) => `${task.title}; reason: ${reason}`),
    [updateTask],
  );

  const editTask = useCallback((taskId: string, changes: Partial<Task>) => {
    setData((current) => {
      const target = current.plans.flatMap((plan) => plan.tasks).find((task) => task.id === taskId);
      const updated = {
        ...current,
        plans: current.plans.map((plan) => ({ ...plan, tasks: plan.tasks.map((task) => (task.id === taskId ? { ...task, ...changes, id: task.id } : task)) })),
      };
      const detail = [
        `${target?.title ?? 'Task'} → ${changes.title || target?.title || 'Task'}`,
        changes.note ? `note: ${changes.note.slice(0, 240)}` : '',
        changes.durationMinutes ? `${changes.durationMinutes} minutes` : '',
        changes.startTime ? `starts ${changes.startTime}` : '',
        changes.recurrence && changes.recurrence !== 'none' ? `repeats ${changes.recurrence}` : '',
        changes.subtasks?.length ? `subtasks: ${changes.subtasks.map((subtask) => subtask.title).join(', ')}` : '',
      ].filter(Boolean).join('; ');
      return target ? appendEvent(updated, 'task-edited', detail) : updated;
    });
  }, []);

  const deleteTask = useCallback((taskId: string) => {
    setData((current) => {
      const target = current.plans.flatMap((plan) => plan.tasks).find((task) => task.id === taskId);
      const updated = { ...current, plans: current.plans.map((plan) => ({ ...plan, tasks: plan.tasks.filter((task) => task.id !== taskId) })) };
      return target ? appendEvent(updated, 'task-deleted', target.title) : updated;
    });
  }, []);

  const duplicateTask = useCallback((taskId: string) => {
    setData((current) => {
      const plan = current.plans.find((item) => item.tasks.some((task) => task.id === taskId));
      const task = plan?.tasks.find((item) => item.id === taskId);
      if (!plan || !task) return current;
      const now = Date.now();
      const copy: Task = {
        ...task,
        id: `task-copy-${now}`,
        title: `${task.title} copy`,
        status: 'pending',
        completedAt: undefined,
        skippedReason: undefined,
        source: 'manual',
        subtasks: task.subtasks?.map((subtask, index) => ({ ...subtask, id: `subtask-copy-${now}-${index}`, completed: false })),
      };
      return appendEvent({
        ...current,
        plans: current.plans.map((item) => item.id === plan.id ? { ...item, tasks: [...item.tasks, copy] } : item),
      }, 'task-duplicated', task.title);
    });
  }, []);

  const duplicateDay = useCallback((sourceDate: string, targetDate: string) => {
    const source = data.plans.find((plan) => plan.date === sourceDate);
    if (!source?.tasks.length || sourceDate === targetDate) return false;
    const now = Date.now();
    const copies = source.tasks.map((task, index) => ({
      ...task,
      id: `task-day-copy-${now}-${index}`,
      planDate: targetDate,
      status: 'pending' as const,
      completedAt: undefined,
      skippedReason: undefined,
      source: 'manual' as const,
      externalId: undefined,
      externalSource: undefined,
      subtasks: task.subtasks?.map((subtask, subtaskIndex) => ({ ...subtask, id: `subtask-day-copy-${now}-${index}-${subtaskIndex}`, completed: false })),
    }));
    setData((current) => {
      const target = current.plans.find((plan) => plan.date === targetDate);
      const plan = target
        ? { ...target, tasks: [...target.tasks, ...copies] }
        : { ...source, id: `plan-day-copy-${now}`, date: targetDate, title: `${source.title} copy`, tasks: copies, createdAt: new Date().toISOString(), rescuedAt: undefined };
      const plans = [plan, ...current.plans.filter((item) => item.id !== plan.id && item.date !== targetDate)].slice(0, 180);
      return appendEvent({ ...current, plans, activePlanId: targetDate === dateKey() ? plan.id : current.activePlanId }, 'plan-duplicated', `${sourceDate} → ${targetDate}`);
    });
    return true;
  }, [data.plans]);

  const moveTask = useCallback((taskId: string, direction: -1 | 1) => {
    setData((current) => {
      const plan = current.plans.find((item) => item.tasks.some((task) => task.id === taskId));
      if (!plan) return current;
      const index = plan.tasks.findIndex((task) => task.id === taskId);
      const targetIndex = index + direction;
      if (index < 0 || targetIndex < 0 || targetIndex >= plan.tasks.length) return current;
      const tasks = [...plan.tasks];
      [tasks[index], tasks[targetIndex]] = [tasks[targetIndex], tasks[index]];
      return appendEvent({
        ...current,
        plans: current.plans.map((item) => item.id === plan.id ? { ...item, tasks } : item),
      }, 'task-edited', `${tasks[targetIndex].title}; moved ${direction < 0 ? 'earlier' : 'later'}`);
    });
  }, []);

  const addManualTask = useCallback((title: string, durationMinutes = 25) => {
    if (!title.trim()) return;
    setData((current) => {
      const planId = current.activePlanId;
      if (!planId) {
        const firstTask = createManualTask(title, dateKey(), durationMinutes);
        const plan = {
          id: `chain-${Date.now()}`,
          date: dateKey(),
          title: 'My day chain',
          style: 'realistic' as const,
          mode: 'day-chain' as const,
          energy: 3 as const,
          intention: title.trim(),
          tasks: [firstTask],
          createdAt: new Date().toISOString(),
          planScore: 0,
        };
        return appendEvent({ ...current, plans: [plan, ...current.plans], activePlanId: plan.id }, 'task-added', title.trim());
      }
      const updated = {
        ...current,
        plans: current.plans.map((plan) =>
          plan.id === planId ? { ...plan, tasks: [...plan.tasks, createManualTask(title, plan.date, durationMinutes)] } : plan,
        ),
      };
      return appendEvent(updated, 'task-added', title.trim());
    });
  }, []);

  const importCalendarTasks = useCallback((tasks: Task[], options?: CalendarImportOptions) => {
    const valid = tasks.filter((task) => task.title.trim() && task.planDate);
    if (!valid.length && !options?.replaceExternalRange) return 0;
    setData((current) => {
      const externalKey = (task: Task) => task.externalId && task.externalSource ? `${task.externalSource}:${task.externalId}` : undefined;
      const incomingIds = new Set(valid.map(externalKey).filter((id): id is string => Boolean(id)));
      const existingIds = new Set<string>();
      const replacement = options?.replaceExternalRange;
      let plans = current.plans.map((plan) => ({
        ...plan,
        tasks: plan.tasks.filter((task) => {
          const key = externalKey(task);
          if (key && incomingIds.has(key)) {
            existingIds.add(key);
            return false;
          }
          const replaceMissing = Boolean(
            replacement &&
            task.externalSource &&
            replacement.sources.includes(task.externalSource) &&
            task.planDate >= replacement.startDate &&
            task.planDate <= replacement.endDate,
          );
          return !replaceMissing;
        }),
      }));
      const unique = valid.filter((task, index) => {
        const key = externalKey(task);
        return !key || valid.findIndex((candidate) => externalKey(candidate) === key) === index;
      });
      let activePlanId = current.activePlanId;
      const grouped = new Map<string, Task[]>();
      unique.forEach((task) => grouped.set(task.planDate, [...(grouped.get(task.planDate) ?? []), task]));
      for (const [day, dayTasks] of grouped) {
        const index = plans.findIndex((plan) => plan.date === day);
        if (index >= 0) {
          plans[index] = { ...plans[index], tasks: [...plans[index].tasks, ...dayTasks] };
          if (day === dateKey()) activePlanId = plans[index].id;
        } else {
          const plan = {
            id: `calendar-plan-${Date.now()}-${day}`,
            date: day,
            title: 'Imported calendar',
            style: 'realistic' as const,
            mode: 'ai-plan' as const,
            energy: 3 as const,
            intention: dayTasks[0].title,
            tasks: dayTasks,
            createdAt: new Date().toISOString(),
            planScore: 0,
          };
          plans = [plan, ...plans];
          if (day === dateKey()) activePlanId = plan.id;
        }
      }
      const updatedCount = unique.filter((task) => {
        const key = externalKey(task);
        return Boolean(key && existingIds.has(key));
      }).length;
      return appendEvent({ ...current, plans: plans.slice(0, 180), activePlanId }, 'calendar-synced', `${unique.length} device items; ${updatedCount} updated`);
    });
    return valid.length;
  }, []);

  const applyCapacitySignal = useCallback((signal?: CapacitySignal, snapshot?: HealthSnapshot) => {
    if (!signal && !snapshot) return;
    setData((current) => {
      const snapshotDate = snapshot ? dateKey(new Date(snapshot.lastUpdated)) : undefined;
      const healthSnapshots = snapshot
        ? [snapshot, ...current.healthSnapshots.filter((item) => dateKey(new Date(item.lastUpdated)) !== snapshotDate)].slice(0, 30)
        : current.healthSnapshots;
      const next = { ...current, healthSnapshots };
      return signal && current.settings.healthPlanningEnabled
        ? appendEvent(next, 'capacity-applied', `${signal.level}; score ${signal.score}; ${signal.suggestedFocusMinutes} minute focus`)
        : next;
    });
  }, []);

  const setPlannerMode = useCallback((mode: PlannerMode) => {
    setData((current) => ({
      ...current,
      plans: current.plans.map((plan) => (plan.id === current.activePlanId ? { ...plan, mode } : plan)),
    }));
  }, []);

  const sendCoachMessage = useCallback(
    async (content: string): Promise<ActionResult<CoachMessage>> => {
      const trimmed = content.trim();
      if (!trimmed) return { ok: false, reason: 'invalid' };
      const fresh = withFreshUsage(data);
      if (fresh.usage.coachMessages >= subscriptionPlans[fresh.subscription].limits.coachMessagesPerDay) return { ok: false, reason: 'limit' };
      const result = await generateCoachReplyWithAI(trimmed, coachContext(fresh, activePlan, capacitySignal));
      const explicitDelete = /\b(delete|remove)\b|удал|убер/i.test(trimmed);
      const executableActions = result.value.actions.filter((action) => action.type !== 'delete_task' || explicitDelete);
      const createdAt = new Date().toISOString();
      const userMessage: CoachMessage = { id: `message-user-${Date.now()}`, role: 'user', content: trimmed, createdAt };
      const actionSummary = executableActions.length
        ? `\n\n✓ ${executableActions.length === 1 ? 'Plan updated' : `${executableActions.length} plan actions applied`}`
        : '';
      const assistantMessage: CoachMessage = {
        id: `message-assistant-${Date.now() + 1}`,
        role: 'assistant',
        content: `${result.value.reply}${actionSummary}`,
        createdAt: new Date().toISOString(),
        mode: fresh.settings.coachMode,
      };
      setData((current) => {
        const normalized = withFreshUsage(current);
        const learned = normalized.settings.autoLearn ? toMemoryFacts(result.value.memories) : [];
        const existing = new Set(normalized.memories.map((memory) => memory.fact.toLowerCase()));
        const unique = learned.filter((memory) => !existing.has(memory.fact.toLowerCase()));
        const next = applyCoachActions(appendEvent(normalized, 'coach-used', trimmed.slice(0, 140)), executableActions);
        return {
          ...next,
          messages: [...next.messages, userMessage, assistantMessage].slice(-160),
          memories: [...next.memories, ...unique].slice(-240),
          usage: { ...next.usage, coachMessages: next.usage.coachMessages + 1 },
        };
      });
      return { ok: true, value: assistantMessage, fallback: result.fallback, warning: result.warning };
    },
    [activePlan, capacitySignal, data],
  );

  const buildHorizonPlan = useCallback(
    async (horizon: PlanningHorizon, objective: string): Promise<ActionResult<HorizonPlan>> => {
      if (!objective.trim()) return { ok: false, reason: 'invalid' };
      const rank: Record<SubscriptionTier, number> = { free: 0, plus: 1, pro: 2, max: 3 };
      const required: Record<PlanningHorizon, number> = { day: 0, week: 1, month: 2, year: 3 };
      if (rank[data.subscription] < required[horizon]) return { ok: false, reason: 'locked' };
      const result = await generateHorizonPlanWithAI(horizon, objective.trim(), coachContext(data, activePlan, capacitySignal));
      setData((current) => appendEvent(
        { ...current, horizonPlans: [result.value, ...current.horizonPlans].slice(0, 30) },
        'roadmap-built',
        `${horizon}: ${objective.trim()}`,
      ));
      return resultFromAI(result);
    },
    [activePlan, capacitySignal, data],
  );

  const addInboxTask = useCallback((title: string) => {
    if (!title.trim()) return;
    const item: InboxTask = { id: `inbox-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`, title: title.trim(), createdAt: new Date().toISOString() };
    setData((current) => appendEvent({ ...current, inbox: [item, ...current.inbox].slice(0, 200) }, 'inbox-added', item.title));
  }, []);

  const removeInboxTasks = useCallback((ids: string[], planned = false) => {
    const selected = new Set(ids);
    setData((current) => {
      const titles = current.inbox.filter((item) => selected.has(item.id)).map((item) => item.title);
      const updated = { ...current, inbox: current.inbox.filter((item) => !selected.has(item.id)) };
      return planned && titles.length ? appendEvent(updated, 'inbox-planned', titles.join('; ')) : updated;
    });
  }, []);

  const addNote = useCallback((title: string, body: string, source: AppNote['source'] = 'manual') => {
    const cleanBody = body.trim();
    const cleanTitle = title.trim() || cleanBody.split(/\r?\n/)[0]?.slice(0, 80) || 'Untitled note';
    if (!cleanBody && !cleanTitle) return undefined;
    const now = new Date().toISOString();
    const id = `note-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`;
    const note: AppNote = { id, title: cleanTitle, body: cleanBody, source, createdAt: now, updatedAt: now };
    setData((current) => appendEvent({ ...current, notes: [note, ...current.notes].slice(0, 500) }, 'note-added', cleanTitle));
    return id;
  }, []);

  const deleteNote = useCallback((noteId: string) => {
    setData((current) => ({ ...current, notes: current.notes.filter((note) => note.id !== noteId) }));
  }, []);

  const updateNote = useCallback((noteId: string, title: string, body: string) => {
    const updatedAt = new Date().toISOString();
    setData((current) => ({
      ...current,
      notes: current.notes.map((note) => note.id === noteId
        ? { ...note, title: title.trim() || 'Untitled note', body: body.trim(), updatedAt }
        : note),
    }));
  }, []);

  const planNote = useCallback((noteId: string) => {
    setData((current) => {
      const note = current.notes.find((item) => item.id === noteId);
      if (!note) return current;
      const item: InboxTask = { id: `inbox-note-${Date.now()}`, title: note.title, note: note.body.slice(0, 500), createdAt: new Date().toISOString() };
      return appendEvent({ ...current, inbox: [item, ...current.inbox].slice(0, 200) }, 'note-planned', note.title);
    });
  }, []);

  const addWorkoutSession = useCallback((session: Omit<WorkoutSession, 'id'>) => {
    const workout = { ...session, id: `workout-${Date.now()}-${Math.random().toString(36).slice(2, 6)}` };
    setData((current) => appendEvent({ ...current, workouts: [workout, ...current.workouts].slice(0, 300) }, 'workout-completed', `${workout.title}; ${workout.durationMinutes} minutes`));
  }, []);

  const addGoal = useCallback((goal: Pick<Goal, 'title' | 'why' | 'category'>) => {
    setData((current) => appendEvent({
      ...current,
      goals: [...current.goals, { ...goal, id: `goal-${Date.now()}`, progress: 0, milestones: [], archived: false }],
    }, 'goal-created', `${goal.title}; why: ${goal.why || 'not specified'}; category: ${goal.category}`));
  }, []);

  const updateGoalProgress = useCallback((goalId: string, progress: number) => {
    setData((current) => {
      const goal = current.goals.find((item) => item.id === goalId);
      const value = Math.max(0, Math.min(100, progress));
      const updated = { ...current, goals: current.goals.map((item) => (item.id === goalId ? { ...item, progress: value } : item)) };
      return goal ? appendEvent(updated, 'goal-progress', `${goal.title}: ${value}%`) : updated;
    });
  }, []);

  const toggleMilestone = useCallback((goalId: string, milestoneId: string) => {
    setData((current) => {
      const goal = current.goals.find((item) => item.id === goalId);
      const milestone = goal?.milestones.find((item) => item.id === milestoneId);
      const updated = {
        ...current,
        goals: current.goals.map((item) =>
          item.id === goalId
            ? { ...item, milestones: item.milestones.map((candidate) => (candidate.id === milestoneId ? { ...candidate, completed: !candidate.completed } : candidate)) }
            : item,
        ),
      };
      return milestone ? appendEvent(updated, 'milestone-updated', `${goal?.title}: ${milestone.title}; ${milestone.completed ? 'reopened' : 'completed'}`) : updated;
    });
  }, []);

  const addHabit = useCallback((title: string) => {
    if (!title.trim()) return;
    const habit: Habit = {
      id: `habit-${Date.now()}`,
      title: title.trim(),
      icon: 'checkmark.seal.fill',
      targetDays: [0, 1, 2, 3, 4, 5, 6],
      completedDates: [],
      currentStreak: 0,
      bestStreak: 0,
    };
    setData((current) => appendEvent({ ...current, habits: [...current.habits, habit] }, 'habit-created', habit.title));
  }, []);

  const toggleHabitToday = useCallback((habitId: string) => {
    const today = dateKey();
    setData((current) => {
      let eventType: BehaviorEventType = 'habit-completed';
      let detail = '';
      const habits = current.habits.map((habit) => {
        if (habit.id !== habitId) return habit;
        const completed = habit.completedDates.includes(today);
        eventType = completed ? 'habit-reopened' : 'habit-completed';
        detail = habit.title;
        const completedDates = completed ? habit.completedDates.filter((date) => date !== today) : [...habit.completedDates, today];
        const currentStreak = calculateHabitStreak(completedDates);
        return { ...habit, completedDates, currentStreak, bestStreak: Math.max(habit.bestStreak, currentStreak) };
      });
      return detail ? appendEvent({ ...current, habits }, eventType, detail) : { ...current, habits };
    });
  }, []);

  const addMemory = useCallback((fact: string, category: MemoryFact['category'] = 'preference') => {
    if (!fact.trim()) return;
    const now = new Date().toISOString();
    setData((current) => appendEvent({
      ...current,
      memories: [...current.memories, { id: `memory-${Date.now()}`, category, fact: fact.trim(), source: 'user', confidence: 1, enabled: true, createdAt: now, updatedAt: now }],
    }, 'memory-updated', `Added ${category}: ${fact.trim()}`));
  }, []);

  const toggleMemory = useCallback((memoryId: string) => {
    setData((current) => {
      const memory = current.memories.find((item) => item.id === memoryId);
      const updated = {
        ...current,
        memories: current.memories.map((item) =>
          item.id === memoryId ? { ...item, enabled: !item.enabled, updatedAt: new Date().toISOString() } : item,
        ),
      };
      return memory ? appendEvent(updated, 'memory-updated', `${memory.enabled ? 'Paused' : 'Restored'}: ${memory.fact}`) : updated;
    });
  }, []);

  const deleteMemory = useCallback((memoryId: string) => {
    setData((current) => {
      const memory = current.memories.find((item) => item.id === memoryId);
      const updated = { ...current, memories: current.memories.filter((item) => item.id !== memoryId) };
      return memory ? appendEvent(updated, 'memory-updated', `Forgot: ${memory.fact}`) : updated;
    });
  }, []);

  const addReview = useCallback((review: Omit<DailyReview, 'id' | 'date'>) => {
    setData((current) => appendEvent({
      ...current,
      reviews: [...current.reviews.filter((item) => item.date !== dateKey()), { ...review, id: `review-${Date.now()}`, date: dateKey() }],
    }, 'review-saved', `Score ${review.score}%; blocker: ${review.blocker || 'none'}; energy ${review.mood}/5; wins: ${review.wins.join(', ') || 'none'}; lesson: ${review.lesson || 'none'}`));
  }, []);

  const resetData = useCallback(async () => {
    const snapshot: RecoverySnapshot = { expiresAt: Date.now() + RECOVERY_WINDOW_MS, data };
    await appStorage.setItem(RECOVERY_KEY, JSON.stringify(snapshot));
    setHasRecoveryBackup(true);
    // Reset product data, not the verified identity or paid entitlement. A
    // reversible reset cannot also delete the login account or cancel a store
    // subscription.
    const initial = { ...createInitialData(), subscription: data.subscription };
    const userId = session?.user.id;
    if (userId && supabase) {
      setSyncStatus('syncing');
      const { error } = await supabase.from('app_snapshots').upsert({
        user_id: userId,
        data: cloudSafeSnapshot(initial),
        updated_at: new Date().toISOString(),
      });
      setSyncStatus(error ? 'error' : 'synced');
      cloudLoadedFor.current = userId;
    }
    setData(initial);
    await appStorage.setItem(STORAGE_KEY, JSON.stringify(initial));
  }, [data, session?.user.id]);

  const restoreLastReset = useCallback(async () => {
    try {
      const saved = await appStorage.getItem(RECOVERY_KEY);
      if (!saved) return false;
      const snapshot = JSON.parse(saved) as RecoverySnapshot;
      if (snapshot.expiresAt <= Date.now()) {
        await appStorage.removeItem(RECOVERY_KEY);
        setHasRecoveryBackup(false);
        return false;
      }
      const restored = withRecurringTasks(mergePersistedData(snapshot.data));
      setData(restored);
      await appStorage.setItem(STORAGE_KEY, JSON.stringify(restored));
      await appStorage.removeItem(RECOVERY_KEY);
      setHasRecoveryBackup(false);
      return true;
    } catch {
      return false;
    }
  }, []);

  const value = useMemo<AppContextValue>(
    () => ({
      data,
      capacitySignal,
      activePlan,
      hydrated,
      syncStatus,
      hasRecoveryBackup,
      updateProfile,
      completeOnboarding,
      updateSettings,
      setSubscription,
      buildPlan: buildPlanAction,
      rescuePlan: rescuePlanAction,
      toggleTask,
      startTask,
      skipTask,
      editTask,
      deleteTask,
      duplicateTask,
      duplicateDay,
      moveTask,
      addManualTask,
      importCalendarTasks,
      applyCapacitySignal,
      setPlannerMode,
      sendCoachMessage,
      buildHorizonPlan,
      addInboxTask,
      removeInboxTasks,
      addNote,
      updateNote,
      deleteNote,
      planNote,
      addWorkoutSession,
      addGoal,
      updateGoalProgress,
      toggleMilestone,
      addHabit,
      toggleHabitToday,
      addMemory,
      toggleMemory,
      deleteMemory,
      addReview,
      resetData,
      restoreLastReset,
    }),
    [
      data,
      capacitySignal,
      activePlan,
      hydrated,
      syncStatus,
      hasRecoveryBackup,
      updateProfile,
      completeOnboarding,
      updateSettings,
      setSubscription,
      buildPlanAction,
      rescuePlanAction,
      toggleTask,
      startTask,
      skipTask,
      editTask,
      deleteTask,
      duplicateTask,
      duplicateDay,
      moveTask,
      addManualTask,
      importCalendarTasks,
      applyCapacitySignal,
      setPlannerMode,
      sendCoachMessage,
      buildHorizonPlan,
      addInboxTask,
      removeInboxTasks,
      addNote,
      updateNote,
      deleteNote,
      planNote,
      addWorkoutSession,
      addGoal,
      updateGoalProgress,
      toggleMilestone,
      addHabit,
      toggleHabitToday,
      addMemory,
      toggleMemory,
      deleteMemory,
      addReview,
      resetData,
      restoreLastReset,
    ],
  );

  return <AppContext.Provider value={value}>{children}</AppContext.Provider>;
}

export function useApp() {
  const value = React.use(AppContext);
  if (!value) throw new Error('useApp must be used inside AppProvider');
  return value;
}
