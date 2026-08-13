import type { Session, User } from '@supabase/supabase-js';
import * as AppleAuthentication from 'expo-apple-authentication';
import * as Crypto from 'expo-crypto';
import * as Linking from 'expo-linking';
import * as WebBrowser from 'expo-web-browser';
import React, { createContext, useCallback, useEffect, useMemo, useState } from 'react';

import { appStorage } from '@/lib/app-storage';
import { isSupabaseConfigured, supabase } from '@/lib/supabase';

WebBrowser.maybeCompleteAuthSession();

type OAuthProvider = 'google' | 'github' | 'apple';
type AuthMode = 'none' | 'guest' | 'account';

interface AuthContextValue {
  mode: AuthMode;
  session: Session | null;
  user: User | null;
  loading: boolean;
  configured: boolean;
  error?: string;
  enterGuest: () => void;
  signInWithOAuth: (provider: OAuthProvider) => Promise<boolean>;
  sendMagicLink: (email: string) => Promise<boolean>;
  signOut: () => Promise<void>;
  clearError: () => void;
}

const AuthContext = createContext<AuthContextValue | null>(null);
const GUEST_MODE_KEY = 'ai-plan-your-day:guest-mode';

function parseAuthUrl(url: string) {
  const normalized = url.includes('#') ? url.replace('#', url.includes('?') ? '&' : '?') : url;
  const parsed = new URL(normalized);
  return {
    code: parsed.searchParams.get('code'),
    accessToken: parsed.searchParams.get('access_token'),
    refreshToken: parsed.searchParams.get('refresh_token'),
  };
}

export function AuthProvider({ children }: React.PropsWithChildren) {
  const [mode, setMode] = useState<AuthMode>('none');
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string>();

  const completeAuthUrl = useCallback(async (url: string) => {
    if (!supabase) return false;
    const values = parseAuthUrl(url);
    if (values.code) {
      const { data, error: exchangeError } = await supabase.auth.exchangeCodeForSession(values.code);
      if (exchangeError) throw exchangeError;
      setSession(data.session);
      setMode('account');
      await appStorage.removeItem(GUEST_MODE_KEY);
      return true;
    }
    if (values.accessToken && values.refreshToken) {
      const { data, error: sessionError } = await supabase.auth.setSession({
        access_token: values.accessToken,
        refresh_token: values.refreshToken,
      });
      if (sessionError) throw sessionError;
      setSession(data.session);
      setMode('account');
      await appStorage.removeItem(GUEST_MODE_KEY);
      return true;
    }
    return false;
  }, []);

  useEffect(() => {
    let mounted = true;
    void (async () => {
      try {
        if (supabase) {
          const { data } = await supabase.auth.getSession();
          if (!mounted) return;
          setSession(data.session);
          if (data.session) {
            setMode('account');
            await appStorage.removeItem(GUEST_MODE_KEY);
          } else if ((await appStorage.getItem(GUEST_MODE_KEY)) === 'true') setMode('guest');
        } else if ((await appStorage.getItem(GUEST_MODE_KEY)) === 'true') {
          setMode('guest');
        }
      } catch {
        // Sign-in can be retried from the welcome screen; never block app startup.
      } finally {
        if (mounted) setLoading(false);
      }
    })();
    const listener = supabase?.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession);
      if (nextSession) {
        setMode('account');
        appStorage.removeItem(GUEST_MODE_KEY).catch(() => undefined);
      } else setMode((current) => (current === 'account' ? 'none' : current));
    });
    return () => {
      mounted = false;
      listener?.data.subscription.unsubscribe();
    };
  }, []);

  useEffect(() => {
    if (!supabase) return;
    const onUrl = ({ url }: { url: string }) => {
      completeAuthUrl(url).catch((nextError) => setError(nextError.message));
    };
    const listener = Linking.addEventListener('url', onUrl);
    Linking.getInitialURL().then((url) => {
      if (url) onUrl({ url });
    });
    return () => listener.remove();
  }, [completeAuthUrl]);

  const enterGuest = useCallback(() => {
    setError(undefined);
    setMode('guest');
    appStorage.setItem(GUEST_MODE_KEY, 'true').catch(() => undefined);
  }, []);

  const oauthFlow = useCallback(async (provider: OAuthProvider) => {
    if (!supabase) {
      setError('Account sign-in is temporarily unavailable. You can continue without an account.');
      return false;
    }
    const redirectTo = Linking.createURL('auth/callback');
    const { data, error: oauthError } = await supabase.auth.signInWithOAuth({
      provider,
      options: { redirectTo, skipBrowserRedirect: true },
    });
    if (oauthError) throw oauthError;
    if (!data.url) throw new Error('The authentication provider did not return a sign-in URL.');
    const result = await WebBrowser.openAuthSessionAsync(data.url, redirectTo);
    if (result.type !== 'success') return false;
    return completeAuthUrl(result.url);
  }, [completeAuthUrl]);

  const signInWithOAuth = useCallback(
    async (provider: OAuthProvider) => {
      setError(undefined);
      try {
        if (provider === 'apple' && process.env.EXPO_OS === 'ios' && supabase) {
          const available = await AppleAuthentication.isAvailableAsync();
          if (available) {
            const rawNonce = `${Crypto.randomUUID()}-${Date.now()}`;
            const hashedNonce = await Crypto.digestStringAsync(
              Crypto.CryptoDigestAlgorithm.SHA256,
              rawNonce,
            );
            const credential = await AppleAuthentication.signInAsync({
              requestedScopes: [
                AppleAuthentication.AppleAuthenticationScope.FULL_NAME,
                AppleAuthentication.AppleAuthenticationScope.EMAIL,
              ],
              nonce: hashedNonce,
            });
            if (!credential.identityToken) throw new Error('Apple did not return an identity token.');
            const { data, error: appleError } = await supabase.auth.signInWithIdToken({
              provider: 'apple',
              token: credential.identityToken,
              nonce: rawNonce,
            });
            if (appleError) throw appleError;
            setSession(data.session);
            setMode('account');
            await appStorage.removeItem(GUEST_MODE_KEY);
            return true;
          }
        }
        return await oauthFlow(provider);
      } catch (nextError) {
        const message = nextError instanceof Error ? nextError.message : 'Sign-in failed.';
        setError(message);
        return false;
      }
    },
    [oauthFlow],
  );

  const sendMagicLink = useCallback(async (email: string) => {
    setError(undefined);
    if (!supabase) {
      setError('Email sign-in is temporarily unavailable. You can continue without an account.');
      return false;
    }
    try {
      const redirectTo = Linking.createURL('auth/callback');
      const { error: magicLinkError } = await supabase.auth.signInWithOtp({
        email: email.trim(),
        options: { emailRedirectTo: redirectTo },
      });
      if (magicLinkError) throw magicLinkError;
      return true;
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : 'Could not send Magic Link.');
      return false;
    }
  }, []);

  const signOut = useCallback(async () => {
    if (supabase && session) await supabase.auth.signOut();
    await appStorage.removeItem(GUEST_MODE_KEY);
    setSession(null);
    setMode('none');
  }, [session]);

  const value = useMemo<AuthContextValue>(
    () => ({
      mode,
      session,
      user: session?.user ?? null,
      loading,
      configured: isSupabaseConfigured,
      error,
      enterGuest,
      signInWithOAuth,
      sendMagicLink,
      signOut,
      clearError: () => setError(undefined),
    }),
    [mode, session, loading, error, enterGuest, signInWithOAuth, sendMagicLink, signOut],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const value = React.use(AuthContext);
  if (!value) throw new Error('useAuth must be used inside AuthProvider');
  return value;
}
