import { timeToMinutes } from '@/lib/date';
import type { DayPlan, RescueInput } from '@/types/app';

export type RealityState = 'empty' | 'on-track' | 'drifting' | 'overloaded' | 'recovered' | 'complete';

export interface RealitySignal {
  state: RealityState;
  score: number;
  title: string;
  message: string;
  overdueMinutes: number;
  skippedCount: number;
  recovery?: RescueInput;
}

const copy: Record<Exclude<RealityState, 'empty'>, { title: string; message: string }> = {
  'on-track': {
    title: 'You are on track',
    message: 'The plan still matches reality. Protect the next block and keep the day simple.',
  },
  drifting: {
    title: 'Drift detected',
    message: 'The schedule is slipping. A ten-minute launch is enough to regain momentum.',
  },
  overloaded: {
    title: 'The plan is now too heavy',
    message: 'Reality changed. Compress the day before unfinished work becomes guilt.',
  },
  recovered: {
    title: 'Recovery plan active',
    message: 'The day has already been repaired. Finish the protected action before adding anything.',
  },
  complete: {
    title: 'Day complete',
    message: 'Real work is finished. Capture one lesson so tomorrow starts smarter.',
  },
};

function clamp(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, value));
}

export function analyzeReality(plan: DayPlan | undefined, now = new Date()): RealitySignal {
  if (!plan?.tasks.length) {
    return {
      state: 'empty',
      score: 0,
      title: 'No reality signal yet',
      message: 'Build a day and Drift Guard will compare the schedule with what actually happens.',
      overdueMinutes: 0,
      skippedCount: 0,
    };
  }

  const currentMinute = now.getHours() * 60 + now.getMinutes();
  const completed = plan.tasks.filter((task) => task.status === 'completed').length;
  const skippedCount = plan.tasks.filter((task) => task.status === 'skipped').length;
  const unfinished = plan.tasks.filter((task) => task.status === 'pending' || task.status === 'active');
  const overdueMinutes = unfinished.reduce((largest, task) => {
    if (!task.startTime) return largest;
    return Math.max(largest, currentMinute - timeToMinutes(task.startTime));
  }, 0);

  let state: RealityState;
  let recovery: RescueInput | undefined;
  if (!unfinished.length && completed > 0) {
    state = 'complete';
  } else if (plan.rescuedAt) {
    state = 'recovered';
  } else if (skippedCount >= 2 || overdueMinutes >= 75) {
    state = 'overloaded';
    recovery = { reason: 'unexpected', energy: plan.energy <= 2 ? plan.energy : 3, availableMinutes: 60 };
  } else if (skippedCount > 0 || overdueMinutes >= 25) {
    state = 'drifting';
    recovery = { reason: 'task-too-big', energy: plan.energy, availableMinutes: 10 };
  } else {
    state = 'on-track';
  }

  const completionBoost = Math.round((completed / plan.tasks.length) * 18);
  const score = state === 'complete'
    ? 100
    : clamp(Math.round(plan.planScore + completionBoost - skippedCount * 12 - Math.max(0, overdueMinutes) / 4), 5, 99);
  const words = copy[state];
  return { state, score, ...words, overdueMinutes: Math.max(0, overdueMinutes), skippedCount, recovery };
}
