import { router } from 'expo-router';
import React, { useMemo } from 'react';
import { ScrollView, View } from 'react-native';

import { AppButton } from '@/components/app/app-button';
import { AppText } from '@/components/app/app-text';
import { Card } from '@/components/app/card';
import { ProgressRing } from '@/components/app/progress-ring';
import { SectionHeader } from '@/components/app/section-header';
import { spacing } from '@/constants/tokens';
import { useApp } from '@/context/app-context';
import { useAppTheme } from '@/context/theme-context';
import { dateKey } from '@/lib/date';
import { learnPlanDNA } from '@/services/plan-dna';

function recentDateKeys() {
  return Array.from({ length: 7 }, (_, index) => {
    const date = new Date();
    date.setDate(date.getDate() - (6 - index));
    return dateKey(date);
  });
}

export default function ProgressScreen() {
  const { colors } = useAppTheme();
  const { data, sendCoachMessage } = useApp();
  const locale = data.settings.language === 'ru' ? 'ru-RU' : 'en-US';
  const tasks = data.plans.flatMap((plan) => plan.tasks);
  const completed = tasks.filter((task) => task.status === 'completed').length;
  const completionRate = tasks.length ? Math.round((completed / tasks.length) * 100) : 0;
  const bestStreak = Math.max(0, ...data.habits.map((habit) => habit.bestStreak));
  const rescueCount = data.events.filter((event) => event.type === 'plan-replanned').length;
  const scoredPlans = data.plans.filter((plan) => plan.planScore > 0);
  const realityScore = scoredPlans.length
    ? Math.round(scoredPlans.reduce((sum, plan) => sum + plan.planScore, 0) / scoredPlans.length)
    : 0;
  const planDNA = useMemo(() => learnPlanDNA(data.plans), [data.plans]);

  const weekly = useMemo(() => {
    const keys = recentDateKeys();
    return keys.map((key) => {
      const review = data.reviews.find((item) => item.date === key);
      const dayPlans = data.plans.filter((plan) => plan.date === key);
      const dayTasks = dayPlans.flatMap((plan) => plan.tasks);
      const taskScore = dayTasks.length
        ? Math.round((dayTasks.filter((task) => task.status === 'completed').length / dayTasks.length) * 100)
        : 0;
      return {
        key,
        label: new Intl.DateTimeFormat(locale, { weekday: 'narrow' }).format(new Date(`${key}T12:00:00`)),
        value: review?.score ?? taskScore,
      };
    });
  }, [data.plans, data.reviews, locale]);

  const blockers = useMemo(() => {
    const counts = new Map<string, number>();
    tasks.forEach((task) => {
      if (task.skippedReason) counts.set(task.skippedReason, (counts.get(task.skippedReason) ?? 0) + 1);
    });
    return [...counts.entries()].sort((a, b) => b[1] - a[1]).slice(0, 3);
  }, [tasks]);

  return (
    <ScrollView contentInsetAdjustmentBehavior="automatic" contentContainerStyle={{ padding: spacing.md, paddingBottom: 120, gap: spacing.xl }}>
      <Card style={{ padding: spacing.lg, flexDirection: 'row', alignItems: 'center', gap: spacing.lg }}>
        <ProgressRing value={completionRate} size={108} stroke={10} />
        <View style={{ flex: 1, gap: spacing.xs }}>
          <AppText variant="caption" tone="accent">
            FOLLOW-THROUGH
          </AppText>
          <AppText variant="title">{completionRate >= 70 ? 'Strong momentum' : completionRate >= 35 ? 'Momentum is building' : 'Start with one win'}</AppText>
          <AppText variant="small" tone="secondary">
            {completed} completed actions across {data.plans.length} plans.
          </AppText>
        </View>
      </Card>

      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm }}>
        <MetricCard label="Best streak" value={`${bestStreak}d`} detail="habit consistency" />
        <MetricCard label="Reality score" value={`${realityScore}%`} detail="plan feasibility" />
        <MetricCard label="Comebacks" value={String(rescueCount)} detail="rescued days" />
        <MetricCard label="Coach uses" value={String(data.usage.coachMessages)} detail="today" />
      </View>

      <Card style={{ backgroundColor: colors.infoSoft, borderColor: colors.info, gap: spacing.md }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.md }}>
          <View style={{ width: 58, height: 58, borderRadius: 20, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.surface }}>
            <AppText variant="heading" style={{ color: colors.info }}>{planDNA.confidence}%</AppText>
          </View>
          <View style={{ flex: 1 }}>
            <AppText variant="caption" style={{ color: colors.info }}>PLAN DNA · LOCAL LEARNING</AppText>
            <AppText variant="heading">Your personal execution pattern</AppText>
            <AppText variant="small" tone="secondary">Built from real starts, completions and skips—not a personality label.</AppText>
          </View>
        </View>
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm }}>
          <MetricCard label="Best window" value={planDNA.strongestWindow ?? 'Learning'} detail={`${planDNA.sampleSize} signals`} />
          <MetricCard label="Best block" value={`${planDNA.idealBlockMinutes}m`} detail={planDNA.strongestCategory ?? 'all categories'} />
        </View>
        <AppText variant="small">{planDNA.experiment}</AppText>
      </Card>

      <View style={{ gap: spacing.md }}>
        <SectionHeader title="Last seven days" detail="Completion / review score" />
        <Card style={{ height: 220, paddingTop: spacing.xl }}>
          <View style={{ flex: 1, flexDirection: 'row', alignItems: 'flex-end', gap: spacing.sm }}>
            {weekly.map((day) => (
              <View key={day.key} style={{ flex: 1, height: '100%', alignItems: 'center', justifyContent: 'flex-end', gap: spacing.xs }}>
                <AppText variant="caption" tone="secondary" style={{ fontVariant: ['tabular-nums'] }}>
                  {day.value || '—'}
                </AppText>
                <View style={{ width: '100%', flex: 1, justifyContent: 'flex-end' }}>
                  <View
                    style={{
                      width: '100%',
                      height: `${Math.max(5, day.value)}%`,
                      minHeight: 5,
                      borderRadius: 8,
                      borderCurve: 'continuous',
                      backgroundColor: day.value >= 70 ? colors.success : day.value >= 40 ? colors.accent : colors.surfaceMuted,
                    }}
                  />
                </View>
                <AppText variant="caption" tone="tertiary">
                  {day.label}
                </AppText>
              </View>
            ))}
          </View>
        </Card>
      </View>

      <View style={{ gap: spacing.md }}>
        <SectionHeader title="Coach insight" />
        <Card style={{ backgroundColor: colors.infoSoft, borderColor: colors.info }}>
          <AppText variant="caption" style={{ color: colors.info }}>
            PATTERN DETECTED
          </AppText>
          <AppText variant="heading">
            {data.memories.find((memory) => memory.category === 'pattern' && memory.enabled)?.fact ??
              'Complete a few days to reveal your strongest work pattern.'}
          </AppText>
          <AppText variant="small" tone="secondary">
            The app learns from starts, completions, skips, energy and rescue outcomes — not only from chat.
          </AppText>
          <AppButton
            title="Ask AI for my next experiment"
            variant="secondary"
            onPress={() => {
              void sendCoachMessage('Analyze my completion, skip, energy, replan and review behavior. Identify the strongest supported pattern and propose one seven-day experiment with a measurable success rule.');
              router.push('/(tabs)/coach');
            }}
          />
        </Card>
      </View>

      <View style={{ gap: spacing.md }}>
        <SectionHeader title="Friction map" detail="Why tasks get skipped" />
        <Card>
          {blockers.length ? (
            blockers.map(([reason, count], index) => (
              <View key={reason} style={{ gap: spacing.xs }}>
                <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
                  <AppText variant="small">{reason}</AppText>
                  <AppText variant="caption" tone="secondary">
                    {count}×
                  </AppText>
                </View>
                <View style={{ height: 7, borderRadius: 99, backgroundColor: colors.surfaceMuted, overflow: 'hidden' }}>
                  <View style={{ height: '100%', width: `${Math.max(22, 100 - index * 25)}%`, backgroundColor: colors.warning, borderRadius: 99 }} />
                </View>
              </View>
            ))
          ) : (
            <AppText variant="small" tone="secondary">
              Skip a task with a reason and the coach will start mapping recurring friction.
            </AppText>
          )}
        </Card>
      </View>

      <View style={{ gap: spacing.md }}>
        <SectionHeader title="Achievements" />
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: spacing.sm }}>
          {data.achievements.map((achievement) => {
            const unlocked = Boolean(achievement.unlockedAt) || achievement.progress >= achievement.target;
            return (
              <Card key={achievement.id} style={{ width: 190, opacity: unlocked ? 1 : 0.62 }}>
                <AppText style={{ fontSize: 28, color: unlocked ? colors.accent : colors.textTertiary }}>{achievement.icon}</AppText>
                <AppText variant="label">{achievement.title}</AppText>
                <AppText variant="caption" tone="secondary">
                  {achievement.description}
                </AppText>
                <AppText variant="caption" tone={unlocked ? 'success' : 'tertiary'}>
                  {unlocked ? 'UNLOCKED' : `${achievement.progress}/${achievement.target}`}
                </AppText>
              </Card>
            );
          })}
        </ScrollView>
      </View>

      {data.subscription === 'free' || data.subscription === 'plus' ? (
        <Card style={{ backgroundColor: colors.accentSoft, borderColor: colors.accent }}>
          <AppText variant="caption" tone="accent">
            PRO ANALYTICS
          </AppText>
          <AppText variant="heading">See deeper friction and recovery patterns</AppText>
          <AppText variant="small" tone="secondary">
            Pro unlocks longer behavior context, month planning, Friction Radar experiments and more adaptive coaching.
          </AppText>
          <AppButton title="See Pro features" onPress={() => router.push('/paywall')} />
        </Card>
      ) : null}
    </ScrollView>
  );
}

function MetricCard({ label, value, detail }: { label: string; value: string; detail: string }) {
  return (
    <Card style={{ flexGrow: 1, flexBasis: '46%', boxShadow: 'none' }}>
      <AppText variant="caption" tone="secondary">
        {label.toUpperCase()}
      </AppText>
      <AppText variant="title" style={{ fontVariant: ['tabular-nums'] }}>
        {value}
      </AppText>
      <AppText variant="caption" tone="tertiary">
        {detail}
      </AppText>
    </Card>
  );
}
