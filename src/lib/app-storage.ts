import 'expo-sqlite/localStorage/install';

/**
 * Async-shaped wrapper keeps state code portable while Expo supplies a
 * SQLite-backed localStorage implementation on native and browser storage on
 * web. Authentication tokens remain in SecureStore via secure-storage.ts.
 */
export const appStorage = {
  async getItem(key: string) {
    return globalThis.localStorage.getItem(key);
  },
  async setItem(key: string, value: string) {
    globalThis.localStorage.setItem(key, value);
  },
  async removeItem(key: string) {
    globalThis.localStorage.removeItem(key);
  },
};
