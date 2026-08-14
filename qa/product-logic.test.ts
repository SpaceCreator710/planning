/// <reference types="node" />

import assert from 'node:assert/strict';

import { createInitialData } from '@/constants/seed-data';
import { subscriptionPlans } from '@/constants/subscriptions';
import { preserveCompletedTasks } from '@/services/ai-client';
import { bodyRhythmForProfile } from '@/services/body-rhythm';
import { mergePersistedData } from '@/services/data-migration';
import { generateMockCoachReply } from '@/services/mock-coach';
import { learnPlanDNA } from '@/services/plan-dna';
import { recurringTasksForDate, rescueDayPlan } from '@/services/plan-engine';
import { analyzeReality } from '@/services/reality-engine';
import type { AppData, CoachContext, DayPlan, Task } from '@/types/app';

const initial = createInitialData();
assert.equal(initial.settings.theme, 'light');
assert.deepEqual(initial.plans, []);
assert.deepEqual(initial.goals, []);
assert.deepEqual(initial.habits, []);
assert.equal(initial.achievements.every((achievement) => achievement.progress === 0 && !achievement.unlockedAt), true);

const legacy = mergePersistedData({
  schemaVersion: 2,
  profile: {
    name: 'Alex',
    primaryGoal: 'Finish the project',
    onboardingCompleted: true,
    deepProfile: {
      fixedSchedule: 'School 09:00–15:00',
      currentRoutines: 'Homework after school',
      peakFocusWindow: '16:00–18:00',
      planningPreferences: 'Short focused blocks',
      lifeDump: 'I postpone large tasks when the first step is vague.',
    },
  },
  settings: {
    theme: 'system',
    coachMode: 'no-excuses',
    voiceReplies: true,
    aiProvider: 'groq',
    aiModel: 'openai/gpt-oss-120b',
  },
  plans: [{ id: 'plan-today' }],
  achievements: [{ id: 'achievement-streak', progress: 5, target: 7, unlockedAt: new Date().toISOString() }],
} as unknown as Partial<AppData>);

assert.equal(legacy.profile.fixedCommitments, 'School 09:00–15:00');
assert.equal(legacy.profile.currentHabits, 'Homework after school');
assert.equal(legacy.profile.productiveHours, '16:00–18:00');
assert.match(legacy.profile.selfDescription, /postpone large tasks/);
assert.equal(legacy.settings.theme, 'light');
assert.equal(legacy.settings.coachMode, 'aggressive');
assert.equal('voiceReplies' in legacy.settings, false);
assert.equal('aiProvider' in legacy.settings, false);
assert.equal(legacy.plans.length, 0);
assert.equal(legacy.achievements.find((achievement) => achievement.id === 'achievement-streak')?.progress, 0);

const completedTask: Task = {
  id: 'completed',
  title: 'Already finished',
  startTime: '09:00',
  endTime: '09:30',
  durationMinutes: 30,
  section: 'morning',
  category: 'study',
  status: 'completed',
  priority: 1,
  mustWin: true,
  planDate: '2026-08-11',
  source: 'manual',
  completedAt: '2026-08-11T09:30:00.000Z',
};
const pendingTask: Task = {
  ...completedTask,
  id: 'pending',
  title: 'Still pending',
  startTime: '10:00',
  endTime: '11:00',
  durationMinutes: 60,
  status: 'pending',
  mustWin: false,
  completedAt: undefined,
};
const currentPlan: DayPlan = {
  id: 'current',
  date: '2026-08-11',
  title: 'Current day',
  style: 'realistic',
  mode: 'day-chain',
  energy: 3,
  intention: 'Finish the project',
  tasks: [completedTask, pendingTask],
  createdAt: '2026-08-11T08:00:00.000Z',
  planScore: 80,
};

const localRepair = rescueDayPlan(currentPlan, { reason: 'unexpected', energy: 2, availableMinutes: 30 });
assert.equal(localRepair.tasks.find((task) => task.id === completedTask.id)?.status, 'completed');
assert.equal(localRepair.tasks.filter((task) => task.status === 'completed').length, 1);

const aiRepair: DayPlan = {
  ...currentPlan,
  id: 'ai-repair',
  mode: 'ai-plan',
  tasks: [
    { ...pendingTask, id: 'duplicate-completed', title: 'Already finished', status: 'pending' },
    { ...pendingTask, id: 'new-pending', title: 'Smaller next step', status: 'pending' },
  ],
};
const mergedRepair = preserveCompletedTasks(currentPlan, aiRepair);
assert.equal(mergedRepair.mode, 'day-chain');
assert.equal(mergedRepair.tasks.some((task) => task.id === completedTask.id && task.status === 'completed'), true);
assert.equal(mergedRepair.tasks.some((task) => task.id === 'duplicate-completed'), false);
assert.equal(mergedRepair.tasks.some((task) => task.id === 'new-pending'), true);

const recurring = recurringTasksForDate([
  {
    ...currentPlan,
    tasks: [{ ...completedTask, recurrence: 'daily', subtasks: [{ id: 'sub-1', title: 'Prepare', completed: true }] }],
  },
], '2026-08-12');
assert.equal(recurring.length, 1);
assert.equal(recurring[0].status, 'pending');
assert.equal(recurring[0].mustWin, false);
assert.equal(recurring[0].subtasks?.[0].completed, false);
assert.equal(recurringTasksForDate([currentPlan], '2026-08-10').length, 0);
assert.equal(recurringTasksForDate([{ ...currentPlan, tasks: [{ ...completedTask, recurrence: 'biweekly', planDate: '2026-07-28' }] }], '2026-08-11').length, 1);
assert.equal(recurringTasksForDate([{ ...currentPlan, tasks: [{ ...completedTask, recurrence: 'monthly', planDate: '2026-07-11' }] }], '2026-08-11').length, 1);

assert.equal(Math.max(...Object.values(subscriptionPlans).map((plan) => plan.limits.coachMessagesPerDay)), 100);
assert.equal(subscriptionPlans.free.capabilities.some((capability) => /Recurring/i.test(capability)), false);
assert.equal(subscriptionPlans.plus.capabilities.some((capability) => /Recurring/i.test(capability)), true);

const drift = analyzeReality({ ...currentPlan, tasks: [{ ...pendingTask, startTime: '08:00', status: 'pending' }] }, new Date('2026-08-11T10:00:00'));
assert.equal(drift.state, 'overloaded');
assert.equal(drift.recovery?.availableMinutes, 60);
const planDNA = learnPlanDNA([{ ...currentPlan, tasks: [completedTask, { ...pendingTask, status: 'skipped', skippedReason: 'No time' }] }]);
assert.equal(planDNA.sampleSize, 2);
assert.equal(planDNA.idealBlockMinutes, 30);
assert.equal(bodyRhythmForProfile({ ...initial.profile, bodyRhythmEnabled: true, cycleStartDate: '2026-08-10' }, new Date('2026-08-11T12:00:00'))?.phase, 'reset');

const coachContext: CoachContext = {
  profile: { ...initial.profile, primaryGoal: 'Finish the project' },
  settings: initial.settings,
  memories: [],
  messages: [],
  goals: [],
  habits: [],
  reviews: [],
  events: [],
  inbox: [],
};
const softReply = generateMockCoachReply('I feel stuck and cannot get started', coachContext).text;
const strictReply = generateMockCoachReply('I feel stuck and cannot get started', {
  ...coachContext,
  settings: { ...coachContext.settings, coachMode: 'strict' },
}).text;
const aggressiveReply = generateMockCoachReply('I feel stuck and cannot get started', {
  ...coachContext,
  settings: { ...coachContext.settings, coachMode: 'aggressive' },
}).text;
assert.match(softReply, /does not make you weak|lower the pressure/i);
assert.match(strictReply, /Action is|set ten minutes/i);
assert.match(aggressiveReply, /two choices|zero day|Decide\. Now/i);
assert.notEqual(softReply, strictReply);
assert.notEqual(strictReply, aggressiveReply);
assert.equal(generateMockCoachReply('I want to kill myself', {
  ...coachContext,
  settings: { ...coachContext.settings, coachMode: 'aggressive' },
}).safetyOverride, true);

console.log('Product logic tests passed.');
