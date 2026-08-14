import { NativeTabs } from 'expo-router/unstable-native-tabs';
import React from 'react';

import { translate } from '@/constants/translations';
import { useApp } from '@/context/app-context';
import { useAppTheme } from '@/context/theme-context';

export default function TabsLayout() {
  const { colors } = useAppTheme();
  const { data } = useApp();
  const t = (key: Parameters<typeof translate>[1]) => translate(data.settings.language, key);
  return (
    <NativeTabs tintColor={colors.accent} minimizeBehavior="onScrollDown">
      <NativeTabs.Trigger name="today">
        <NativeTabs.Trigger.Icon sf={{ default: 'sparkles', selected: 'sparkles' }} md="auto_awesome" />
        <NativeTabs.Trigger.Label>{t('today')}</NativeTabs.Trigger.Label>
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="calendar">
        <NativeTabs.Trigger.Icon sf={{ default: 'calendar', selected: 'calendar' }} md="calendar_month" />
        <NativeTabs.Trigger.Label>{data.settings.language === 'ru' ? 'Календарь' : 'Calendar'}</NativeTabs.Trigger.Label>
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="health">
        <NativeTabs.Trigger.Icon sf={{ default: 'heart', selected: 'heart.fill' }} md="health_metrics" />
        <NativeTabs.Trigger.Label>{data.settings.language === 'ru' ? 'Здоровье' : 'Health'}</NativeTabs.Trigger.Label>
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="notes">
        <NativeTabs.Trigger.Icon sf={{ default: 'note.text', selected: 'note.text' }} md="note" />
        <NativeTabs.Trigger.Label>{data.settings.language === 'ru' ? 'Заметки' : 'Notes'}</NativeTabs.Trigger.Label>
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="coach">
        <NativeTabs.Trigger.Icon sf={{ default: 'wand.and.sparkles', selected: 'wand.and.sparkles' }} md="psychology_alt" />
        <NativeTabs.Trigger.Label>{t('coach')}</NativeTabs.Trigger.Label>
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="profile">
        <NativeTabs.Trigger.Icon sf={{ default: 'person.crop.circle', selected: 'person.crop.circle.fill' }} md="account_circle" />
        <NativeTabs.Trigger.Label>{t('me')}</NativeTabs.Trigger.Label>
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="goals" hidden />
      <NativeTabs.Trigger name="progress" hidden />
    </NativeTabs>
  );
}
