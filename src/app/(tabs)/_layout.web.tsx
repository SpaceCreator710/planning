import { Tabs } from 'expo-router';
import React from 'react';
import type { ColorValue } from 'react-native';

import { AppIcon } from '@/components/app/app-icon';
import { translate } from '@/constants/translations';
import { useApp } from '@/context/app-context';
import { useAppTheme } from '@/context/theme-context';

function TabGlyph({ name, fallback, color, focused }: { name: Parameters<typeof AppIcon>[0]['name']; fallback: string; color: ColorValue; focused: boolean }) {
  return <AppIcon name={name} fallback={fallback} color={color} size={21} animated={focused} />;
}

export default function WebTabsLayout() {
  const { colors } = useAppTheme();
  const { data } = useApp();
  const t = (key: Parameters<typeof translate>[1]) => translate(data.settings.language, key);
  return (
    <Tabs
      screenOptions={{
        animation: 'fade',
        headerStyle: { backgroundColor: colors.background },
        headerShadowVisible: false,
        headerTintColor: colors.text,
        headerTitleStyle: { fontWeight: '800' },
        sceneStyle: { backgroundColor: colors.background },
        tabBarStyle: {
          position: 'absolute',
          left: 12,
          right: 12,
          bottom: 10,
          backgroundColor: colors.tabBar,
          borderTopWidth: 0,
          borderRadius: 28,
          height: 70,
          paddingTop: 7,
          boxShadow: '0 10px 36px rgba(0,0,0,0.16)',
        },
        tabBarHideOnKeyboard: true,
        tabBarActiveTintColor: colors.accent,
        tabBarInactiveTintColor: colors.textTertiary,
        tabBarLabelStyle: { fontSize: 11, fontWeight: '700' },
      }}>
      <Tabs.Screen name="today" options={{ title: t('today'), tabBarIcon: ({ color, focused }) => <TabGlyph name="sparkles" fallback="•" color={color} focused={focused} /> }} />
      <Tabs.Screen name="calendar" options={{ title: data.settings.language === 'ru' ? 'Календарь' : 'Calendar', tabBarIcon: ({ color, focused }) => <TabGlyph name="calendar" fallback="•" color={color} focused={focused} /> }} />
      <Tabs.Screen name="health" options={{ title: data.settings.language === 'ru' ? 'Здоровье' : 'Health', tabBarIcon: ({ color, focused }) => <TabGlyph name="heart.text.clipboard" fallback="•" color={color} focused={focused} /> }} />
      <Tabs.Screen name="notes" options={{ title: data.settings.language === 'ru' ? 'Заметки' : 'Notes', tabBarIcon: ({ color, focused }) => <TabGlyph name="note.text" fallback="•" color={color} focused={focused} /> }} />
      <Tabs.Screen name="coach" options={{ title: t('coach'), tabBarIcon: ({ color, focused }) => <TabGlyph name="wand.and.sparkles" fallback="•" color={color} focused={focused} /> }} />
      <Tabs.Screen name="profile" options={{ title: t('me'), tabBarIcon: ({ color, focused }) => <TabGlyph name="person.crop.circle" fallback="•" color={color} focused={focused} /> }} />
      <Tabs.Screen name="goals" options={{ href: null }} />
      <Tabs.Screen name="progress" options={{ href: null }} />
    </Tabs>
  );
}
