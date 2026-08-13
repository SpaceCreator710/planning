import { router, useLocalSearchParams } from 'expo-router';
import React, { useState } from 'react';
import { Alert, Pressable, ScrollView, View } from 'react-native';

import { AppButton } from '@/components/app/app-button';
import { AppIcon } from '@/components/app/app-icon';
import { AppInput } from '@/components/app/app-input';
import { AppText } from '@/components/app/app-text';
import { Card } from '@/components/app/card';
import { Chip } from '@/components/app/chip';
import { canUseDeviceIntegration } from '@/constants/subscriptions';
import { spacing, taskPalettes } from '@/constants/tokens';
import { useApp } from '@/context/app-context';
import { useAppTheme } from '@/context/theme-context';
import { minutesToTime, timeToMinutes } from '@/lib/date';
import type { TaskCategory, TaskColor, TaskRecurrence, TaskSubtask } from '@/types/app';

const taskColors: TaskColor[] = ['red', 'orange', 'yellow', 'green', 'teal', 'blue', 'indigo', 'violet', 'pink', 'gray'];
const taskIcons: Parameters<typeof AppIcon>[0]['name'][] = ['scope', 'briefcase.fill', 'book.closed.fill', 'figure.run', 'house.fill', 'moon.zzz.fill', 'heart.fill', 'star.fill', 'checkmark.seal.fill', 'calendar'];

export default function TaskEditorScreen() {
  const { colors } = useAppTheme();
  const { id } = useLocalSearchParams<{ id: string }>();
  const { data, editTask, deleteTask, duplicateTask, moveTask, sendCoachMessage } = useApp();
  const task = data.plans.flatMap((plan) => plan.tasks).find((item) => item.id === id);
  const [title, setTitle] = useState(task?.title ?? '');
  const [note, setNote] = useState(task?.note ?? '');
  const [startTime, setStartTime] = useState(task?.startTime ?? '');
  const [duration, setDuration] = useState(String(task?.durationMinutes ?? 25));
  const [category, setCategory] = useState<TaskCategory>(task?.category ?? 'work');
  const [mustWin, setMustWin] = useState(Boolean(task?.mustWin));
  const [recurrence, setRecurrence] = useState<TaskRecurrence>(task?.recurrence ?? 'none');
  const [color, setColor] = useState<TaskColor | undefined>(task?.color);
  const [icon, setIcon] = useState(task?.icon ?? '');
  const [allDay, setAllDay] = useState(Boolean(task?.allDay));
  const [reminderMinutesBefore, setReminderMinutesBefore] = useState(task?.reminderMinutesBefore ?? 0);
  const [subtasks, setSubtasks] = useState<TaskSubtask[]>(task?.subtasks ?? []);
  const [subtaskTitle, setSubtaskTitle] = useState('');

  if (!task) {
    return (
      <View style={{ flex: 1, justifyContent: 'center', padding: spacing.xl, gap: spacing.md }}>
        <AppText variant="title" style={{ textAlign: 'center' }}>Task not found</AppText>
        <AppButton title="Back to today" onPress={() => router.replace('/(tabs)/today')} />
      </View>
    );
  }
  const currentTask = task;

  function addSubtask() {
    if (!subtaskTitle.trim()) return;
    setSubtasks((current) => [...current, { id: `subtask-${Date.now()}`, title: subtaskTitle.trim(), completed: false }]);
    setSubtaskTitle('');
  }

  function save() {
    const minutes = Math.max(5, Math.min(480, Number(duration) || 25));
    if (!title.trim()) {
      Alert.alert('Task needs a title');
      return;
    }
    if (startTime && !/^([01]\d|2[0-3]):[0-5]\d$/.test(startTime)) {
      Alert.alert('Check the time', 'Use 24-hour time, for example 14:30, or leave it empty for an anytime task.');
      return;
    }
    const startMinute = !allDay && startTime ? timeToMinutes(startTime) : undefined;
    editTask(currentTask.id, {
      title: title.trim(),
      note: note.trim() || undefined,
      startTime: startTime || undefined,
      endTime: startMinute === undefined ? undefined : minutesToTime(startMinute + minutes),
      durationMinutes: minutes,
      section: startMinute === undefined ? currentTask.section : startMinute < 720 ? 'morning' : startMinute < 1020 ? 'day' : startMinute < 1320 ? 'evening' : 'night',
      category,
      mustWin,
      recurrence,
      color,
      icon: icon || undefined,
      allDay,
      reminderMinutesBefore,
      subtasks,
    });
    router.dismiss();
  }

  function confirmDelete() {
    Alert.alert('Delete this task?', 'This removes it from the current plan. The action is retained only as a behavior signal.', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Delete', style: 'destructive', onPress: () => { deleteTask(currentTask.id); router.dismiss(); } },
    ]);
  }

  return (
    <ScrollView contentInsetAdjustmentBehavior="automatic" keyboardShouldPersistTaps="handled" contentContainerStyle={{ padding: spacing.lg, paddingBottom: 90, gap: spacing.xl }}>
      <View style={{ gap: spacing.xs }}>
        <AppText variant="title">Edit the action</AppText>
        <AppText tone="secondary">Manual control stays available. Every edit becomes context for the next AI plan.</AppText>
      </View>
      <View style={{ gap: spacing.xs }}>
        <AppText variant="label">Title</AppText>
        <AppInput value={title} onChangeText={setTitle} placeholder="Task title" autoFocus />
      </View>
      <View style={{ gap: spacing.xs }}>
        <AppText variant="label">Notes</AppText>
        <AppInput value={note} onChangeText={setNote} placeholder="Context, link or definition of done" multiline />
      </View>
      <View style={{ flexDirection: 'row', gap: spacing.sm }}>
        <View style={{ flex: 1, gap: spacing.xs }}>
          <AppText variant="label">Start time</AppText>
          <AppInput value={startTime} onChangeText={setStartTime} placeholder="Anytime" keyboardType="numbers-and-punctuation" />
        </View>
        <View style={{ flex: 1, gap: spacing.xs }}>
          <AppText variant="label">Minutes</AppText>
          <AppInput value={duration} onChangeText={setDuration} placeholder="25" keyboardType="number-pad" />
        </View>
      </View>
      <Card muted style={{ flexDirection: 'row', alignItems: 'center' }}>
        <View style={{ flex: 1 }}>
          <AppText variant="label">All-day task</AppText>
          <AppText variant="caption" tone="secondary">Keep it above the timed flow without forcing a fake hour.</AppText>
        </View>
        <Chip label={allDay ? 'All day' : 'Timed'} selected={allDay} onPress={() => setAllDay((value) => !value)} />
      </Card>
      <View style={{ gap: spacing.sm }}>
        <AppText variant="label">Category</AppText>
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.xs }}>
          {(['focus', 'work', 'study', 'fitness', 'life', 'rest'] as TaskCategory[]).map((item) => <Chip key={item} label={item} selected={category === item} onPress={() => setCategory(item)} />)}
        </View>
      </View>
      <View style={{ gap: spacing.sm }}>
        <AppText variant="label">Color</AppText>
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.xs }}>
          {taskColors.map((item) => <Chip key={item} label={item} color={taskPalettes[item].solid} selected={color === item} onPress={() => setColor(item)} />)}
        </View>
        <AppText variant="caption" tone="tertiary">Every palette is free.</AppText>
      </View>
      <View style={{ gap: spacing.sm }}>
        <AppText variant="label">Icon</AppText>
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.xs }}>
          {taskIcons.map((item) => {
            const selected = icon === item;
            return (
              <Pressable
                key={item}
                accessibilityRole="button"
                accessibilityState={{ selected }}
                onPress={() => setIcon(item)}
                style={({ pressed }) => ({ width: 46, height: 46, borderRadius: 17, borderCurve: 'continuous', alignItems: 'center', justifyContent: 'center', borderWidth: selected ? 2 : 1, borderColor: selected ? colors.accent : colors.border, backgroundColor: selected ? colors.accentSoft : colors.surface, opacity: pressed ? 0.7 : 1 })}>
                <AppIcon name={item} fallback="•" color={selected ? colors.accent : colors.textSecondary} size={21} animated={selected} />
              </Pressable>
            );
          })}
        </View>
      </View>
      <View style={{ gap: spacing.sm }}>
        <AppText variant="label">Repeat</AppText>
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.xs }}>
          {(['none', 'daily', 'weekdays', 'weekly', 'biweekly', 'monthly'] as TaskRecurrence[]).map((item) => (
            <Chip
              key={item}
              label={item}
              selected={recurrence === item}
              onPress={() => {
                if (item !== 'none' && !canUseDeviceIntegration(data.subscription)) router.push('/paywall');
                else setRecurrence(item);
              }}
            />
          ))}
        </View>
        <AppText variant="caption" tone="tertiary">Single tasks stay free. Plus adds recurring routines; new occurrences always start with honest zero progress.</AppText>
      </View>
      <View style={{ gap: spacing.sm }}>
        <AppText variant="label">Custom reminder</AppText>
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.xs }}>
          {([0, 5, 10, 15, 30] as const).map((minutes) => (
            <Chip key={minutes} label={minutes === 0 ? 'At start' : `${minutes} min before`} selected={reminderMinutesBefore === minutes} onPress={() => setReminderMinutesBefore(minutes)} />
          ))}
        </View>
      </View>
      <View style={{ gap: spacing.sm }}>
        <AppText variant="label">Subtasks</AppText>
        {subtasks.map((subtask) => (
          <View key={subtask.id} style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.sm }}>
            <Chip
              label={subtask.completed ? 'Done' : 'Open'}
              selected={subtask.completed}
              onPress={() => setSubtasks((current) => current.map((item) => item.id === subtask.id ? { ...item, completed: !item.completed } : item))}
            />
            <AppText variant="small" style={{ flex: 1, textDecorationLine: subtask.completed ? 'line-through' : 'none' }}>{subtask.title}</AppText>
            <AppButton title="Remove" compact variant="ghost" onPress={() => setSubtasks((current) => current.filter((item) => item.id !== subtask.id))} />
          </View>
        ))}
        <View style={{ flexDirection: 'row', gap: spacing.sm }}>
          <AppInput value={subtaskTitle} onChangeText={setSubtaskTitle} placeholder="Small step" returnKeyType="done" onSubmitEditing={addSubtask} style={{ flex: 1 }} />
          <AppButton title="Add" compact variant="secondary" disabled={!subtaskTitle.trim()} onPress={addSubtask} />
        </View>
      </View>
      <Card muted style={{ flexDirection: 'row', alignItems: 'center' }}>
        <View style={{ flex: 1 }}>
          <AppText variant="label">Must-win task</AppText>
          <AppText variant="caption" tone="secondary">Protect this result when the day needs to be repaired.</AppText>
        </View>
        <Chip label={mustWin ? 'Protected' : 'Optional'} selected={mustWin} onPress={() => setMustWin((value) => !value)} />
      </Card>
      <AppButton title="Save task" onPress={save} />
      <AppButton
        title="Duplicate task"
        variant="secondary"
        onPress={() => {
          duplicateTask(currentTask.id);
          Alert.alert('Task duplicated', 'A new pending copy was added to this day.');
        }}
      />
      <View style={{ flexDirection: 'row', gap: spacing.sm }}>
        <AppButton title="Move earlier" variant="secondary" onPress={() => moveTask(currentTask.id, -1)} style={{ flex: 1 }} />
        <AppButton title="Move later" variant="secondary" onPress={() => moveTask(currentTask.id, 1)} style={{ flex: 1 }} />
      </View>
      <AppButton
        title="Ask AI to improve this task"
        variant="secondary"
        onPress={() => {
          void sendCoachMessage(`Review this task in my current plan: "${title}" (${duration} minutes). Definition or note: "${note || 'none'}". Suggest a clearer definition of done and the smallest first physical step.`);
          router.push('/(tabs)/coach');
        }}
      />
      <AppButton title="Delete task" variant="danger" onPress={confirmDelete} />
    </ScrollView>
  );
}
