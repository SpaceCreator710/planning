import * as Calendar from 'expo-calendar';

import { dateKey } from '@/lib/date';
import type { DayPlan, Task, TaskCategory } from '@/types/app';

export interface DeviceCalendarSyncResult {
  supported: boolean;
  calendarPermission: boolean;
  remindersPermission: boolean;
  tasks: Task[];
  calendarCount: number;
  eventCount: number;
  reminderCount: number;
  rangeStart: string;
  rangeEnd: string;
}

export interface DeviceCalendarExportResult {
  created: number;
  updated: number;
  removed: number;
}

const importantPattern = /(birthday|anniversary|holiday|deadline|exam|flight|trip|appointment|concert|graduation|срок|день рождения|годовщин|праздник|экзамен|вылет|поездк|при[её]м|важно)/i;

function time(value: Date) {
  return `${String(value.getHours()).padStart(2, '0')}:${String(value.getMinutes()).padStart(2, '0')}`;
}

function categoryFor(title: string): TaskCategory {
  if (/(work|meeting|client|office|работ|встреч)/i.test(title)) return 'work';
  if (/(school|study|class|exam|lesson|уч[её]б|урок|экзамен)/i.test(title)) return 'study';
  if (/(gym|run|walk|sport|workout|трен|спорт|пробеж)/i.test(title)) return 'fitness';
  if (/(sleep|rest|break|сон|отдых)/i.test(title)) return 'rest';
  return 'life';
}

function durationMinutes(start: Date, end: Date, allDay: boolean) {
  if (allDay) return 30;
  return Math.max(5, Math.min(720, Math.round((end.getTime() - start.getTime()) / 60_000)));
}

function deviceSyncRange() {
  const start = new Date();
  start.setDate(start.getDate() - 30);
  start.setHours(0, 0, 0, 0);
  const end = new Date(start);
  end.setDate(end.getDate() + 430);
  return { start, end, rangeStart: dateKey(start), rangeEnd: dateKey(end) };
}

function eventTask(event: Calendar.ExpoCalendarEvent, calendarName: string, index: number): Task {
  const start = new Date(event.startDate);
  const end = new Date(event.endDate);
  const allDay = Boolean(event.allDay);
  const important = allDay || importantPattern.test(event.title || '');
  return {
    id: `device-event-${event.id || index}`,
    title: event.title || 'Calendar event',
    note: [event.location, event.notes].filter(Boolean).join(' · ') || undefined,
    startTime: allDay ? undefined : time(start),
    endTime: allDay ? undefined : time(end),
    durationMinutes: durationMinutes(start, end, allDay),
    section: allDay || start.getHours() < 12 ? 'morning' : start.getHours() < 17 ? 'day' : start.getHours() < 22 ? 'evening' : 'night',
    category: categoryFor(event.title || ''),
    status: 'pending',
    priority: important ? 1 : 2,
    mustWin: false,
    planDate: dateKey(start),
    source: 'calendar',
    allDay,
    externalSource: 'calendar',
    externalId: event.id,
    externalCalendarName: calendarName,
    externalImportance: important ? 'important' : 'standard',
    externalLastModified: event.lastModifiedDate ? new Date(event.lastModifiedDate).toISOString() : undefined,
    color: important ? 'pink' : 'blue',
    icon: important ? 'calendar.badge.exclamationmark' : 'calendar',
  };
}

function reminderTask(reminder: Calendar.ExpoCalendarReminder, calendarName: string, index: number): Task {
  const due = new Date(reminder.dueDate || reminder.startDate || Date.now());
  const important = importantPattern.test(reminder.title || '');
  return {
    id: `device-reminder-${reminder.id || index}`,
    title: reminder.title || 'Reminder',
    note: reminder.notes || undefined,
    startTime: reminder.allDay ? undefined : time(due),
    endTime: undefined,
    durationMinutes: 20,
    section: due.getHours() < 12 ? 'morning' : due.getHours() < 17 ? 'day' : 'evening',
    category: categoryFor(reminder.title || ''),
    status: reminder.completed ? 'completed' : 'pending',
    priority: important ? 1 : 2,
    mustWin: false,
    planDate: dateKey(due),
    source: 'reminder',
    allDay: Boolean(reminder.allDay),
    externalSource: 'reminder',
    externalId: reminder.id,
    externalCalendarName: calendarName,
    externalImportance: important ? 'important' : 'standard',
    externalLastModified: reminder.lastModifiedDate ? new Date(reminder.lastModifiedDate).toISOString() : undefined,
    color: important ? 'pink' : 'indigo',
    icon: 'checklist',
    completedAt: reminder.completed && reminder.completionDate ? new Date(reminder.completionDate).toISOString() : undefined,
  };
}

export async function syncDeviceCalendar({ includeReminders = true, requestPermissions = true } = {}): Promise<DeviceCalendarSyncResult> {
  const { start, end, rangeStart, rangeEnd } = deviceSyncRange();
  if (process.env.EXPO_OS === 'web') {
    return { supported: false, calendarPermission: false, remindersPermission: false, tasks: [], calendarCount: 0, eventCount: 0, reminderCount: 0, rangeStart, rangeEnd };
  }

  const calendarStatus = requestPermissions ? await Calendar.requestCalendarPermissions(false) : await Calendar.getCalendarPermissions(false);
  let reminderGranted = false;
  if (process.env.EXPO_OS === 'ios' && includeReminders) {
    const status = requestPermissions ? await Calendar.requestRemindersPermissions() : await Calendar.getRemindersPermissions();
    reminderGranted = status.granted;
  }
  if (!calendarStatus.granted) {
    return { supported: true, calendarPermission: false, remindersPermission: reminderGranted, tasks: [], calendarCount: 0, eventCount: 0, reminderCount: 0, rangeStart, rangeEnd };
  }

  const eventCalendars = await Calendar.getCalendars(Calendar.EntityTypes.EVENT);
  const calendarNames = new Map(eventCalendars.map((item) => [item.id, item.title]));
  const events = eventCalendars.length ? await Calendar.listEvents(eventCalendars, start, end) : [];
  const eventTasks = events.map((event, index) => eventTask(event, calendarNames.get(event.calendarId) || 'Apple Calendar', index));

  let reminderTasks: Task[] = [];
  let reminderCount = 0;
  if (process.env.EXPO_OS === 'ios' && reminderGranted) {
    const reminderCalendars = await Calendar.getCalendars(Calendar.EntityTypes.REMINDER);
    const lists = await Promise.all(reminderCalendars.map(async (calendar) => ({ calendar, reminders: await calendar.listReminders(start, end, null) })));
    reminderCount = lists.reduce((sum, item) => sum + item.reminders.length, 0);
    reminderTasks = lists.flatMap(({ calendar, reminders }) => reminders.map((reminder, index) => reminderTask(reminder, calendar.title, index)));
  }

  return {
    supported: true,
    calendarPermission: true,
    remindersPermission: reminderGranted,
    tasks: [...eventTasks, ...reminderTasks],
    calendarCount: eventCalendars.length,
    eventCount: eventTasks.length,
    reminderCount,
    rangeStart,
    rangeEnd,
  };
}

const ownedEventPrefix = 'aiplanyourday://task/';

function ownedTaskId(url?: string) {
  if (!url?.startsWith(ownedEventPrefix)) return undefined;
  try {
    return decodeURIComponent(url.slice(ownedEventPrefix.length));
  } catch {
    return undefined;
  }
}

function calendarDetails(plan: DayPlan, task: Task) {
  const start = task.allDay
    ? new Date(`${plan.date}T00:00:00`)
    : new Date(`${plan.date}T${task.startTime || '09:00'}:00`);
  const end = task.allDay
    ? new Date(start.getTime() + 24 * 60 * 60_000)
    : new Date(start.getTime() + Math.max(5, task.durationMinutes) * 60_000);
  return {
    title: task.title,
    notes: task.note || 'Planned with Plan Your Day',
    startDate: start,
    endDate: end,
    allDay: Boolean(task.allDay),
    url: `${ownedEventPrefix}${encodeURIComponent(task.id)}`,
  };
}

export async function exportPlanToDeviceCalendar(plan: DayPlan): Promise<DeviceCalendarExportResult> {
  if (process.env.EXPO_OS === 'web') throw new Error('Direct device-calendar export requires the installed app.');
  const permission = await Calendar.requestCalendarPermissions(false);
  if (!permission.granted) throw new Error('Calendar permission was not granted.');
  const calendars = await Calendar.getCalendars(Calendar.EntityTypes.EVENT);
  const target = process.env.EXPO_OS === 'ios'
    ? Calendar.getDefaultCalendarSync()
    : calendars.find((calendar) => calendar.allowsModifications);
  if (!target) throw new Error('No writable device calendar is available.');

  const dayStart = new Date(`${plan.date}T00:00:00`);
  const dayEnd = new Date(dayStart.getTime() + 24 * 60 * 60_000);
  const deviceEvents = await target.listEvents(dayStart, dayEnd);
  const ownedEvents = deviceEvents.filter((event) => ownedTaskId(event.url));
  const existingByTask = new Map<string, Calendar.ExpoCalendarEvent>();
  ownedEvents.forEach((event) => {
    const taskId = ownedTaskId(event.url);
    if (taskId && !existingByTask.has(taskId)) existingByTask.set(taskId, event);
  });

  let created = 0;
  let updated = 0;
  const keptEventIds = new Set<string>();
  for (const task of plan.tasks.filter((item) => !item.externalSource)) {
    const existing = existingByTask.get(task.id);
    if (existing) {
      await existing.update(calendarDetails(plan, task));
      keptEventIds.add(existing.id);
      updated += 1;
    } else {
      const event = await target.createEvent(calendarDetails(plan, task));
      keptEventIds.add(event.id);
      created += 1;
    }
  }

  let removed = 0;
  for (const event of ownedEvents) {
    if (keptEventIds.has(event.id)) continue;
    await event.delete();
    removed += 1;
  }
  return { created, updated, removed };
}
