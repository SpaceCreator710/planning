export async function resolve(specifier, context, nextResolve) {
  if (specifier === 'expo/fetch') {
    return { url: new URL('./expo-fetch-shim.mjs', import.meta.url).href, shortCircuit: true };
  }
  if (specifier.startsWith('@/')) {
    const path = specifier.slice(2);
    return {
      url: new URL(`../src/${path}.ts`, import.meta.url).href,
      shortCircuit: true,
    };
  }
  return nextResolve(specifier, context);
}
