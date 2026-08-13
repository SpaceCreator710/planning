import { router } from 'expo-router';
import React, { useState } from 'react';
import { Alert, KeyboardAvoidingView, ScrollView, View } from 'react-native';

import { AppButton } from '@/components/app/app-button';
import { AppInput } from '@/components/app/app-input';
import { AppText } from '@/components/app/app-text';
import { BrandMark } from '@/components/app/brand-mark';
import { Card } from '@/components/app/card';
import { spacing } from '@/constants/tokens';
import { useApp } from '@/context/app-context';
import { useAuth } from '@/context/auth-context';
import { useAppTheme } from '@/context/theme-context';

export default function WelcomeScreen() {
  const { colors } = useAppTheme();
  const { data } = useApp();
  const { enterGuest, signInWithOAuth, sendMagicLink, error, clearError } = useAuth();
  const [email, setEmail] = useState('');
  const [sending, setSending] = useState(false);
  const [sent, setSent] = useState(false);

  const finish = () => router.replace(data.profile.onboardingCompleted ? '/(tabs)/today' : '/onboarding');

  async function oauth(provider: 'google' | 'github' | 'apple') {
    clearError();
    const ok = await signInWithOAuth(provider);
    if (ok) finish();
  }

  async function magicLink() {
    if (!/^\S+@\S+\.\S+$/.test(email.trim())) {
      Alert.alert('Check your email', 'Enter a valid email address.');
      return;
    }
    setSending(true);
    const ok = await sendMagicLink(email);
    setSending(false);
    if (ok) setSent(true);
  }

  return (
    <KeyboardAvoidingView style={{ flex: 1 }} behavior={process.env.EXPO_OS === 'ios' ? 'padding' : undefined}>
      <ScrollView
        contentInsetAdjustmentBehavior="automatic"
        keyboardShouldPersistTaps="handled"
        contentContainerStyle={{ flexGrow: 1, padding: spacing.xl, gap: spacing.xl, backgroundColor: colors.background }}>
        <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center', gap: spacing.md, paddingTop: spacing.huge }}>
          <BrandMark size={72} />
          <View style={{ alignItems: 'center', gap: spacing.xs }}>
            <AppText variant="title" style={{ textAlign: 'center' }}>
              AI Plan Your Day
            </AppText>
            <AppText tone="secondary" style={{ textAlign: 'center', maxWidth: 420 }}>
              A coach that plans the day, catches the slip, and gets you moving again.
            </AppText>
          </View>
        </View>

        <Card style={{ gap: spacing.sm, maxWidth: 520, width: '100%', alignSelf: 'center' }}>
          <AppButton title="Continue with Google" variant="secondary" icon="globe" onPress={() => oauth('google')} />
          <AppButton title="Continue with Apple" variant="secondary" icon="apple.logo" onPress={() => oauth('apple')} />
          <AppButton title="Continue with GitHub" variant="secondary" icon="chevron.left.forwardslash.chevron.right" onPress={() => oauth('github')} />

          <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.sm, paddingVertical: spacing.xs }}>
            <View style={{ flex: 1, height: 1, backgroundColor: colors.divider }} />
            <AppText variant="caption" tone="tertiary">
              OR USE EMAIL
            </AppText>
            <View style={{ flex: 1, height: 1, backgroundColor: colors.divider }} />
          </View>

          {sent ? (
            <View style={{ padding: spacing.md, borderRadius: 16, backgroundColor: colors.successSoft, gap: 4 }}>
              <AppText variant="label" tone="success">
                Magic Link sent
              </AppText>
              <AppText variant="small" tone="secondary">
                Open the email on this device to finish signing in.
              </AppText>
            </View>
          ) : (
            <>
              <AppInput
                value={email}
                onChangeText={setEmail}
                autoCapitalize="none"
                autoComplete="email"
                keyboardType="email-address"
                placeholder="you@example.com"
                returnKeyType="send"
                onSubmitEditing={magicLink}
              />
              <AppButton title="Send Magic Link" loading={sending} onPress={magicLink} />
            </>
          )}

          <AppButton
            title="Try without account"
            variant="ghost"
            onPress={() => {
              enterGuest();
              finish();
            }}
          />
          {error ? (
            <AppText variant="small" tone="accent" style={{ textAlign: 'center' }}>
              {error}
            </AppText>
          ) : null}
        </Card>

        <AppText variant="caption" tone="tertiary" style={{ textAlign: 'center', maxWidth: 520, alignSelf: 'center' }}>
          By continuing, you agree to the Terms and acknowledge the Privacy Policy. The coach supports productivity and is not medical care.
        </AppText>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}
