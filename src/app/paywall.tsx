import { router } from 'expo-router';
import React, { useState } from 'react';
import { Alert, ScrollView, View } from 'react-native';

import { AppButton } from '@/components/app/app-button';
import { AppIcon } from '@/components/app/app-icon';
import { AppText } from '@/components/app/app-text';
import { Card } from '@/components/app/card';
import { Chip } from '@/components/app/chip';
import { subscriptionPlans } from '@/constants/subscriptions';
import { spacing } from '@/constants/tokens';
import { useApp } from '@/context/app-context';
import { useAppTheme } from '@/context/theme-context';
import { billingChannelForPlatform, openConfiguredCheckout, type CheckoutProvider } from '@/services/billing';
import type { SubscriptionTier } from '@/types/app';

const order: SubscriptionTier[] = ['free', 'plus', 'pro', 'max'];

export default function PaywallScreen() {
  const { colors } = useAppTheme();
  const { data, setSubscription } = useApp();
  const [annual, setAnnual] = useState(true);
  const [selected, setSelected] = useState<SubscriptionTier>(data.subscription === 'free' ? 'plus' : data.subscription);
  const plan = subscriptionPlans[selected];
  const demoBilling = process.env.EXPO_PUBLIC_DEMO_BILLING !== 'false';

  function activateDemo() {
    if (!demoBilling) {
      Alert.alert('Store billing required', 'Connect verified App Store / Google Play entitlements before selling this subscription.');
      return;
    }
    setSubscription(selected);
    Alert.alert('Demo entitlement activated', `${plan.name} features are unlocked locally for testing. No payment was made.`, [
      { text: 'Continue', onPress: () => router.dismiss() },
    ]);
  }

  async function checkout(provider: CheckoutProvider) {
    const result = await openConfiguredCheckout(provider, selected);
    if (!result.ok) Alert.alert('Merchant setup required', result.message);
  }

  return (
    <ScrollView contentInsetAdjustmentBehavior="automatic" contentContainerStyle={{ padding: spacing.lg, paddingBottom: 80, gap: spacing.xl }}>
      <View style={{ alignItems: 'center', gap: spacing.sm }}>
        <Chip label={demoBilling ? 'DEMO CATALOG · NO CHARGE' : 'SUBSCRIPTION CATALOG'} selected color={colors.success} />
        <AppText variant="title" style={{ textAlign: 'center' }}>
          Pay for a better action system — not more clutter
        </AppText>
        <AppText tone="secondary" style={{ textAlign: 'center', maxWidth: 560 }}>
          Free is a real planner. Plus adds Apple device sync and widgets, Pro adds deep adaptation, and Lifetime unlocks the complete system with one $129.99 purchase.
        </AppText>
        <View style={{ flexDirection: 'row', gap: spacing.xs }}>
          <Chip label="Monthly" selected={!annual} onPress={() => setAnnual(false)} />
          <Chip label="Annual · best value" selected={annual} color={colors.success} onPress={() => setAnnual(true)} />
        </View>
      </View>

      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: spacing.sm }}>
        {order.map((tier) => {
          const item = subscriptionPlans[tier];
          const active = selected === tier;
          const lifetime = tier === 'max';
          const price = lifetime ? item.annualPrice : annual ? item.annualPrice : item.monthlyPrice;
          const displayMonthly = lifetime ? item.annualPrice : annual && tier !== 'free' ? item.annualPrice / 12 : item.monthlyPrice;
          return (
            <Card
              key={tier}
              style={{
                width: 255,
                minHeight: 330,
                borderColor: active ? item.accent : colors.border,
                borderWidth: active ? 2 : 1,
                backgroundColor: active ? `${item.accent}10` : colors.surface,
              }}>
              <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
                <AppText variant="heading" style={{ color: item.accent }}>
                  {item.name}
                </AppText>
                {tier === data.subscription ? <Chip label="CURRENT" selected color={item.accent} /> : null}
              </View>
              <View>
                <AppText variant="display" style={{ fontSize: 34, color: item.accent, fontVariant: ['tabular-nums'] }}>
                  ${displayMonthly.toFixed(tier === 'free' ? 0 : 2)}
                </AppText>
                <AppText variant="caption" tone="secondary">
                  {tier === 'free' ? 'forever' : lifetime ? 'one-time · no renewal' : annual ? `$${price.toFixed(2)} billed yearly` : 'per month'}
                </AppText>
              </View>
              <AppText variant="small" style={{ fontWeight: '700' }}>
                {item.tagline}
              </AppText>
              <View style={{ gap: spacing.xs, flex: 1 }}>
                {item.headlineFeatures.map((feature) => (
                  <View key={feature} style={{ flexDirection: 'row', gap: spacing.xs }}>
                    <AppIcon name="checkmark.circle.fill" fallback="✓" color={item.accent} size={16} />
                    <AppText variant="small" style={{ flex: 1 }}>
                      {feature}
                    </AppText>
                  </View>
                ))}
              </View>
              <AppButton
                title={active ? 'Selected' : 'Choose'}
                compact
                variant={active ? 'primary' : 'secondary'}
                onPress={() => setSelected(tier)}
              />
            </Card>
          );
        })}
      </ScrollView>

      <Card style={{ borderColor: plan.accent, backgroundColor: `${plan.accent}0D` }}>
        <View style={{ flexDirection: 'row', justifyContent: 'space-between', gap: spacing.sm }}>
          <View style={{ flex: 1 }}>
            <AppText variant="caption" style={{ color: plan.accent }}>
              {plan.name.toUpperCase()} INCLUDES
            </AppText>
            <AppText variant="heading">Everything you unlock</AppText>
          </View>
          <Chip label={`${plan.limits.memoryDays} memory days`} color={plan.accent} selected />
        </View>
        {plan.capabilities.map((feature) => (
          <View key={feature} style={{ flexDirection: 'row', gap: spacing.sm }}>
            <AppIcon name="checkmark.circle.fill" fallback="✓" color={plan.accent} size={16} />
            <AppText variant="small" style={{ flex: 1 }}>
              {feature}
            </AppText>
          </View>
        ))}
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.xs, paddingTop: spacing.xs }}>
          <Chip label={`${plan.limits.coachMessagesPerDay} coach msgs/day`} />
          <Chip label={`${plan.limits.plansPerDay} plans/day`} />
          <Chip label={`${plan.limits.rescuesPerDay} rescues/day`} />
        </View>
      </Card>

      <View style={{ gap: spacing.sm }}>
        <AppButton
          title={selected === 'free' ? 'Use Free' : demoBilling ? `Activate ${plan.name} demo` : selected === 'max' ? 'Buy Lifetime once' : `Subscribe to ${plan.name}`}
          onPress={activateDemo}
          style={{ backgroundColor: plan.accent }}
        />
        <AppText variant="caption" tone="tertiary" style={{ textAlign: 'center' }}>
          {demoBilling
            ? 'Demo activation is local and makes no purchase. Production entitlements must come from a verified store receipt or server webhook.'
            : 'Purchases must be verified by the selected store or a signed server webhook before features unlock.'}
        </AppText>
      </View>

      <View style={{ gap: spacing.md }}>
        <AppText variant="heading">Production payment routes</AppText>
        <Card muted>
          <View style={{ gap: 3 }}>
            <AppText variant="label">Mobile: {billingChannelForPlatform()}</AppText>
            <AppText variant="small" tone="secondary">
              Digital subscriptions—and the one-time Lifetime unlock—use App Store or Google Play billing. Prices and currencies are localized by the store.
            </AppText>
          </View>
          <View style={{ gap: 3 }}>
            <AppText variant="label">Web: cards + PayPal</AppText>
            <AppText variant="small" tone="secondary">
              Server-created checkout pages can accept supported US and European cards plus PayPal after merchant verification.
            </AppText>
          </View>
          <View style={{ gap: 3 }}>
            <AppText variant="label">Russia: separate regional web provider</AppText>
            <AppText variant="small" tone="secondary">
              A Russian acquiring provider requires an eligible adult-owned merchant account and separate compliance. Google Play billing remains unavailable in Russia.
            </AppText>
          </View>
          {selected !== 'free' ? (
            <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.xs, paddingTop: spacing.xs }}>
              <AppButton title="PayPal setup" compact variant="secondary" onPress={() => checkout('paypal')} />
              <AppButton title="US / EU cards" compact variant="secondary" onPress={() => checkout('card')} />
              <AppButton title="RU cards" compact variant="secondary" onPress={() => checkout('ru-card')} />
            </View>
          ) : null}
        </Card>
      </View>

      <View style={{ flexDirection: 'row', justifyContent: 'center', flexWrap: 'wrap', gap: spacing.md }}>
        <AppText variant="caption" tone="tertiary">Restore purchases</AppText>
        <AppText variant="caption" tone="tertiary">Terms</AppText>
        <AppText variant="caption" tone="tertiary">Privacy</AppText>
      </View>
    </ScrollView>
  );
}
