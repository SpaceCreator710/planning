import type { CapacitySignal, DayPlan, HealthSnapshot } from '@/types/app';

export function capacityFromHealth(snapshot: HealthSnapshot): CapacitySignal {
  const sleepScore = snapshot.sleepHours <= 0 ? 58 : Math.max(25, Math.min(100, (snapshot.sleepHours / 8) * 100));
  const movementScore = Math.max(35, Math.min(100, 45 + snapshot.exerciseMinutes * 1.1 + Math.min(20, snapshot.steps / 500)));
  const score = Math.round(sleepScore * 0.72 + movementScore * 0.28);
  const level = score < 58 ? 'recover' : score < 78 ? 'steady' : 'strong';
  return {
    score,
    level,
    summary:
      level === 'recover'
        ? 'Protect essentials, shorten focus blocks, and add recovery margin.'
        : level === 'steady'
          ? 'Use a realistic workload with normal transition buffers.'
          : 'Capacity looks strong; protect one demanding block without filling every free minute.',
    suggestedFocusMinutes: level === 'recover' ? 20 : level === 'steady' ? 40 : 55,
    sourceDate: snapshot.lastUpdated,
  };
}

export interface ScheduleCollision {
  id: string;
  severity: 'medium' | 'high';
  title: string;
  detail: string;
}

export function detectScheduleCollisions(plan: DayPlan | undefined, capacity?: CapacitySignal): ScheduleCollision[] {
  if (!plan) return [];
  const collisions: ScheduleCollision[] = [];
  const demanding = plan.tasks.filter((task) => task.status === 'pending' && ['focus', 'work', 'study'].includes(task.category));
  const importantCalendar = plan.tasks.filter((task) => task.externalImportance === 'important');
  if (capacity?.level === 'recover' && demanding.reduce((sum, task) => sum + task.durationMinutes, 0) > 120) {
    collisions.push({ id: 'capacity-overload', severity: 'high', title: 'Capacity collision', detail: 'Today contains more than two hours of demanding work while recovery capacity is low.' });
  }
  if (importantCalendar.length && plan.tasks.filter((task) => task.status === 'pending').length > 8) {
    collisions.push({ id: 'important-date-load', severity: 'medium', title: 'Important-date overload', detail: 'A significant calendar event shares the day with a crowded task chain.' });
  }
  return collisions;
}
