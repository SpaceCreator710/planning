import { router } from 'expo-router';
import React, { useEffect, useState } from 'react';
import { Alert, ScrollView, Switch, View } from 'react-native';

import { AppButton } from '@/components/app/app-button';
import { AppInput } from '@/components/app/app-input';
import { AppText } from '@/components/app/app-text';
import { Card } from '@/components/app/card';
import { Chip } from '@/components/app/chip';
import { canUseCoachMode } from '@/constants/subscriptions';
import { accentThemes, canvasThemes, spacing } from '@/constants/tokens';
import { useApp } from '@/context/app-context';
import { useAppTheme } from '@/context/theme-context';
import { checkAIConnection, type AIConnection } from '@/services/ai-client';
import { requestNotificationPermission } from '@/services/notifications';
import type { AccentTheme, CanvasTheme, CoachMode, FontScaleMode, ThemeMode, VisualEnergy } from '@/types/app';

export default function SettingsScreen() {
  const { colors } = useAppTheme();
  const { data, updateSettings, updateProfile, resetData, restoreLastReset, hasRecoveryBackup } = useApp();
  const settings = data.settings;
  const [aiConnection, setAIConnection] = useState<AIConnection>({ status: 'offline', message: 'Checking the protected AI server…' });
  const [checkingAI, setCheckingAI] = useState(true);

  async function testAI() {
    setCheckingAI(true);
    setAIConnection(await checkAIConnection());
    setCheckingAI(false);
  }

  useEffect(() => {
    let active = true;
    void checkAIConnection().then((connection) => {
      if (!active) return;
      setAIConnection(connection);
      setCheckingAI(false);
    });
    return () => {
      active = false;
    };
  }, []);

  async function toggleNotifications(enabled: boolean) {
    if (!enabled) {
      updateSettings({ notificationsEnabled: false });
      return;
    }
    const allowed = await requestNotificationPermission().catch(() => false);
    updateSettings({ notificationsEnabled: allowed });
    if (!allowed) Alert.alert('Notifications are off', 'Enable notification permission in system settings when you are ready.');
  }

  function chooseMode(mode: CoachMode) {
    if (!canUseCoachMode(data.subscription, mode)) {
      router.push('/paywall');
      return;
    }
    updateSettings({ coachMode: mode });
  }

  function confirmReset() {
    Alert.alert('Reset all account data?', 'Plans, messages, statistics, goals, habits, memories and your profile will be cleared. Your sign-in and paid entitlement stay active. You can restore the last snapshot for seven days.', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Reset',
        style: 'destructive',
        onPress: async () => {
          await resetData();
          router.replace('/');
        },
      },
    ]);
  }

  return (
    <ScrollView contentInsetAdjustmentBehavior="automatic" keyboardShouldPersistTaps="handled" contentContainerStyle={{ padding: spacing.md, paddingBottom: 80, gap: spacing.xl }}>
      <SettingsSection title="Coach style">
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.xs }}>
          {([
            ['soft', 'Soft'],
            ['strict', 'Strict'],
            ['aggressive', 'Aggressive'],
          ] as const).map(([mode, label]) => (
            <Chip
              key={mode}
              label={`${label}${canUseCoachMode(data.subscription, mode) ? '' : ' · lock'}`}
              selected={settings.coachMode === mode}
              color={mode === 'soft' ? colors.success : colors.accent}
              onPress={() => chooseMode(mode)}
            />
          ))}
        </View>
        <View style={{ gap: spacing.xs }}>
          <AppText variant="label">Accountability intensity</AppText>
          <View style={{ flexDirection: 'row', gap: spacing.xs }}>
            {(['light', 'balanced', 'high'] as const).map((level) => (
              <Chip
                key={level}
                label={level}
                selected={settings.accountability === level}
                onPress={() => updateSettings({ accountability: level })}
                style={{ flex: 1 }}
              />
            ))}
          </View>
        </View>
        <View style={{ gap: spacing.xs }}>
          <AppText variant="label">Accent</AppText>
          <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.xs }}>
            {(Object.keys(accentThemes) as AccentTheme[]).map((accentTheme) => (
              <Chip
                key={accentTheme}
                label={accentTheme}
                color={accentThemes[accentTheme].accent}
                selected={settings.accentTheme === accentTheme}
                onPress={() => updateSettings({ accentTheme })}
              />
            ))}
          </View>
          <AppText variant="caption" tone="tertiary">All palettes and task colors are free.</AppText>
        </View>
        <SettingToggle
          title="Safety guardrails"
          detail="Switch to a supportive response when intense coaching would be unsafe"
          value={settings.safeMode}
          onValueChange={(safeMode) => updateSettings({ safeMode })}
        />
      </SettingsSection>

      <SettingsSection title="Appearance & language">
        <View style={{ gap: spacing.xs }}>
          <AppText variant="label">Theme</AppText>
          <View style={{ flexDirection: 'row', gap: spacing.xs }}>
            {(['light', 'dark', 'system'] as ThemeMode[]).map((theme) => (
              <Chip key={theme} label={theme} selected={settings.theme === theme} onPress={() => updateSettings({ theme })} style={{ flex: 1 }} />
            ))}
          </View>
        </View>
        <View style={{ gap: spacing.xs }}>
          <AppText variant="label">Whole-app canvas</AppText>
          <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.xs }}>
            {(Object.keys(canvasThemes) as CanvasTheme[]).map((canvasTheme) => (
              <Chip
                key={canvasTheme}
                label={canvasTheme}
                color={canvasThemes[canvasTheme].swatch}
                selected={settings.canvasTheme === canvasTheme}
                onPress={() => updateSettings({ canvasTheme })}
              />
            ))}
          </View>
          <AppText variant="caption" tone="tertiary">The backdrop, surfaces and accents change as one palette. Blush is soft pink without copying another planner’s identity.</AppText>
        </View>
        <View style={{ gap: spacing.xs }}>
          <AppText variant="label">Visual energy</AppText>
          <View style={{ flexDirection: 'row', gap: spacing.xs }}>
            {(['calm', 'balanced', 'vivid'] as VisualEnergy[]).map((visualEnergy) => (
              <Chip key={visualEnergy} label={visualEnergy} selected={settings.visualEnergy === visualEnergy} onPress={() => updateSettings({ visualEnergy })} style={{ flex: 1 }} />
            ))}
          </View>
        </View>
        <View style={{ gap: spacing.xs }}>
          <AppText variant="label">Language</AppText>
          <View style={{ flexDirection: 'row', gap: spacing.xs }}>
            <Chip label="English" selected={settings.language === 'en'} onPress={() => updateSettings({ language: 'en' })} style={{ flex: 1 }} />
            <Chip label="Русский" selected={settings.language === 'ru'} onPress={() => updateSettings({ language: 'ru' })} style={{ flex: 1 }} />
          </View>
          <AppText variant="caption" tone="tertiary">
            Core navigation is localized. More coach-language packs can be added without changing stored data.
          </AppText>
        </View>
        <View style={{ gap: spacing.xs }}>
          <AppText variant="label">Text size</AppText>
          <View style={{ flexDirection: 'row', gap: spacing.xs }}>
            {(['compact', 'standard', 'large'] as FontScaleMode[]).map((fontScale) => (
              <Chip key={fontScale} label={fontScale} selected={settings.fontScale === fontScale} onPress={() => updateSettings({ fontScale })} style={{ flex: 1 }} />
            ))}
          </View>
        </View>
      </SettingsSection>

      <SettingsSection title="Notifications">
        <SettingToggle
          title="Enable notifications"
          detail="Ask the device for permission only when you turn this on"
          value={settings.notificationsEnabled}
          onValueChange={toggleNotifications}
        />
        <SettingToggle
          title="Task reminders"
          detail="Remind at the scheduled start of important actions"
          value={settings.taskReminders}
          disabled={!settings.notificationsEnabled}
          onValueChange={(taskReminders) => updateSettings({ taskReminders })}
        />
        <SettingToggle
          title="Evening review"
          detail="One short prompt to close the learning loop"
          value={settings.eveningReview}
          disabled={!settings.notificationsEnabled}
          onValueChange={(eveningReview) => updateSettings({ eveningReview })}
        />
        <View style={{ flexDirection: 'row', gap: spacing.sm }}>
          <View style={{ flex: 1, gap: spacing.xs }}>
            <AppText variant="caption" tone="secondary">QUIET FROM</AppText>
            <AppInput value={settings.quietHoursStart} onChangeText={(quietHoursStart) => updateSettings({ quietHoursStart })} />
          </View>
          <View style={{ flex: 1, gap: spacing.xs }}>
            <AppText variant="caption" tone="secondary">UNTIL</AppText>
            <AppInput value={settings.quietHoursEnd} onChangeText={(quietHoursEnd) => updateSettings({ quietHoursEnd })} />
          </View>
        </View>
      </SettingsSection>

      <SettingsSection title="AI learning">
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.sm }}>
          <View style={{ flex: 1, gap: 3 }}>
            <AppText variant="label">Built-in AI · {aiConnection.status === 'online' ? 'online' : aiConnection.status === 'unconfigured' ? 'setup needed' : 'offline'}</AppText>
            <AppText variant="caption" tone="secondary">
              {aiConnection.message}{aiConnection.latencyMs ? ` · ${aiConnection.latencyMs} ms` : ''}
            </AppText>
          </View>
          <Chip label={checkingAI ? 'CHECKING' : aiConnection.status === 'online' ? 'READY' : 'RETRY'} selected={aiConnection.status === 'online'} onPress={() => void testAI()} />
        </View>
        <AppText variant="caption" tone="tertiary">Production uses one private Groq key inside the protected server function. People using the app never enter or see that key.</AppText>
        <AppButton title="Check protected Groq connection" variant="secondary" onPress={() => router.push('/ai-setup')} />
        <SettingToggle
          title="Learn useful facts"
          detail="Propose memory from goals, routines and behavior"
          value={settings.autoLearn}
          onValueChange={(autoLearn) => updateSettings({ autoLearn })}
        />
      </SettingsSection>

      <SettingsSection title="Calendars & devices">
        <AppText variant="small" tone="secondary">Built-in calendars stay free. Plus adds automatic Apple Calendar, Reminders and Health synchronization.</AppText>
        <AppButton title="Open integrations" variant="secondary" onPress={() => router.push('/integrations')} />
      </SettingsSection>

      <SettingsSection title="Daily rhythm">
        <View style={{ flexDirection: 'row', gap: spacing.sm }}>
          <View style={{ flex: 1, gap: spacing.xs }}>
            <AppText variant="caption" tone="secondary">WAKE</AppText>
            <AppInput value={data.profile.wakeTime} onChangeText={(wakeTime) => updateProfile({ wakeTime })} />
          </View>
          <View style={{ flex: 1, gap: spacing.xs }}>
            <AppText variant="caption" tone="secondary">SLEEP</AppText>
            <AppInput value={data.profile.sleepTime} onChangeText={(sleepTime) => updateProfile({ sleepTime })} />
          </View>
        </View>
      </SettingsSection>

      <SettingsSection title="Optional body rhythm">
        <SettingToggle
          title="Use a private cycle rhythm"
          detail="Offer planning margin from dates you enter; never infer this automatically"
          value={data.profile.bodyRhythmEnabled}
          onValueChange={(bodyRhythmEnabled) => updateProfile({ bodyRhythmEnabled })}
        />
        {data.profile.bodyRhythmEnabled ? (
          <>
            <View style={{ gap: spacing.xs }}>
              <AppText variant="caption" tone="secondary">LAST CYCLE START · YYYY-MM-DD</AppText>
              <AppInput value={data.profile.cycleStartDate} onChangeText={(cycleStartDate) => updateProfile({ cycleStartDate })} placeholder="2026-08-01" keyboardType="numbers-and-punctuation" />
            </View>
            <View style={{ flexDirection: 'row', gap: spacing.sm }}>
              <View style={{ flex: 1, gap: spacing.xs }}>
                <AppText variant="caption" tone="secondary">CYCLE DAYS</AppText>
                <AppInput value={String(data.profile.cycleLengthDays)} onChangeText={(value) => updateProfile({ cycleLengthDays: Math.max(20, Math.min(45, Number(value) || 28)) })} keyboardType="number-pad" />
              </View>
              <View style={{ flex: 1, gap: spacing.xs }}>
                <AppText variant="caption" tone="secondary">RESET DAYS</AppText>
                <AppInput value={String(data.profile.cyclePeriodDays)} onChangeText={(value) => updateProfile({ cyclePeriodDays: Math.max(2, Math.min(10, Number(value) || 5)) })} keyboardType="number-pad" />
              </View>
            </View>
            <AppText variant="caption" tone="tertiary">Optional, stored with your profile, and used only as a planning hint. It is not medical or fertility advice.</AppText>
          </>
        ) : null}
      </SettingsSection>

      <SettingsSection title="Data controls">
        <AppButton title="Review AI memory" variant="secondary" onPress={() => router.push('/memory')} />
        <AppButton
          title="Export data"
          variant="secondary"
          onPress={() => Alert.alert('Export adapter ready', 'Production cloud export will generate a portable JSON archive after account backend setup.')}
        />
        {hasRecoveryBackup ? (
          <AppButton
            title="Restore last reset"
            variant="secondary"
            onPress={async () => {
              const restored = await restoreLastReset();
              Alert.alert(restored ? 'Data restored' : 'Could not restore', restored ? 'Your plans, stats, memories and profile are back.' : 'The recovery window may have expired.');
            }}
          />
        ) : null}
        <AppButton title="Reset all account data" variant="danger" onPress={confirmReset} />
        <AppText variant="caption" tone="tertiary">
          A reset removes plans, stats, memory, goals, habits and onboarding data on this device and from the synced snapshot. Sign-in and paid entitlement remain. One local recovery snapshot stays available for seven days.
        </AppText>
      </SettingsSection>
    </ScrollView>
  );
}

function SettingsSection({ title, children }: React.PropsWithChildren<{ title: string }>) {
  return (
    <View style={{ gap: spacing.sm }}>
      <AppText variant="caption" tone="tertiary">
        {title.toUpperCase()}
      </AppText>
      <Card>{children}</Card>
    </View>
  );
}

function SettingToggle({
  title,
  detail,
  value,
  onValueChange,
  disabled,
}: {
  title: string;
  detail: string;
  value: boolean;
  onValueChange: (value: boolean) => void;
  disabled?: boolean;
}) {
  const { colors } = useAppTheme();
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.sm, opacity: disabled ? 0.45 : 1 }}>
      <View style={{ flex: 1, gap: 2 }}>
        <AppText variant="label">{title}</AppText>
        <AppText variant="caption" tone="secondary">
          {detail}
        </AppText>
      </View>
      <Switch
        disabled={disabled}
        value={value}
        onValueChange={onValueChange}
        trackColor={{ false: colors.surfaceMuted, true: colors.accentSoft }}
        thumbColor={value ? colors.accent : colors.textTertiary}
      />
    </View>
  );
}
