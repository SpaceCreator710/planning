import type { DayPlan, DaySection, TaskCategory } from '@/types/app';

export interface PlanDNA {
  confidence: number;
  sampleSize: number;
  strongestWindow?: DaySection;
  strongestCategory?: TaskCategory;
  idealBlockMinutes: number;
  completionRate: number;
  experiment: string;
}

function bestRate<K extends string>(items: { key: K; completed: boolean }[]) {
  const groups = new Map<K, { total: number; completed: number }>();
  items.forEach((item) => {
    const current = groups.get(item.key) ?? { total: 0, completed: 0 };
    current.total += 1;
    if (item.completed) current.completed += 1;
    groups.set(item.key, current);
  });
  return [...groups.entries()]
    .filter(([, score]) => score.total >= 2)
    .sort((a, b) => b[1].completed / b[1].total - a[1].completed / a[1].total)[0]?.[0];
}

export function learnPlanDNA(plans: DayPlan[]): PlanDNA {
  const tasks = plans.flatMap((plan) => plan.tasks).filter((task) => task.status === 'completed' || task.status === 'skipped');
  const completed = tasks.filter((task) => task.status === 'completed');
  const sortedDurations = completed.map((task) => task.durationMinutes).filter((value) => value >= 5).sort((a, b) => a - b);
  const median = sortedDurations.length ? sortedDurations[Math.floor(sortedDurations.length / 2)] : 25;
  const strongestWindow = bestRate(tasks.map((task) => ({ key: task.section, completed: task.status === 'completed' })));
  const strongestCategory = bestRate(tasks.map((task) => ({ key: task.category, completed: task.status === 'completed' })));
  const idealBlockMinutes = Math.max(10, Math.min(90, Math.round(median / 5) * 5));
  const completionRate = tasks.length ? Math.round((completed.length / tasks.length) * 100) : 0;
  const experiment = strongestWindow && strongestCategory
    ? `For seven days, place one ${idealBlockMinutes}-minute ${strongestCategory} block in the ${strongestWindow} and compare completion.`
    : 'Complete or skip five scheduled actions honestly to reveal your first reliable pattern.';
  return {
    confidence: Math.min(100, Math.round(tasks.length * 6.5)),
    sampleSize: tasks.length,
    strongestWindow,
    strongestCategory,
    idealBlockMinutes,
    completionRate,
    experiment,
  };
}
