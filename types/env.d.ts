declare namespace NodeJS {
  interface ProcessEnv {
    EXPO_PUBLIC_SUPABASE_URL?: string;
    EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY?: string;
    EXPO_PUBLIC_PAYPAL_CHECKOUT_URL?: string;
    EXPO_PUBLIC_CARD_CHECKOUT_URL?: string;
    EXPO_PUBLIC_RU_CHECKOUT_URL?: string;
    EXPO_PUBLIC_DEMO_BILLING?: string;
    EXPO_PUBLIC_AI_ENDPOINT?: string;
    EXPO_OS?: 'android' | 'ios' | 'web';
  }
}
