import { router } from 'expo-router';
import React, { useEffect, useRef, useState } from 'react';
import { KeyboardAvoidingView, Pressable, ScrollView, View } from 'react-native';

import { AppInput } from '@/components/app/app-input';
import { AppText } from '@/components/app/app-text';
import { BrandMark } from '@/components/app/brand-mark';
import { Card } from '@/components/app/card';
import { Chip } from '@/components/app/chip';
import { SlidingSegmentedControl } from '@/components/app/sliding-segmented-control';
import { canUseCoachMode, subscriptionPlans } from '@/constants/subscriptions';
import { radii, spacing } from '@/constants/tokens';
import { useApp } from '@/context/app-context';
import { useAppTheme } from '@/context/theme-context';
import { checkAIConnection, type AIConnectionStatus } from '@/services/ai-client';
import type { CoachMode } from '@/types/app';

const prompts = ['I am procrastinating', 'Shrink my next task', 'Challenge my excuse', 'My day changed'];

export default function CoachScreen() {
  const { colors, isDark } = useAppTheme();
  const { data, updateSettings, sendCoachMessage } = useApp();
  const [input, setInput] = useState('');
  const [sending, setSending] = useState(false);
  const [connectionNote, setConnectionNote] = useState('');
  const [aiStatus, setAIStatus] = useState<AIConnectionStatus | 'checking'>('checking');
  const scrollRef = useRef<ScrollView>(null);
  const plan = subscriptionPlans[data.subscription];
  const remaining = Math.max(0, plan.limits.coachMessagesPerDay - data.usage.coachMessages);

  useEffect(() => {
    const timeout = setTimeout(() => scrollRef.current?.scrollToEnd({ animated: true }), 80);
    return () => clearTimeout(timeout);
  }, [data.messages.length, sending]);

  useEffect(() => {
    let active = true;
    void checkAIConnection().then((connection) => {
      if (active) setAIStatus(connection.status);
    });
    return () => {
      active = false;
    };
  }, []);

  function chooseMode(mode: CoachMode) {
    if (!canUseCoachMode(data.subscription, mode)) {
      router.push('/paywall');
      return;
    }
    updateSettings({ coachMode: mode });
  }

  async function send(value = input) {
    const trimmed = value.trim();
    if (!trimmed || sending) return;
    setInput('');
    setConnectionNote('');
    setSending(true);
    const result = await sendCoachMessage(trimmed);
    setSending(false);
    if (!result.ok) {
      if (result.reason === 'limit') router.push('/paywall');
      else setInput(trimmed);
      return;
    }
    if (result.fallback) setConnectionNote('The protected AI connection was unavailable, so a local safety reply was used.');
  }

  return (
    <KeyboardAvoidingView style={{ flex: 1 }} behavior={process.env.EXPO_OS === 'ios' ? 'padding' : undefined} keyboardVerticalOffset={88}>
      <View style={{ flex: 1 }}>
        <ScrollView
          ref={scrollRef}
          contentInsetAdjustmentBehavior="automatic"
          keyboardShouldPersistTaps="handled"
          contentContainerStyle={{ padding: spacing.md, paddingBottom: 170, gap: spacing.md }}>
          <Card muted style={{ flexDirection: 'row', alignItems: 'center', padding: spacing.sm }}>
            <BrandMark size={38} />
            <View style={{ flex: 1, gap: 2 }}>
              <AppText variant="label">Personal action coach</AppText>
              <AppText variant="caption" tone="secondary">Uses your profile, plan, memory and recent behavior · {remaining} turns left today</AppText>
            </View>
            <View style={{ width: 8, height: 8, borderRadius: 4, backgroundColor: sending || aiStatus === 'checking' ? colors.warning : aiStatus === 'online' ? colors.success : colors.textTertiary }} />
          </Card>

          <SlidingSegmentedControl
            value={data.settings.coachMode}
            onChange={chooseMode}
            options={[
              { value: 'soft', label: 'Soft' },
              { value: 'strict', label: canUseCoachMode(data.subscription, 'strict') ? 'Strict' : 'Strict · lock' },
              { value: 'aggressive', label: canUseCoachMode(data.subscription, 'aggressive') ? 'Aggressive' : 'Aggressive · lock' },
            ]}
          />
          <Card muted style={{ padding: spacing.sm }}>
            <AppText variant="caption" tone={data.settings.coachMode === 'soft' ? 'success' : 'accent'}>
              {data.settings.coachMode === 'soft'
                ? 'SOFT · extremely kind, patient, tiny next steps, no guilt'
                : data.settings.coachMode === 'strict'
                  ? 'STRICT · factual, direct, clear command and deadline'
                  : 'AGGRESSIVE · provocative confrontation of avoidance, short commands, never insults or humiliation'}
            </AppText>
          </Card>

          {connectionNote ? (
            <Card muted style={{ padding: spacing.sm }}>
              <AppText variant="caption" tone="warning">{connectionNote}</AppText>
            </Card>
          ) : null}

          {aiStatus !== 'online' && aiStatus !== 'checking' && !connectionNote ? (
            <Pressable onPress={() => router.push('/settings')}>
              <Card muted style={{ padding: spacing.sm }}>
                <AppText variant="caption" tone="warning">Built-in AI is not online. Local safety replies remain available; open Settings to diagnose the server connection.</AppText>
              </Card>
            </Pressable>
          ) : null}

          <View style={{ gap: spacing.sm }}>
            {data.messages.map((message) => {
              const user = message.role === 'user';
              return (
                <View key={message.id} style={{ alignItems: user ? 'flex-end' : 'flex-start' }}>
                  <View
                    style={{
                      maxWidth: '88%',
                      paddingHorizontal: spacing.md,
                      paddingVertical: spacing.sm,
                      borderRadius: radii.lg,
                      borderCurve: 'continuous',
                      backgroundColor: user ? colors.accent : message.safetyOverride ? colors.successSoft : colors.surface,
                      borderWidth: user ? 0 : 1,
                      borderColor: message.safetyOverride ? colors.success : colors.border,
                    }}>
                    <AppText style={{ color: user ? '#FFFFFF' : colors.text }}>{message.content}</AppText>
                  </View>
                </View>
              );
            })}
            {sending ? (
              <View style={{ alignItems: 'flex-start' }}>
                <View style={{ paddingHorizontal: spacing.md, paddingVertical: spacing.sm, borderRadius: radii.lg, backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border }}>
                  <AppText tone="tertiary">Thinking…</AppText>
                </View>
              </View>
            ) : null}
          </View>

          <View style={{ gap: spacing.xs }}>
            <AppText variant="caption" tone="tertiary">QUICK ACTIONS</AppText>
            <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.xs }}>
              {prompts.map((prompt) => <Chip key={prompt} label={prompt} onPress={() => send(prompt)} />)}
            </View>
          </View>
        </ScrollView>

        <View
          style={{
            position: 'absolute',
            left: 0,
            right: 0,
            bottom: 0,
            backgroundColor: colors.tabBar,
            borderTopWidth: 1,
            borderTopColor: colors.border,
            paddingHorizontal: spacing.md,
            paddingTop: spacing.sm,
            paddingBottom: process.env.EXPO_OS === 'ios' ? 88 : 72,
          }}>
          <View style={{ flexDirection: 'row', alignItems: 'flex-end', gap: spacing.xs }}>
            <AppInput
              value={input}
              onChangeText={setInput}
              placeholder="Message your coach"
              multiline
              editable={!sending}
              style={{ flex: 1, minHeight: 48, maxHeight: 112, borderRadius: 24, paddingHorizontal: 18 }}
            />
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="Send message"
              disabled={!input.trim() || sending}
              onPress={() => send()}
              style={({ pressed }) => ({
                width: 48,
                height: 48,
                borderRadius: 24,
                backgroundColor: input.trim() && !sending ? colors.accent : colors.surfaceMuted,
                alignItems: 'center',
                justifyContent: 'center',
                opacity: pressed ? 0.76 : 1,
                transform: [{ scale: pressed ? 0.96 : 1 }],
              })}>
              <AppText style={{ color: input.trim() && !sending ? (isDark ? '#101114' : '#FFFFFF') : colors.textTertiary, fontSize: 23, fontWeight: '900', marginTop: -2 }}>↑</AppText>
            </Pressable>
          </View>
        </View>
      </View>
    </KeyboardAvoidingView>
  );
}
