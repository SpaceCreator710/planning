import { router } from 'expo-router';
import React, { useEffect, useMemo, useState } from 'react';
import { Alert, Pressable, ScrollView, Switch, View } from 'react-native';

import { AppButton } from '@/components/app/app-button';
import { AppIcon } from '@/components/app/app-icon';
import { AppInput } from '@/components/app/app-input';
import { AppText } from '@/components/app/app-text';
import { Card } from '@/components/app/card';
import { Chip } from '@/components/app/chip';
import { canUseDeviceIntegration } from '@/constants/subscriptions';
import { radii, spacing } from '@/constants/tokens';
import { useApp } from '@/context/app-context';
import { useAppTheme } from '@/context/theme-context';
import { capacityFromHealth } from '@/services/capacity-twin';
import { healthKitAvailable, readHealthSnapshot, requestHealthAccess } from '@/services/health-bridge';
import type { HealthSnapshot, WorkoutKind } from '@/types/app';

const workoutIcons: Record<WorkoutKind, Parameters<typeof AppIcon>[0]['name']> = {
  walk: 'figure.walk',
  run: 'figure.run',
  cycling: 'bicycle',
  strength: 'dumbbell.fill',
  mobility: 'figure.cooldown',
  sport: 'figure.play',
};

export default function HealthTab() {
  const { colors } = useAppTheme();
  const { data, updateSettings, capacitySignal, applyCapacitySignal, addWorkoutSession } = useApp();
  const [loading, setLoading] = useState(false);
  const [activeWorkout, setActiveWorkout] = useState<{ kind: WorkoutKind; startedAt: string }>();
  const [elapsedSeconds, setElapsedSeconds] = useState(0);
  const [sleepInput, setSleepInput] = useState('');
  const [stepsInput, setStepsInput] = useState('');
  const [activityInput, setActivityInput] = useState('');
  const [standInput, setStandInput] = useState('');
  const snapshot = data.healthSnapshots[0];

  useEffect(() => {
    if (!activeWorkout) return;
    const update = () => setElapsedSeconds(Math.max(0, Math.floor((Date.now() - new Date(activeWorkout.startedAt).getTime()) / 1000)));
    update();
    const timer = setInterval(update, 1000);
    return () => clearInterval(timer);
  }, [activeWorkout]);

  const recentWorkouts = useMemo(() => [...data.workouts].sort((a, b) => b.completedAt.localeCompare(a.completedAt)).slice(0, 5), [data.workouts]);
  const recentHealth = useMemo(() => data.healthSnapshots.slice(0, 7).reverse(), [data.healthSnapshots]);

  async function connectHealth() {
    if (!canUseDeviceIntegration(data.subscription)) {
      router.push('/paywall');
      return;
    }
    setLoading(true);
    try {
      if (!healthKitAvailable()) {
        Alert.alert('Apple Health requires the iPhone app', 'HealthKit is available in the iOS development/App Store build, not in a browser or Expo Go. The built-in workout timer still works here.');
        return;
      }
      const granted = await requestHealthAccess();
      if (!granted) {
        Alert.alert('Health access was not enabled', 'You can choose individual read permissions in Apple Health and try again.');
        return;
      }
      const next = await readHealthSnapshot();
      updateSettings({ healthSyncEnabled: true });
      const signal = capacityFromHealth(next);
      applyCapacitySignal(signal, next);
    } catch (error) {
      Alert.alert('Health data unavailable', error instanceof Error ? error.message : 'Apple Health could not be read.');
    } finally {
      setLoading(false);
    }
  }

  function saveManualCheckIn() {
    if (![sleepInput, stepsInput, activityInput, standInput].some((value) => value.trim())) {
      Alert.alert('Add at least one value', 'Sleep, steps or activity is enough for a simple check-in.');
      return;
    }
    const number = (value: string, maximum: number) => Math.max(0, Math.min(maximum, Number(value.replace(',', '.')) || 0));
    const end = new Date();
    const start = new Date(end);
    start.setHours(0, 0, 0, 0);
    const todaysWorkouts = data.workouts.filter((workout) => new Date(workout.completedAt).toDateString() === end.toDateString());
    const manual: HealthSnapshot = {
      source: 'manual',
      available: true,
      startDate: start.toISOString(),
      endDate: end.toISOString(),
      sleepHours: number(sleepInput, 24),
      steps: Math.round(number(stepsInput, 200_000)),
      exerciseMinutes: Math.round(number(activityInput, 1_440)),
      standMinutes: Math.round(number(standInput, 1_440)),
      distanceKilometers: 0,
      workoutCount: todaysWorkouts.length,
      workoutMinutes: todaysWorkouts.reduce((sum, workout) => sum + workout.durationMinutes, 0),
      lastUpdated: end.toISOString(),
    };
    applyCapacitySignal(capacityFromHealth(manual), manual);
    setSleepInput('');
    setStepsInput('');
    setActivityInput('');
    setStandInput('');
  }

  function startWorkout(kind: WorkoutKind) {
    setElapsedSeconds(0);
    setActiveWorkout({ kind, startedAt: new Date().toISOString() });
  }

  function stopWorkout() {
    if (!activeWorkout) return;
    const completedAt = new Date().toISOString();
    addWorkoutSession({
      kind: activeWorkout.kind,
      title: workoutTitle(activeWorkout.kind),
      durationMinutes: Math.max(1, Math.round(elapsedSeconds / 60)),
      startedAt: activeWorkout.startedAt,
      completedAt,
    });
    setActiveWorkout(undefined);
    setElapsedSeconds(0);
  }

  const duration = `${String(Math.floor(elapsedSeconds / 3600)).padStart(2, '0')}:${String(Math.floor((elapsedSeconds % 3600) / 60)).padStart(2, '0')}:${String(elapsedSeconds % 60).padStart(2, '0')}`;

  return (
    <ScrollView contentInsetAdjustmentBehavior="automatic" contentContainerStyle={{ padding: spacing.md, paddingBottom: 120, gap: spacing.xl }}>
      <View style={{ gap: 3 }}>
        <AppText variant="title">Health & capacity</AppText>
        <AppText variant="small" tone="secondary">Sleep, movement and activity become realistic planning margin—not a score of your worth.</AppText>
      </View>

      <Card style={{ backgroundColor: colors.accentSoft, borderColor: colors.accent, gap: spacing.md }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.md }}>
          <View style={{ width: 58, height: 58, borderRadius: 22, borderCurve: 'continuous', backgroundColor: colors.surface, alignItems: 'center', justifyContent: 'center' }}>
            <AppIcon name="heart.fill" fallback="♥" color={colors.accent} size={28} animated={loading} />
          </View>
          <View style={{ flex: 1, gap: 3 }}>
            <AppText variant="caption" tone="accent">APPLE HEALTH · READ ONLY</AppText>
            <AppText variant="heading">{data.settings.healthSyncEnabled ? 'Health is connected' : 'Connect Apple Health'}</AppText>
            <AppText variant="small" tone="secondary">You choose permissions. Raw HealthKit data stays on the device and is never sent to the AI provider.</AppText>
          </View>
        </View>
        <AppButton title={data.settings.healthSyncEnabled ? 'Refresh from Apple Health' : canUseDeviceIntegration(data.subscription) ? 'Choose health permissions' : 'Unlock Apple Health connection'} loading={loading} onPress={() => void connectHealth()} />
      </Card>

      <Card muted style={{ gap: spacing.md }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.md }}>
          <View style={{ width: 48, height: 48, borderRadius: 18, backgroundColor: colors.successSoft, alignItems: 'center', justifyContent: 'center' }}>
            <AppIcon name="plus.forwardslash.minus" fallback="+" color={colors.success} size={22} />
          </View>
          <View style={{ flex: 1 }}>
            <AppText variant="heading">Built-in health check-in</AppText>
            <AppText variant="small" tone="secondary">Works on every device without Apple Health. Enter only what you want to track.</AppText>
          </View>
        </View>
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm }}>
          <AppInput value={sleepInput} onChangeText={setSleepInput} placeholder="Sleep hours" keyboardType="decimal-pad" style={{ flexBasis: '47%', flexGrow: 1 }} />
          <AppInput value={stepsInput} onChangeText={setStepsInput} placeholder="Steps" keyboardType="number-pad" style={{ flexBasis: '47%', flexGrow: 1 }} />
          <AppInput value={activityInput} onChangeText={setActivityInput} placeholder="Active minutes" keyboardType="number-pad" style={{ flexBasis: '47%', flexGrow: 1 }} />
          <AppInput value={standInput} onChangeText={setStandInput} placeholder="Standing minutes" keyboardType="number-pad" style={{ flexBasis: '47%', flexGrow: 1 }} />
        </View>
        <AppButton title="Save health check-in" variant="secondary" onPress={saveManualCheckIn} />
      </Card>

      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm }}>
        <MetricCard icon="bed.double.fill" label="Sleep" value={snapshot ? `${snapshot.sleepHours.toFixed(1)} h` : '—'} detail="last 48 hours" color={colors.info} />
        <MetricCard icon="shoeprints.fill" label="Steps" value={snapshot ? snapshot.steps.toLocaleString() : '—'} detail="today + recent" color={colors.success} />
        <MetricCard icon="figure.run" label="Active" value={snapshot ? `${Math.round(snapshot.exerciseMinutes)} min` : '—'} detail="exercise time" color={colors.accent} />
        <MetricCard icon="figure.stand" label="Standing" value={snapshot ? `${Math.round(snapshot.standMinutes)} min` : '—'} detail="Apple activity" color={colors.warning} />
        <MetricCard icon="map.fill" label="Distance" value={snapshot ? `${snapshot.distanceKilometers.toFixed(1)} km` : '—'} detail="walking + running" color={colors.info} />
        <MetricCard icon="heart.text.square.fill" label="Resting pulse" value={snapshot?.restingHeartRate ? `${snapshot.restingHeartRate} bpm` : '—'} detail="when shared" color={colors.accent} />
      </View>

      {recentHealth.length ? (
        <Card style={{ gap: spacing.md }}>
          <View>
            <AppText variant="heading">Recent health history</AppText>
            <AppText variant="small" tone="secondary">One private snapshot per day, from Apple Health or your check-in.</AppText>
          </View>
          <View style={{ flexDirection: 'row', alignItems: 'flex-end', minHeight: 120, gap: spacing.sm }}>
            {recentHealth.map((item) => {
              const score = capacityFromHealth(item).score;
              return (
                <View key={item.lastUpdated} style={{ flex: 1, alignItems: 'center', justifyContent: 'flex-end', gap: 5 }}>
                  <AppText style={{ fontSize: 10, color: colors.textTertiary, fontVariant: ['tabular-nums'] }}>{score}</AppText>
                  <View style={{ width: '100%', maxWidth: 34, height: Math.max(20, score), borderRadius: radii.pill, backgroundColor: item.source === 'apple-health' ? colors.accent : colors.success }} />
                  <AppText style={{ fontSize: 9, color: colors.textTertiary }}>{new Date(item.lastUpdated).toLocaleDateString(undefined, { weekday: 'narrow' })}</AppText>
                </View>
              );
            })}
          </View>
        </Card>
      ) : null}

      {capacitySignal ? (
        <Card style={{ borderColor: capacitySignal.level === 'recover' ? colors.info : capacitySignal.level === 'strong' ? colors.success : colors.border, gap: spacing.sm }}>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.md }}>
            <View style={{ width: 52, height: 52, borderRadius: 20, backgroundColor: colors.surfaceMuted, alignItems: 'center', justifyContent: 'center' }}>
              <AppText variant="heading" tone="accent">{capacitySignal.score}</AppText>
            </View>
            <View style={{ flex: 1 }}>
              <AppText variant="caption" tone="secondary">CAPACITY TWIN · {capacitySignal.level.toUpperCase()}</AppText>
              <AppText variant="label">Suggested focus block: {capacitySignal.suggestedFocusMinutes} minutes</AppText>
            </View>
          </View>
          <AppText variant="small" tone="secondary">{capacitySignal.summary}</AppText>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.sm }}>
            <View style={{ flex: 1 }}>
              <AppText variant="label">Use for AI planning</AppText>
              <AppText variant="caption" tone="secondary">Only the compact capacity signal—not raw health records—is included.</AppText>
            </View>
            <Switch
              value={data.settings.healthPlanningEnabled}
              onValueChange={(healthPlanningEnabled) => updateSettings({ healthPlanningEnabled })}
              trackColor={{ false: colors.surfaceMuted, true: colors.accentSoft }}
              thumbColor={data.settings.healthPlanningEnabled ? colors.accent : colors.textTertiary}
            />
          </View>
        </Card>
      ) : null}

      <View style={{ gap: spacing.md }}>
        <View>
          <AppText variant="heading">Sport timer</AppText>
          <AppText variant="small" tone="secondary">A simple timer for movement you choose. No calorie targets and no pressure to overtrain.</AppText>
        </View>
        {activeWorkout ? (
          <Card style={{ alignItems: 'center', gap: spacing.lg, paddingVertical: spacing.xl, borderColor: colors.success }}>
            <View style={{ width: 76, height: 76, borderRadius: 28, backgroundColor: colors.successSoft, alignItems: 'center', justifyContent: 'center' }}>
              <AppIcon name={workoutIcons[activeWorkout.kind]} fallback="▶" color={colors.success} size={36} animated />
            </View>
            <View style={{ alignItems: 'center', gap: 3 }}>
              <AppText variant="caption" tone="success">{workoutTitle(activeWorkout.kind).toUpperCase()}</AppText>
              <AppText style={{ fontSize: 42, lineHeight: 48, fontWeight: '800', fontVariant: ['tabular-nums'], color: colors.text }}>{duration}</AppText>
            </View>
            <AppButton title="Finish session" variant="success" onPress={stopWorkout} style={{ alignSelf: 'stretch' }} />
          </Card>
        ) : (
          <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm }}>
            {(Object.keys(workoutIcons) as WorkoutKind[]).map((kind) => (
              <Pressable
                key={kind}
                onPress={() => startWorkout(kind)}
                style={({ pressed }) => ({ width: '31%', minHeight: 104, padding: spacing.sm, borderRadius: radii.lg, borderCurve: 'continuous', backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border, alignItems: 'center', justifyContent: 'center', gap: spacing.xs, opacity: pressed ? 0.7 : 1 })}>
                <AppIcon name={workoutIcons[kind]} fallback="▶" color={colors.accent} size={27} />
                <AppText variant="caption" style={{ textAlign: 'center' }}>{workoutTitle(kind)}</AppText>
              </Pressable>
            ))}
          </View>
        )}
      </View>

      {recentWorkouts.length ? (
        <Card style={{ gap: spacing.sm }}>
          <AppText variant="heading">Recent sessions</AppText>
          {recentWorkouts.map((workout) => (
            <View key={workout.id} style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.sm, paddingVertical: spacing.xs }}>
              <View style={{ width: 38, height: 38, borderRadius: 15, backgroundColor: colors.successSoft, alignItems: 'center', justifyContent: 'center' }}>
                <AppIcon name={workoutIcons[workout.kind]} fallback="•" color={colors.success} size={19} />
              </View>
              <View style={{ flex: 1 }}>
                <AppText variant="label">{workout.title}</AppText>
                <AppText variant="caption" tone="secondary">{new Date(workout.completedAt).toLocaleDateString()} · {workout.durationMinutes} min</AppText>
              </View>
              <Chip label="DONE" selected color={colors.success} />
            </View>
          ))}
        </Card>
      ) : null}

      <AppText variant="caption" tone="tertiary" style={{ textAlign: 'center' }}>Wellbeing insights are informational and are not medical advice or a diagnosis.</AppText>
    </ScrollView>
  );
}

function MetricCard({ icon, label, value, detail, color }: { icon: Parameters<typeof AppIcon>[0]['name']; label: string; value: string; detail: string; color: string }) {
  const { colors } = useAppTheme();
  return (
    <Card style={{ width: '47%', minHeight: 132, gap: spacing.sm }}>
      <View style={{ width: 42, height: 42, borderRadius: 16, backgroundColor: `${color}18`, alignItems: 'center', justifyContent: 'center' }}>
        <AppIcon name={icon} fallback="•" color={color} size={22} />
      </View>
      <View>
        <AppText variant="caption" tone="secondary">{label.toUpperCase()}</AppText>
        <AppText variant="heading">{value}</AppText>
        <AppText variant="caption" style={{ color: colors.textTertiary }}>{detail}</AppText>
      </View>
    </Card>
  );
}

function workoutTitle(kind: WorkoutKind) {
  return ({ walk: 'Walk', run: 'Run', cycling: 'Cycling', strength: 'Strength', mobility: 'Mobility', sport: 'Sport' } as const)[kind];
}
