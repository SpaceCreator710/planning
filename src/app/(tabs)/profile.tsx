import Constants from 'expo-constants';
import { router } from 'expo-router';
import React from 'react';
import { Pressable, ScrollView, View } from 'react-native';

import { AppButton } from '@/components/app/app-button';
import { AppIcon } from '@/components/app/app-icon';
import { AppText } from '@/components/app/app-text';
import { BrandMark } from '@/components/app/brand-mark';
import { Card } from '@/components/app/card';
import { subscriptionPlans } from '@/constants/subscriptions';
import { spacing } from '@/constants/tokens';
import { useApp } from '@/context/app-context';
import { useAuth } from '@/context/auth-context';
import { useAppTheme } from '@/context/theme-context';

export default function ProfileScreen() {
  const { colors } = useAppTheme();
  const { data, syncStatus } = useApp();
  const { mode, user, signOut } = useAuth();
  const subscription = subscriptionPlans[data.subscription];

  async function leave() {
    await signOut();
    router.replace('/welcome');
  }

  return (
    <ScrollView contentInsetAdjustmentBehavior="automatic" contentContainerStyle={{ padding: spacing.md, paddingBottom: 120, gap: spacing.xl }}>
      <View style={{ alignItems: 'center', gap: spacing.sm, paddingTop: spacing.sm }}>
        <BrandMark size={68} />
        <View style={{ alignItems: 'center', gap: 3 }}>
          <AppText variant="title">{data.profile.name || 'Your profile'}</AppText>
          <AppText variant="small" tone="secondary">
            {user?.email ?? (mode === 'guest' ? 'Guest mode · stored on this device' : 'AI accountability profile')}
          </AppText>
        </View>
        <View style={{ flexDirection: 'row', gap: spacing.xs }}>
          <Pill label={`${subscription.name} plan`} color={subscription.accent} />
          <Pill
            label={mode === 'account' ? (syncStatus === 'synced' ? 'Cloud synced' : syncStatus) : 'Local only'}
            color={mode === 'account' ? colors.success : colors.textTertiary}
          />
        </View>
      </View>

      <Pressable onPress={() => router.push('/paywall')}>
        <Card style={{ backgroundColor: `${subscription.accent}16`, borderColor: subscription.accent, flexDirection: 'row', alignItems: 'center' }}>
          <View style={{ flex: 1, gap: 3 }}>
            <AppText variant="caption" style={{ color: subscription.accent }}>
              CURRENT PLAN
            </AppText>
            <AppText variant="heading">{subscription.name}</AppText>
            <AppText variant="small" tone="secondary">
              {subscription.tagline}
            </AppText>
          </View>
          <AppIcon name="chevron.right" fallback="›" color={subscription.accent} size={20} />
        </Card>
      </Pressable>

      <View style={{ gap: spacing.sm }}>
        <AppText variant="caption" tone="tertiary">
          YOUR COACH
        </AppText>
        <Card style={{ gap: 0, padding: 0, overflow: 'hidden' }}>
          <MenuRow icon="brain.head.profile" title="AI memory" detail={`${data.memories.filter((memory) => memory.enabled).length} active facts`} onPress={() => router.push('/memory')} />
          <Divider />
          <MenuRow icon="target" title="Goals & habits" detail={data.profile.primaryGoal || 'Add your main goal'} onPress={() => router.push('/(tabs)/goals')} />
          <Divider />
          <MenuRow icon="chart.xyaxis.line" title="Progress & patterns" detail="Completion, consistency and real behavior" onPress={() => router.push('/(tabs)/progress')} />
          <Divider />
          <MenuRow icon="person.text.rectangle" title="Planning profile" detail="Goals, rhythm and preferences" onPress={() => router.push('/onboarding')} />
          <Divider />
          <MenuRow icon="slider.horizontal.3" title="Coach settings" detail={`${data.settings.coachMode} · ${data.settings.accountability}`} onPress={() => router.push('/settings')} />
        </Card>
      </View>

      <View style={{ gap: spacing.sm }}>
        <AppText variant="caption" tone="tertiary">
          PRIVACY & CONTROL
        </AppText>
        <Card style={{ gap: 0, padding: 0, overflow: 'hidden' }}>
          <MenuRow icon="key.horizontal.fill" title="Protected AI connection" detail="Server key or private personal test key" onPress={() => router.push('/ai-setup')} />
          <Divider />
          <MenuRow icon="link.badge.plus" title="Connected life" detail="Calendar, Health, Notes and widgets" onPress={() => router.push('/integrations')} />
          <Divider />
          <MenuRow icon="square.and.arrow.down" title="Data export" detail="Portable export is prepared for the account backend" />
          <Divider />
          <MenuRow icon="trash" title="Delete account data" detail="Available from Settings" onPress={() => router.push('/settings')} />
        </Card>
      </View>

      {mode === 'guest' ? (
        <Card style={{ backgroundColor: colors.infoSoft, borderColor: colors.info }}>
          <AppText variant="heading">Keep progress across devices</AppText>
          <AppText variant="small" tone="secondary">
            Connect an account after Supabase is configured. Your local guest data stays available until sync completes.
          </AppText>
          <AppButton title="Connect account" variant="secondary" onPress={() => router.push('/welcome')} />
        </Card>
      ) : null}

      <AppButton title={mode === 'guest' ? 'Exit guest mode' : 'Sign out'} variant="ghost" onPress={leave} />
      <AppText variant="caption" tone="tertiary" style={{ textAlign: 'center' }}>
        AI Plan Your Day {Constants.expoConfig?.version ?? '1.0.0'} · You control the plan.
      </AppText>
    </ScrollView>
  );

  function Divider() {
    return <View style={{ height: 1, backgroundColor: colors.divider, marginLeft: 56 }} />;
  }
}

function Pill({ label, color }: { label: string; color: string }) {
  return (
    <View style={{ borderRadius: 999, borderWidth: 1, borderColor: `${color}66`, paddingHorizontal: 10, paddingVertical: 5, backgroundColor: `${color}14` }}>
      <AppText variant="caption" style={{ color }}>
        {label}
      </AppText>
    </View>
  );
}

function MenuRow({ icon, title, detail, onPress }: { icon: Parameters<typeof AppIcon>[0]['name']; title: string; detail: string; onPress?: () => void }) {
  const { colors } = useAppTheme();
  return (
    <Pressable
      accessibilityRole={onPress ? 'button' : undefined}
      onPress={onPress}
      style={({ pressed }) => ({ flexDirection: 'row', alignItems: 'center', gap: spacing.sm, padding: spacing.md, opacity: pressed ? 0.65 : 1 })}>
      <View style={{ width: 28, alignItems: 'center' }}>
        <AppIcon name={icon} fallback="•" color={colors.accent} size={19} />
      </View>
      <View style={{ flex: 1, gap: 2 }}>
        <AppText variant="label">{title}</AppText>
        <AppText variant="caption" tone="secondary" numberOfLines={1}>
          {detail}
        </AppText>
      </View>
      {onPress ? <AppIcon name="chevron.right" fallback="›" color={colors.textTertiary} size={14} /> : null}
    </Pressable>
  );
}
