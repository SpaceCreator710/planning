import { router } from 'expo-router';
import React, { useMemo, useState } from 'react';
import { Alert, Platform, Pressable, ScrollView, View } from 'react-native';

import { AppButton } from '@/components/app/app-button';
import { AppIcon } from '@/components/app/app-icon';
import { AppText } from '@/components/app/app-text';
import { Card } from '@/components/app/card';
import { SlidingSegmentedControl } from '@/components/app/sliding-segmented-control';
import { canUseDeviceIntegration } from '@/constants/subscriptions';
import { radii, spacing, taskPalettes } from '@/constants/tokens';
import { useApp } from '@/context/app-context';
import { useAppTheme } from '@/context/theme-context';
import { dateKey } from '@/lib/date';
import { syncDeviceCalendar } from '@/services/device-calendar';
import type { Task, TaskColor } from '@/types/app';

type CalendarRange = 'day' | 'week' | 'month' | 'year';

function daysFrom(start: Date, count: number) {
  return Array.from({ length: count }, (_, index) => {
    const day = new Date(start);
    day.setDate(day.getDate() + index);
    return day;
  });
}

export default function CalendarTab() {
  const { colors } = useAppTheme();
  const { data, importCalendarTasks, updateSettings } = useApp();
  const [range, setRange] = useState<CalendarRange>('week');
  const [syncing, setSyncing] = useState(false);
  const locale = data.settings.language === 'ru' ? 'ru-RU' : 'en-US';
  const today = useMemo(() => {
    const day = new Date();
    day.setHours(12, 0, 0, 0);
    return day;
  }, []);
  const weekStart = useMemo(() => {
    const day = new Date(today);
    const weekday = (day.getDay() + 6) % 7;
    day.setDate(day.getDate() - weekday);
    return day;
  }, [today]);
  const weekDays = useMemo(() => daysFrom(weekStart, 7), [weekStart]);
  const monthDays = useMemo(() => {
    const first = new Date(today.getFullYear(), today.getMonth(), 1, 12);
    const offset = (first.getDay() + 6) % 7;
    first.setDate(first.getDate() - offset);
    return daysFrom(first, 42);
  }, [today]);

  async function syncApple() {
    if (!canUseDeviceIntegration(data.subscription)) {
      router.push('/paywall');
      return;
    }
    if (Platform.OS === 'web') {
      router.push('/integrations');
      return;
    }
    setSyncing(true);
    try {
      const result = await syncDeviceCalendar({ includeReminders: data.settings.remindersSyncEnabled });
      if (!result.calendarPermission) {
        Alert.alert('Calendar permission needed', 'Allow Calendar access in Apple Settings, then try again.');
        return;
      }
      const imported = importCalendarTasks(result.tasks, {
        replaceExternalRange: {
          startDate: result.rangeStart,
          endDate: result.rangeEnd,
          sources: result.remindersPermission ? ['calendar', 'reminder'] : ['calendar'],
        },
      });
      updateSettings({ calendarSyncEnabled: true, calendarWriteBackEnabled: true, remindersSyncEnabled: result.remindersPermission || data.settings.remindersSyncEnabled });
      Alert.alert(
        'Apple Calendar connected',
        `${imported} items synchronized from ${result.calendarCount} calendars${result.reminderCount ? ` and ${result.reminderCount} reminders` : ''}. Important dates are protected in their day plans.`,
      );
    } catch (error) {
      Alert.alert('Could not sync', error instanceof Error ? error.message : 'The device calendar could not be read.');
    } finally {
      setSyncing(false);
    }
  }

  return (
    <ScrollView contentInsetAdjustmentBehavior="automatic" contentContainerStyle={{ padding: spacing.md, paddingBottom: 120, gap: spacing.xl }}>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.md }}>
        <View style={{ flex: 1, gap: 3 }}>
          <AppText variant="title">Flow Calendar</AppText>
          <AppText variant="small" tone="secondary">Your plans and important device dates in one connected view.</AppText>
        </View>
        <Pressable
          accessibilityRole="button"
          onPress={() => void syncApple()}
          style={({ pressed }) => ({ width: 48, height: 48, borderRadius: 18, borderCurve: 'continuous', backgroundColor: colors.accentSoft, alignItems: 'center', justifyContent: 'center', opacity: pressed ? 0.7 : 1 })}>
          <AppIcon name="arrow.triangle.2.circlepath" fallback="↻" color={colors.accent} animated={syncing} />
        </Pressable>
      </View>

      <SlidingSegmentedControl
        value={range}
        onChange={setRange}
        options={[
          { value: 'day', label: 'Day' },
          { value: 'week', label: 'Week' },
          { value: 'month', label: 'Month' },
          { value: 'year', label: 'Year' },
        ]}
      />

      {range === 'day' ? <DayView day={today} locale={locale} /> : null}
      {range === 'week' ? <WeekView days={weekDays} locale={locale} /> : null}
      {range === 'month' ? <MonthView days={monthDays} currentMonth={today.getMonth()} locale={locale} /> : null}
      {range === 'year' ? <YearView year={today.getFullYear()} locale={locale} /> : null}

      <Card style={{ gap: spacing.md, borderColor: data.settings.calendarSyncEnabled ? colors.success : colors.border }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.md }}>
          <View style={{ width: 48, height: 48, borderRadius: 18, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.infoSoft }}>
            <AppIcon name="calendar.badge.checkmark" fallback="✓" color={colors.info} />
          </View>
          <View style={{ flex: 1, gap: 2 }}>
            <AppText variant="heading">Apple Calendar + Reminders</AppText>
            <AppText variant="small" tone="secondary">Birthdays, holidays, exams, appointments and marked events are imported with their names and kept fixed while the rest of the day moves around them.</AppText>
          </View>
        </View>
        <AppButton title={data.settings.calendarSyncEnabled ? 'Sync device changes' : canUseDeviceIntegration(data.subscription) ? 'Connect device calendar' : 'Unlock automatic device sync'} loading={syncing} onPress={() => void syncApple()} />
        <AppButton title="Calendar & export settings" variant="secondary" onPress={() => router.push('/integrations')} />
      </Card>
    </ScrollView>
  );
}

function tasksForDay(plans: ReturnType<typeof useApp>['data']['plans'], day: Date) {
  return plans.find((plan) => plan.date === dateKey(day))?.tasks ?? [];
}

function DayView({ day, locale }: { day: Date; locale: string }) {
  const { data } = useApp();
  const tasks = tasksForDay(data.plans, day);
  return (
    <Card style={{ gap: spacing.md }}>
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <View style={{ flex: 1 }}>
          <AppText variant="heading">{new Intl.DateTimeFormat(locale, { weekday: 'long', month: 'long', day: 'numeric' }).format(day)}</AppText>
          <AppText variant="small" tone="secondary">{tasks.length} connected blocks</AppText>
        </View>
        <AppButton compact title="Open" variant="secondary" onPress={() => router.push({ pathname: '/calendar-view', params: { date: dateKey(day) } })} />
      </View>
      {tasks.length ? <CompactChain tasks={tasks} /> : <EmptyDay />}
    </Card>
  );
}

function WeekView({ days, locale }: { days: Date[]; locale: string }) {
  const { data } = useApp();
  const { colors } = useAppTheme();
  return (
    <Card style={{ paddingHorizontal: spacing.sm, gap: spacing.sm }}>
      <View style={{ flexDirection: 'row', gap: 5, minHeight: 300 }}>
        {days.map((day) => {
          const tasks = tasksForDay(data.plans, day);
          const isToday = dateKey(day) === dateKey();
          return (
            <Pressable
              key={dateKey(day)}
              onPress={() => router.push({ pathname: '/calendar-view', params: { date: dateKey(day) } })}
              style={({ pressed }) => ({ flex: 1, alignItems: 'center', gap: 7, opacity: pressed ? 0.72 : 1 })}>
              <AppText variant="caption" tone="tertiary">{new Intl.DateTimeFormat(locale, { weekday: 'narrow' }).format(day)}</AppText>
              <View style={{ width: 34, height: 34, borderRadius: 17, alignItems: 'center', justifyContent: 'center', backgroundColor: isToday ? colors.accent : 'transparent' }}>
                <AppText variant="label" style={{ color: isToday ? '#FFFFFF' : colors.text }}>{day.getDate()}</AppText>
              </View>
              <View style={{ flex: 1, width: '100%', alignItems: 'center' }}>
                {tasks.slice(0, 7).map((task, index) => {
                  const tone = taskPalettes[(task.color ?? 'blue') as TaskColor];
                  return (
                    <View key={task.id} style={{ alignItems: 'center', width: '100%' }}>
                      {index ? <View style={{ width: 2, height: 4, backgroundColor: tone.solid }} /> : null}
                      <View style={{ width: '88%', minHeight: task.allDay ? 28 : Math.max(34, Math.min(70, task.durationMinutes / 2)), borderRadius: 14, borderCurve: 'continuous', backgroundColor: tone.solid, alignItems: 'center', justifyContent: 'center', padding: 3 }}>
                        <AppIcon name={(task.icon || 'circle.fill') as Parameters<typeof AppIcon>[0]['name']} fallback="•" color="#FFFFFF" size={13} />
                      </View>
                    </View>
                  );
                })}
                {!tasks.length ? <View style={{ width: '70%', flex: 1, maxHeight: 210, borderRadius: 18, backgroundColor: colors.surfaceMuted }} /> : null}
              </View>
            </Pressable>
          );
        })}
      </View>
      <AppText variant="caption" tone="tertiary" style={{ textAlign: 'center' }}>Tap any chain to open that day.</AppText>
    </Card>
  );
}

function MonthView({ days, currentMonth, locale }: { days: Date[]; currentMonth: number; locale: string }) {
  const { data } = useApp();
  const { colors } = useAppTheme();
  return (
    <Card style={{ padding: spacing.sm, gap: 5 }}>
      <AppText variant="heading" style={{ padding: spacing.xs }}>{new Intl.DateTimeFormat(locale, { month: 'long', year: 'numeric' }).format(new Date(days[20]))}</AppText>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap' }}>
        {days.map((day) => {
          const tasks = tasksForDay(data.plans, day);
          const muted = day.getMonth() !== currentMonth;
          return (
            <Pressable key={dateKey(day)} onPress={() => router.push({ pathname: '/calendar-view', params: { date: dateKey(day) } })} style={{ width: '14.285%', minHeight: 68, padding: 3, opacity: muted ? 0.35 : 1 }}>
              <AppText variant="caption" style={{ textAlign: 'center' }}>{day.getDate()}</AppText>
              <View style={{ gap: 2, paddingTop: 4 }}>
                {tasks.slice(0, 3).map((task) => <View key={task.id} style={{ height: 7, borderRadius: radii.pill, backgroundColor: taskPalettes[(task.color ?? 'blue') as TaskColor].solid }} />)}
                {tasks.length > 3 ? <AppText style={{ fontSize: 9, color: colors.textTertiary, textAlign: 'center' }}>+{tasks.length - 3}</AppText> : null}
              </View>
            </Pressable>
          );
        })}
      </View>
    </Card>
  );
}

function YearView({ year, locale }: { year: number; locale: string }) {
  const { data } = useApp();
  const { colors } = useAppTheme();
  return (
    <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm }}>
      {Array.from({ length: 12 }, (_, month) => {
        const prefix = `${year}-${String(month + 1).padStart(2, '0')}`;
        const plans = data.plans.filter((plan) => plan.date.startsWith(prefix));
        const tasks = plans.flatMap((plan) => plan.tasks);
        const bars: (Task | undefined)[] = tasks.length ? tasks.slice(0, 8) : Array.from({ length: 4 }, () => undefined);
        return (
          <Card key={month} style={{ width: '47%', minHeight: 126, justifyContent: 'space-between', gap: spacing.sm }}>
            <View>
              <AppText variant="label">{new Intl.DateTimeFormat(locale, { month: 'long' }).format(new Date(year, month, 1))}</AppText>
              <AppText variant="caption" tone="secondary">{tasks.length} blocks · {plans.length} planned days</AppText>
            </View>
            <View style={{ flexDirection: 'row', gap: 3, alignItems: 'flex-end', height: 38 }}>
              {bars.map((task, index) => (
                <View key={task?.id ?? index} style={{ flex: 1, height: task ? Math.max(8, Math.min(38, task.durationMinutes / 3)) : 6, borderRadius: 5, backgroundColor: task ? taskPalettes[(task.color ?? 'blue') as TaskColor].solid : colors.surfaceMuted }} />
              ))}
            </View>
          </Card>
        );
      })}
    </View>
  );
}

function CompactChain({ tasks }: { tasks: Task[] }) {
  return (
    <View style={{ gap: 0 }}>
      {tasks.map((task, index) => {
        const tone = taskPalettes[(task.color ?? 'blue') as TaskColor];
        return (
          <View key={task.id} style={{ flexDirection: 'row', gap: spacing.sm }}>
            <View style={{ width: 28, alignItems: 'center' }}>
              {index ? <View style={{ height: 7, width: 2, backgroundColor: tone.solid }} /> : <View style={{ height: 7 }} />}
              <View style={{ width: 26, height: 26, borderRadius: 13, backgroundColor: tone.solid, alignItems: 'center', justifyContent: 'center' }}>
                <AppIcon name={(task.icon || 'circle.fill') as Parameters<typeof AppIcon>[0]['name']} fallback="•" color="#FFFFFF" size={13} />
              </View>
              {index < tasks.length - 1 ? <View style={{ flex: 1, minHeight: 10, width: 2, backgroundColor: tone.solid }} /> : null}
            </View>
            <View style={{ flex: 1, paddingVertical: 7, paddingHorizontal: spacing.md, marginBottom: 2, borderRadius: radii.md, backgroundColor: `${tone.solid}18`, borderWidth: 1, borderColor: `${tone.solid}55` }}>
              <AppText variant="caption" style={{ color: tone.solid }}>{task.allDay ? 'ALL DAY' : task.startTime || 'ANYTIME'} · {task.durationMinutes} MIN</AppText>
              <AppText variant="label">{task.title}</AppText>
              {task.externalImportance === 'important' ? <AppText variant="caption" tone="accent">Protected device date</AppText> : null}
            </View>
          </View>
        );
      })}
    </View>
  );
}

function EmptyDay() {
  const { colors } = useAppTheme();
  return (
    <View style={{ minHeight: 150, borderRadius: radii.lg, backgroundColor: colors.surfaceMuted, alignItems: 'center', justifyContent: 'center', gap: spacing.xs }}>
      <AppIcon name="calendar.badge.plus" fallback="+" color={colors.textTertiary} size={30} />
      <AppText variant="label" tone="secondary">An open day</AppText>
    </View>
  );
}
