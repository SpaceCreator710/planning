import { router } from 'expo-router';
import React, { useEffect, useMemo, useState } from 'react';
import { ScrollView, View } from 'react-native';

import { AppButton } from '@/components/app/app-button';
import { AppText } from '@/components/app/app-text';
import { Card } from '@/components/app/card';
import { ProgressRing } from '@/components/app/progress-ring';
import { spacing } from '@/constants/tokens';
import { useApp } from '@/context/app-context';
import { useAppTheme } from '@/context/theme-context';

export default function FocusScreen() {
  const { colors } = useAppTheme();
  const { activePlan, startTask, toggleTask, sendCoachMessage } = useApp();
  const task = activePlan?.tasks.find((item) => item.status === 'active') ?? activePlan?.tasks.find((item) => item.status === 'pending');
  const total = Math.max(5, task?.durationMinutes ?? 25) * 60;
  const [remaining, setRemaining] = useState(total);
  const [running, setRunning] = useState(false);

  useEffect(() => {
    if (!running || remaining <= 0) return;
    const timer = setInterval(() => setRemaining((value) => Math.max(0, value - 1)), 1000);
    return () => clearInterval(timer);
  }, [remaining, running]);

  const progress = useMemo(() => Math.round(((total - remaining) / total) * 100), [remaining, total]);
  const minutes = Math.floor(remaining / 60);
  const seconds = remaining % 60;

  if (!task) {
    return (
      <View style={{ flex: 1, padding: spacing.lg, justifyContent: 'center', gap: spacing.md }}>
        <AppText variant="title" style={{ textAlign: 'center' }}>Nothing to focus on yet</AppText>
        <AppText tone="secondary" style={{ textAlign: 'center' }}>Build a day plan first. The coach will choose a realistic next action.</AppText>
        <AppButton title="Build my day" onPress={() => router.replace('/plan-builder')} />
      </View>
    );
  }

  return (
    <ScrollView contentInsetAdjustmentBehavior="automatic" contentContainerStyle={{ flexGrow: 1, padding: spacing.xl, gap: spacing.xl, justifyContent: 'center' }}>
      <View style={{ alignItems: 'center', gap: spacing.md }}>
        <ProgressRing value={progress} size={178} stroke={12} />
        <AppText variant="display" style={{ fontVariant: ['tabular-nums'], fontSize: 48 }}>{String(minutes).padStart(2, '0')}:{String(seconds).padStart(2, '0')}</AppText>
        <View style={{ alignItems: 'center', gap: spacing.xs, maxWidth: 520 }}>
          <AppText variant="title" style={{ textAlign: 'center' }}>{task.title}</AppText>
          <AppText tone="secondary" style={{ textAlign: 'center' }}>{task.note || 'Only this action matters until the timer ends.'}</AppText>
        </View>
      </View>

      <Card style={{ backgroundColor: colors.accentSoft, borderColor: colors.accent }}>
        <AppText variant="caption" tone="accent">FOCUS CONTRACT</AppText>
        <AppText variant="small">No switching tasks. If you get stuck, ask the coach to reduce the next physical step instead of abandoning the block.</AppText>
      </Card>

      <View style={{ flexDirection: 'row', gap: spacing.sm }}>
        <AppButton
          title={running ? 'Pause' : remaining < total ? 'Continue' : 'Start focus'}
          onPress={() => {
            if (!running && task.status !== 'active') startTask(task.id);
            setRunning((value) => !value);
          }}
          style={{ flex: 2 }}
        />
        <AppButton title="Finish" variant="success" onPress={() => { toggleTask(task.id); router.dismiss(); }} style={{ flex: 1 }} />
      </View>
      <AppButton
        title="AI: make this easier to start"
        variant="secondary"
        onPress={() => {
          void sendCoachMessage(`I am stuck on my current task: "${task.title}". Use my profile and behavior to reduce it to the smallest physical first step without changing the real objective.`);
          router.push('/(tabs)/coach');
        }}
      />
    </ScrollView>
  );
}
