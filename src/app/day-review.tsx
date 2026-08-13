import { router } from 'expo-router';
import React, { useMemo, useState } from 'react';
import { ScrollView, View } from 'react-native';

import { AppButton } from '@/components/app/app-button';
import { AppIcon } from '@/components/app/app-icon';
import { AppInput } from '@/components/app/app-input';
import { AppText } from '@/components/app/app-text';
import { Card } from '@/components/app/card';
import { Chip } from '@/components/app/chip';
import { ProgressRing } from '@/components/app/progress-ring';
import { spacing } from '@/constants/tokens';
import { useApp } from '@/context/app-context';
import { useAppTheme } from '@/context/theme-context';
import type { EnergyLevel } from '@/types/app';

const blockerOptions = ['Distraction', 'Low energy', 'Task too big', 'Unexpected event', 'Bad estimate', 'No clear first step'];

export default function DayReviewScreen() {
  const { colors } = useAppTheme();
  const { activePlan, addReview } = useApp();
  const [mood, setMood] = useState<EnergyLevel>(3);
  const [blocker, setBlocker] = useState('');
  const [win, setWin] = useState('');
  const [lesson, setLesson] = useState('');
  const score = useMemo(() => {
    if (!activePlan?.tasks.length) return 0;
    return Math.round((activePlan.tasks.filter((task) => task.status === 'completed').length / activePlan.tasks.length) * 100);
  }, [activePlan]);
  const autoWins = activePlan?.tasks.filter((task) => task.status === 'completed').map((task) => task.title).slice(0, 3) ?? [];

  function save() {
    addReview({
      score,
      wins: win.trim() ? [win.trim(), ...autoWins].slice(0, 4) : autoWins,
      blocker: blocker || undefined,
      lesson: lesson.trim() || undefined,
      mood,
    });
    router.dismiss();
  }

  return (
    <ScrollView contentInsetAdjustmentBehavior="automatic" keyboardShouldPersistTaps="handled" contentContainerStyle={{ padding: spacing.lg, gap: spacing.xl }}>
      <View style={{ alignItems: 'center', gap: spacing.sm }}>
        <ProgressRing value={score} size={112} stroke={10} />
        <AppText variant="title" style={{ textAlign: 'center' }}>
          Facts, not judgment
        </AppText>
        <AppText tone="secondary" style={{ textAlign: 'center' }}>
          A finished review teaches the next plan more than a perfect streak.
        </AppText>
      </View>

      {autoWins.length ? (
        <Card style={{ backgroundColor: colors.successSoft, borderColor: colors.success }}>
          <AppText variant="caption" tone="success">
            TODAY’S VISIBLE WINS
          </AppText>
          {autoWins.map((item) => (
            <View key={item} style={{ flexDirection: 'row', gap: spacing.sm }}>
              <AppIcon name="checkmark.circle.fill" fallback="✓" color={colors.success} size={17} />
              <AppText variant="small" style={{ flex: 1 }}>
                {item}
              </AppText>
            </View>
          ))}
        </Card>
      ) : null}

      <View style={{ gap: spacing.sm }}>
        <AppText variant="label">Energy at the end</AppText>
        <View style={{ flexDirection: 'row', gap: spacing.xs }}>
          {([1, 2, 3, 4, 5] as const).map((value) => (
            <Chip key={value} label={String(value)} selected={mood === value} onPress={() => setMood(value)} style={{ flex: 1 }} />
          ))}
        </View>
      </View>

      <View style={{ gap: spacing.sm }}>
        <AppText variant="label">What created the most friction?</AppText>
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.xs }}>
          {blockerOptions.map((option) => (
            <Chip key={option} label={option} selected={blocker === option} onPress={() => setBlocker(blocker === option ? '' : option)} />
          ))}
        </View>
      </View>

      <View style={{ gap: spacing.xs }}>
        <AppText variant="label">One win worth remembering</AppText>
        <AppInput value={win} onChangeText={setWin} placeholder="Something you did even when it was uncomfortable" />
      </View>

      <View style={{ gap: spacing.xs }}>
        <AppText variant="label">What should tomorrow’s coach change?</AppText>
        <AppInput value={lesson} onChangeText={setLesson} placeholder="Start later, shorten focus blocks, protect the morning…" multiline />
      </View>

      <AppButton title="Save the lesson" onPress={save} />
      <AppButton title="Skip review" variant="ghost" onPress={() => router.dismiss()} />
    </ScrollView>
  );
}
