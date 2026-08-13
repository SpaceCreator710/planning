import { router } from 'expo-router';
import React, { useMemo, useState } from 'react';
import { Alert, Pressable, ScrollView, View } from 'react-native';

import { AppButton } from '@/components/app/app-button';
import { AppIcon } from '@/components/app/app-icon';
import { AppInput } from '@/components/app/app-input';
import { AppText } from '@/components/app/app-text';
import { Card } from '@/components/app/card';
import { Chip } from '@/components/app/chip';
import { spacing } from '@/constants/tokens';
import { useApp } from '@/context/app-context';
import { useAppTheme } from '@/context/theme-context';

export default function InboxScreen() {
  const { colors } = useAppTheme();
  const { data, addInboxTask, removeInboxTasks, buildPlan } = useApp();
  const [title, setTitle] = useState('');
  const [excluded, setExcluded] = useState<string[]>([]);
  const [planning, setPlanning] = useState(false);
  const selected = useMemo(() => data.inbox.filter((item) => !excluded.includes(item.id)), [data.inbox, excluded]);

  function capture() {
    if (!title.trim()) return;
    addInboxTask(title);
    setTitle('');
  }

  async function planSelected() {
    if (!selected.length) {
      Alert.alert('Choose at least one task', 'Tap a task to include it in this AI plan.');
      return;
    }
    setPlanning(true);
    const result = await buildPlan({
      brainDump: selected.map((item) => item.title).join('\n'),
      mustWin: selected[0].title,
      fixedCommitments: data.profile.fixedCommitments,
      energy: 3,
      style: 'realistic',
    });
    setPlanning(false);
    if (!result.ok) {
      if (result.reason === 'limit') router.push('/paywall');
      return;
    }
    removeInboxTasks(selected.map((item) => item.id), true);
    if (result.fallback) Alert.alert('AI connection unavailable', 'A local emergency schedule was created. Retry later for full personalization.');
    router.replace('/(tabs)/today');
  }

  return (
    <ScrollView contentInsetAdjustmentBehavior="automatic" keyboardShouldPersistTaps="handled" contentContainerStyle={{ padding: spacing.lg, paddingBottom: 90, gap: spacing.xl }}>
      <View style={{ gap: spacing.xs }}>
        <AppText variant="title">Inbox first. Decide later.</AppText>
        <AppText tone="secondary">Capture as many tasks as you want without choosing a time. When ready, AI schedules the selected set around your real day.</AppText>
      </View>

      <Card style={{ gap: spacing.sm }}>
        <AppInput value={title} onChangeText={setTitle} placeholder="Add a task, then press return" autoFocus returnKeyType="done" onSubmitEditing={capture} />
        <AppButton title="Add to inbox" compact disabled={!title.trim()} onPress={capture} />
      </Card>

      <View style={{ gap: spacing.sm }}>
        <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', gap: spacing.sm }}>
          <AppText variant="heading">Unscheduled</AppText>
          <Chip label={`${selected.length}/${data.inbox.length} selected`} selected={selected.length > 0} />
        </View>
        {data.inbox.length ? data.inbox.map((item) => {
          const included = !excluded.includes(item.id);
          return (
            <Card key={item.id} style={{ flexDirection: 'row', alignItems: 'center', boxShadow: 'none', opacity: included ? 1 : 0.58 }}>
              <Pressable
                accessibilityRole="checkbox"
                accessibilityState={{ checked: included }}
                onPress={() => setExcluded((current) => current.includes(item.id) ? current.filter((id) => id !== item.id) : [...current, item.id])}
                style={{ width: 28, height: 28, borderRadius: 14, borderWidth: 1, borderColor: included ? colors.accent : colors.border, backgroundColor: included ? colors.accentSoft : colors.background, alignItems: 'center', justifyContent: 'center' }}>
                {included ? <AppIcon name="checkmark" fallback="✓" color={colors.accent} size={13} /> : null}
              </Pressable>
              <AppText variant="small" style={{ flex: 1 }}>{item.title}</AppText>
              <Pressable onPress={() => removeInboxTasks([item.id])}>
                <AppText variant="caption" tone="accent">Remove</AppText>
              </Pressable>
            </Card>
          );
        }) : (
          <Card muted>
            <AppText variant="small" tone="secondary">Nothing is waiting. Add several tasks above; they will remain unscheduled until you choose to plan them.</AppText>
          </Card>
        )}
      </View>

      {data.inbox.length ? (
        <Card style={{ backgroundColor: colors.accentSoft, borderColor: colors.accent }}>
          <AppText variant="caption" tone="accent">ONE-TAP AI SCHEDULING</AppText>
          <AppText variant="heading">Turn {selected.length} selected tasks into a realistic timeline</AppText>
          <AppText variant="small" tone="secondary">The AI sees existing commitments, goals, energy patterns, memory and recent follow-through before placing anything.</AppText>
          <AppButton title="Plan selected tasks" loading={planning} disabled={!selected.length} onPress={planSelected} />
        </Card>
      ) : null}
    </ScrollView>
  );
}
