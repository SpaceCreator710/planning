import { router } from 'expo-router';
import React, { useEffect, useState } from 'react';
import { ScrollView, View } from 'react-native';

import { AppButton } from '@/components/app/app-button';
import { AppText } from '@/components/app/app-text';
import { Card } from '@/components/app/card';
import { Chip } from '@/components/app/chip';
import { spacing } from '@/constants/tokens';
import { useAppTheme } from '@/context/theme-context';
import { checkAIConnection } from '@/services/ai-client';

export default function AISetupScreen() {
  const { colors } = useAppTheme();
  const [connected, setConnected] = useState(false);
  const [testing, setTesting] = useState(false);
  const [message, setMessage] = useState('Checking the protected Groq server…');

  useEffect(() => {
    let active = true;
    void checkAIConnection().then((server) => {
      if (!active) return;
      setConnected(server.status === 'online');
      setMessage(server.message);
    });
    return () => {
      active = false;
    };
  }, []);

  async function checkServer() {
    setTesting(true);
    const server = await checkAIConnection();
    setConnected(server.status === 'online');
    setMessage(server.message);
    setTesting(false);
  }

  return (
    <ScrollView contentInsetAdjustmentBehavior="automatic" keyboardShouldPersistTaps="handled" contentContainerStyle={{ padding: spacing.lg, paddingBottom: 90, gap: spacing.xl }}>
      <View style={{ gap: spacing.xs }}>
        <AppText variant="title">Built-in AI</AppText>
        <AppText tone="secondary">The app uses one protected Groq connection. People never need to enter or pay for their own API key.</AppText>
      </View>

      <Card style={{ borderColor: connected ? colors.success : colors.warning, backgroundColor: connected ? colors.successSoft : colors.warningSoft }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.sm }}>
          <View style={{ flex: 1, gap: 3 }}>
            <AppText variant="label">{connected ? 'AI READY' : 'SETUP NEEDED'}</AppText>
            <AppText variant="small" tone="secondary">{message}</AppText>
          </View>
          <Chip label={connected ? 'CONNECTED' : 'OFFLINE'} selected={connected} color={connected ? colors.success : colors.warning} />
        </View>
      </Card>

      <Card muted>
        <AppText variant="label">Protected Groq connection</AppText>
        <AppText variant="small" tone="secondary">The release server reads GROQ_API_KEY privately and applies user limits before forwarding requests. The key is never shipped inside the app or shown to users.</AppText>
        <AppButton title="Check protected server now" variant="secondary" loading={testing} onPress={() => void checkServer()} />
      </Card>

      <AppButton title="Done" variant="secondary" onPress={() => router.dismiss()} />
    </ScrollView>
  );
}
