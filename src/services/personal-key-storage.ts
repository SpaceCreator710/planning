const KEY_NAME = 'ai-plan-your-day:openrouter-test-key';

function session() {
  if (typeof globalThis.sessionStorage === 'undefined') return undefined;
  return globalThis.sessionStorage;
}

export async function savePersonalKey(value: string) {
  session()?.setItem(KEY_NAME, value);
}

export async function getPersonalKey() {
  return session()?.getItem(KEY_NAME) ?? null;
}

export async function removePersonalKey() {
  session()?.removeItem(KEY_NAME);
}
