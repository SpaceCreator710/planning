import * as WebBrowser from 'expo-web-browser';

import type { SubscriptionTier } from '@/types/app';

export type CheckoutProvider = 'paypal' | 'card' | 'ru-card';

const checkoutUrls: Record<CheckoutProvider, string | undefined> = {
  paypal: process.env.EXPO_PUBLIC_PAYPAL_CHECKOUT_URL,
  card: process.env.EXPO_PUBLIC_CARD_CHECKOUT_URL,
  'ru-card': process.env.EXPO_PUBLIC_RU_CHECKOUT_URL,
};

export async function openConfiguredCheckout(provider: CheckoutProvider, tier: SubscriptionTier) {
  const baseUrl = checkoutUrls[provider]?.trim();
  if (!baseUrl) {
    return {
      ok: false,
      message: 'This checkout needs a merchant account and a server-created checkout URL.',
    };
  }
  const separator = baseUrl.includes('?') ? '&' : '?';
  await WebBrowser.openBrowserAsync(`${baseUrl}${separator}plan=${tier}`);
  return { ok: true, message: 'Checkout opened.' };
}

export function billingChannelForPlatform() {
  if (process.env.EXPO_OS === 'ios') return 'App Store In-App Purchase';
  if (process.env.EXPO_OS === 'android') return 'Google Play Billing';
  return 'Secure web checkout';
}
