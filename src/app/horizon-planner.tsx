import { router } from 'expo-router';
import React, { useMemo, useState } from 'react';
import { Alert, Pressable, ScrollView, View } from 'react-native';

import { AppButton } from '@/components/app/app-button';
import { AppInput } from '@/components/app/app-input';
import { AppText } from '@/components/app/app-text';
import { Card } from '@/components/app/card';
import { Chip } from '@/components/app/chip';
import { spacing } from '@/constants/tokens';
import { useApp } from '@/context/app-context';
import { useAppTheme } from '@/context/theme-context';
import type { HorizonPlan, PlanningHorizon, SubscriptionTier } from '@/types/app';

const horizons: { id: PlanningHorizon; label: string; detail: string; tier: SubscriptionTier }[] = [
  { id: 'day', label: 'Day', detail: 'Actions and time blocks', tier: 'free' },
  { id: 'week', label: 'Week', detail: 'Outcomes and recovery margin', tier: 'plus' },
  { id: 'month', label: 'Month', detail: 'Milestones and dependencies', tier: 'pro' },
  { id: 'year', label: 'Year', detail: 'Quarterly direction and checkpoints', tier: 'max' },
];

const rank: Record<SubscriptionTier, number> = { free: 0, plus: 1, pro: 2, max: 3 };

export default function HorizonPlannerScreen() {
  const { colors } = useAppTheme();
  const { data, buildHorizonPlan } = useApp();
  const [horizon, setHorizon] = useState<PlanningHorizon>('day');
  const [objective, setObjective] = useState(data.profile.primaryGoal);
  const [building, setBuilding] = useState(false);
  const [result, setResult] = useState<HorizonPlan>();
  const latest = useMemo(() => data.horizonPlans.find((plan) => plan.horizon === horizon), [data.horizonPlans, horizon]);

  function choose(item: (typeof horizons)[number]) {
    if (rank[data.subscription] < rank[item.tier]) {
      router.push('/paywall');
      return;
    }
    setHorizon(item.id);
    setResult(undefined);
  }

  async function build() {
    if (!objective.trim()) {
      Alert.alert('Add an objective', 'What should this roadmap move forward?');
      return;
    }
    setBuilding(true);
    const next = await buildHorizonPlan(horizon, objective);
    setBuilding(false);
    if (!next.ok) {
      if (next.reason === 'locked') router.push('/paywall');
      return;
    }
    setResult(next.value);
    if (next.fallback) Alert.alert('AI connection unavailable', 'A conservative local outline was created. Retry later for deep personalization.');
  }

  const shown = result ?? latest;

  return (
    <ScrollView contentInsetAdjustmentBehavior="automatic" keyboardShouldPersistTaps="handled" contentContainerStyle={{ padding: spacing.lg, paddingBottom: 90, gap: spacing.xl }}>
      <View style={{ gap: spacing.xs }}>
        <AppText variant="title">One goal, every horizon</AppText>
        <AppText tone="secondary">The AI connects the long view to actions you can actually schedule, then revises it as your behavior changes.</AppText>
      </View>

      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm }}>
        {horizons.map((item) => {
          const locked = rank[data.subscription] < rank[item.tier];
          const selected = horizon === item.id;
          return (
            <Pressable key={item.id} onPress={() => choose(item)} style={{ flexBasis: '47%', flexGrow: 1 }}>
              <Card style={{ minHeight: 104, borderColor: selected ? colors.accent : colors.border, backgroundColor: selected ? colors.accentSoft : colors.surface, opacity: locked ? 0.66 : 1 }}>
                <View style={{ flexDirection: 'row', justifyContent: 'space-between', gap: spacing.xs }}>
                  <AppText variant="heading">{item.label}</AppText>
                  <Chip label={locked ? `${item.tier} · locked` : item.tier} selected={selected} />
                </View>
                <AppText variant="small" tone="secondary">{item.detail}</AppText>
              </Card>
            </Pressable>
          );
        })}
      </View>

      <View style={{ gap: spacing.xs }}>
        <AppText variant="label">Objective</AppText>
        <AppInput value={objective} onChangeText={setObjective} placeholder="What result should this period produce?" multiline />
      </View>
      <AppButton title={`Build ${horizon} roadmap`} loading={building} onPress={build} />

      {shown ? (
        <View style={{ gap: spacing.md }}>
          <Card style={{ backgroundColor: colors.infoSoft, borderColor: colors.info }}>
            <AppText variant="caption" style={{ color: colors.info }}>{shown.horizon.toUpperCase()} ROADMAP</AppText>
            <AppText variant="heading">{shown.title}</AppText>
            <AppText variant="small" tone="secondary">{shown.summary}</AppText>
          </Card>
          {shown.checkpoints.map((checkpoint, index) => (
            <View key={checkpoint.id} style={{ flexDirection: 'row', gap: spacing.sm, position: 'relative' }}>
              {index < shown.checkpoints.length - 1 ? <View style={{ position: 'absolute', left: 15, top: 31, bottom: -spacing.md, width: 1, backgroundColor: colors.border }} /> : null}
              <View style={{ width: 31, height: 31, borderRadius: 16, borderWidth: 1, borderColor: colors.accent, backgroundColor: colors.background, alignItems: 'center', justifyContent: 'center', zIndex: 1 }}>
                <AppText variant="caption" tone="accent">{index + 1}</AppText>
              </View>
              <Card style={{ flex: 1, boxShadow: 'none' }}>
                <AppText variant="caption" tone="accent">{checkpoint.label.toUpperCase()}</AppText>
                <AppText variant="heading">{checkpoint.outcome}</AppText>
                {checkpoint.actions.map((action) => (
                  <View key={action} style={{ flexDirection: 'row', gap: spacing.xs }}>
                    <AppText tone="tertiary">—</AppText>
                    <AppText variant="small" tone="secondary" style={{ flex: 1 }}>{action}</AppText>
                  </View>
                ))}
              </Card>
            </View>
          ))}
          <AppButton title="Turn the next checkpoint into today" variant="secondary" onPress={() => router.push('/plan-builder')} />
        </View>
      ) : null}
    </ScrollView>
  );
}
