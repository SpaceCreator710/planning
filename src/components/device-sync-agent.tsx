import { useCallback, useEffect, useRef } from 'react';
import { AppState, Platform } from 'react-native';

import { canUseDeviceIntegration } from '@/constants/subscriptions';
import { accentThemes } from '@/constants/tokens';
import { useApp } from '@/context/app-context';
import { dateKey } from '@/lib/date';
import { capacityFromHealth } from '@/services/capacity-twin';
import { exportPlanToDeviceCalendar, syncDeviceCalendar } from '@/services/device-calendar';
import { healthKitAvailable, readHealthSnapshot } from '@/services/health-bridge';
import { updateNextActionWidget } from '@/services/widget-bridge';

const MIN_SYNC_INTERVAL = 20 * 60 * 1000;

export function DeviceSyncAgent() {
  const { data, activePlan, importCalendarTasks, applyCapacitySignal, rescuePlan } = useApp();
  const lastRun = useRef(0);
  const running = useRef(false);
  const activePlanRef = useRef(activePlan);
  const rescuePlanRef = useRef(rescuePlan);
  const replanTimer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);

  useEffect(() => {
    activePlanRef.current = activePlan;
    rescuePlanRef.current = rescuePlan;
  }, [activePlan, rescuePlan]);

  const queueCalendarReplan = useCallback(() => {
    if (replanTimer.current) clearTimeout(replanTimer.current);
    replanTimer.current = setTimeout(() => {
      const latest = activePlanRef.current;
      if (!latest) return;
      const unfinishedMinutes = latest.tasks.filter((task) => task.status !== 'completed' && !task.externalSource).reduce((sum, task) => sum + task.durationMinutes, 0);
      const availableMinutes = unfinishedMinutes >= 120 ? 120 : unfinishedMinutes >= 60 ? 60 : unfinishedMinutes >= 30 ? 30 : 10;
      void rescuePlanRef.current({ reason: 'unexpected', availableMinutes, energy: latest.energy });
    }, 450);
  }, []);

  const sync = useCallback(async () => {
    if (Platform.OS === 'web' || running.current || Date.now() - lastRun.current < MIN_SYNC_INTERVAL) return;
    if (!canUseDeviceIntegration(data.subscription)) return;
    if (!data.settings.calendarSyncEnabled && !data.settings.healthSyncEnabled) return;
    running.current = true;
    lastRun.current = Date.now();
    try {
      if (data.settings.calendarSyncEnabled) {
        const result = await syncDeviceCalendar({ includeReminders: data.settings.remindersSyncEnabled, requestPermissions: false });
        if (result.calendarPermission) {
          importCalendarTasks(result.tasks, {
            replaceExternalRange: {
              startDate: result.rangeStart,
              endDate: result.rangeEnd,
              sources: result.remindersPermission ? ['calendar', 'reminder'] : ['calendar'],
            },
          });
          if (data.settings.autoCalendarReplan && result.tasks.some((task) => task.planDate === dateKey() && task.externalImportance === 'important')) {
            queueCalendarReplan();
          }
          if (data.settings.calendarWriteBackEnabled && activePlanRef.current) {
            await exportPlanToDeviceCalendar(activePlanRef.current);
          }
        }
      }
      if (data.settings.healthSyncEnabled && healthKitAvailable()) {
        const snapshot = await readHealthSnapshot();
        applyCapacitySignal(capacityFromHealth(snapshot), snapshot);
      }
    } catch {
      // Background sync stays silent; the integrations screen provides explicit diagnostics.
    } finally {
      running.current = false;
    }
  }, [applyCapacitySignal, data.settings.autoCalendarReplan, data.settings.calendarSyncEnabled, data.settings.calendarWriteBackEnabled, data.settings.healthSyncEnabled, data.settings.remindersSyncEnabled, data.subscription, importCalendarTasks, queueCalendarReplan]);

  useEffect(() => {
    const initial = setTimeout(() => void sync(), 0);
    const subscription = AppState.addEventListener('change', (state) => {
      if (state === 'active') void sync();
    });
    return () => {
      clearTimeout(initial);
      if (replanTimer.current) clearTimeout(replanTimer.current);
      subscription.remove();
    };
  }, [sync]);

  useEffect(() => {
    if (!canUseDeviceIntegration(data.subscription)) return;
    updateNextActionWidget(activePlan, accentThemes[data.settings.accentTheme].accent);
  }, [activePlan, data.settings.accentTheme, data.subscription]);

  return null;
}
