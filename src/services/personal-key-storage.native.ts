import * as SecureStore from 'expo-secure-store';

const KEY_NAME = 'ai-plan-your-day:openrouter-test-key';

export async function savePersonalKey(value: string) {
  await SecureStore.setItemAsync(KEY_NAME, value, {
    keychainAccessible: SecureStore.WHEN_UNLOCKED_THIS_DEVICE_ONLY,
  });
}

export async function getPersonalKey() {
  return SecureStore.getItemAsync(KEY_NAME);
}

export async function removePersonalKey() {
  await SecureStore.deleteItemAsync(KEY_NAME);
}
