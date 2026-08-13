import { Redirect } from 'expo-router';
import React from 'react';
import { ActivityIndicator, View } from 'react-native';

import { AppText } from '@/components/app/app-text';
import { useAuth } from '@/context/auth-context';
import { useAppTheme } from '@/context/theme-context';

export default function AuthCallbackScreen() {
  const { mode, error } = useAuth();
  const { colors } = useAppTheme();
  if (mode === 'account') return <Redirect href="/" />;
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', gap: 16, backgroundColor: colors.background, padding: 24 }}>
      <ActivityIndicator color={colors.accent} />
      <AppText>{error ?? 'Finishing sign-in…'}</AppText>
    </View>
  );
}
