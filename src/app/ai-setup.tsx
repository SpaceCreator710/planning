import { router } from 'expo-router';
import React, { useEffect, useState } from 'react';
import { Linking, ScrollView, View } from 'react-native';

import { AppButton } from '@/components/app/app-button';
import { AppInput } from '@/components/app/app-input';
import { AppText } from '@/components/app/app-text';
import { Card } from '@/components/app/card';
import { Chip } from '@/components/app/chip';
import { spacing } from '@/constants/tokens';
import { useAppTheme } from '@/context/theme-context';
import { checkAIConnection } from '@/services/ai-client';
import {
  hasPersonalOpenRouterKey,
  removePersonalOpenRouterKey,
  savePersonalOpenRouterKey,
  testPersonalOpenRouterKey,
} from '@/services/openrouter-client';

export default function AISetupScreen() {
  const { colors } = useAppTheme();
  const [key, setKey] = useState('');
  const [connected, setConnected] = useState(false);
  const [testing, setTesting] = useState(false);
  const [message, setMessage] = useState('Checking available AI paths…');

  useEffect(() => {
    let active = true;
    void Promise.all([hasPersonalOpenRouterKey(), checkAIConnection()]).then(([personal, server]) => {
      if (!active) return;
      setConnected(personal || server.status === 'online');
      setMessage(server.status === 'online' ? server.message : personal ? 'A personal test key is saved on this device.' : server.message);
    });
    return () => {
      active = false;
    };
  }, []);

  async function connect() {
    setTesting(true);
    const result = await testPersonalOpenRouterKey(key);
    if (result.ok) {
      await savePersonalOpenRouterKey(key);
      setKey('');
      setConnected(true);
    }
    setMessage(result.message);
    setTesting(false);
  }

  async function disconnect() {
    await removePersonalOpenRouterKey();
    const server = await checkAIConnection();
    setConnected(server.status === 'online');
    setMessage(server.status === 'online' ? server.message : 'Personal test key removed. The protected server is not ready yet.');
  }

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
        <AppText variant="title">Connect AI</AppText>
        <AppText tone="secondary">Use the protected server for a public release. For private testing, connect one personal OpenRouter key on this device.</AppText>
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

      <Card>
        <View style={{ gap: spacing.xs }}>
          <AppText variant="label">Personal OpenRouter key</AppText>
          <AppInput
            value={key}
            onChangeText={setKey}
            placeholder="sk-or-v1-…"
            secureTextEntry
            autoCapitalize="none"
            autoCorrect={false}
          />
          <AppText variant="caption" tone="tertiary">
            {process.env.EXPO_OS === 'web'
              ? 'Web keeps it only in this browser tab. Closing the tab removes it.'
              : 'iPhone stores it in Keychain/SecureStore for private testing.'}
          </AppText>
        </View>
        <AppButton title="Test and connect" loading={testing} onPress={() => void connect()} />
        <AppButton title="Create key on OpenRouter" variant="secondary" onPress={() => void Linking.openURL('https://openrouter.ai/settings/keys')} />
      </Card>

      <Card muted>
        <AppText variant="label">Public-release rule</AppText>
        <AppText variant="small" tone="secondary">Never place the key in app code, a ZIP, GitHub, or an EXPO_PUBLIC variable. The release server reads OPENROUTER_API_KEY privately and applies user limits before forwarding requests.</AppText>
        <AppButton title="Check protected server now" variant="secondary" loading={testing} onPress={() => void checkServer()} />
      </Card>

      <AppButton title="Remove personal test key" variant="danger" onPress={() => void disconnect()} />
      <AppButton title="Done" variant="secondary" onPress={() => router.dismiss()} />
    </ScrollView>
  );
}
