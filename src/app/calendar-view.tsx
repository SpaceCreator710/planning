import { useLocalSearchParams } from 'expo-router';
import React, { useMemo, useState } from 'react';
import { Pressable, ScrollView, View } from 'react-native';

import { AppText } from '@/components/app/app-text';
import { Card } from '@/components/app/card';
import { Chip } from '@/components/app/chip';
import { categoryTaskColor, radii, spacing, taskPalettes } from '@/constants/tokens';
import { useApp } from '@/context/app-context';
import { useAppTheme } from '@/context/theme-context';
import { dateKey, formatFriendlyDate } from '@/lib/date';
import type { DayPlan, Task } from '@/types/app';

type CalendarMode = 'day' | 'week' | 'month';

function fromKey(value: string) {
  const parsed = new Date(`${value}T12:00:00`);
  return Number.isNaN(parsed.getTime()) ? new Date() : parsed;
}

function taskTone(task: Task, isDark: boolean) {
  const tone = taskPalettes[task.color ?? categoryTaskColor[task.category]];
  return { solid: tone.solid, soft: isDark ? tone.darkSoft : tone.soft };
}

function progressFor(plan?: DayPlan) {
  if (!plan?.tasks.length) return 0;
  return plan.tasks.filter((task) => task.status === 'completed').length / plan.tasks.length;
}

export default function CalendarViewScreen() {
  const params = useLocalSearchParams<{ date?: string }>();
  const { data } = useApp();
  const { colors, isDark } = useAppTheme();
  const locale = data.settings.language === 'ru' ? 'ru-RU' : 'en-US';
  const [mode, setMode] = useState<CalendarMode>('week');
  const [selectedDate, setSelectedDate] = useState(params.date || dateKey());
  const selected = fromKey(selectedDate);
  const selectedPlan = data.plans.find((plan) => plan.date === selectedDate);

  const week = useMemo(() => {
    const start = fromKey(selectedDate);
    const offset = (start.getDay() + 6) % 7;
    start.setDate(start.getDate() - offset);
    return Array.from({ length: 7 }, (_, index) => {
      const day = new Date(start);
      day.setDate(start.getDate() + index);
      const key = dateKey(day);
      return { day, key, plan: data.plans.find((plan) => plan.date === key) };
    });
  }, [data.plans, selectedDate]);

  const month = useMemo(() => {
    const first = new Date(selected.getFullYear(), selected.getMonth(), 1, 12);
    const offset = (first.getDay() + 6) % 7;
    first.setDate(first.getDate() - offset);
    return Array.from({ length: 42 }, (_, index) => {
      const day = new Date(first);
      day.setDate(first.getDate() + index);
      const key = dateKey(day);
      return { day, key, plan: data.plans.find((plan) => plan.date === key) };
    });
  }, [data.plans, selected]);

  return (
    <ScrollView contentInsetAdjustmentBehavior="automatic" contentContainerStyle={{ padding: spacing.lg, paddingBottom: 100, gap: spacing.xl }}>
      <View style={{ gap: spacing.xs }}>
        <AppText variant="title">Flow calendar</AppText>
        <AppText tone="secondary">A visual map of time, energy and completion—not a copy of another timeline.</AppText>
      </View>

      <View style={{ flexDirection: 'row', gap: spacing.xs }}>
        {(['day', 'week', 'month'] as const).map((item) => (
          <Chip key={item} label={item[0].toUpperCase() + item.slice(1)} selected={mode === item} onPress={() => setMode(item)} style={{ flex: 1 }} />
        ))}
      </View>

      {mode === 'day' ? (
        <View style={{ gap: spacing.md }}>
          <AppText variant="heading">{formatFriendlyDate(selected, locale)}</AppText>
          {selectedPlan?.tasks.length ? selectedPlan.tasks.map((task) => {
            const tone = taskTone(task, isDark);
            return (
              <Card key={task.id} style={{ flexDirection: 'row', alignItems: 'center', borderColor: `${tone.solid}55`, backgroundColor: tone.soft }}>
                <View style={{ width: 56 }}><AppText variant="caption" tone="secondary">{task.allDay ? 'All day' : task.startTime ?? 'Any'}</AppText></View>
                <View style={{ width: 10, height: 46, borderRadius: 6, backgroundColor: tone.solid }} />
                <View style={{ flex: 1 }}>
                  <AppText variant="label" style={{ textDecorationLine: task.status === 'completed' ? 'line-through' : 'none' }}>{task.title}</AppText>
                  <AppText variant="caption" tone="secondary">{task.durationMinutes} min · {task.category}</AppText>
                </View>
              </Card>
            );
          }) : <EmptyDay />}
        </View>
      ) : null}

      {mode === 'week' ? (
        <View style={{ gap: spacing.sm }}>
          {week.map(({ day, key, plan }) => (
            <Pressable key={key} onPress={() => { setSelectedDate(key); setMode('day'); }}>
              <Card style={{ flexDirection: 'row', alignItems: 'stretch', padding: 0, overflow: 'hidden', borderColor: key === selectedDate ? colors.accent : colors.border }}>
                <View style={{ width: 68, padding: spacing.sm, alignItems: 'center', justifyContent: 'center', backgroundColor: key === dateKey() ? colors.accentSoft : colors.surfaceMuted }}>
                  <AppText variant="caption" tone={key === dateKey() ? 'accent' : 'secondary'}>{new Intl.DateTimeFormat(locale, { weekday: 'short' }).format(day)}</AppText>
                  <AppText variant="heading">{day.getDate()}</AppText>
                </View>
                <View style={{ flex: 1, padding: spacing.sm, gap: 6 }}>
                  {plan?.tasks.length ? plan.tasks.slice(0, 5).map((task) => {
                    const tone = taskTone(task, isDark);
                    return (
                      <View key={task.id} style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.xs }}>
                        <View style={{ width: 8, height: 8, borderRadius: 4, backgroundColor: tone.solid }} />
                        <AppText variant="caption" numberOfLines={1} style={{ flex: 1, textDecorationLine: task.status === 'completed' ? 'line-through' : 'none' }}>{task.title}</AppText>
                        <AppText variant="caption" tone="tertiary">{task.startTime ?? 'Any'}</AppText>
                      </View>
                    );
                  }) : <AppText variant="caption" tone="tertiary">Open day</AppText>}
                </View>
                <View style={{ width: 5, backgroundColor: colors.surfaceMuted, justifyContent: 'flex-end' }}>
                  <View style={{ height: `${Math.round(progressFor(plan) * 100)}%`, backgroundColor: colors.success }} />
                </View>
              </Card>
            </Pressable>
          ))}
        </View>
      ) : null}

      {mode === 'month' ? (
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', borderTopWidth: 1, borderLeftWidth: 1, borderColor: colors.border }}>
          {month.map(({ day, key, plan }) => {
            const outside = day.getMonth() !== selected.getMonth();
            return (
              <Pressable
                key={key}
                onPress={() => { setSelectedDate(key); setMode('day'); }}
                style={{ width: '14.2857%', minHeight: 82, padding: 5, gap: 4, borderRightWidth: 1, borderBottomWidth: 1, borderColor: colors.border, backgroundColor: key === dateKey() ? colors.accentSoft : colors.surface, opacity: outside ? 0.42 : 1 }}>
                <AppText variant="caption" tone={key === dateKey() ? 'accent' : 'secondary'}>{day.getDate()}</AppText>
                {plan?.tasks.slice(0, 3).map((task) => {
                  const tone = taskTone(task, isDark);
                  return <View key={task.id} style={{ height: 5, borderRadius: radii.pill, backgroundColor: tone.solid, opacity: task.status === 'completed' ? 0.38 : 1 }} />;
                })}
                {plan?.tasks.length ? <AppText variant="caption" tone="tertiary" style={{ fontSize: 9 }}>{Math.round(progressFor(plan) * 100)}%</AppText> : null}
              </Pressable>
            );
          })}
        </View>
      ) : null}
    </ScrollView>
  );
}

function EmptyDay() {
  return (
    <Card muted>
      <AppText variant="label">Nothing scheduled</AppText>
      <AppText variant="small" tone="secondary">This day stays intentionally open until you add or import something.</AppText>
    </Card>
  );
}
