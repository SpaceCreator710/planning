import React, { useState } from 'react';
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
import type { MemoryFact } from '@/types/app';

const categoryIcons: Record<MemoryFact['category'], Parameters<typeof AppIcon>[0]['name']> = {
  goal: 'target',
  routine: 'repeat.circle.fill',
  blocker: 'exclamationmark.triangle.fill',
  preference: 'slider.horizontal.3',
  pattern: 'chart.line.uptrend.xyaxis',
};

export default function MemoryScreen() {
  const { colors } = useAppTheme();
  const { data, addMemory, toggleMemory, deleteMemory, updateSettings } = useApp();
  const [fact, setFact] = useState('');
  const [category, setCategory] = useState<MemoryFact['category']>('preference');
  const [showAdd, setShowAdd] = useState(false);

  function add() {
    if (!fact.trim()) return;
    addMemory(fact, category);
    setFact('');
    setShowAdd(false);
  }

  function confirmDelete(id: string) {
    Alert.alert('Forget this?', 'The coach will stop using this fact immediately.', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Forget', style: 'destructive', onPress: () => deleteMemory(id) },
    ]);
  }

  return (
    <ScrollView contentInsetAdjustmentBehavior="automatic" keyboardShouldPersistTaps="handled" contentContainerStyle={{ padding: spacing.md, paddingBottom: 80, gap: spacing.xl }}>
      <Card style={{ backgroundColor: colors.infoSoft, borderColor: colors.info }}>
        <AppText variant="caption" style={{ color: colors.info }}>
          TRANSPARENT BY DESIGN
        </AppText>
        <AppText variant="heading">The coach remembers what helps you act.</AppText>
        <AppText variant="small" tone="secondary">
          You can pause, correct or delete every memory. Behavioral patterns use completion data; they are not guesses about your personality.
        </AppText>
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.xs }}>
          <Chip label={`${data.memories.filter((memory) => memory.enabled).length} active`} selected color={colors.info} />
          <Chip label={`${data.memories.filter((memory) => memory.source === 'behavior').length} behavioral`} />
          <Chip label={`${data.memories.filter((memory) => memory.source === 'user').length} user-added`} />
        </View>
      </Card>

      <View style={{ gap: spacing.sm }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: spacing.sm }}>
          <AppText variant="heading">Memory facts</AppText>
          <Chip
            label={data.settings.autoLearn ? 'Auto-learn on' : 'Auto-learn off'}
            selected={data.settings.autoLearn}
            color={colors.success}
            onPress={() => updateSettings({ autoLearn: !data.settings.autoLearn })}
          />
        </View>
        {data.memories.map((memory) => (
          <Card key={memory.id} style={{ opacity: memory.enabled ? 1 : 0.54, boxShadow: 'none' }}>
            <View style={{ flexDirection: 'row', gap: spacing.sm }}>
              <View style={{ width: 40, height: 40, borderRadius: 14, backgroundColor: colors.surfaceMuted, alignItems: 'center', justifyContent: 'center' }}>
                <AppIcon name={categoryIcons[memory.category]} fallback="•" color={colors.accent} size={20} />
              </View>
              <View style={{ flex: 1, gap: spacing.xs }}>
                <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.xs }}>
                  <Chip label={memory.category} selected={memory.enabled} />
                  <Chip label={`${Math.round(memory.confidence * 100)}% confidence`} />
                  <Chip label={memory.source} />
                </View>
                <AppText variant="small">{memory.fact}</AppText>
                <View style={{ flexDirection: 'row', gap: spacing.md }}>
                  <Pressable onPress={() => toggleMemory(memory.id)}>
                    <AppText variant="caption" tone={memory.enabled ? 'warning' : 'success'}>
                      {memory.enabled ? 'Pause' : 'Use again'}
                    </AppText>
                  </Pressable>
                  <Pressable onPress={() => confirmDelete(memory.id)}>
                    <AppText variant="caption" tone="accent">
                      Forget
                    </AppText>
                  </Pressable>
                </View>
              </View>
            </View>
          </Card>
        ))}
      </View>

      {showAdd ? (
        <Card>
          <AppText variant="heading">Add a fact</AppText>
          <AppInput value={fact} onChangeText={setFact} placeholder="Example: I focus best before lunch" multiline autoFocus />
          <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.xs }}>
            {(Object.keys(categoryIcons) as MemoryFact['category'][]).map((item) => (
              <Chip key={item} label={item} selected={category === item} onPress={() => setCategory(item)} />
            ))}
          </View>
          <View style={{ flexDirection: 'row', gap: spacing.sm }}>
            <AppButton title="Cancel" compact variant="secondary" onPress={() => setShowAdd(false)} style={{ flex: 1 }} />
            <AppButton title="Remember" compact onPress={add} style={{ flex: 2 }} />
          </View>
        </Card>
      ) : (
        <AppButton title="Add memory" variant="secondary" onPress={() => setShowAdd(true)} />
      )}

      <Card muted>
        <AppText variant="label">Private day</AppText>
        <AppText variant="small" tone="secondary">
          Incognito planning is prepared for Pro: a private day can run without adding chat or behavior to long-term memory.
        </AppText>
      </Card>
    </ScrollView>
  );
}
