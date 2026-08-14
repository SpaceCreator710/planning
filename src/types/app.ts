export type CoachMode = 'soft' | 'strict' | 'aggressive';
export type AccountabilityLevel = 'light' | 'balanced' | 'high';
export type SubscriptionTier = 'free' | 'plus' | 'pro' | 'max';
export type ThemeMode = 'light' | 'dark' | 'system';
export type AccentTheme = 'crimson' | 'ocean' | 'violet' | 'forest' | 'sunset' | 'blossom' | 'sky' | 'lavender' | 'mint' | 'amber';
export type CanvasTheme = 'paper' | 'blush' | 'mist' | 'sage' | 'lavender' | 'midnight';
export type VisualEnergy = 'calm' | 'balanced' | 'vivid';
export type FontScaleMode = 'compact' | 'standard' | 'large';
export type AppLanguage = 'en' | 'ru';
export type EnergyLevel = 1 | 2 | 3 | 4 | 5;
export type PlanStyle = 'full' | 'realistic' | 'minimum';
export type PlannerMode = 'ai-plan' | 'day-chain';
export type TaskStatus = 'pending' | 'active' | 'completed' | 'skipped';
export type TaskRecurrence = 'none' | 'daily' | 'weekdays' | 'weekly' | 'biweekly' | 'monthly' | 'yearly';
export type DaySection = 'morning' | 'day' | 'evening' | 'night';
export type TaskCategory = 'focus' | 'work' | 'study' | 'fitness' | 'life' | 'rest';
export type TaskColor = 'red' | 'coral' | 'orange' | 'gold' | 'yellow' | 'lime' | 'green' | 'mint' | 'teal' | 'cyan' | 'blue' | 'navy' | 'indigo' | 'violet' | 'purple' | 'pink' | 'magenta' | 'brown' | 'gray';

export interface TaskSubtask {
  id: string;
  title: string;
  completed: boolean;
}

export interface UserProfile {
  name: string;
  email?: string;
  category: 'money' | 'fitness' | 'study' | 'career' | 'custom';
  primaryGoal: string;
  goalWhy: string;
  struggle: string;
  wakeTime: string;
  sleepTime: string;
  chronotype: 'early-bird' | 'balanced' | 'night-owl';
  discipline: 1 | 2 | 3 | 4 | 5;
  excuses: string[];
  fixedCommitments: string;
  currentHabits: string;
  productiveHours: string;
  planningPreferences: string;
  selfDescription: string;
  bodyRhythmEnabled: boolean;
  cycleStartDate: string;
  cycleLengthDays: number;
  cyclePeriodDays: number;
  aiSummary?: string;
  onboardingCompleted: boolean;
  createdAt: string;
}

export interface AppSettings {
  coachMode: CoachMode;
  accountability: AccountabilityLevel;
  language: AppLanguage;
  theme: ThemeMode;
  accentTheme: AccentTheme;
  canvasTheme: CanvasTheme;
  visualEnergy: VisualEnergy;
  fontScale: FontScaleMode;
  notificationsEnabled: boolean;
  taskReminders: boolean;
  eveningReview: boolean;
  quietHoursStart: string;
  quietHoursEnd: string;
  autoLearn: boolean;
  safeMode: boolean;
  calendarSyncEnabled: boolean;
  calendarWriteBackEnabled: boolean;
  remindersSyncEnabled: boolean;
  autoCalendarReplan: boolean;
  healthSyncEnabled: boolean;
  healthPlanningEnabled: boolean;
}

export interface Task {
  id: string;
  title: string;
  note?: string;
  startTime?: string;
  endTime?: string;
  durationMinutes: number;
  section: DaySection;
  category: TaskCategory;
  status: TaskStatus;
  priority: 1 | 2 | 3;
  mustWin?: boolean;
  planDate: string;
  source: 'ai' | 'manual' | 'habit' | 'rescue' | 'calendar' | 'reminder' | 'notes' | 'workout';
  recurrence?: TaskRecurrence;
  recurrenceDays?: number[];
  color?: TaskColor;
  icon?: string;
  allDay?: boolean;
  externalSource?: 'calendar' | 'reminder';
  externalId?: string;
  externalCalendarName?: string;
  externalImportance?: 'standard' | 'important';
  externalLastModified?: string;
  reminderMinutesBefore?: number;
  subtasks?: TaskSubtask[];
  completedAt?: string;
  skippedReason?: string;
}

export interface DayPlan {
  id: string;
  date: string;
  title: string;
  style: PlanStyle;
  mode: PlannerMode;
  energy: EnergyLevel;
  intention: string;
  tasks: Task[];
  createdAt: string;
  rescuedAt?: string;
  planScore: number;
}

export interface GoalMilestone {
  id: string;
  title: string;
  completed: boolean;
}

export interface Goal {
  id: string;
  title: string;
  why: string;
  category: TaskCategory;
  progress: number;
  targetDate?: string;
  milestones: GoalMilestone[];
  archived: boolean;
}

export interface Habit {
  id: string;
  title: string;
  icon: string;
  targetDays: number[];
  completedDates: string[];
  currentStreak: number;
  bestStreak: number;
  reminderTime?: string;
}

export interface MemoryFact {
  id: string;
  category: 'goal' | 'routine' | 'blocker' | 'preference' | 'pattern';
  fact: string;
  source: 'user' | 'behavior' | 'coach';
  confidence: number;
  enabled: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface CoachMessage {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  createdAt: string;
  mode?: CoachMode;
  safetyOverride?: boolean;
}

export interface InboxTask {
  id: string;
  title: string;
  note?: string;
  createdAt: string;
}

export interface AppNote {
  id: string;
  title: string;
  body: string;
  createdAt: string;
  updatedAt: string;
  source: 'manual' | 'apple-share' | 'import';
}

export type WorkoutKind = 'walk' | 'run' | 'cycling' | 'strength' | 'mobility' | 'sport';

export interface WorkoutSession {
  id: string;
  kind: WorkoutKind;
  title: string;
  durationMinutes: number;
  startedAt: string;
  completedAt: string;
  note?: string;
}

export interface HealthSnapshot {
  source?: 'apple-health' | 'manual';
  available: boolean;
  startDate: string;
  endDate: string;
  sleepHours: number;
  steps: number;
  exerciseMinutes: number;
  standMinutes: number;
  distanceKilometers: number;
  restingHeartRate?: number;
  workoutCount: number;
  workoutMinutes: number;
  lastUpdated: string;
}

export interface CapacitySignal {
  score: number;
  level: 'recover' | 'steady' | 'strong';
  summary: string;
  suggestedFocusMinutes: number;
  sourceDate: string;
}

export type BehaviorEventType =
  | 'plan-built'
  | 'plan-replanned'
  | 'task-added'
  | 'task-started'
  | 'task-completed'
  | 'task-reopened'
  | 'task-skipped'
  | 'task-edited'
  | 'task-deleted'
  | 'task-duplicated'
  | 'plan-duplicated'
  | 'calendar-imported'
  | 'calendar-synced'
  | 'health-connected'
  | 'capacity-applied'
  | 'note-added'
  | 'note-planned'
  | 'workout-completed'
  | 'reality-action'
  | 'habit-completed'
  | 'habit-reopened'
  | 'goal-created'
  | 'goal-progress'
  | 'review-saved'
  | 'coach-used'
  | 'inbox-added'
  | 'inbox-planned'
  | 'profile-analyzed'
  | 'roadmap-built'
  | 'habit-created'
  | 'milestone-updated'
  | 'memory-updated'
  | 'subscription-changed';

export interface BehaviorEvent {
  id: string;
  type: BehaviorEventType;
  detail: string;
  createdAt: string;
}

export type PlanningHorizon = 'day' | 'week' | 'month' | 'year';

export interface HorizonCheckpoint {
  id: string;
  label: string;
  outcome: string;
  actions: string[];
}

export interface HorizonPlan {
  id: string;
  horizon: PlanningHorizon;
  objective: string;
  title: string;
  summary: string;
  checkpoints: HorizonCheckpoint[];
  createdAt: string;
}

export interface DailyReview {
  id: string;
  date: string;
  score: number;
  wins: string[];
  blocker?: string;
  lesson?: string;
  mood: EnergyLevel;
}

export interface Achievement {
  id: string;
  title: string;
  description: string;
  icon: string;
  unlockedAt?: string;
  progress: number;
  target: number;
}

export interface UsageLedger {
  date: string;
  coachMessages: number;
  plansBuilt: number;
  rescues: number;
}

export interface AppData {
  schemaVersion: number;
  profile: UserProfile;
  settings: AppSettings;
  subscription: SubscriptionTier;
  plans: DayPlan[];
  goals: Goal[];
  habits: Habit[];
  memories: MemoryFact[];
  messages: CoachMessage[];
  reviews: DailyReview[];
  achievements: Achievement[];
  events: BehaviorEvent[];
  horizonPlans: HorizonPlan[];
  inbox: InboxTask[];
  notes: AppNote[];
  workouts: WorkoutSession[];
  healthSnapshots: HealthSnapshot[];
  usage: UsageLedger;
  activePlanId?: string;
}

export interface PlanBuildInput {
  brainDump: string;
  plannedTasks?: { title: string; durationMinutes: number }[];
  mustWin: string;
  fixedCommitments: string;
  energy: EnergyLevel;
  style: PlanStyle;
  availableMinutes?: number;
  plannerMode?: PlannerMode;
}

export type RescueReason =
  | 'overslept'
  | 'distracted'
  | 'low-energy'
  | 'task-too-big'
  | 'unexpected'
  | 'anxious';

export interface RescueInput {
  reason: RescueReason;
  energy: EnergyLevel;
  availableMinutes: 10 | 30 | 60 | 120;
}

export interface CoachContext {
  profile: UserProfile;
  settings: AppSettings;
  activePlan?: DayPlan;
  memories: MemoryFact[];
  messages: CoachMessage[];
  goals: Goal[];
  habits: Habit[];
  reviews: DailyReview[];
  events: BehaviorEvent[];
  inbox: InboxTask[];
  capacitySignal?: CapacitySignal;
}
