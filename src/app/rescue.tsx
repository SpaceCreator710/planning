import { router } from 'expo-router';
import React, { useState } from 'react';
import { Alert, Pressable, ScrollView, View } from 'react-native';

import { AppButton } from '@/components/app/app-button';
import { AppIcon } from '@/components/app/app-icon';
import { AppText } from '@/components/app/app-text';
import { Card } from '@/components/app/card';
import { Chip } from '@/components/app/chip';
import { spacing } from '@/constants/tokens';
import { useApp } from '@/context/app-context';
import { useAppTheme } from '@/context/theme-context';
import type { DayPlan, RescueInput, RescueReason } from '@/types/app';

const reasons: { id: RescueReason; title: string; detail: string; icon: Parameters<typeof AppIcon>[0]['name'] }[] = [
  { id: 'overslept', title: 'Started late', detail: 'The old schedule no longer fits', icon: 'alarm.waves.left.and.right' },
  { id: 'distracted', title: 'Got distracted', detail: 'I lost the thread of the day', icon: 'arrow.trianglehead.branch' },
  { id: 'low-energy', title: 'Low energy', detail: 'The plan is too demanding now', icon: 'battery.25percent' },
  { id: 'task-too-big', title: 'Task feels too big', detail: 'I keep avoiding the first step', icon: 'square.stack.3d.up.fill' },
  { id: 'unexpected', title: 'Something happened', detail: 'An interruption changed the day', icon: 'bolt.trianglebadge.exclamationmark.fill' },
  { id: 'anxious', title: 'Feeling anxious', detail: 'I need a calmer restart', icon: 'wind' },
];

export default function RescueScreen() {
  const { colors } = useAppTheme();
  const { activePlan, rescuePlan } = useApp();
  const [reason, setReason] = useState<RescueReason>();
  const [availableMinutes, setAvailableMinutes] = useState<RescueInput['availableMinutes']>(60);
  const [result, setResult] = useState<DayPlan>();
  const [working, setWorking] = useState(false);

  async function rescue() {
    if (!reason || !availableMinutes) {
      Alert.alert('Two taps first', 'Choose what changed and how much usable time is left.');
      return;
    }
    const energy = reason === 'low-energy' ? 1 : reason === 'anxious' || reason === 'distracted' ? 2 : activePlan?.energy ?? 3;
    setWorking(true);
    const next = await rescuePlan({ reason, energy, availableMinutes });
    setWorking(false);
    if (!next.ok) {
      if (next.reason === 'missing-plan') Alert.alert('No day to rescue', 'Build a plan first, then come back when reality changes.');
      if (next.reason === 'limit') {
        Alert.alert('Daily rescue limit reached', 'Upgrade for more live replanning.', [
          { text: 'Not now', style: 'cancel' },
          { text: 'See plans', onPress: () => router.replace('/paywall') },
        ]);
      }
      return;
    }
    setResult(next.value);
    if (next.fallback) Alert.alert('AI connection unavailable', 'A local emergency repair was used. The plan is safe to use, but it has less personalization.');
  }

  if (result) {
    const remainingTasks = result.tasks.filter((task) => task.status !== 'completed');
    return (
      <ScrollView contentInsetAdjustmentBehavior="automatic" contentContainerStyle={{ padding: spacing.lg, gap: spacing.xl }}>
        <View style={{ alignItems: 'center', gap: spacing.sm, paddingTop: spacing.md }}>
          <View style={{ width: 84, height: 84, borderRadius: 42, backgroundColor: colors.successSoft, alignItems: 'center', justifyContent: 'center' }}>
            <AppIcon name="arrow.triangle.2.circlepath" fallback="↻" color={colors.success} size={38} animated />
          </View>
          <AppText variant="title" style={{ textAlign: 'center' }}>
            The day is back under control
          </AppText>
          <AppText tone="secondary" style={{ textAlign: 'center' }}>
            The old plan is released. Only the actions that still matter remain.
          </AppText>
        </View>
        <Card style={{ backgroundColor: colors.successSoft, borderColor: colors.success }}>
          <AppText variant="caption" tone="success">
            FIRST MOVE
          </AppText>
          <AppText variant="heading">{remainingTasks[0]?.title ?? 'Take a two-minute reset'}</AppText>
          <AppText variant="small" tone="secondary">
            Start before evaluating the rest. Motion first, analysis second.
          </AppText>
        </Card>
        <View style={{ gap: spacing.sm }}>
          {remainingTasks.map((task, index) => (
            <Card key={task.id} muted={index > 0} style={{ flexDirection: 'row', alignItems: 'center', boxShadow: 'none' }}>
              <View style={{ width: 32, height: 32, borderRadius: 16, backgroundColor: index === 0 ? colors.accent : colors.surface, alignItems: 'center', justifyContent: 'center' }}>
                <AppText variant="caption" style={{ color: index === 0 ? '#FFFFFF' : colors.textSecondary }}>
                  {index + 1}
                </AppText>
              </View>
              <View style={{ flex: 1 }}>
                <AppText variant="label">{task.title}</AppText>
                <AppText variant="caption" tone="secondary">
                  {task.startTime} · {task.durationMinutes} min
                </AppText>
              </View>
            </Card>
          ))}
        </View>
        <AppButton title="Start the rescue" onPress={() => router.dismiss()} />
      </ScrollView>
    );
  }

  return (
    <ScrollView contentInsetAdjustmentBehavior="automatic" contentContainerStyle={{ padding: spacing.lg, gap: spacing.xl }}>
      <View style={{ gap: spacing.xs }}>
        <AppText variant="title">Repair the day in two taps</AppText>
        <AppText tone="secondary">Choose what changed, then apply. Sixty usable minutes is preselected; change it only when needed.</AppText>
      </View>

      <View style={{ gap: spacing.sm }}>
        {reasons.map((item) => {
          const selected = reason === item.id;
          return (
            <Pressable key={item.id} onPress={() => setReason(item.id)}>
              <Card style={{ flexDirection: 'row', alignItems: 'center', borderColor: selected ? colors.accent : colors.border, backgroundColor: selected ? colors.accentSoft : colors.surface }}>
                <View style={{ width: 42, height: 42, borderRadius: 15, alignItems: 'center', justifyContent: 'center', backgroundColor: selected ? colors.accent : colors.surfaceMuted }}>
                  <AppIcon name={item.icon} fallback="•" color={selected ? '#FFFFFF' : colors.text} size={20} animated={selected} />
                </View>
                <View style={{ flex: 1, gap: 2 }}>
                  <AppText variant="label">{item.title}</AppText>
                  <AppText variant="caption" tone="secondary">
                    {item.detail}
                  </AppText>
                </View>
                <AppIcon name={selected ? 'checkmark.circle.fill' : 'circle'} fallback={selected ? '✓' : '○'} color={selected ? colors.accent : colors.textTertiary} size={21} />
              </Card>
            </Pressable>
          );
        })}
      </View>

      <View style={{ gap: spacing.sm }}>
        <AppText variant="label">How much usable time is left?</AppText>
        <View style={{ flexDirection: 'row', gap: spacing.xs }}>
          {([10, 30, 60, 120] as const).map((minutes) => (
            <Chip
              key={minutes}
              label={minutes < 60 ? `${minutes}m` : `${minutes / 60}h`}
              selected={availableMinutes === minutes}
              onPress={() => setAvailableMinutes(minutes)}
              style={{ flex: 1 }}
            />
          ))}
        </View>
      </View>

      <Card muted>
        <AppText variant="caption" tone="secondary">
          CURRENT MUST-WIN
        </AppText>
        <AppText variant="label">{activePlan?.tasks.find((task) => task.mustWin)?.title ?? 'Build a plan to define one'}</AppText>
      </Card>
      <AppButton title="Apply AI repair" loading={working} disabled={!reason || !availableMinutes} onPress={rescue} />
    </ScrollView>
  );
}
