import { router } from 'expo-router';
import React, { useState } from 'react';
import { Alert, Platform, ScrollView, Switch, View } from 'react-native';

import { AppButton } from '@/components/app/app-button';
import { AppIcon } from '@/components/app/app-icon';
import { AppText } from '@/components/app/app-text';
import { Card } from '@/components/app/card';
import { Chip } from '@/components/app/chip';
import { canUseDeviceIntegration } from '@/constants/subscriptions';
import { spacing } from '@/constants/tokens';
import { useApp } from '@/context/app-context';
import { useAppTheme } from '@/context/theme-context';
import { exportPlanToCalendar, pickIcsTasksOnWeb } from '@/services/calendar-bridge';
import { capacityFromHealth } from '@/services/capacity-twin';
import { exportPlanToDeviceCalendar, syncDeviceCalendar } from '@/services/device-calendar';
import { healthKitAvailable, readHealthSnapshot, requestHealthAccess } from '@/services/health-bridge';
import { schedulePlanReminders } from '@/services/notifications';

type Working = 'calendar' | 'export' | 'health' | 'reminders';

export default function IntegrationsScreen() {
  const { colors } = useAppTheme();
  const { data, activePlan, importCalendarTasks, applyCapacitySignal, updateSettings, syncStatus } = useApp();
  const [working, setWorking] = useState<Working>();
  const deviceUnlocked = canUseDeviceIntegration(data.subscription);

  async function connectCalendar() {
    if (Platform.OS === 'web') {
      setWorking('calendar');
      try {
        const tasks = await pickIcsTasksOnWeb();
        const imported = importCalendarTasks(tasks);
        Alert.alert(imported ? 'Calendar imported' : 'Nothing new', imported ? `${imported} events are now in Flow Calendar.` : 'No new events were found.');
      } catch (error) {
        Alert.alert('Import failed', error instanceof Error ? error.message : 'The .ics file could not be read.');
      } finally {
        setWorking(undefined);
      }
      return;
    }
    if (!deviceUnlocked) {
      router.push('/paywall');
      return;
    }
    setWorking('calendar');
    try {
      const result = await syncDeviceCalendar({ includeReminders: data.settings.remindersSyncEnabled });
      if (!result.calendarPermission) {
        Alert.alert('Permission needed', 'Allow Calendar access in Apple Settings.');
        return;
      }
      const imported = importCalendarTasks(result.tasks, {
        replaceExternalRange: {
          startDate: result.rangeStart,
          endDate: result.rangeEnd,
          sources: result.remindersPermission ? ['calendar', 'reminder'] : ['calendar'],
        },
      });
      updateSettings({ calendarSyncEnabled: true, calendarWriteBackEnabled: true, remindersSyncEnabled: result.remindersPermission || data.settings.remindersSyncEnabled });
      Alert.alert('Device calendar synchronized', `${imported} calendar and reminder items were placed into their days. Important dates stay protected during replanning.`);
    } catch (error) {
      Alert.alert('Sync failed', error instanceof Error ? error.message : 'The device calendar could not be read.');
    } finally {
      setWorking(undefined);
    }
  }

  async function exportCalendar() {
    if (!activePlan) {
      Alert.alert('No day to export', 'Build or open a day first.');
      return;
    }
    setWorking('export');
    try {
      if (Platform.OS === 'web') await exportPlanToCalendar(activePlan);
      else {
        const result = await exportPlanToDeviceCalendar(activePlan);
        Alert.alert('Apple Calendar updated', `${result.created} created · ${result.updated} updated · ${result.removed} removed. No duplicate app-owned events were left behind.`);
      }
    } catch (error) {
      Alert.alert('Export failed', error instanceof Error ? error.message : 'The plan could not be exported.');
    } finally {
      setWorking(undefined);
    }
  }

  async function connectHealth() {
    if (!deviceUnlocked) {
      router.push('/paywall');
      return;
    }
    if (!healthKitAvailable()) {
      Alert.alert('iPhone build required', 'Apple Health is available in a native iOS development or App Store build.');
      return;
    }
    setWorking('health');
    try {
      const granted = await requestHealthAccess();
      if (!granted) return;
      const snapshot = await readHealthSnapshot();
      applyCapacitySignal(capacityFromHealth(snapshot), snapshot);
      updateSettings({ healthSyncEnabled: true });
      Alert.alert('Apple Health connected', 'Sleep, steps and activity are now available in the Health tab. Raw records stay on device.');
    } catch (error) {
      Alert.alert('Health unavailable', error instanceof Error ? error.message : 'HealthKit could not be read.');
    } finally {
      setWorking(undefined);
    }
  }

  async function enableReminders() {
    if (!activePlan) {
      Alert.alert('No day to schedule', 'Build your day first.');
      return;
    }
    setWorking('reminders');
    const enabled = await schedulePlanReminders(activePlan).catch(() => false);
    setWorking(undefined);
    updateSettings({ notificationsEnabled: enabled, taskReminders: enabled });
    Alert.alert(enabled ? 'Notifications scheduled' : 'Permission needed', enabled ? 'Upcoming timed tasks now have local alerts.' : 'Allow notifications in device settings and try again.');
  }

  return (
    <ScrollView contentInsetAdjustmentBehavior="automatic" contentContainerStyle={{ padding: spacing.md, paddingBottom: 100, gap: spacing.xl }}>
      <View style={{ gap: 3 }}>
        <AppText variant="title">Connected life</AppText>
        <AppText tone="secondary">Each source stays behind its own Apple permission. You can disconnect planning use at any time.</AppText>
      </View>

      <IntegrationCard icon="calendar" color={colors.info} title="Apple Calendar + Reminders" badge={deviceUnlocked ? 'PLUS' : 'LOCKED'} detail="Read device events and reminder lists, preserve marked dates, and export your plan back to the default calendar.">
        <SettingSwitch label="Include Apple Reminders" value={data.settings.remindersSyncEnabled} onChange={(remindersSyncEnabled) => updateSettings({ remindersSyncEnabled })} />
        <SettingSwitch label="Write local plans back to Apple Calendar" value={data.settings.calendarWriteBackEnabled} onChange={(calendarWriteBackEnabled) => updateSettings({ calendarWriteBackEnabled })} />
        <SettingSwitch label="Plan around important dates" value={data.settings.autoCalendarReplan} onChange={(autoCalendarReplan) => updateSettings({ autoCalendarReplan })} />
        <View style={{ flexDirection: 'row', gap: spacing.sm }}>
          <AppButton title={Platform.OS === 'web' ? 'Import .ics' : 'Sync Apple'} loading={working === 'calendar'} onPress={() => void connectCalendar()} style={{ flex: 1 }} />
          <AppButton title="Export today" variant="secondary" loading={working === 'export'} onPress={() => void exportCalendar()} style={{ flex: 1 }} />
        </View>
      </IntegrationCard>

      <IntegrationCard icon="heart.fill" color={colors.accent} title="Apple Health" badge={deviceUnlocked ? 'PLUS' : 'LOCKED'} detail="Read selected sleep, step, activity and workout metrics. Only a small capacity signal can be used by the planner.">
        <SettingSwitch label="Use capacity for planning" value={data.settings.healthPlanningEnabled} onChange={(healthPlanningEnabled) => updateSettings({ healthPlanningEnabled })} />
        <AppButton title={data.settings.healthSyncEnabled ? 'Refresh Health access' : 'Connect Apple Health'} loading={working === 'health'} onPress={() => void connectHealth()} />
      </IntegrationCard>

      <IntegrationCard icon="note.text" color={colors.warning} title="Apple Notes" badge="FREE" detail="Receive text and links through Apple’s Share Sheet and send internal notes back through the same private system handoff.">
        <AppButton title="Open built-in Notes" variant="secondary" onPress={() => router.push('/(tabs)/notes')} />
      </IntegrationCard>

      <IntegrationCard icon="bell.badge.fill" color={colors.success} title="Notifications + widgets" badge="PLUS" detail="Local task alerts are available now. Native home/lock-screen widgets are included in iOS development and App Store builds.">
        <AppButton title="Schedule today’s alerts" loading={working === 'reminders'} onPress={() => void enableReminders()} />
      </IntegrationCard>

      <Card muted style={{ gap: spacing.md }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.md }}>
          <View style={{ flex: 1 }}>
            <AppText variant="heading">Cross-device continuity</AppText>
            <AppText variant="small" tone="secondary">Your account snapshot follows the account when cloud registration is connected.</AppText>
          </View>
          <Chip label={syncStatus.toUpperCase()} selected={syncStatus === 'synced'} />
        </View>
        <AppButton title="Account & sync" variant="secondary" onPress={() => router.push('/(tabs)/profile')} />
      </Card>
    </ScrollView>
  );
}

function IntegrationCard({ icon, color, title, detail, badge, children }: React.PropsWithChildren<{ icon: Parameters<typeof AppIcon>[0]['name']; color: string; title: string; detail: string; badge: string }>) {
  return (
    <Card style={{ gap: spacing.md }}>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.md }}>
        <View style={{ width: 50, height: 50, borderRadius: 19, backgroundColor: `${color}18`, alignItems: 'center', justifyContent: 'center' }}>
          <AppIcon name={icon} fallback="•" color={color} size={25} />
        </View>
        <View style={{ flex: 1, gap: 2 }}>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.xs }}>
            <AppText variant="heading" style={{ flex: 1 }}>{title}</AppText>
            <Chip label={badge} selected color={color} />
          </View>
          <AppText variant="small" tone="secondary">{detail}</AppText>
        </View>
      </View>
      {children}
    </Card>
  );
}

function SettingSwitch({ label, value, onChange }: { label: string; value: boolean; onChange: (value: boolean) => void }) {
  const { colors } = useAppTheme();
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.sm }}>
      <AppText variant="small" style={{ flex: 1 }}>{label}</AppText>
      <Switch value={value} onValueChange={onChange} trackColor={{ false: colors.surfaceMuted, true: colors.accentSoft }} thumbColor={value ? colors.accent : colors.textTertiary} />
    </View>
  );
}
