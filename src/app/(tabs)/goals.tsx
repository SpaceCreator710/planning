import { router } from 'expo-router';
import React, { useState } from 'react';
import { Pressable, ScrollView, View } from 'react-native';

import { AppButton } from '@/components/app/app-button';
import { AppIcon } from '@/components/app/app-icon';
import { AppInput } from '@/components/app/app-input';
import { AppText } from '@/components/app/app-text';
import { Card } from '@/components/app/card';
import { Chip } from '@/components/app/chip';
import { SectionHeader } from '@/components/app/section-header';
import { radii, spacing } from '@/constants/tokens';
import { useApp } from '@/context/app-context';
import { useAppTheme } from '@/context/theme-context';
import { dateKey } from '@/lib/date';
import type { TaskCategory } from '@/types/app';

export default function GoalsScreen() {
  const { colors } = useAppTheme();
  const { data, addGoal, updateGoalProgress, toggleMilestone, addHabit, toggleHabitToday, sendCoachMessage } = useApp();
  const [showGoalForm, setShowGoalForm] = useState(false);
  const [goalTitle, setGoalTitle] = useState('');
  const [goalWhy, setGoalWhy] = useState('');
  const [goalCategory, setGoalCategory] = useState<TaskCategory>('focus');
  const [habitTitle, setHabitTitle] = useState('');
  const [showHabitForm, setShowHabitForm] = useState(false);
  const today = dateKey();

  function createGoal() {
    if (!goalTitle.trim()) return;
    addGoal({ title: goalTitle.trim(), why: goalWhy.trim(), category: goalCategory });
    setGoalTitle('');
    setGoalWhy('');
    setShowGoalForm(false);
  }

  function createHabit() {
    if (!habitTitle.trim()) return;
    addHabit(habitTitle);
    setHabitTitle('');
    setShowHabitForm(false);
  }

  return (
    <ScrollView contentInsetAdjustmentBehavior="automatic" keyboardShouldPersistTaps="handled" contentContainerStyle={{ padding: spacing.md, paddingBottom: 120, gap: spacing.xl }}>
      <Card style={{ backgroundColor: colors.accentSoft, borderColor: colors.accent }}>
        <AppText variant="caption" tone="accent">
          GOAL → DAY CONNECTION
        </AppText>
        <AppText variant="heading">Every plan should move something that matters.</AppText>
        <AppText variant="small" tone="secondary">
          The coach prioritizes tasks connected to active goals and notices when a goal keeps getting avoided.
        </AppText>
      </Card>

      <View style={{ gap: spacing.md }}>
        <SectionHeader title="Active goals" detail={`${data.goals.filter((goal) => !goal.archived).length} active`} />
        {data.goals.filter((goal) => !goal.archived).map((goal) => (
          <Card key={goal.id} style={{ gap: spacing.md }}>
            <View style={{ flexDirection: 'row', alignItems: 'flex-start', gap: spacing.sm }}>
              <View
                style={{
                  width: 42,
                  height: 42,
                  borderRadius: 15,
                  backgroundColor: colors.infoSoft,
                  alignItems: 'center',
                  justifyContent: 'center',
                }}>
                <AppIcon name="target" fallback="◎" color={colors.info} size={21} />
              </View>
              <View style={{ flex: 1, gap: 3 }}>
                <AppText variant="heading">{goal.title}</AppText>
                {goal.why ? (
                  <AppText variant="small" tone="secondary">
                    {goal.why}
                  </AppText>
                ) : null}
              </View>
              <AppText variant="label" tone="accent" style={{ fontVariant: ['tabular-nums'] }}>
                {goal.progress}%
              </AppText>
            </View>
            <View style={{ height: 8, borderRadius: 999, backgroundColor: colors.surfaceMuted, overflow: 'hidden' }}>
              <View style={{ height: '100%', width: `${goal.progress}%`, backgroundColor: colors.accent, borderRadius: 999 }} />
            </View>
            <View style={{ flexDirection: 'row', gap: spacing.xs }}>
              <AppButton title="−5" compact variant="secondary" onPress={() => updateGoalProgress(goal.id, goal.progress - 5)} />
              <AppButton title="+5 progress" compact variant="secondary" onPress={() => updateGoalProgress(goal.id, goal.progress + 5)} />
              <AppButton
                title="AI next step"
                compact
                onPress={() => {
                  void sendCoachMessage(`Analyze my goal "${goal.title}" at ${goal.progress}% using my profile and recent behavior. Give me one concrete next action and explain why it is the right size now.`);
                  router.push('/(tabs)/coach');
                }}
                style={{ flex: 1 }}
              />
            </View>
            {goal.milestones.length ? (
              <View style={{ gap: spacing.xs, paddingTop: spacing.xs }}>
                {goal.milestones.map((milestone) => (
                  <Pressable
                    key={milestone.id}
                    onPress={() => toggleMilestone(goal.id, milestone.id)}
                    style={{ flexDirection: 'row', gap: spacing.sm, alignItems: 'center', paddingVertical: 3 }}>
                    <View
                      style={{
                        width: 22,
                        height: 22,
                        borderRadius: 11,
                        borderWidth: milestone.completed ? 0 : 1,
                        borderColor: colors.border,
                        backgroundColor: milestone.completed ? colors.success : colors.surfaceMuted,
                        alignItems: 'center',
                        justifyContent: 'center',
                      }}>
                      {milestone.completed ? <AppIcon name="checkmark" fallback="✓" color="#FFFFFF" size={12} /> : null}
                    </View>
                    <AppText variant="small" style={{ flex: 1, textDecorationLine: milestone.completed ? 'line-through' : 'none' }}>
                      {milestone.title}
                    </AppText>
                  </Pressable>
                ))}
              </View>
            ) : null}
          </Card>
        ))}

        {showGoalForm ? (
          <Card>
            <AppText variant="heading">New goal</AppText>
            <AppInput value={goalTitle} onChangeText={setGoalTitle} placeholder="What result are you building?" autoFocus />
            <AppInput value={goalWhy} onChangeText={setGoalWhy} placeholder="Why does it matter?" multiline />
            <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.xs }}>
              {(['focus', 'study', 'work', 'fitness', 'life'] as TaskCategory[]).map((category) => (
                <Chip key={category} label={category} selected={goalCategory === category} onPress={() => setGoalCategory(category)} />
              ))}
            </View>
            <View style={{ flexDirection: 'row', gap: spacing.sm }}>
              <AppButton title="Cancel" compact variant="secondary" onPress={() => setShowGoalForm(false)} style={{ flex: 1 }} />
              <AppButton title="Create goal" compact onPress={createGoal} style={{ flex: 2 }} />
            </View>
          </Card>
        ) : (
          <AppButton title="Add goal" variant="secondary" onPress={() => setShowGoalForm(true)} />
        )}
      </View>

      <View style={{ gap: spacing.md }}>
        <SectionHeader title="Habits" detail="Consistency without perfection" />
        <View style={{ gap: spacing.sm }}>
          {data.habits.map((habit) => {
            const complete = habit.completedDates.includes(today);
            return (
              <Pressable key={habit.id} onPress={() => toggleHabitToday(habit.id)}>
                <Card style={{ flexDirection: 'row', alignItems: 'center', boxShadow: 'none' }}>
                  <View
                    style={{
                      width: 44,
                      height: 44,
                      borderRadius: 16,
                      backgroundColor: complete ? colors.success : colors.surfaceMuted,
                      alignItems: 'center',
                      justifyContent: 'center',
                    }}>
                    <AppIcon
                      name={complete ? 'checkmark' : habit.icon.includes('.') ? habit.icon as Parameters<typeof AppIcon>[0]['name'] : 'checkmark.seal.fill'}
                      fallback={complete ? '✓' : '•'}
                      color={complete ? '#FFFFFF' : colors.text}
                      size={20}
                      animated={complete}
                    />
                  </View>
                  <View style={{ flex: 1, gap: 2 }}>
                    <AppText variant="label" style={{ textDecorationLine: complete ? 'line-through' : 'none' }}>
                      {habit.title}
                    </AppText>
                    <AppText variant="caption" tone="secondary">
                      {habit.currentStreak} day streak · best {habit.bestStreak}
                    </AppText>
                  </View>
                  <View style={{ paddingHorizontal: 9, paddingVertical: 5, borderRadius: radii.pill, backgroundColor: complete ? colors.successSoft : colors.surfaceMuted }}>
                    <AppText variant="caption" tone={complete ? 'success' : 'secondary'}>
                      {complete ? 'DONE' : 'TODAY'}
                    </AppText>
                  </View>
                </Card>
              </Pressable>
            );
          })}
        </View>
        {showHabitForm ? (
          <Card>
            <AppInput value={habitTitle} onChangeText={setHabitTitle} placeholder="A small repeatable action" autoFocus returnKeyType="done" onSubmitEditing={createHabit} />
            <View style={{ flexDirection: 'row', gap: spacing.sm }}>
              <AppButton title="Cancel" compact variant="secondary" onPress={() => setShowHabitForm(false)} style={{ flex: 1 }} />
              <AppButton title="Add habit" compact onPress={createHabit} style={{ flex: 2 }} />
            </View>
          </Card>
        ) : (
          <AppButton title="Add habit" variant="secondary" onPress={() => setShowHabitForm(true)} />
        )}
        {data.habits.length ? (
          <AppButton
            title="Let AI audit these habits"
            variant="secondary"
            onPress={() => {
              void sendCoachMessage('Audit my current habits against my main goal and actual completion behavior. Keep what works, identify friction, and suggest only one change.');
              router.push('/(tabs)/coach');
            }}
          />
        ) : null}
      </View>
    </ScrollView>
  );
}
