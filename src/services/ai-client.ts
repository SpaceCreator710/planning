import { fetch } from 'expo/fetch';
import { z } from 'zod';

import { dateKey, minutesToTime, timeToMinutes } from '@/lib/date';
import { generateMockCoachReply } from '@/services/mock-coach';
import { buildDayPlan, rescueDayPlan } from '@/services/plan-engine';
import { suggestTaskAppearance, taskColorChoices, taskIconChoices } from '@/services/task-appearance';
import type {
  CoachContext,
  DayPlan,
  DaySection,
  HorizonPlan,
  MemoryFact,
  PlanBuildInput,
  PlanningHorizon,
  RescueInput,
  Task,
  TaskCategory,
  UserProfile,
} from '@/types/app';

const taskSchema = z.object({
  title: z.string().min(1).max(140),
  note: z.string().max(240).optional().default(''),
  startTime: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/),
  endTime: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/),
  durationMinutes: z.number().int().min(5).max(480),
  section: z.enum(['morning', 'day', 'evening', 'night']),
  category: z.enum(['focus', 'work', 'study', 'fitness', 'life', 'rest']),
  priority: z.number().int().min(1).max(3),
  mustWin: z.boolean(),
  color: z.enum(taskColorChoices),
  icon: z.enum(taskIconChoices),
});

const planSchema = z.object({
  title: z.string().min(1).max(100),
  intention: z.string().min(1).max(180),
  planScore: z.number().int().min(0).max(100),
  coachNote: z.string().max(320).optional().default(''),
  tasks: z.array(taskSchema).min(1).max(16),
});

const coachSchema = z.object({
  reply: z.string().min(1).max(2400),
  memories: z
    .array(
      z.object({
        category: z.enum(['goal', 'routine', 'blocker', 'preference', 'pattern']),
        fact: z.string().min(3).max(180),
        confidence: z.number().min(0).max(1),
      }),
    )
    .max(3),
  actions: z
    .array(
      z.object({
        type: z.enum(['create_task', 'update_task', 'complete_task', 'skip_task', 'delete_task']),
        taskId: z.string().max(120),
        title: z.string().max(140),
        date: z.string().max(10),
        startTime: z.union([z.literal(''), z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/)]),
        durationMinutes: z.number().int().min(5).max(480),
        category: z.enum(['focus', 'work', 'study', 'fitness', 'life', 'rest']),
      }),
    )
    .max(5),
});

const profileAnalysisSchema = z.object({
  summary: z.string().min(1).max(500),
  planningRules: z.array(z.string().min(1).max(180)).min(2).max(6),
  risks: z.array(z.string().min(1).max(180)).min(1).max(5),
  suggestedHabits: z.array(z.string().min(1).max(100)).max(4),
});

const horizonSchema = z.object({
  title: z.string().min(1).max(120),
  summary: z.string().min(1).max(600),
  checkpoints: z
    .array(
      z.object({
        label: z.string().min(1).max(80),
        outcome: z.string().min(1).max(220),
        actions: z.array(z.string().min(1).max(160)).min(1).max(5),
      }),
    )
    .min(2)
    .max(12),
});

type PlanPayload = z.infer<typeof planSchema>;
type CoachPayload = z.infer<typeof coachSchema>;
export type CoachAction = CoachPayload['actions'][number];
export type ProfileAnalysis = z.infer<typeof profileAnalysisSchema>;

export interface AIResult<T> {
  value: T;
  fallback: boolean;
  warning?: string;
}

export type AIConnectionStatus = 'online' | 'unconfigured' | 'offline';

export interface AIConnection {
  status: AIConnectionStatus;
  message: string;
  latencyMs?: number;
}

function endpoint() {
  const configured = process.env.EXPO_PUBLIC_AI_ENDPOINT?.trim();
  if (configured) return configured;
  return process.env.EXPO_OS === 'web' ? '/api/ai' : '';
}

interface AIRequestOptions {
  mode?: CoachContext['settings']['coachMode'];
  language?: CoachContext['settings']['language'];
  operation?: 'build' | 'replan';
  horizon?: PlanningHorizon;
}

export async function checkAIConnection(): Promise<AIConnection> {
  const url = endpoint();
  if (!url) {
    return { status: 'unconfigured', message: 'The protected Groq server endpoint is not configured for this build.' };
  }
  const startedAt = Date.now();
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 8_000);
  try {
    const response = await fetch(url, { method: 'GET', signal: controller.signal });
    const body = (await response.json().catch(() => ({}))) as { ready?: boolean; message?: string };
    if (response.ok && body.ready) {
      return { status: 'online', message: 'Groq AI is online.', latencyMs: Date.now() - startedAt };
    }
    if (response.status === 503) return { status: 'unconfigured', message: body.message || 'The server is online, but its private AI key is not configured.' };
    return { status: 'offline', message: body.message || `The AI server returned ${response.status}.` };
  } catch {
    return { status: 'offline', message: 'The protected Groq server function is unavailable.' };
  } finally {
    clearTimeout(timeout);
  }
}

async function requestAI(
  schema: 'coach' | 'plan' | 'profile' | 'horizon',
  prompt: string,
  options: AIRequestOptions = {},
) {
  const url = endpoint();
  if (!url) throw new Error('The protected Groq server endpoint is not configured.');

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 28_000);
  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ schema, prompt, ...options }),
      signal: controller.signal,
    });
    const body = (await response.json().catch(() => ({}))) as { text?: string; error?: string };
    if (response.ok && body.text) return body.text;
    throw new Error(body.error || `Groq AI request failed (${response.status}).`);
  } finally {
    clearTimeout(timeout);
  }
}

function compactContext(context: CoachContext) {
  const clip = (value: string | undefined, limit: number) => (value ?? '').slice(0, limit);
  const plan = context.activePlan
    ? JSON.stringify(
        context.activePlan.tasks.map((task) => ({
          id: task.id,
          title: task.title.slice(0, 180),
          note: task.note?.slice(0, 300),
          time: task.startTime ? `${task.startTime}-${task.endTime}` : 'anytime',
          minutes: task.durationMinutes,
          priority: task.priority,
          mustWin: task.mustWin,
          status: task.status,
          skippedReason: task.skippedReason,
        })),
      )
    : 'No active plan';
  return [
    `PROFILE: ${JSON.stringify({
      goal: context.profile.primaryGoal,
      why: context.profile.goalWhy,
      struggle: context.profile.struggle,
      wake: context.profile.wakeTime,
      sleep: context.profile.sleepTime,
      discipline: context.profile.discipline,
      commitments: clip(context.profile.fixedCommitments, 1200),
      habits: clip(context.profile.currentHabits, 1200),
      productiveHours: clip(context.profile.productiveHours, 500),
      preferences: clip(context.profile.planningPreferences, 900),
      description: clip(context.profile.selfDescription, 4000),
      optionalBodyRhythm: context.profile.bodyRhythmEnabled
        ? { startDate: context.profile.cycleStartDate, cycleDays: context.profile.cycleLengthDays, resetDays: context.profile.cyclePeriodDays }
        : 'disabled',
      aiSummary: clip(context.profile.aiSummary, 600),
    })}`,
    `ACTIVE GOALS: ${context.goals.filter((goal) => !goal.archived).slice(0, 20).map((goal) => `${clip(goal.title, 180)} (${goal.progress}%)`).join('; ') || 'none'}`,
    `HABITS: ${context.habits.slice(0, 30).map((habit) => `${clip(habit.title, 140)}: ${habit.currentStreak} current / ${habit.bestStreak} best`).join('; ') || 'none'}`,
    `RECENT REVIEWS: ${context.reviews.slice(-7).map((review) => `${review.date}: ${review.score}%, energy ${review.mood}/5, blocker ${clip(review.blocker, 160) || 'none'}, lesson ${clip(review.lesson, 240) || 'none'}`).join('; ') || 'none'}`,
    `MEMORY: ${context.memories.filter((memory) => memory.enabled).slice(-20).map((memory) => clip(memory.fact, 240)).join('; ') || 'none'}`,
    `RECENT COACH CONVERSATION: ${context.messages.slice(-12).map((message) => `${message.role}: ${clip(message.content, 600)}`).join('\n') || 'none'}`,
    `RECENT BEHAVIOR: ${context.events.slice(-50).map((event) => `${event.type}: ${clip(event.detail, 240)}`).join('; ') || 'none yet'}`,
    `INBOX: ${context.inbox.slice(0, 30).map((item) => clip(item.title, 160)).join('; ') || 'empty'}`,
    `OPTIONAL CAPACITY SIGNAL: ${context.capacitySignal ? JSON.stringify(context.capacitySignal) : 'not connected or not consented for planning'}`,
    `TODAY:\n${plan}`,
  ].join('\n\n');
}

function toDayPlan(payload: PlanPayload, input: PlanBuildInput, source: Task['source'], rescued = false): DayPlan {
  const now = Date.now();
  let occupiedUntil = -10;
  const orderedTasks = [...payload.tasks].sort((a, b) => timeToMinutes(a.startTime) - timeToMinutes(b.startTime));
  const mustWinIndex = Math.max(0, orderedTasks.findIndex((task) => task.mustWin));
  const tasks: Task[] = orderedTasks
    .map((item, index) => {
      const chosenDuration = input.plannedTasks?.find((task) => task.title.trim().toLocaleLowerCase() === item.title.trim().toLocaleLowerCase())?.durationMinutes;
      const requestedDuration = chosenDuration ?? (item.durationMinutes || timeToMinutes(item.endTime) - timeToMinutes(item.startTime));
      const duration = Math.max(5, Math.min(480, requestedDuration));
      let startMinute = Math.max(0, timeToMinutes(item.startTime));
      if (startMinute < occupiedUntil + 10) startMinute = occupiedUntil + 10;
      const endMinute = startMinute + duration;
      if (endMinute >= 1440) throw new Error('The AI returned a schedule that runs past the end of the day.');
      occupiedUntil = endMinute;
      const appearance = suggestTaskAppearance(item.title, item.category);
      return {
        id: `task-ai-${now}-${index}`,
        title: item.title,
        note: item.note || undefined,
        startTime: minutesToTime(startMinute),
        endTime: minutesToTime(endMinute),
        durationMinutes: duration,
        section: (startMinute < 720 ? 'morning' : startMinute < 1020 ? 'day' : startMinute < 1320 ? 'evening' : 'night') as DaySection,
        category: item.category as TaskCategory,
        color: item.color ?? appearance.color,
        icon: item.icon ?? appearance.icon,
        status: 'pending' as const,
        priority: item.priority as 1 | 2 | 3,
        mustWin: index === mustWinIndex,
        planDate: dateKey(),
        source,
      };
    });

  return {
    id: `${rescued ? 'rescue' : 'plan'}-ai-${now}`,
    date: dateKey(),
    title: payload.title,
    style: rescued ? 'minimum' : input.style,
    mode: input.plannerMode ?? 'ai-plan',
    energy: input.energy,
    intention: payload.intention,
    tasks,
    createdAt: new Date(now).toISOString(),
    rescuedAt: rescued ? new Date(now).toISOString() : undefined,
    planScore: payload.planScore,
  };
}

function normalizedTitle(value: string) {
  return value.trim().toLocaleLowerCase().replace(/\s+/g, ' ');
}

/** Completed work is immutable history: replanning may move unfinished work,
 * but it must never erase a completion or turn it back into a pending task. */
export function preserveCompletedTasks(currentPlan: DayPlan, replanned: DayPlan): DayPlan {
  const protectedTasks = currentPlan.tasks.filter((task) => task.status === 'completed' || task.externalImportance === 'important' || task.externalSource === 'calendar');
  const protectedTitles = new Set(protectedTasks.map((task) => normalizedTitle(task.title)));
  const unfinished = replanned.tasks.filter((task) => !protectedTitles.has(normalizedTitle(task.title)));
  return {
    ...replanned,
    mode: currentPlan.mode,
    tasks: [...protectedTasks, ...unfinished].sort((a, b) => {
      const aTime = a.startTime ? timeToMinutes(a.startTime) : 1440;
      const bTime = b.startTime ? timeToMinutes(b.startTime) : 1440;
      return aTime - bTime;
    }),
  };
}

export async function generateDayPlanWithAI(
  input: PlanBuildInput,
  context: CoachContext,
): Promise<AIResult<DayPlan>> {
  const prompt = `${compactContext(context)}\n\nBUILD INPUT: ${JSON.stringify(input)}\nCurrent ISO time: ${new Date().toISOString()}`;
  try {
    const raw = await requestAI('plan', prompt, { operation: 'build', language: context.settings.language });
    return { value: toDayPlan(planSchema.parse(JSON.parse(raw)), input, 'ai'), fallback: false };
  } catch (error) {
    return {
      value: buildDayPlan(input, context.profile),
      fallback: true,
      warning: error instanceof Error ? error.message : 'Built-in AI is temporarily unavailable.',
    };
  }
}

export async function replanDayWithAI(
  currentPlan: DayPlan,
  input: RescueInput,
  context: CoachContext,
): Promise<AIResult<DayPlan>> {
  const completed = currentPlan.tasks.filter((task) => task.status === 'completed').map((task) => task.title);
  const unfinished = currentPlan.tasks.filter((task) => task.status !== 'completed').map((task) => task.title);
  const prompt = `${compactContext(context)}\n\nREALITY SIGNAL: ${JSON.stringify(input)}\nCOMPLETED TASKS (do not return these): ${JSON.stringify(completed)}\nUNFINISHED TASKS TO REPAIR: ${JSON.stringify(unfinished)}\nCurrent ISO time: ${new Date().toISOString()}`;
  try {
    const raw = await requestAI('plan', prompt, { operation: 'replan', language: context.settings.language });
    const planInput: PlanBuildInput = {
      brainDump: currentPlan.tasks.map((task) => task.title).join('\n'),
      mustWin: currentPlan.intention,
      fixedCommitments: context.profile.fixedCommitments,
      energy: input.energy,
      style: 'minimum',
      availableMinutes: input.availableMinutes,
    };
    const replanned = toDayPlan(planSchema.parse(JSON.parse(raw)), planInput, 'rescue', true);
    return { value: preserveCompletedTasks(currentPlan, replanned), fallback: false };
  } catch (error) {
    return {
      value: rescueDayPlan(currentPlan, input),
      fallback: true,
      warning: error instanceof Error ? error.message : 'Built-in AI is temporarily unavailable.',
    };
  }
}

export async function generateCoachReplyWithAI(message: string, context: CoachContext): Promise<AIResult<CoachPayload>> {
  const safetyCheck = generateMockCoachReply(message, context);
  if (safetyCheck.safetyOverride) {
    return { value: { reply: safetyCheck.text, memories: [], actions: [] }, fallback: true };
  }

  const prompt = `${compactContext(context)}\n\nUSER MESSAGE: ${message}`;
  try {
    const raw = await requestAI('coach', prompt, {
      mode: context.settings.coachMode,
      language: context.settings.language,
    });
    return { value: coachSchema.parse(JSON.parse(raw)), fallback: false };
  } catch (error) {
    return {
      value: { reply: safetyCheck.text, memories: [], actions: [] },
      fallback: true,
      warning: error instanceof Error ? error.message : 'Built-in AI is temporarily unavailable.',
    };
  }
}

export async function analyzeProfileWithAI(
  profile: UserProfile,
  language: CoachContext['settings']['language'] = 'en',
): Promise<AIResult<ProfileAnalysis>> {
  try {
    const raw = await requestAI('profile', JSON.stringify(profile), { language });
    return { value: profileAnalysisSchema.parse(JSON.parse(raw)), fallback: false };
  } catch (error) {
    return {
      value: {
        summary: `Plans should protect “${profile.primaryGoal || 'the main goal'}”, respect ${profile.wakeTime}–${profile.sleepTime}, and begin with a small visible action.`,
        planningRules: ['Protect one must-win result per day.', 'Add transition buffers and shorten blocks when energy drops.'],
        risks: [profile.struggle || 'Unclear first steps can create avoidable friction.'],
        suggestedHabits: [],
      },
      fallback: true,
      warning: error instanceof Error ? error.message : 'Built-in AI is temporarily unavailable.',
    };
  }
}

export async function generateHorizonPlanWithAI(
  horizon: PlanningHorizon,
  objective: string,
  context: CoachContext,
): Promise<AIResult<HorizonPlan>> {
  try {
    const raw = await requestAI('horizon', `${compactContext(context)}\n\nOBJECTIVE: ${objective}`, {
      horizon,
      language: context.settings.language,
    });
    const parsed = horizonSchema.parse(JSON.parse(raw));
    const now = Date.now();
    return {
      value: {
        id: `horizon-${horizon}-${now}`,
        horizon,
        objective,
        title: parsed.title,
        summary: parsed.summary,
        checkpoints: parsed.checkpoints.map((checkpoint, index) => ({ ...checkpoint, id: `checkpoint-${now}-${index}` })),
        createdAt: new Date(now).toISOString(),
      },
      fallback: false,
    };
  } catch (error) {
    const labels: Record<PlanningHorizon, string[]> = {
      day: ['First focus block', 'Midday check', 'Day close'],
      week: ['Days 1–2', 'Days 3–5', 'Weekly review'],
      month: ['Week 1', 'Weeks 2–3', 'Week 4'],
      year: ['Quarter 1', 'Quarter 2', 'Quarter 3', 'Quarter 4'],
    };
    const now = Date.now();
    return {
      value: {
        id: `horizon-local-${now}`,
        horizon,
        objective,
        title: `${horizon[0].toUpperCase()}${horizon.slice(1)} roadmap`,
        summary: `A conservative local roadmap for ${objective}. Rebuild it when the AI connection is available for deeper personalization.`,
        checkpoints: labels[horizon].map((label, index) => ({
          id: `checkpoint-local-${now}-${index}`,
          label,
          outcome: index === labels[horizon].length - 1 ? `Review measurable progress toward ${objective}` : `Move ${objective} one visible step forward`,
          actions: ['Choose one measurable result', 'Schedule the next concrete action'],
        })),
        createdAt: new Date(now).toISOString(),
      },
      fallback: true,
      warning: error instanceof Error ? error.message : 'Built-in AI is temporarily unavailable.',
    };
  }
}

export function toMemoryFacts(items: CoachPayload['memories']): MemoryFact[] {
  const now = new Date().toISOString();
  return items.map((item, index) => ({
    id: `memory-ai-${Date.now()}-${index}`,
    category: item.category,
    fact: item.fact,
    source: 'coach',
    confidence: item.confidence,
    enabled: true,
    createdAt: now,
    updatedAt: now,
  }));
}
