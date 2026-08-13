import { router } from 'expo-router';
import React, { useRef, useState } from 'react';
import { Alert, KeyboardAvoidingView, Pressable, ScrollView, View } from 'react-native';
import Animated, { FadeInDown, FadeOutUp, LinearTransition } from 'react-native-reanimated';

import { AppButton } from '@/components/app/app-button';
import { AppIcon } from '@/components/app/app-icon';
import { AppInput } from '@/components/app/app-input';
import { AppText } from '@/components/app/app-text';
import { BrandMark } from '@/components/app/brand-mark';
import { Card } from '@/components/app/card';
import { Chip } from '@/components/app/chip';
import { canUseCoachMode } from '@/constants/subscriptions';
import { radii, spacing } from '@/constants/tokens';
import { useApp } from '@/context/app-context';
import { useAppTheme } from '@/context/theme-context';
import type { ProfileAnalysis } from '@/services/ai-client';
import type { AccountabilityLevel, CoachMode, DayPlan, UserProfile } from '@/types/app';

const categories: { id: UserProfile['category']; title: string; symbol: string; description: string }[] = [
  { id: 'study', title: 'Study', symbol: 'S', description: 'Focus, exams and learning' },
  { id: 'career', title: 'Career', symbol: 'C', description: 'Projects and professional growth' },
  { id: 'fitness', title: 'Fitness', symbol: 'F', description: 'Movement, training and health' },
  { id: 'money', title: 'Money', symbol: 'M', description: 'Income and financial action' },
  { id: 'custom', title: 'My own path', symbol: 'P', description: 'Build around anything important' },
];

const blockerOptions = ['I wait for motivation', 'My phone distracts me', 'Tasks feel too big', 'I run out of energy', 'I over-plan', 'I fear doing it badly'];

export default function OnboardingScreen() {
  const { colors } = useAppTheme();
  const { data, completeOnboarding, hasRecoveryBackup, restoreLastReset } = useApp();
  const [step, setStep] = useState(0);
  const [analyzing, setAnalyzing] = useState(false);
  const [name, setName] = useState(data.profile.name);
  const [category, setCategory] = useState<UserProfile['category']>(data.profile.category || 'custom');
  const [goal, setGoal] = useState(data.profile.primaryGoal);
  const [goalWhy, setGoalWhy] = useState(data.profile.goalWhy);
  const [wakeTime, setWakeTime] = useState(data.profile.wakeTime);
  const [sleepTime, setSleepTime] = useState(data.profile.sleepTime);
  const [chronotype, setChronotype] = useState<UserProfile['chronotype']>(data.profile.chronotype);
  const [fixedCommitments, setFixedCommitments] = useState(data.profile.fixedCommitments);
  const [currentHabits, setCurrentHabits] = useState(data.profile.currentHabits);
  const [productiveHours, setProductiveHours] = useState(data.profile.productiveHours);
  const [planningPreferences, setPlanningPreferences] = useState(data.profile.planningPreferences);
  const [discipline, setDiscipline] = useState<UserProfile['discipline']>(data.profile.discipline);
  const [excuses, setExcuses] = useState<string[]>(data.profile.excuses);
  const [struggle, setStruggle] = useState(data.profile.struggle);
  const [selfDescription, setSelfDescription] = useState(data.profile.selfDescription);
  const [coachMode, setCoachMode] = useState<CoachMode>(data.settings.coachMode);
  const [accountability, setAccountability] = useState<AccountabilityLevel>(data.settings.accountability);
  const [blueprint, setBlueprint] = useState<{ analysis: ProfileAnalysis; starterPlan?: DayPlan; fallback: boolean }>();
  const scroll = useRef<ScrollView>(null);

  const steps = 10;
  const progress = ((step + 1) / steps) * 100;

  function validate(target = step) {
    if (target === 2 && (!/^([01]\d|2[0-3]):[0-5]\d$/.test(wakeTime) || !/^([01]\d|2[0-3]):[0-5]\d$/.test(sleepTime))) {
      Alert.alert('Check the time', 'Use 24-hour time, for example 08:00 and 23:00. You can also skip this page.');
      return false;
    }
    return true;
  }

  function move(nextStep: number) {
    setStep(nextStep);
    requestAnimationFrame(() => scroll.current?.scrollTo({ y: 0, animated: true }));
  }

  async function finish() {
    setAnalyzing(true);
    const result = await completeOnboarding({
      name: name.trim(),
      category,
      primaryGoal: goal.trim(),
      goalWhy: goalWhy.trim(),
      wakeTime: /^([01]\d|2[0-3]):[0-5]\d$/.test(wakeTime) ? wakeTime : data.profile.wakeTime,
      sleepTime: /^([01]\d|2[0-3]):[0-5]\d$/.test(sleepTime) ? sleepTime : data.profile.sleepTime,
      chronotype,
      fixedCommitments: fixedCommitments.trim(),
      currentHabits: currentHabits.trim(),
      productiveHours: productiveHours.trim(),
      planningPreferences: planningPreferences.trim(),
      discipline,
      excuses,
      struggle: struggle.trim(),
      selfDescription: selfDescription.trim(),
    }, { coachMode, accountability });
    setAnalyzing(false);
    if (!result.ok || !result.value) {
      Alert.alert('Could not save the profile', 'Please try again. Your answers are still on this screen.');
      return;
    }
    setBlueprint({ ...result.value, fallback: Boolean(result.fallback) });
  }

  async function next() {
    if (!validate()) return;
    if (step < steps - 1) {
      move(step + 1);
      return;
    }
    await finish();
  }

  async function skip() {
    if (step < steps - 1) {
      move(step + 1);
      return;
    }
    await finish();
  }

  if (blueprint) {
    const nextActions = blueprint.starterPlan?.tasks.filter((task) => task.status !== 'completed').slice(0, 4) ?? [];
    return (
      <ScrollView
        contentInsetAdjustmentBehavior="automatic"
        contentContainerStyle={{ flexGrow: 1, padding: spacing.xl, paddingBottom: 80, gap: spacing.xl, backgroundColor: colors.background }}>
        <View style={{ width: '100%', maxWidth: 620, alignSelf: 'center', gap: spacing.xl }}>
          <View style={{ alignItems: 'center', gap: spacing.sm, paddingTop: spacing.xl }}>
            <BrandMark size={64} />
            <AppText variant="title" style={{ textAlign: 'center' }}>Your personal operating blueprint</AppText>
            <AppText tone="secondary" style={{ textAlign: 'center' }}>
              The AI analyzed your goal, schedule, habits, blockers and full description together.
            </AppText>
          </View>

          {blueprint.fallback ? (
            <Card style={{ backgroundColor: colors.warningSoft, borderColor: colors.warning }}>
              <AppText variant="label" tone="warning">Temporary local analysis</AppText>
              <AppText variant="small" tone="secondary">Your profile is saved. The app will use the protected AI automatically as soon as the server connection is available.</AppText>
            </Card>
          ) : null}

          <Card style={{ backgroundColor: colors.infoSoft, borderColor: colors.info }}>
            <AppText variant="caption" style={{ color: colors.info }}>AI PROFILE</AppText>
            <AppText variant="heading">{blueprint.analysis.summary}</AppText>
          </Card>

          <Card>
            <AppText variant="caption" tone="accent">PLANNING RULES</AppText>
            {blueprint.analysis.planningRules.map((rule, index) => (
              <View key={`${rule}-${index}`} style={{ flexDirection: 'row', gap: spacing.sm }}>
                <AppText tone="accent">{index + 1}</AppText>
                <AppText variant="small" style={{ flex: 1 }}>{rule}</AppText>
              </View>
            ))}
          </Card>

          <Card muted>
            <AppText variant="caption" tone="warning">FRICTION TO WATCH</AppText>
            {blueprint.analysis.risks.map((risk) => (
              <AppText key={risk} variant="small" tone="secondary">— {risk}</AppText>
            ))}
            {blueprint.analysis.suggestedHabits.length ? (
              <>
                <AppText variant="caption" tone="success" style={{ marginTop: spacing.xs }}>SUGGESTED HABITS</AppText>
                {blueprint.analysis.suggestedHabits.map((habit) => (
                  <AppText key={habit} variant="small" tone="secondary">— {habit}</AppText>
                ))}
              </>
            ) : null}
          </Card>

          {blueprint.starterPlan ? (
            <Card style={{ borderColor: colors.accent }}>
              <AppText variant="caption" tone="accent">FIRST DAY CREATED AUTOMATICALLY</AppText>
              <AppText variant="heading">{blueprint.starterPlan.title}</AppText>
              <AppText variant="small" tone="secondary">No task is marked complete. Progress begins only when you finish a real action.</AppText>
              {nextActions.map((task) => (
                <View key={task.id} style={{ flexDirection: 'row', gap: spacing.sm }}>
                  <AppText variant="caption" tone="secondary" style={{ width: 44 }}>{task.startTime ?? 'Any'}</AppText>
                  <AppText variant="small" style={{ flex: 1 }}>{task.title}</AppText>
                </View>
              ))}
            </Card>
          ) : null}

          <AppButton title={blueprint.starterPlan ? 'Open my first day' : 'Save and return'} onPress={() => router.replace('/(tabs)/today')} />
        </View>
      </ScrollView>
    );
  }

  return (
    <KeyboardAvoidingView style={{ flex: 1 }} behavior={process.env.EXPO_OS === 'ios' ? 'padding' : undefined}>
      <ScrollView
        ref={scroll}
        contentInsetAdjustmentBehavior="automatic"
        keyboardShouldPersistTaps="handled"
        contentContainerStyle={{ flexGrow: 1, padding: spacing.xl, gap: spacing.xl, backgroundColor: colors.background }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.md, paddingTop: spacing.md }}>
          <BrandMark size={42} />
          <View style={{ flex: 1, height: 7, borderRadius: 999, backgroundColor: colors.surfaceMuted, overflow: 'hidden' }}>
            <Animated.View layout={LinearTransition.duration(220)} style={{ width: `${progress}%`, height: '100%', backgroundColor: colors.accent, borderRadius: 999 }} />
          </View>
          <AppText variant="caption" tone="secondary" style={{ fontVariant: ['tabular-nums'] }}>
            {step + 1}/{steps}
          </AppText>
          <Pressable disabled={analyzing} accessibilityRole="button" onPress={() => void skip()}>
            <AppText variant="caption" tone="accent">Skip</AppText>
          </Pressable>
        </View>

        {hasRecoveryBackup ? (
          <Pressable
            onPress={async () => {
              const restored = await restoreLastReset();
              if (restored) router.replace('/(tabs)/today');
              else Alert.alert('Could not restore', 'The seven-day recovery window may have expired.');
            }}
            style={{ width: '100%', maxWidth: 620, alignSelf: 'center' }}>
            <Card style={{ flexDirection: 'row', alignItems: 'center', padding: spacing.sm, borderColor: colors.success, backgroundColor: colors.successSoft }}>
              <View style={{ flex: 1 }}>
                <AppText variant="label" tone="success">Restore the account you just reset</AppText>
                <AppText variant="caption" tone="secondary">Your recovery snapshot is available for seven days.</AppText>
              </View>
              <AppText tone="success">Restore</AppText>
            </Card>
          </Pressable>
        ) : null}

        <Animated.View
          key={step}
          entering={FadeInDown.duration(260)}
          exiting={FadeOutUp.duration(120)}
          style={{ flex: 1, width: '100%', maxWidth: 620, alignSelf: 'center', gap: spacing.xl }}>
          {step === 0 ? (
            <>
              <Heading title="A planner that learns you" detail="Answer what helps. Every one of the ten pages can be skipped." />
              <View style={{ gap: spacing.md }}>
                <Field label="What should we call you?">
                  <AppInput value={name} onChangeText={setName} placeholder="Your name" autoCapitalize="words" />
                </Field>
                <View style={{ gap: spacing.sm }}>
                  {categories.map((item) => {
                    const selected = category === item.id;
                    return (
                      <Pressable key={item.id} onPress={() => setCategory(item.id)}>
                        <Card style={{ flexDirection: 'row', alignItems: 'center', borderColor: selected ? colors.accent : colors.border, backgroundColor: selected ? colors.accentSoft : colors.surface }}>
                          <View style={{ width: 42, height: 42, borderRadius: 14, alignItems: 'center', justifyContent: 'center', backgroundColor: selected ? colors.accent : colors.surfaceMuted }}>
                            <AppText style={{ color: selected ? '#FFFFFF' : colors.text, fontWeight: '900' }}>{item.symbol}</AppText>
                          </View>
                          <View style={{ flex: 1 }}>
                            <AppText variant="label">{item.title}</AppText>
                            <AppText variant="small" tone="secondary">{item.description}</AppText>
                          </View>
                          <AppIcon name={selected ? 'checkmark.circle.fill' : 'circle'} fallback={selected ? '✓' : '○'} color={selected ? colors.accent : colors.textTertiary} size={20} />
                        </Card>
                      </Pressable>
                    );
                  })}
                </View>
              </View>
            </>
          ) : null}

          {step === 1 ? (
            <>
              <Heading title="What matters now?" detail="A direction helps the AI protect the right work when your day changes." />
              <Field label="Your most important result">
                <AppInput value={goal} onChangeText={setGoal} placeholder="Example: pass the exam without last-minute panic" multiline />
              </Field>
              <Field label="Why does it matter to you?">
                <AppInput value={goalWhy} onChangeText={setGoalWhy} placeholder="The real reason, not the impressive answer" multiline />
              </Field>
            </>
          ) : null}

          {step === 2 ? (
            <>
              <Heading title="Your natural rhythm" detail="The schedule should fit your sleep and energy instead of fighting them." />
              <View style={{ flexDirection: 'row', gap: spacing.sm }}>
                <Field label="Wake" style={{ flex: 1 }}>
                  <AppInput value={wakeTime} onChangeText={setWakeTime} placeholder="08:00" keyboardType="numbers-and-punctuation" />
                </Field>
                <Field label="Sleep" style={{ flex: 1 }}>
                  <AppInput value={sleepTime} onChangeText={setSleepTime} placeholder="23:00" keyboardType="numbers-and-punctuation" />
                </Field>
              </View>
              <View style={{ gap: spacing.sm }}>
                <AppText variant="label">When do you usually work best?</AppText>
                <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.xs }}>
                  {([
                    ['early-bird', 'Morning'],
                    ['balanced', 'It varies'],
                    ['night-owl', 'Evening'],
                  ] as const).map(([id, label]) => (
                    <Chip key={id} label={label} selected={chronotype === id} onPress={() => setChronotype(id)} />
                  ))}
                </View>
              </View>
            </>
          ) : null}

          {step === 3 ? (
            <>
              <Heading title="Immovable commitments" detail="The AI must plan around reality, not through school, work or family time." />
              <Field label="Fixed commitments">
                <AppInput value={fixedCommitments} onChangeText={setFixedCommitments} placeholder="School 09:00–15:00, football Tue/Thu 18:00, family dinner…" multiline style={{ minHeight: 150 }} />
              </Field>
            </>
          ) : null}

          {step === 4 ? (
            <>
              <Heading title="What already repeats?" detail="Existing routines are stronger anchors than ideal routines invented today." />
              <Field label="Current habits and routines">
                <AppInput value={currentHabits} onChangeText={setCurrentHabits} placeholder="What you already do in the morning, after school/work and before sleep" multiline />
              </Field>
            </>
          ) : null}

          {step === 5 ? (
            <>
              <Heading title="Your energy map" detail="Tell the planner where hard work fits and where recovery belongs." />
              <Field label="When is your energy usually best?">
                <AppInput value={productiveHours} onChangeText={setProductiveHours} placeholder="Example: 10:00–13:00, weak after lunch" />
              </Field>
            </>
          ) : null}

          {step === 7 ? (
            <>
              <Heading title="How should a plan feel?" detail="Choose flexibility, strict timing, block length and breaks in your own words." />
              <Field label="How do you prefer to plan?">
                <AppInput value={planningPreferences} onChangeText={setPlanningPreferences} placeholder="Short blocks, a strict timeline, flexible order, more breaks…" multiline />
              </Field>
            </>
          ) : null}

          {step === 6 ? (
            <>
              <Heading title="Where plans break" detail="Honest friction gives the AI something useful to adapt to." />
              <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.xs }}>
                {blockerOptions.map((option) => (
                  <Chip key={option} label={option} selected={excuses.includes(option)} onPress={() => setExcuses((current) => current.includes(option) ? current.filter((item) => item !== option) : [...current, option])} />
                ))}
              </View>
              <Field label="Describe the main pattern">
                <AppInput value={struggle} onChangeText={setStruggle} placeholder="What happens just before you postpone or abandon a task?" multiline />
              </Field>
              <View style={{ gap: spacing.sm }}>
                <AppText variant="label">Current discipline</AppText>
                <View style={{ flexDirection: 'row', gap: spacing.xs }}>
                  {([1, 2, 3, 4, 5] as const).map((value) => (
                    <Pressable key={value} onPress={() => setDiscipline(value)} style={{ flex: 1, aspectRatio: 1, maxHeight: 58, borderRadius: radii.md, backgroundColor: discipline === value ? colors.accent : colors.surface, borderWidth: 1, borderColor: discipline === value ? colors.accent : colors.border, alignItems: 'center', justifyContent: 'center' }}>
                      <AppText style={{ color: discipline === value ? '#FFFFFF' : colors.text, fontWeight: '800' }}>{value}</AppText>
                    </Pressable>
                  ))}
                </View>
              </View>
            </>
          ) : null}

          {step === 8 ? (
            <>
              <Heading title="Describe yourself" detail="Write freely. The AI will analyze this together with your schedule, habits, goal and blockers." />
              <AppInput
                value={selfDescription}
                onChangeText={setSelfDescription}
                placeholder="Describe your normal week, responsibilities, personality, what motivates you, what drains you, what you keep postponing, and anything the coach should never forget…"
                multiline
                autoFocus
                maxLength={4000}
                style={{ minHeight: 230, textAlignVertical: 'top' }}
              />
              <Card muted>
                <AppText variant="small" tone="secondary">This becomes your editable personal operating profile. The coach uses it in planning, replanning, goals, habits, reviews and chat.</AppText>
              </Card>
            </>
          ) : null}

          {step === 9 ? (
            <>
              <Heading title="Choose your coach" detail="The three modes now have deliberately different behavior." />
              <View style={{ gap: spacing.sm }}>
                {([
                  ['soft', 'Soft', 'A warm friend: gentle, reassuring and action-oriented', 'Free'],
                  ['strict', 'Strict', 'A firm coach: direct, disciplined and measurable', 'Plus'],
                  ['aggressive', 'Aggressive', 'Controlled confrontation: provocative, intense, never insulting', 'Pro'],
                ] as const).map(([id, title, description, tier]) => {
                  const locked = !canUseCoachMode(data.subscription, id);
                  const selected = coachMode === id;
                  return (
                    <Pressable key={id} onPress={() => locked ? router.push('/paywall') : setCoachMode(id)}>
                      <Card style={{ borderColor: selected ? colors.accent : colors.border, backgroundColor: selected ? colors.accentSoft : colors.surface, opacity: locked ? 0.72 : 1 }}>
                        <View style={{ flexDirection: 'row', justifyContent: 'space-between', gap: spacing.sm }}>
                          <View style={{ flex: 1, gap: 3 }}>
                            <AppText variant="label">{title}</AppText>
                            <AppText variant="small" tone="secondary">{description}</AppText>
                          </View>
                          <Chip label={locked ? `${tier} · locked` : tier} selected={selected} />
                        </View>
                      </Card>
                    </Pressable>
                  );
                })}
              </View>
              <View style={{ gap: spacing.sm }}>
                <AppText variant="label">Accountability check-ins</AppText>
                <View style={{ flexDirection: 'row', gap: spacing.xs }}>
                  {(['light', 'balanced', 'high'] as const).map((level) => (
                    <Chip key={level} label={level[0].toUpperCase() + level.slice(1)} selected={accountability === level} onPress={() => setAccountability(level)} style={{ flex: 1 }} />
                  ))}
                </View>
              </View>
            </>
          ) : null}
        </Animated.View>

        <View style={{ flexDirection: 'row', gap: spacing.sm, width: '100%', maxWidth: 620, alignSelf: 'center' }}>
          {step > 0 ? <AppButton title="Back" variant="secondary" disabled={analyzing} onPress={() => move(step - 1)} style={{ flex: 1 }} /> : null}
          <AppButton title={step === steps - 1 ? 'Analyze and start' : 'Continue'} loading={analyzing} onPress={() => void next()} style={{ flex: 2 }} />
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

function Heading({ title, detail }: { title: string; detail: string }) {
  return (
    <View style={{ gap: spacing.xs }}>
      <AppText variant="title">{title}</AppText>
      <AppText tone="secondary">{detail}</AppText>
    </View>
  );
}

function Field({ label, children, style }: React.PropsWithChildren<{ label: string; style?: object }>) {
  return (
    <View style={[{ gap: spacing.xs }, style]}>
      <AppText variant="label">{label}</AppText>
      {children}
    </View>
  );
}
