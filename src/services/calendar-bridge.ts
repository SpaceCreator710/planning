import { Platform, Share } from 'react-native';

import { dateKey, minutesToTime, timeToMinutes } from '@/lib/date';
import type { DayPlan, DaySection, Task } from '@/types/app';

function unfoldIcs(value: string) {
  return value.replace(/\r?\n[ \t]/g, '').replace(/\r/g, '');
}

function unescapeIcs(value: string) {
  return value.replace(/\\n/gi, '\n').replace(/\\,/g, ',').replace(/\\;/g, ';').replace(/\\\\/g, '\\').trim();
}

function escapeIcs(value: string) {
  return value.replace(/\\/g, '\\\\').replace(/\n/g, '\\n').replace(/,/g, '\\,').replace(/;/g, '\\;');
}

function valueFor(block: string, key: string) {
  const match = block.match(new RegExp(`^${key}(?:;[^:]*)?:(.*)$`, 'mi'));
  return match ? unescapeIcs(match[1]) : '';
}

function parseIcsDate(value: string) {
  const utc = value.endsWith('Z');
  const clean = value.replace(/Z$/, '');
  const match = clean.match(/^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?)?/);
  if (!match) return undefined;
  const [, year, month, day, hour = '00', minute = '00', second = '00'] = match;
  const date = utc
    ? new Date(Date.UTC(Number(year), Number(month) - 1, Number(day), Number(hour), Number(minute), Number(second)))
    : new Date(Number(year), Number(month) - 1, Number(day), Number(hour), Number(minute), Number(second));
  return Number.isNaN(date.getTime()) ? undefined : date;
}

function sectionFor(minutes: number): DaySection {
  if (minutes < 720) return 'morning';
  if (minutes < 1020) return 'day';
  if (minutes < 1320) return 'evening';
  return 'night';
}

export function parseIcsTasks(content: string): Task[] {
  const blocks = unfoldIcs(content).match(/BEGIN:(?:VEVENT|VTODO)[\s\S]*?END:(?:VEVENT|VTODO)/gim) ?? [];
  const now = Date.now();
  return blocks.flatMap((block, index) => {
    const title = valueFor(block, 'SUMMARY');
    const isReminder = /^BEGIN:VTODO/im.test(block);
    const startRaw = valueFor(block, 'DTSTART') || valueFor(block, 'DUE');
    const endRaw = valueFor(block, 'DTEND');
    const start = parseIcsDate(startRaw);
    const end = parseIcsDate(endRaw);
    if (!title || !start) return [];
    const allDay = !startRaw.includes('T');
    const startMinutes = start.getHours() * 60 + start.getMinutes();
    const duration = allDay ? 30 : Math.max(5, Math.min(720, Math.round(((end?.getTime() ?? start.getTime() + 30 * 60_000) - start.getTime()) / 60_000)));
    const uid = valueFor(block, 'UID') || `${title}-${start.toISOString()}`;
    const recurrenceRule = valueFor(block, 'RRULE').toUpperCase();
    const recurrence = recurrenceRule.includes('FREQ=DAILY')
      ? ('daily' as const)
      : recurrenceRule.includes('FREQ=YEARLY')
        ? ('yearly' as const)
        : recurrenceRule.includes('FREQ=MONTHLY')
          ? ('monthly' as const)
          : recurrenceRule.includes('FREQ=WEEKLY')
            ? (recurrenceRule.includes('INTERVAL=2') ? ('biweekly' as const) : ('weekly' as const))
            : ('none' as const);
    return [{
      id: `task-calendar-${now}-${index}`,
      title,
      note: valueFor(block, 'DESCRIPTION') || undefined,
      startTime: allDay ? undefined : minutesToTime(startMinutes),
      endTime: allDay ? undefined : minutesToTime(startMinutes + duration),
      durationMinutes: duration,
      section: sectionFor(startMinutes),
      category: 'life' as const,
      status: 'pending' as const,
      priority: 2 as const,
      mustWin: false,
      planDate: dateKey(start),
      source: 'manual' as const,
      allDay,
      externalSource: isReminder ? ('reminder' as const) : ('calendar' as const),
      externalId: uid,
      recurrence,
      color: 'teal' as const,
      icon: isReminder ? 'checklist' : 'calendar',
    }];
  });
}

function icsDate(day: string, time?: string) {
  const compactDay = day.replace(/-/g, '');
  return time ? `${compactDay}T${time.replace(':', '')}00` : compactDay;
}

function followingDate(day: string) {
  const date = new Date(`${day}T12:00:00`);
  date.setDate(date.getDate() + 1);
  return dateKey(date);
}

export function buildPlanIcs(plan: DayPlan) {
  const events = plan.tasks.map((task) => {
    const start = icsDate(plan.date, task.startTime);
    const endMinutes = task.endTime
      ? timeToMinutes(task.endTime)
      : task.startTime
        ? timeToMinutes(task.startTime) + task.durationMinutes
        : undefined;
    const end = task.allDay || !task.startTime
      ? icsDate(followingDate(plan.date))
      : icsDate(plan.date, minutesToTime(endMinutes ?? timeToMinutes(task.startTime) + task.durationMinutes));
    const dateType = task.allDay || !task.startTime ? ';VALUE=DATE' : '';
    return [
      'BEGIN:VEVENT',
      `UID:${task.id}@aiplanyourday`,
      `DTSTAMP:${new Date().toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '')}`,
      `DTSTART${dateType}:${start}`,
      `DTEND${dateType}:${end}`,
      `SUMMARY:${escapeIcs(task.title)}`,
      task.note ? `DESCRIPTION:${escapeIcs(task.note)}` : '',
      'END:VEVENT',
    ].filter(Boolean).join('\r\n');
  }).join('\r\n');
  return ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//Plan Your Day//Flow Calendar//EN', 'CALSCALE:GREGORIAN', events, 'END:VCALENDAR'].join('\r\n');
}

export async function exportPlanToCalendar(plan: DayPlan) {
  const content = buildPlanIcs(plan);
  if (Platform.OS === 'web' && typeof document !== 'undefined') {
    const blob = new Blob([content], { type: 'text/calendar;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `plan-${plan.date}.ics`;
    link.click();
    setTimeout(() => URL.revokeObjectURL(url), 1_000);
    return true;
  }
  await Share.share({ title: plan.title, message: content });
  return true;
}

export function pickIcsTasksOnWeb(): Promise<Task[]> {
  if (Platform.OS !== 'web' || typeof document === 'undefined') return Promise.resolve([]);
  return new Promise((resolve, reject) => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = '.ics,text/calendar';
    input.onchange = () => {
      const file = input.files?.[0];
      if (!file) {
        resolve([]);
        return;
      }
      const reader = new FileReader();
      reader.onload = () => resolve(parseIcsTasks(String(reader.result ?? '')));
      reader.onerror = () => reject(new Error('Could not read this calendar file.'));
      reader.readAsText(file);
    };
    input.click();
  });
}
