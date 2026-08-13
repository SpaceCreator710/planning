import * as Notifications from 'expo-notifications';

import type { DayPlan } from '@/types/app';

Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldPlaySound: true,
    shouldSetBadge: false,
    shouldShowBanner: true,
    shouldShowList: true,
  }),
});

export async function requestNotificationPermission() {
  const current = await Notifications.getPermissionsAsync();
  if (current.granted) return true;
  const requested = await Notifications.requestPermissionsAsync();
  return requested.granted;
}

export async function schedulePlanReminders(plan: DayPlan) {
  const allowed = await requestNotificationPermission();
  if (!allowed) return false;

  await Notifications.cancelAllScheduledNotificationsAsync();
  const now = new Date();
  for (const task of plan.tasks.slice(0, 8)) {
    if (!task.startTime) continue;
    const [hours, minutes] = task.startTime.split(':').map(Number);
    const trigger = new Date();
    trigger.setHours(hours, minutes, 0, 0);
    trigger.setMinutes(trigger.getMinutes() - (task.reminderMinutesBefore ?? 0));
    if (trigger <= now) continue;
    await Notifications.scheduleNotificationAsync({
      content: {
        title: task.mustWin ? 'Your must-win is coming up' : 'Next action',
        body: task.title,
        data: { taskId: task.id, planId: plan.id },
      },
      trigger: { type: Notifications.SchedulableTriggerInputTypes.DATE, date: trigger },
    });
  }
  return true;
}
