import { router } from 'expo-router';
import React, { useState } from 'react';
import { Alert, KeyboardAvoidingView, ScrollView, View } from 'react-native';

import { AppButton } from '@/components/app/app-button';
import { AppInput } from '@/components/app/app-input';
import { AppText } from '@/components/app/app-text';
import { Card } from '@/components/app/card';
import { Chip } from '@/components/app/chip';
import { ProgressRing } from '@/components/app/progress-ring';
import { spacing } from '@/constants/tokens';
import { useApp } from '@/context/app-context';
import { useAppTheme } from '@/context/theme-context';
import { schedulePlanReminders } from '@/services/notifications';
import type { DayPlan, EnergyLevel, PlanStyle } from '@/types/app';

export default function PlanBuilderScreen() {
  const { colors } = useAppTheme();
  const { data, buildPlan } = useApp();
  const [brainDump, setBrainDump] = useState('');
  const [mustWin, setMustWin] = useState(data.profile.primaryGoal);
  const [fixed, setFixed] = useState(data.profile.fixedCommitments);
  const [energy, setEnergy] = useState<EnergyLevel>(3);
  const [style, setStyle] = useState<PlanStyle>('realistic');
  const [result, setResult] = useState<DayPlan>();
  const [building, setBuilding] = useState(false);

  async function generate() {
    if (!brainDump.trim() && !mustWin.trim()) {
      Alert.alert('Give the planner something to work with', 'Add a brain dump or one must-win result.');
      return;
    }
    setBuilding(true);
    const next = await buildPlan({ brainDump, mustWin, fixedCommitments: fixed, energy, style });
    setBuilding(false);
    if (!next.ok) {
      if (next.reason === 'limit') {
        Alert.alert('Daily plan limit reached', 'Upgrade to create more AI plans today.', [
          { text: 'Not now', style: 'cancel' },
          { text: 'See plans', onPress: () => router.replace('/paywall') },
        ]);
      }
      return;
    }
    setResult(next.value);
    if (next.fallback) {
      Alert.alert('AI connection unavailable', 'A local emergency planner created this version. Retry later for full personalization.');
    }
    if (data.settings.notificationsEnabled && data.settings.taskReminders && next.value) {
      schedulePlanReminders(next.value).catch(() => undefined);
    }
  }

  if (result) {
    return (
      <ScrollView contentInsetAdjustmentBehavior="automatic" contentContainerStyle={{ padding: spacing.lg, gap: spacing.xl }}>
        <View style={{ alignItems: 'center', gap: spacing.sm, paddingTop: spacing.md }}>
          <ProgressRing value={result.planScore} size={118} stroke={10} />
          <AppText variant="title" style={{ textAlign: 'center' }}>
            {result.title} is ready
          </AppText>
          <AppText tone="secondary" style={{ textAlign: 'center' }}>
            {result.tasks.length} actions · energy {result.energy}/5 · one protected must-win
          </AppText>
        </View>
        <Card style={{ backgroundColor: result.planScore >= 80 ? colors.successSoft : colors.warningSoft }}>
          <AppText variant="caption" tone={result.planScore >= 80 ? 'success' : 'warning'}>
            REALITY CHECK
          </AppText>
          <AppText variant="heading">
            {result.planScore >= 80 ? 'This plan leaves room for real life.' : 'This plan is ambitious. Protect the first two actions.'}
          </AppText>
          <AppText variant="small" tone="secondary">
            Breaks and transition buffers are already included. If the day slips, Rescue My Day will protect the main result.
          </AppText>
        </Card>
        <View style={{ gap: spacing.sm }}>
          {result.tasks.map((task) => (
            <View key={task.id} style={{ flexDirection: 'row', gap: spacing.sm, alignItems: 'center' }}>
              <AppText variant="caption" tone="secondary" style={{ width: 88, fontVariant: ['tabular-nums'] }}>
                {task.startTime}–{task.endTime}
              </AppText>
              <View style={{ width: 8, height: 8, borderRadius: 4, backgroundColor: task.mustWin ? colors.accent : colors.border }} />
              <AppText variant="small" style={{ flex: 1, fontWeight: task.mustWin ? '700' : '500' }}>
                {task.title}
              </AppText>
            </View>
          ))}
        </View>
        <AppButton title="Use this plan" onPress={() => router.dismiss()} />
        <AppButton title="Build another version" variant="secondary" onPress={() => setResult(undefined)} />
      </ScrollView>
    );
  }

  return (
    <KeyboardAvoidingView style={{ flex: 1 }} behavior={process.env.EXPO_OS === 'ios' ? 'padding' : undefined}>
      <ScrollView
        contentInsetAdjustmentBehavior="automatic"
        keyboardShouldPersistTaps="handled"
        contentContainerStyle={{ padding: spacing.lg, gap: spacing.xl }}>
        <View style={{ gap: spacing.xs }}>
          <AppText variant="title">Drop the mental load</AppText>
          <AppText tone="secondary">Write everything. The planner will cut, order, time-box and add breathing room.</AppText>
        </View>

        <View style={{ gap: spacing.xs }}>
          <AppText variant="label">Brain dump</AppText>
          <AppInput
            value={brainDump}
            onChangeText={setBrainDump}
            placeholder={'Finish presentation\nStudy chapter 4\nBuy groceries\nWorkout'}
            multiline
            autoFocus
            style={{ minHeight: 150 }}
          />
        </View>

        <View style={{ gap: spacing.xs }}>
          <AppText variant="label">One must-win result</AppText>
          <AppInput value={mustWin} onChangeText={setMustWin} placeholder="What makes today count?" />
        </View>

        <View style={{ gap: spacing.xs }}>
          <AppText variant="label">Fixed commitments</AppText>
          <AppInput value={fixed} onChangeText={setFixed} placeholder="School 09:00–15:00, call at 17:30" />
          <AppText variant="caption" tone="tertiary">
            Free calendar import can populate this from the Integrations screen.
          </AppText>
        </View>

        <View style={{ gap: spacing.sm }}>
          <AppText variant="label">Energy right now</AppText>
          <View style={{ flexDirection: 'row', gap: spacing.xs }}>
            {([1, 2, 3, 4, 5] as const).map((value) => (
              <Chip key={value} label={String(value)} selected={energy === value} onPress={() => setEnergy(value)} style={{ flex: 1 }} />
            ))}
          </View>
        </View>

        <View style={{ gap: spacing.sm }}>
          <AppText variant="label">Plan version</AppText>
          <View style={{ gap: spacing.sm }}>
            <StyleCard
              title="Minimum"
              detail="1 must-win + only essentials"
              selected={style === 'minimum'}
              onPress={() => setStyle('minimum')}
            />
            <StyleCard
              title="Realistic"
              detail="Priorities, breaks and buffers"
              selected={style === 'realistic'}
              recommended
              onPress={() => setStyle('realistic')}
            />
            <StyleCard title="Full" detail="An ambitious structured day" selected={style === 'full'} onPress={() => setStyle('full')} />
          </View>
        </View>

        <AppButton title="Build my real day" loading={building} onPress={generate} />
        <AppText variant="caption" tone="tertiary" style={{ textAlign: 'center' }}>
          The AI reads your profile, active goals, memories, recent behavior and fixed commitments before scheduling.
        </AppText>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

function StyleCard({
  title,
  detail,
  selected,
  recommended,
  onPress,
}: {
  title: string;
  detail: string;
  selected: boolean;
  recommended?: boolean;
  onPress: () => void;
}) {
  const { colors } = useAppTheme();
  return (
    <Card style={{ borderColor: selected ? colors.accent : colors.border, backgroundColor: selected ? colors.accentSoft : colors.surface }}>
      <AppButton
        title={title}
        variant="ghost"
        compact
        onPress={onPress}
        style={{ position: 'absolute', inset: 0, opacity: 0.01 }}
        accessibilityLabel={`${title}: ${detail}`}
      />
      <View pointerEvents="none" style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.sm }}>
        <View style={{ width: 24, height: 24, borderRadius: 12, borderWidth: 2, borderColor: selected ? colors.accent : colors.border, alignItems: 'center', justifyContent: 'center' }}>
          {selected ? <View style={{ width: 12, height: 12, borderRadius: 6, backgroundColor: colors.accent }} /> : null}
        </View>
        <View style={{ flex: 1 }}>
          <AppText variant="label">{title}</AppText>
          <AppText variant="small" tone="secondary">
            {detail}
          </AppText>
        </View>
        {recommended ? <Chip label="RECOMMENDED" selected /> : null}
      </View>
    </Card>
  );
}
