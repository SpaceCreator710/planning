import { DarkTheme, DefaultTheme, ThemeProvider } from 'expo-router';
import { Stack } from 'expo-router/stack';
import * as SplashScreen from 'expo-splash-screen';
import { StatusBar } from 'expo-status-bar';
import React, { useEffect } from 'react';
import { GestureHandlerRootView } from 'react-native-gesture-handler';

import { DeviceSyncAgent } from '@/components/device-sync-agent';
import { AppProvider, useApp } from '@/context/app-context';
import { AuthProvider, useAuth } from '@/context/auth-context';
import { AppThemeProvider, useAppTheme } from '@/context/theme-context';

SplashScreen.preventAutoHideAsync();

function RootNavigator() {
  const { colors, isDark } = useAppTheme();
  const { hydrated } = useApp();
  const { loading } = useAuth();

  useEffect(() => {
    if (hydrated && !loading) SplashScreen.hideAsync().catch(() => undefined);
  }, [hydrated, loading]);

  const base = isDark ? DarkTheme : DefaultTheme;
  const navigationTheme = {
    ...base,
    colors: {
      ...base.colors,
      background: colors.background,
      card: colors.surface,
      text: colors.text,
      border: colors.border,
      primary: colors.accent,
    },
  };

  return (
    <ThemeProvider value={navigationTheme}>
      <StatusBar style={isDark ? 'light' : 'dark'} />
      <Stack
        screenOptions={{
          headerShadowVisible: false,
          headerTransparent: process.env.EXPO_OS === 'ios',
          headerBlurEffect: isDark ? 'systemMaterialDark' : 'systemMaterialLight',
          headerStyle: { backgroundColor: process.env.EXPO_OS === 'ios' ? 'transparent' : colors.background },
          headerTintColor: colors.text,
          headerBackButtonDisplayMode: 'minimal',
          contentStyle: { backgroundColor: colors.background },
          animation: 'ios_from_right',
          animationDuration: 300,
          fullScreenGestureEnabled: true,
          fullScreenGestureShadowEnabled: true,
        }}>
        <Stack.Screen name="index" options={{ headerShown: false }} />
        <Stack.Screen name="welcome" options={{ headerShown: false }} />
        <Stack.Screen name="onboarding" options={{ headerShown: false, gestureEnabled: false }} />
        <Stack.Screen name="(tabs)" options={{ headerShown: false, gestureEnabled: false }} />
        <Stack.Screen name="plan-builder" options={{ title: 'Build my day', presentation: 'modal', animation: 'slide_from_bottom' }} />
        <Stack.Screen name="rescue" options={{ title: 'Repair my day', presentation: 'formSheet', sheetGrabberVisible: true, sheetAllowedDetents: [0.9, 1], animation: 'slide_from_bottom', contentStyle: { backgroundColor: process.env.EXPO_OS === 'ios' ? 'transparent' : colors.background } }} />
        <Stack.Screen name="horizon-planner" options={{ title: 'AI roadmap' }} />
        <Stack.Screen name="calendar-view" options={{ title: 'Flow calendar' }} />
        <Stack.Screen name="integrations" options={{ title: 'Calendars & devices' }} />
        <Stack.Screen name="focus" options={{ title: 'Focus', presentation: 'modal', animation: 'slide_from_bottom' }} />
        <Stack.Screen name="inbox" options={{ title: 'Inbox' }} />
        <Stack.Screen name="task-editor" options={{ title: 'Task', presentation: 'formSheet', sheetGrabberVisible: true, sheetAllowedDetents: [0.9, 1], animation: 'slide_from_bottom', contentStyle: { backgroundColor: process.env.EXPO_OS === 'ios' ? 'transparent' : colors.background } }} />
        <Stack.Screen name="day-review" options={{ title: 'Close the day', presentation: 'formSheet', sheetGrabberVisible: true, sheetAllowedDetents: [0.75, 1], contentStyle: { backgroundColor: process.env.EXPO_OS === 'ios' ? 'transparent' : colors.background } }} />
        <Stack.Screen name="paywall" options={{ title: 'Choose your coach', presentation: 'modal' }} />
        <Stack.Screen name="memory" options={{ title: 'What AI knows' }} />
        <Stack.Screen name="ai-setup" options={{ title: 'Groq AI', presentation: 'formSheet', sheetGrabberVisible: true, sheetAllowedDetents: [0.85, 1], contentStyle: { backgroundColor: process.env.EXPO_OS === 'ios' ? 'transparent' : colors.background } }} />
        <Stack.Screen name="settings" options={{ title: 'Settings' }} />
        <Stack.Screen name="auth/callback" options={{ headerShown: false }} />
      </Stack>
    </ThemeProvider>
  );
}

export default function RootLayout() {
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <AuthProvider>
        <AppProvider>
          <AppThemeProvider>
            <DeviceSyncAgent />
            <RootNavigator />
          </AppThemeProvider>
        </AppProvider>
      </AuthProvider>
    </GestureHandlerRootView>
  );
}
