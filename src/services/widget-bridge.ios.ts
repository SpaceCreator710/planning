import type { DayPlan } from '@/types/app';
import NextActionWidget from '@/widgets/next-action-widget';

export function updateNextActionWidget(plan: DayPlan | undefined, accent: string) {
  const tasks = plan?.tasks ?? [];
  const next = tasks.find((task) => task.status === 'active') ?? tasks.find((task) => task.status === 'pending');
  const completed = tasks.filter((task) => task.status === 'completed').length;
  const progress = tasks.length ? Math.round((completed / tasks.length) * 100) : 0;
  NextActionWidget.updateSnapshot({
    title: next?.title ?? 'No next action',
    time: next?.startTime ?? 'Anytime',
    minutes: next?.durationMinutes ?? 0,
    progress,
    accent,
    complete: Boolean(plan && !next),
  });
}
