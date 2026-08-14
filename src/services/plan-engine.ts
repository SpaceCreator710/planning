import { dateKey, minutesToTime, timeToMinutes } from '@/lib/date';
import { suggestTaskAppearance } from '@/services/task-appearance';
import type {
  DayPlan,
  DaySection,
  PlanBuildInput,
  RescueInput,
  Task,
  TaskCategory,
  TaskRecurrence,
  UserProfile,
} from '@/types/app';

const FOCUS_WORDS = /deep|focus|project|code|write|exam|study|уч|проект|код|экзамен|работ/i;
const FITNESS_WORDS = /gym|run|walk|workout|train|спорт|зал|бег|трен|прогул/i;
const REST_WORDS = /rest|break|relax|nap|отдых|перерыв|сон/i;
const LIFE_WORDS = /shop|clean|call|email|home|buy|убор|магаз|позвон|купить|почт/i;

function id(prefix: string) {
  return `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

function sectionForMinute(minute: number): DaySection {
  if (minute < 720) return 'morning';
  if (minute < 1020) return 'day';
  if (minute < 1320) return 'evening';
  return 'night';
}

function categoryForTitle(title: string): TaskCategory {
  if (FITNESS_WORDS.test(title)) return 'fitness';
  if (REST_WORDS.test(title)) return 'rest';
  if (LIFE_WORDS.test(title)) return 'life';
  if (FOCUS_WORDS.test(title)) return /study|exam|уч|экзамен/i.test(title) ? 'study' : 'focus';
  return 'work';
}

function durationForTitle(title: string, energy: number) {
  if (REST_WORDS.test(title)) return 20;
  if (FITNESS_WORDS.test(title)) return 45;
  if (LIFE_WORDS.test(title)) return 25;
  if (FOCUS_WORDS.test(title)) return energy <= 2 ? 30 : 60;
  return energy <= 2 ? 25 : 40;
}

function parseBrainDump(value: string) {
  return value
    .split(/\n|;|,(?=\s*[A-Za-zА-Яа-я])/)
    .map((item) => item.replace(/^[-•\d.)\s]+/, '').trim())
    .filter((item) => item.length > 1)
    .slice(0, 14);
}

function makeTask(
  title: string,
  startMinute: number,
  duration: number,
  index: number,
  mustWin: boolean,
  source: Task['source'] = 'ai',
): Task {
  const appearance = suggestTaskAppearance(title, categoryForTitle(title));
  return {
    id: id('task'),
    title,
    startTime: minutesToTime(startMinute),
    endTime: minutesToTime(startMinute + duration),
    durationMinutes: duration,
    section: sectionForMinute(startMinute),
    category: appearance.category,
    color: appearance.color,
    icon: appearance.icon,
    status: 'pending',
    priority: mustWin ? 1 : index < 3 ? 2 : 3,
    mustWin,
    planDate: dateKey(),
    source,
  };
}

export function buildDayPlan(input: PlanBuildInput, profile: UserProfile): DayPlan {
  const requestedDurations = new Map((input.plannedTasks ?? []).map((task) => [task.title.trim().toLocaleLowerCase(), Math.max(5, Math.min(480, task.durationMinutes))]));
  const rawTasks = input.plannedTasks?.length ? input.plannedTasks.map((task) => task.title.trim()).filter(Boolean) : parseBrainDump(input.brainDump);
  const mustWin = input.mustWin.trim() || rawTasks[0] || profile.primaryGoal || 'Move the main goal forward';
  const tasks = [mustWin, ...rawTasks.filter((task) => task.toLowerCase() !== mustWin.toLowerCase())];

  const styleLimit = input.style === 'minimum' ? 3 : input.style === 'realistic' ? 7 : 11;
  const selected = tasks.slice(0, styleLimit);
  const now = new Date();
  const wakeMinute = timeToMinutes(profile.wakeTime || '08:00');
  const roundedNow = Math.ceil((now.getHours() * 60 + now.getMinutes()) / 15) * 15;
  let cursor = Math.max(wakeMinute + 30, roundedNow);

  const builtTasks: Task[] = [];
  selected.forEach((title, index) => {
    let duration = requestedDurations.get(title.toLocaleLowerCase()) ?? durationForTitle(title, input.energy);
    if (!requestedDurations.has(title.toLocaleLowerCase()) && input.style === 'minimum') duration = Math.min(duration, index === 0 ? 30 : 20);
    if (!requestedDurations.has(title.toLocaleLowerCase()) && input.style === 'realistic') duration = Math.min(duration, 50);
    builtTasks.push(makeTask(title, cursor, duration, index, index === 0));
    const buffer = input.style === 'full' ? 10 : 15;
    cursor += duration + buffer;
    if (cursor >= 720 && cursor - duration < 720) cursor += 35;
    if (cursor >= 1080 && cursor - duration < 1080) cursor += 30;
  });

  const loadMinutes = builtTasks.reduce((sum, task) => sum + task.durationMinutes, 0);
  const available = input.availableMinutes ?? Math.max(180, timeToMinutes(profile.sleepTime || '23:00') - roundedNow - 60);
  const planScore = Math.max(42, Math.min(98, Math.round(100 - Math.max(0, loadMinutes - available) / 8)));

  return {
    id: id('plan'),
    date: dateKey(),
    title: input.style === 'minimum' ? 'Minimum viable day' : input.style === 'full' ? 'Full power day' : 'Realistic day',
    style: input.style,
    mode: input.plannerMode ?? 'ai-plan',
    energy: input.energy,
    intention: mustWin,
    tasks: builtTasks,
    createdAt: new Date().toISOString(),
    planScore,
  };
}

export function rescueDayPlan(plan: DayPlan, input: RescueInput): DayPlan {
  const now = new Date();
  let cursor = Math.ceil((now.getHours() * 60 + now.getMinutes()) / 5) * 5;
  const pending = plan.tasks.filter((task) => task.status !== 'completed');
  const main = pending.find((task) => task.mustWin) ?? pending.sort((a, b) => a.priority - b.priority)[0];
  const available = input.availableMinutes;
  const completed = plan.tasks.filter((task) => task.status === 'completed');
  const rescued: Task[] = [];

  if (main) {
    const launchDuration = available === 10 ? 10 : Math.min(30, main.durationMinutes);
    rescued.push(
      makeTask(
        available === 10 ? `10-minute launch: ${main.title}` : main.title,
        cursor,
        launchDuration,
        0,
        true,
        'rescue',
      ),
    );
    cursor += launchDuration + 5;
  }

  let remaining = available - rescued.reduce((sum, task) => sum + task.durationMinutes, 0);
  pending
    .filter((task) => task.id !== main?.id && task.category !== 'rest')
    .slice(0, input.energy <= 2 ? 1 : 3)
    .forEach((task, index) => {
      if (remaining < 15) return;
      const duration = Math.min(task.durationMinutes, remaining, input.energy <= 2 ? 20 : 35);
      rescued.push(makeTask(task.title, cursor, duration, index + 1, false, 'rescue'));
      cursor += duration + 5;
      remaining -= duration + 5;
    });

  return {
    ...plan,
    id: id('rescue'),
    title: 'Rescued day',
    style: 'minimum',
    energy: input.energy,
    tasks: [...completed, ...rescued],
    createdAt: new Date().toISOString(),
    rescuedAt: new Date().toISOString(),
    planScore: 94,
  };
}

export function createManualTask(title: string, planDate = dateKey(), durationMinutes = 25): Task {
  const now = new Date();
  const startMinute = Math.ceil((now.getHours() * 60 + now.getMinutes()) / 5) * 5;
  return {
    ...makeTask(title.trim(), startMinute, Math.max(5, Math.min(480, durationMinutes)), 8, false, 'manual'),
    startTime: undefined,
    endTime: undefined,
    section: sectionForMinute(startMinute),
    planDate,
  };
}

function recurrenceMatches(recurrence: TaskRecurrence, sourceDate: string, targetDate: string, recurrenceDays?: number[]) {
  // Recurrence only moves forward. A future-dated template must never create
  // a phantom occurrence in an earlier day.
  if (sourceDate >= targetDate) return false;
  if (recurrence === 'daily') return true;
  const target = new Date(`${targetDate}T12:00:00`);
  if (recurrence === 'weekdays') return target.getDay() >= 1 && target.getDay() <= 5;
  const source = new Date(`${sourceDate}T12:00:00`);
  if (recurrence === 'weekly') return recurrenceDays?.length ? recurrenceDays.includes(target.getDay()) : source.getDay() === target.getDay();
  const daysSinceSource = Math.round((target.getTime() - source.getTime()) / 86_400_000);
  if (recurrence === 'biweekly') return daysSinceSource > 0 && daysSinceSource % 14 === 0;
  if (recurrence === 'monthly') return source.getDate() === target.getDate();
  if (recurrence === 'yearly') return source.getMonth() === target.getMonth() && source.getDate() === target.getDate();
  return false;
}

export function recurringTasksForDate(plans: DayPlan[], targetDate = dateKey()) {
  const sources = [...plans]
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
    .flatMap((plan) => plan.tasks.map((task) => ({ plan, task })));
  const seen = new Set<string>();
  const now = Date.now();
  return sources.flatMap(({ task }, index) => {
    const recurrence = task.recurrence ?? 'none';
    const key = `${task.title.trim().toLocaleLowerCase()}|${recurrence}`;
    if (seen.has(key) || task.planDate === targetDate || !recurrenceMatches(recurrence, task.planDate, targetDate, task.recurrenceDays)) return [];
    seen.add(key);
    return [{
      ...task,
      id: `task-recurring-${now}-${index}`,
      planDate: targetDate,
      status: 'pending' as const,
      completedAt: undefined,
      skippedReason: undefined,
      source: 'habit' as const,
      mustWin: false,
      subtasks: task.subtasks?.map((subtask, subtaskIndex) => ({
        ...subtask,
        id: `subtask-recurring-${now}-${index}-${subtaskIndex}`,
        completed: false,
      })),
    }];
  });
}
