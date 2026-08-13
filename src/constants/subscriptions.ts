import type { CoachMode, SubscriptionTier } from '@/types/app';

export interface SubscriptionPlan {
  id: SubscriptionTier;
  name: string;
  monthlyPrice: number;
  annualPrice: number;
  accent: string;
  tagline: string;
  headlineFeatures: string[];
  coachModes: CoachMode[];
  limits: {
    coachMessagesPerDay: number;
    plansPerDay: number;
    rescuesPerDay: number;
    memoryDays: number;
  };
  capabilities: string[];
}

export const subscriptionPlans: Record<SubscriptionTier, SubscriptionPlan> = {
  free: {
    id: 'free',
    name: 'Free',
    monthlyPrice: 0,
    annualPrice: 0,
    accent: '#8A8A92',
    tagline: 'A complete daily planner, not a demo',
    headlineFeatures: ['Visual day chain', 'Calendar + notes', 'Core health timer'],
    coachModes: ['soft'],
    limits: { coachMessagesPerDay: 4, plansPerDay: 2, rescuesPerDay: 2, memoryDays: 14 },
    capabilities: [
      'AI Day Plan, Day Chain and two Reality Replans',
      'Built-in day, week, month and year calendar',
      'ICS import and day export',
      'Built-in Notes, subtasks and all-day tasks',
      'All task colors, icons, notes and subtasks',
      'Workout timer, goals, habits, inbox and focus mode',
      'Drift Guard and 14-day learning',
    ],
  },
  plus: {
    id: 'plus',
    name: 'Plus',
    monthlyPrice: 2.99,
    annualPrice: 17.99,
    accent: '#367BF5',
    tagline: 'More AI capacity, weekly strategy and real accountability',
    headlineFeatures: ['Apple device sync', 'Widgets + repeats', 'Soft + Strict'],
    coachModes: ['soft', 'strict'],
    limits: { coachMessagesPerDay: 10, plansPerDay: 6, rescuesPerDay: 6, memoryDays: 180 },
    capabilities: [
      'Everything in Free',
      'Automatic Apple Calendar + Reminders sync',
      'Apple Health read-only connection and Capacity Twin',
      'Recurring routines, richer notifications and widgets',
      'Higher AI limits and cross-device cloud history',
      'Unlimited goals and habits',
      'AI week strategy and weekly pattern insights',
      'Strict accountability mode',
      'Ten focused coach turns and six replans per day',
    ],
  },
  pro: {
    id: 'pro',
    name: 'Pro',
    monthlyPrice: 5.99,
    annualPrice: 26.99,
    accent: '#E3342F',
    tagline: 'Adaptive planning that undercuts a $30 annual rival',
    headlineFeatures: ['30 focused AI turns', 'Aggressive mode', 'Behavioral memory'],
    coachModes: ['soft', 'strict', 'aggressive'],
    limits: { coachMessagesPerDay: 30, plansPerDay: 15, rescuesPerDay: 15, memoryDays: 730 },
    capabilities: [
      'Everything in Plus',
      'Controlled Aggressive coach mode',
      'AI month strategy and adaptive behavioral memory',
      'Collision Radar, schedule analytics and two-year context',
      'Automatic plan repair from two-tap reality signals',
      'Thirty focused coach turns per day',
      'Fifteen reality replans per day',
      'AI-assisted focus and personal experiments',
    ],
  },
  max: {
    id: 'max',
    name: 'Lifetime',
    monthlyPrice: 129.99,
    annualPrice: 129.99,
    accent: '#7C3AED',
    tagline: 'One payment. The complete action system for life.',
    headlineFeatures: ['One-time purchase', 'Every Pro feature', 'Future core upgrades'],
    coachModes: ['soft', 'strict', 'aggressive'],
    limits: { coachMessagesPerDay: 100, plansPerDay: 40, rescuesPerDay: 40, memoryDays: 3650 },
    capabilities: [
      'Everything in Pro, permanently',
      'AI year roadmap with monthly checkpoints',
      'Long-term personal operating model',
      'Ten-year behavior context',
      'One hundred focused coach turns per day',
      'Forty reality replans per day',
      'Highest planning and history limits',
      'Early access to new core features',
    ],
  },
};

export function canUseCoachMode(tier: SubscriptionTier, mode: CoachMode) {
  return subscriptionPlans[tier].coachModes.includes(mode);
}

export function canUseDeviceIntegration(tier: SubscriptionTier) {
  return tier !== 'free';
}
