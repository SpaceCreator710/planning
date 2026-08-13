import { Redirect } from 'expo-router';
import React from 'react';
import { ActivityIndicator, View } from 'react-native';

import { BrandMark } from '@/components/app/brand-mark';
import { useApp } from '@/context/app-context';
import { useAuth } from '@/context/auth-context';
import { useAppTheme } from '@/context/theme-context';

export default function IndexScreen() {
  const { hydrated, data } = useApp();
  const { loading, mode } = useAuth();
  const { colors } = useAppTheme();

  if (!hydrated || loading) {
    return (
      <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.background, gap: 20 }}>
        <BrandMark size={64} />
        <ActivityIndicator color={colors.accent} />
      </View>
    );
  }
  if (mode === 'none') return <Redirect href="/welcome" />;
  if (!data.profile.onboardingCompleted) return <Redirect href="/onboarding" />;
  return <Redirect href="/(tabs)/today" />;
}
