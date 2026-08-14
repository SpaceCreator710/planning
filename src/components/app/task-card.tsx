/* eslint-disable react-hooks/immutability -- Reanimated shared values are intentionally mutated inside UI-thread gesture worklets. */
import * as Haptics from 'expo-haptics';
import React, { useMemo } from 'react';
import { Pressable, View } from 'react-native';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import Animated, { FadeInDown, LinearTransition, runOnJS, useAnimatedStyle, useSharedValue, withSpring } from 'react-native-reanimated';

import { AppIcon } from '@/components/app/app-icon';
import { AppText } from '@/components/app/app-text';
import { categoryTaskColor, radii, spacing, taskPalettes } from '@/constants/tokens';
import { useAppTheme } from '@/context/theme-context';
import { suggestTaskAppearance } from '@/services/task-appearance';
import type { Task } from '@/types/app';

const categoryIcon: Record<Task['category'], Parameters<typeof AppIcon>[0]['name']> = {
  focus: 'scope',
  work: 'briefcase.fill',
  study: 'book.closed.fill',
  fitness: 'figure.run',
  life: 'house.fill',
  rest: 'moon.zzz.fill',
};

export function TaskCard({
  task,
  onToggle,
  onStart,
  onSkip,
  onEdit,
  onMove,
}: {
  task: Task;
  onToggle: () => void;
  onStart: () => void;
  onSkip: () => void;
  onEdit: () => void;
  onMove?: (direction: -1 | 1) => void;
}) {
  const { colors } = useAppTheme();
  const completed = task.status === 'completed';
  const skipped = task.status === 'skipped';
  const active = task.status === 'active';
  const subtaskCount = task.subtasks?.length ?? 0;
  const completedSubtasks = task.subtasks?.filter((subtask) => subtask.completed).length ?? 0;
  const automaticAppearance = suggestTaskAppearance(task.title, task.category);
  const taskColor = task.color ?? automaticAppearance.color ?? categoryTaskColor[task.category];
  const tone = taskPalettes[taskColor];
  const symbol = (task.icon || automaticAppearance.icon || categoryIcon[task.category]) as Parameters<typeof AppIcon>[0]['name'];
  const translateY = useSharedValue(0);
  const dragging = useSharedValue(false);
  const drag = useMemo(() => Gesture.Pan()
    .enabled(Boolean(onMove))
    .activateAfterLongPress(240)
    .onStart(() => {
      dragging.value = true;
    })
    .onUpdate((event) => {
      translateY.value = event.translationY;
    })
    .onEnd((event) => {
      if (onMove && Math.abs(event.translationY) > 42) runOnJS(onMove)(event.translationY < 0 ? -1 : 1);
      translateY.value = withSpring(0, { damping: 20, stiffness: 220 });
      dragging.value = false;
    })
    .onFinalize(() => {
      translateY.value = withSpring(0, { damping: 20, stiffness: 220 });
      dragging.value = false;
    }), [dragging, onMove, translateY]);
  const dragStyle = useAnimatedStyle(() => ({ transform: [{ translateY: translateY.value }, { scale: dragging.value ? 1.018 : 1 }], zIndex: dragging.value ? 20 : 1 }));
  return (
    <GestureDetector gesture={drag}>
      <Animated.View
        entering={FadeInDown.duration(260)}
        layout={LinearTransition.springify().damping(20).stiffness(180)}
        style={[{ flexDirection: 'row', gap: spacing.sm, opacity: skipped ? 0.56 : 1 }, dragStyle]}>
      <View style={{ width: 48, paddingTop: spacing.sm, alignItems: 'flex-end' }}>
        <AppText variant="caption" tone="secondary" style={{ fontVariant: ['tabular-nums'] }}>
          {task.allDay ? 'All day' : task.startTime ?? 'Any'}
        </AppText>
      </View>

      <View style={{ width: 34, alignItems: 'center', position: 'relative' }}>
        <View style={{ position: 'absolute', top: -spacing.sm, bottom: -spacing.sm, width: 2, borderRadius: 2, backgroundColor: colors.border }} />
        <View style={{ width: 32, height: 32, marginTop: 7, borderRadius: 16, alignItems: 'center', justifyContent: 'center', backgroundColor: tone.solid, zIndex: 1 }}>
          <AppIcon name={symbol} fallback="•" color="#FFFFFF" size={15} animated={active} />
        </View>
      </View>

      <View
        style={{
          flex: 1,
          gap: spacing.xs,
          padding: spacing.md,
          borderRadius: radii.lg,
          borderCurve: 'continuous',
          backgroundColor: active ? colors.accent : tone.solid,
          borderWidth: 0,
          boxShadow: `0 10px 26px ${tone.solid}32`,
        }}>
        <View style={{ flexDirection: 'row', alignItems: 'flex-start', gap: spacing.sm }}>
          <View style={{ flex: 1, gap: 3 }}>
            <View style={{ flexDirection: 'row', alignItems: 'center', flexWrap: 'wrap', gap: spacing.xs }}>
              <AppText variant="caption" style={{ color: 'rgba(255,255,255,0.82)', fontWeight: '800' }}>
                {task.allDay ? 'ALL DAY' : task.startTime ? `${task.durationMinutes} MIN` : `ANYTIME · ${task.durationMinutes} MIN`}
              </AppText>
              {task.mustWin ? (
                <View style={{ backgroundColor: 'rgba(255,255,255,0.22)', borderRadius: radii.pill, paddingHorizontal: 7, paddingVertical: 3 }}>
                  <AppText variant="caption" style={{ color: '#FFFFFF', fontSize: 10, fontWeight: '900' }}>MUST WIN</AppText>
                </View>
              ) : null}
            </View>
            <AppText
              variant="body"
              style={{ color: '#FFFFFF', fontWeight: task.mustWin ? '800' : '700', textDecorationLine: completed || skipped ? 'line-through' : 'none' }}>
              {task.title}
            </AppText>
            {task.note ? <AppText variant="caption" style={{ color: 'rgba(255,255,255,0.78)' }} numberOfLines={2}>{task.note}</AppText> : null}
          </View>
          <Pressable
            accessibilityRole="checkbox"
            accessibilityState={{ checked: completed }}
            onPress={() => {
              if (process.env.EXPO_OS === 'ios') Haptics.selectionAsync().catch(() => undefined);
              onToggle();
            }}
            style={{ width: 27, height: 27, borderRadius: 14, alignItems: 'center', justifyContent: 'center', backgroundColor: completed ? '#FFFFFF' : 'rgba(255,255,255,0.18)', borderWidth: 2, borderColor: '#FFFFFF' }}>
            {completed ? <AppIcon name="checkmark" fallback="✓" color={tone.solid} size={14} /> : null}
          </Pressable>
        </View>
        {subtaskCount ? <AppText variant="caption" style={{ color: 'rgba(255,255,255,0.78)' }}>{completedSubtasks}/{subtaskCount} subtasks complete</AppText> : null}
        {!completed && !skipped ? (
          <View style={{ flexDirection: 'row', gap: spacing.md, paddingTop: 2 }}>
            <Pressable onPress={onStart} accessibilityRole="button"><AppText variant="caption" style={{ color: '#FFFFFF', fontWeight: '900' }}>{active ? 'In focus now' : 'Start focus'}</AppText></Pressable>
            <Pressable onPress={onSkip} accessibilityRole="button"><AppText variant="caption" style={{ color: 'rgba(255,255,255,0.76)' }}>Skip</AppText></Pressable>
            <Pressable onPress={onEdit} accessibilityRole="button"><AppText variant="caption" style={{ color: 'rgba(255,255,255,0.76)' }}>Edit</AppText></Pressable>
          </View>
        ) : null}
      </View>
      </Animated.View>
    </GestureDetector>
  );
}
