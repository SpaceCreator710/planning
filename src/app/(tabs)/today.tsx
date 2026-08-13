import { router } from 'expo-router';
import React, { useMemo, useState } from 'react';
import { Alert, Pressable, ScrollView, View } from 'react-native';

import { AppButton } from '@/components/app/app-button';
import { AppIcon } from '@/components/app/app-icon';
import { AppInput } from '@/components/app/app-input';
import { AppText } from '@/components/app/app-text';
import { Card } from '@/components/app/card';
import { Chip } from '@/components/app/chip';
import { ProgressRing } from '@/components/app/progress-ring';
import { SectionHeader } from '@/components/app/section-header';
import { TaskCard } from '@/components/app/task-card';
import { categoryTaskColor, spacing, taskPalettes } from '@/constants/tokens';
import { translate } from '@/constants/translations';
import { useApp } from '@/context/app-context';
import { useAppTheme } from '@/context/theme-context';
import { dateKey, formatFriendlyDate, greetingForHour, minutesToTime, timeToMinutes } from '@/lib/date';
import { bodyRhythmForProfile } from '@/services/body-rhythm';
import { detectScheduleCollisions } from '@/services/capacity-twin';
import { analyzeReality } from '@/services/reality-engine';
import type { DaySection, TaskColor } from '@/types/app';

const sectionOrder: DaySection[] = ['morning', 'day', 'evening', 'night'];

export default function TodayScreen() {
  const { colors } = useAppTheme();
  const { data, activePlan, capacitySignal, toggleTask, startTask, skipTask, moveTask, addManualTask, sendCoachMessage, setPlannerMode, buildPlan, rescuePlan, duplicateDay } = useApp();
  const plannerMode = activePlan?.mode ?? 'ai-plan';
  const [adding, setAdding] = useState(false);
  const [newTask, setNewTask] = useState('');
  const [optimizingChain, setOptimizingChain] = useState(false);
  const [repairingReality, setRepairingReality] = useState(false);
  const language = data.settings.language;
  const locale = language === 'ru' ? 'ru-RU' : 'en-US';
  const t = (key: Parameters<typeof translate>[1]) => translate(language, key);

  const progress = useMemo(() => {
    if (!activePlan?.tasks.length) return 0;
    const complete = activePlan.tasks.filter((task) => task.status === 'completed').length;
    return Math.round((complete / activePlan.tasks.length) * 100);
  }, [activePlan]);
  const nextTask = activePlan?.tasks.find((task) => task.status === 'active') ?? activePlan?.tasks.find((task) => task.status === 'pending');
  const completedCount = activePlan?.tasks.filter((task) => task.status === 'completed').length ?? 0;
  const reality = useMemo(() => analyzeReality(activePlan), [activePlan]);
  const collisions = useMemo(() => detectScheduleCollisions(activePlan, capacitySignal), [activePlan, capacitySignal]);
  const bodyRhythm = useMemo(() => bodyRhythmForProfile(data.profile), [data.profile]);
  const freeWindows = useMemo(() => {
    if (!activePlan) return [];
    const start = timeToMinutes(data.profile.wakeTime || '07:00');
    const end = timeToMinutes(data.profile.sleepTime || '23:00');
    const timed = activePlan.tasks
      .filter((task) => task.startTime && !task.allDay && task.status !== 'skipped')
      .map((task) => ({ start: timeToMinutes(task.startTime!), end: task.endTime ? timeToMinutes(task.endTime) : timeToMinutes(task.startTime!) + task.durationMinutes }))
      .sort((a, b) => a.start - b.start);
    const gaps: { start: string; end: string; minutes: number }[] = [];
    let cursor = start;
    for (const block of timed) {
      if (block.start - cursor >= 20) gaps.push({ start: minutesToTime(cursor), end: minutesToTime(block.start), minutes: block.start - cursor });
      cursor = Math.max(cursor, block.end);
    }
    if (end - cursor >= 20) gaps.push({ start: minutesToTime(cursor), end: minutesToTime(end), minutes: end - cursor });
    return gaps.slice(0, 5);
  }, [activePlan, data.profile.sleepTime, data.profile.wakeTime]);
  const yesterdayKey = useMemo(() => {
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    return dateKey(yesterday);
  }, []);
  const week = useMemo(() => Array.from({ length: 7 }, (_, index) => {
    const day = new Date();
    day.setHours(12, 0, 0, 0);
    day.setDate(day.getDate() + index - 2);
    const key = day.toISOString().slice(0, 10);
    const plan = data.plans.find((item) => item.date === key);
    const done = plan?.tasks.filter((task) => task.status === 'completed').length ?? 0;
    return {
      key,
      label: new Intl.DateTimeFormat(locale, { weekday: 'short' }).format(day).slice(0, 2),
      number: day.getDate(),
      progress: plan?.tasks.length ? done / plan.tasks.length : 0,
      today: index === 2,
    };
  }), [data.plans, locale]);

  function addTask() {
    if (!newTask.trim()) return;
    addManualTask(newTask);
    setNewTask('');
    setAdding(false);
  }

  function motivate() {
    void sendCoachMessage('Use my current plan and recent behavior. Motivate me to start the exact next task now.');
    router.push('/(tabs)/coach');
  }

  function confirmSkip(taskId: string) {
    Alert.alert('Skip this task?', 'The coach will keep the reason as a planning signal.', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'No time', onPress: () => skipTask(taskId, 'No time') },
      { text: 'Low energy', onPress: () => skipTask(taskId, 'Low energy') },
    ]);
  }

  async function optimizeChain() {
    if (!activePlan?.tasks.length || optimizingChain) return;
    const unfinished = activePlan.tasks.filter((task) => task.status !== 'completed');
    if (!unfinished.length) {
      Alert.alert('Chain complete', 'Every action in this chain is already finished.');
      return;
    }
    setOptimizingChain(true);
    const result = await buildPlan({
      brainDump: unfinished.map((task) => task.title).join('\n'),
      mustWin: unfinished.find((task) => task.mustWin)?.title ?? unfinished[0]?.title ?? data.profile.primaryGoal,
      fixedCommitments: data.profile.fixedCommitments,
      energy: activePlan.energy,
      style: 'realistic',
      plannerMode: 'day-chain',
    });
    setOptimizingChain(false);
    if (!result.ok && result.reason === 'limit') router.push('/paywall');
    else if (result.fallback) Alert.alert('AI connection unavailable', 'The chain was ordered with the local emergency planner. Retry later for full personalization.');
  }

  async function repairFromReality() {
    if (!reality.recovery || repairingReality) return;
    setRepairingReality(true);
    const result = await rescuePlan(reality.recovery);
    setRepairingReality(false);
    if (!result.ok && result.reason === 'limit') router.push('/paywall');
    else if (result.fallback) Alert.alert('Day repaired locally', 'The protected AI was unavailable, so the safe on-device repair kept your completed work and rebuilt the unfinished part.');
  }

  return (
    <ScrollView
      contentInsetAdjustmentBehavior="automatic"
      keyboardShouldPersistTaps="handled"
      contentContainerStyle={{ padding: spacing.md, paddingBottom: 120, gap: spacing.xl }}>
      <View style={{ gap: spacing.xs }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: spacing.sm }}>
          <View style={{ flex: 1 }}>
            <AppText variant="title">
              {greetingForHour()}{data.profile.name ? `, ${data.profile.name}` : ''}
            </AppText>
            <AppText variant="small" tone="secondary">
              {formatFriendlyDate(new Date(), locale)}
            </AppText>
          </View>
          <Chip
            label={data.settings.coachMode.toUpperCase()}
            selected
            color={data.settings.coachMode === 'soft' ? colors.success : colors.accent}
            onPress={() => router.push('/settings')}
          />
        </View>
      </View>

      <Pressable onPress={() => router.push('/inbox')}>
        <Card muted style={{ flexDirection: 'row', alignItems: 'center', padding: spacing.sm }}>
          <View style={{ flex: 1, gap: 2, paddingHorizontal: spacing.xs }}>
            <AppText variant="label">Inbox</AppText>
            <AppText variant="caption" tone="secondary">Capture many tasks now; let AI schedule them when you are ready.</AppText>
          </View>
          <Chip label={String(data.inbox.length)} selected={data.inbox.length > 0} />
        </Card>
      </Pressable>

      <View style={{ flexDirection: 'row', gap: spacing.xs }}>
        {week.map((day) => (
          <Pressable
            key={day.key}
            accessibilityRole="button"
            onPress={() => router.push({ pathname: '/calendar-view', params: { date: day.key } })}
            style={({ pressed }) => ({
              flex: 1,
              minWidth: 38,
              alignItems: 'center',
              gap: 5,
              paddingVertical: spacing.sm,
              borderRadius: 16,
              backgroundColor: day.today ? colors.accent : colors.surface,
              borderWidth: 1,
              borderColor: day.today ? colors.accent : colors.border,
              opacity: pressed ? 0.72 : 1,
            })}>
            <AppText variant="caption" style={{ color: day.today ? '#FFFFFF' : colors.textSecondary }}>{day.label}</AppText>
            <AppText variant="label" style={{ color: day.today ? '#FFFFFF' : colors.text }}>{day.number}</AppText>
            <View style={{ width: 20, height: 3, borderRadius: 99, backgroundColor: day.today ? 'rgba(255,255,255,0.35)' : colors.surfaceMuted, overflow: 'hidden' }}>
              <View style={{ width: `${Math.round(day.progress * 100)}%`, height: '100%', backgroundColor: day.today ? '#FFFFFF' : colors.success }} />
            </View>
          </Pressable>
        ))}
      </View>

      <Card
        style={{
          padding: spacing.lg,
          borderColor: nextTask ? colors.accent : colors.success,
          backgroundColor: nextTask ? colors.surface : colors.successSoft,
          gap: spacing.md,
        }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.md }}>
          <ProgressRing value={progress} size={78} />
          <View style={{ flex: 1, gap: spacing.xs }}>
            <AppText variant="caption" tone={nextTask ? 'accent' : 'success'}>
              {t('nextAction').toUpperCase()}
            </AppText>
            <AppText variant="heading">{nextTask?.title ?? 'Day complete. Close it with a review.'}</AppText>
            <AppText variant="small" tone="secondary">
              {nextTask
                ? `${nextTask.durationMinutes} min · ${nextTask.mustWin ? 'Your must-win task' : 'One step at a time'}`
                : `${completedCount} actions completed`}
            </AppText>
          </View>
        </View>
        <View style={{ flexDirection: 'row', gap: spacing.sm }}>
          {nextTask ? (
            <>
              <AppButton
                title={nextTask.status === 'active' ? 'Finish now' : t('start')}
                onPress={() => {
                  if (nextTask.status === 'active') toggleTask(nextTask.id);
                  else {
                    startTask(nextTask.id);
                    router.push('/focus');
                  }
                }}
                style={{ flex: 2 }}
              />
              <AppButton title="Adjust" variant="secondary" onPress={() => router.push('/rescue')} style={{ flex: 1 }} />
            </>
          ) : (
            <AppButton title="Review the day" variant="success" onPress={() => router.push('/day-review')} style={{ flex: 1 }} />
          )}
        </View>
      </Card>

      {collisions.map((collision) => (
        <Card key={collision.id} style={{ gap: spacing.sm, backgroundColor: colors.warningSoft, borderColor: colors.warning }}>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.md }}>
            <View style={{ width: 46, height: 46, borderRadius: 17, backgroundColor: colors.surface, alignItems: 'center', justifyContent: 'center' }}>
              <AppIcon name="exclamationmark.triangle.fill" fallback="!" color={colors.warning} size={23} animated />
            </View>
            <View style={{ flex: 1, gap: 2 }}>
              <AppText variant="caption" tone="secondary">COLLISION RADAR · {collision.severity.toUpperCase()}</AppText>
              <AppText variant="label">{collision.title}</AppText>
              <AppText variant="small" tone="secondary">{collision.detail}</AppText>
            </View>
          </View>
          <AppButton compact title="Let AI make room" onPress={() => router.push('/rescue')} />
        </Card>
      ))}

      {bodyRhythm ? (
        <Pressable onPress={() => router.push('/settings')}>
          <Card muted style={{ flexDirection: 'row', alignItems: 'center', padding: spacing.sm }}>
            <View style={{ width: 42, height: 42, borderRadius: 16, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.accentSoft }}>
              <AppText tone="accent" style={{ fontWeight: '900' }}>{bodyRhythm.day}</AppText>
            </View>
            <View style={{ flex: 1, gap: 2 }}>
              <AppText variant="label">Body rhythm · {bodyRhythm.phase}</AppText>
              <AppText variant="caption" tone="secondary">{bodyRhythm.guidance}</AppText>
            </View>
          </Card>
        </Pressable>
      ) : null}

      <View style={{ flexDirection: 'row', gap: spacing.xs }}>
        <QuickAction title={t('buildDay')} detail="AI schedule" onPress={() => router.push('/plan-builder')} />
        <QuickAction title="Plan changed" detail="2-tap repair" onPress={() => router.push('/rescue')} />
        <QuickAction title={t('motivate')} detail="Coach me" onPress={motivate} />
      </View>

      <Card
        style={{
          borderColor: reality.state === 'overloaded' || reality.state === 'drifting' ? colors.warning : colors.info,
          backgroundColor: reality.state === 'overloaded' || reality.state === 'drifting' ? colors.warningSoft : colors.infoSoft,
          gap: spacing.sm,
        }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.md }}>
          <View style={{ width: 48, height: 48, borderRadius: 18, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.surface }}>
            <AppText variant="heading" style={{ color: reality.state === 'overloaded' || reality.state === 'drifting' ? colors.warning : colors.info }}>
              {reality.score}
            </AppText>
          </View>
          <View style={{ flex: 1, gap: 3 }}>
            <AppText variant="caption" tone="secondary">DRIFT GUARD · LIVE REALITY ENGINE</AppText>
            <AppText variant="label">{reality.title}</AppText>
            <AppText variant="small" tone="secondary">{reality.message}</AppText>
          </View>
        </View>
        {reality.recovery ? (
          <AppButton
            compact
            loading={repairingReality}
            title={reality.state === 'overloaded' ? 'Compress my day' : 'Start a 10-minute recovery'}
            onPress={() => void repairFromReality()}
          />
        ) : null}
      </Card>

      {activePlan ? (
        <Card muted style={{ flexDirection: 'row', alignItems: 'center', padding: spacing.sm }}>
          <View style={{ flex: 1, gap: 2, paddingHorizontal: spacing.xs }}>
            <AppText variant="label">{activePlan.title}</AppText>
            <AppText variant="caption" tone="secondary">
              Reality score {activePlan.planScore}% · Energy {activePlan.energy}/5
            </AppText>
          </View>
          <View style={{ flexDirection: 'row', gap: spacing.xs }}>
            <Chip label={t('aiPlan')} selected={plannerMode === 'ai-plan'} onPress={() => setPlannerMode('ai-plan')} />
            <Chip label={t('dayChain')} selected={plannerMode === 'day-chain'} onPress={() => setPlannerMode('day-chain')} />
          </View>
        </Card>
      ) : null}

      {freeWindows.length ? (
        <Card muted style={{ gap: spacing.sm }}>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.sm }}>
            <AppIcon name="clock.badge.checkmark" fallback="◷" color={colors.success} size={20} />
            <View style={{ flex: 1 }}>
              <AppText variant="label">Breathing room</AppText>
              <AppText variant="caption" tone="secondary">Automatically calculated openings between scheduled blocks.</AppText>
            </View>
          </View>
          <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.xs }}>
            {freeWindows.map((gap) => <Chip key={`${gap.start}-${gap.end}`} label={`${gap.start}–${gap.end} · ${gap.minutes}m`} color={colors.success} />)}
          </View>
        </Card>
      ) : null}

      <View style={{ gap: spacing.md }}>
        <SectionHeader title={plannerMode === 'ai-plan' ? 'Your timeline' : 'Your day chain'} detail={`${completedCount}/${activePlan?.tasks.length ?? 0} complete`} />
        {activePlan ? (
          plannerMode === 'ai-plan' ? (
            sectionOrder.map((section) => {
              const tasks = activePlan.tasks.filter((task) => task.section === section);
              if (!tasks.length) return null;
              return (
                <View key={section} style={{ gap: spacing.sm }}>
                  <AppText variant="label" tone="secondary">
                    {t(section).toUpperCase()}
                  </AppText>
                  {tasks.map((task) => (
                    <TaskCard
                      key={task.id}
                      task={task}
                      onToggle={() => toggleTask(task.id)}
                      onStart={() => startTask(task.id)}
                      onSkip={() => confirmSkip(task.id)}
                      onMove={(direction) => moveTask(task.id, direction)}
                      onEdit={() => router.push({ pathname: '/task-editor', params: { id: task.id } })}
                    />
                  ))}
                </View>
              );
            })
          ) : (
            <>
              {activePlan.tasks.map((task, index) => {
                const tone = taskPalettes[(task.color ?? categoryTaskColor[task.category]) as TaskColor];
                return (
                <View key={task.id} style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.sm, position: 'relative' }}>
                  {index < activePlan.tasks.length - 1 ? (
                    <View style={{ position: 'absolute', left: 15, top: 28, bottom: -spacing.sm - 1, width: 2, borderRadius: 2, backgroundColor: tone.solid }} />
                  ) : null}
                  <View style={{ width: 32, height: 32, borderRadius: 16, alignItems: 'center', justifyContent: 'center', backgroundColor: tone.solid, borderWidth: 2, borderColor: colors.surface, zIndex: 1 }}>
                    {task.status === 'completed'
                      ? <AppIcon name="checkmark" fallback="✓" color="#FFFFFF" size={14} />
                      : <AppText variant="caption" style={{ color: '#FFFFFF', fontWeight: '900' }}>{String(index + 1)}</AppText>}
                  </View>
                  <View style={{ flex: 1, flexDirection: 'row', alignItems: 'center', gap: spacing.sm, padding: spacing.md, borderRadius: 18, borderCurve: 'continuous', backgroundColor: `${tone.solid}18`, borderWidth: 1, borderColor: `${tone.solid}66` }}>
                    <Pressable onPress={() => toggleTask(task.id)} style={{ flex: 1 }}>
                      <AppText variant="caption" style={{ color: tone.solid, fontWeight: '800' }}>{task.startTime || 'ANYTIME'} · {task.durationMinutes} MIN</AppText>
                      <AppText style={{ textDecorationLine: task.status === 'completed' ? 'line-through' : 'none' }}>{task.title}</AppText>
                    </Pressable>
                    <Pressable onPress={() => router.push({ pathname: '/task-editor', params: { id: task.id } })}>
                      <AppIcon name="ellipsis.circle" fallback="…" color={tone.solid} size={20} />
                    </Pressable>
                  </View>
                </View>
              );})}
              <Card muted style={{ marginLeft: 42 }}>
                <AppText variant="label">AI has the whole chain</AppText>
                <AppText variant="small" tone="secondary">It will reorder every item, estimate effort, add useful buffers and keep your main result first.</AppText>
                <AppButton title="Optimize this chain" loading={optimizingChain} onPress={optimizeChain} />
              </Card>
            </>
          )
        ) : (
          <Card>
            <AppText variant="heading">No plan yet</AppText>
            <AppText tone="secondary">Drop everything on your mind and let the planner turn it into a realistic day.</AppText>
            <AppButton title={t('buildDay')} onPress={() => router.push('/plan-builder')} />
            {data.plans.some((plan) => plan.date === yesterdayKey) ? (
              <AppButton
                title="Duplicate yesterday"
                variant="secondary"
                onPress={() => duplicateDay(yesterdayKey, dateKey())}
              />
            ) : null}
          </Card>
        )}
      </View>

      {adding ? (
        <Card>
          <AppInput value={newTask} onChangeText={setNewTask} placeholder="What needs doing?" autoFocus returnKeyType="done" onSubmitEditing={addTask} />
          <View style={{ flexDirection: 'row', gap: spacing.sm }}>
            <AppButton title="Cancel" variant="secondary" compact onPress={() => setAdding(false)} style={{ flex: 1 }} />
            <AppButton title="Add to today" compact onPress={addTask} style={{ flex: 2 }} />
          </View>
        </Card>
      ) : (
        <AppButton title={t('addTask')} variant="secondary" onPress={() => setAdding(true)} />
      )}

      <Pressable onPress={() => router.push('/horizon-planner')}>
        <Card muted style={{ flexDirection: 'row', alignItems: 'center' }}>
          <View style={{ flex: 1, gap: 3 }}>
            <AppText variant="label">Plan beyond today</AppText>
            <AppText variant="small" tone="secondary">AI roadmaps for a day, week, month or year—with each level tied back to real actions.</AppText>
          </View>
          <AppIcon name="chevron.right" fallback="›" color={colors.accent} size={18} />
        </Card>
      </Pressable>

      <Pressable onPress={() => router.push('/day-review')}>
        <Card muted style={{ flexDirection: 'row', alignItems: 'center' }}>
          <View style={{ flex: 1, gap: 3 }}>
            <AppText variant="label">Close the feedback loop</AppText>
            <AppText variant="small" tone="secondary">
              A 30-second review makes tomorrow’s plan smarter.
            </AppText>
          </View>
          <AppIcon name="chevron.right" fallback="›" color={colors.accent} size={18} />
        </Card>
      </Pressable>
    </ScrollView>
  );
}

function QuickAction({ title, detail, onPress }: { title: string; detail: string; onPress: () => void }) {
  const { colors } = useAppTheme();
  return (
    <Pressable
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => ({
        flex: 1,
        minHeight: 86,
        padding: spacing.sm,
        borderRadius: 18,
        borderCurve: 'continuous',
        borderWidth: 1,
        borderColor: colors.border,
        backgroundColor: colors.surface,
        alignItems: 'center',
        justifyContent: 'center',
        gap: spacing.xs,
        opacity: pressed ? 0.7 : 1,
      })}>
      <AppText variant="caption" style={{ textAlign: 'center', fontWeight: '800' }}>
        {title}
      </AppText>
      <AppText variant="caption" tone="tertiary" style={{ textAlign: 'center' }}>{detail}</AppText>
    </Pressable>
  );
}
