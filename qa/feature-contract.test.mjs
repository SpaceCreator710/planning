import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '..');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');
const exists = (relativePath) => fs.existsSync(path.join(root, relativePath));
const contains = (relativePath, value, message = `${relativePath} must contain ${value}`) => {
  assert.ok(read(relativePath).includes(value), message);
};

// Netlify repository contract: npm and the build config must both live at the
// archive/repository root, not only inside a generated dist folder.
assert.ok(exists('package.json'), 'package.json must be at repository root');
assert.ok(exists('package-lock.json'), 'package-lock.json must be at repository root');
assert.ok(exists('netlify.toml'), 'netlify.toml must be at repository root');
assert.ok(exists('netlify/functions/ai.mjs'), 'AI function must ship with the project');
contains('netlify.toml', 'base = "."');
contains('netlify.toml', 'command = "npm run export:web"');
contains('netlify.toml', 'publish = "dist"');

// The structured-output-capable Groq model is fixed on the protected route.
// Production secrets must never be exposed as EXPO_PUBLIC variables.
const model = 'openai/gpt-oss-120b';
contains('netlify/functions/ai.mjs', model);
contains('.env.example', 'GROQ_API_KEY=');
assert.doesNotMatch(read('.env.example'), /EXPO_PUBLIC_GROQ|EXPO_PUBLIC_AI_KEY/);
assert.doesNotMatch(read('src/app/ai-setup.tsx'), /personal.*key|OpenRouter/i);

// Dedicated product areas and planning horizons.
for (const tab of ['today', 'calendar', 'health', 'notes', 'coach', 'profile']) {
  assert.ok(exists(`src/app/(tabs)/${tab}.tsx`), `Missing ${tab} tab`);
}
for (const horizon of ["'day'", "'week'", "'month'", "'year'"]) {
  contains('src/app/horizon-planner.tsx', horizon);
}

// Apple platform connections plus portable in-app fallbacks.
const appConfig = JSON.parse(read('app.json'));
assert.equal(appConfig.expo.ios.entitlements['com.apple.developer.healthkit'], true);
assert.ok(appConfig.expo.plugins.some((plugin) => Array.isArray(plugin) && plugin[0] === 'expo-calendar'));
assert.ok(appConfig.expo.plugins.some((plugin) => Array.isArray(plugin) && plugin[0] === 'expo-sharing'));
assert.ok(appConfig.expo.plugins.some((plugin) => Array.isArray(plugin) && plugin[0] === 'expo-widgets'));
contains('src/services/device-calendar.ts', 'syncDeviceCalendar');
contains('src/services/device-calendar.ts', 'exportPlanToDeviceCalendar');
contains('src/services/device-calendar.ts', 'await existing.update');
contains('src/services/device-calendar.ts', 'await event.delete');
contains('src/context/app-context.tsx', 'replaceExternalRange');
contains('src/app/(tabs)/health.tsx', 'Save health check-in');
contains('src/app/(tabs)/health.tsx', 'Recent health history');
for (const healthType of ['stepCount', 'appleExerciseTime', 'appleStandTime', 'distanceWalkingRunning', 'restingHeartRate', 'sleepAnalysis']) {
  contains('modules/capacity-health/ios/CapacityHealthModule.swift', healthType);
}
contains('src/app/(tabs)/notes.tsx', 'Saved from Apple Notes');

// Visual language, motion and ADHD-friendly customization.
const tokens = read('src/constants/tokens.ts');
assert.ok((tokens.match(/solid:/g) ?? []).length >= 10, 'At least ten task colors are required');
for (const canvas of ['paper', 'blush', 'mist', 'sage', 'lavender', 'midnight']) assert.ok(tokens.includes(`${canvas}:`));
contains('src/components/app/task-card.tsx', 'LinearTransition.springify()');
contains('src/components/app/task-card.tsx', 'Gesture.Pan()');
contains('src/components/app/sliding-segmented-control.tsx', 'withSpring');
contains('src/components/app/task-card.tsx', 'backgroundColor: active ? colors.accent : tone.solid');
contains('src/services/task-appearance.ts', "'figure.yoga'");
contains('src/app/plan-builder.tsx', 'plannedTasks');
contains('src/app/task-editor.tsx', "'monthly', 'yearly'");

// Commercial split and the two differentiated planning systems.
const subscriptions = read('src/constants/subscriptions.ts');
for (const price of ['monthlyPrice: 2.99', 'annualPrice: 17.99', 'monthlyPrice: 5.99', 'annualPrice: 26.99', 'monthlyPrice: 129.99']) {
  assert.ok(subscriptions.includes(price), `Missing catalog value ${price}`);
}
assert.ok(exists('src/services/capacity-twin.ts'));
contains('src/services/capacity-twin.ts', 'detectScheduleCollisions');
contains('netlify/functions/ai.mjs', 'Never insult, humiliate, shame, threaten');

// App Store text limits and release-name hygiene.
const listing = read('docs/APP_STORE_LISTING_RU.txt');
const promotionalText = listing.match(/PROMOTIONAL TEXT[^\n]*\n([^\n]+)/)?.[1] ?? '';
const description = listing.split('DESCRIPTION\n')[1]?.trim() ?? '';
const hook = description.split(/\n\n/)[0]?.trim() ?? '';
assert.ok(promotionalText.length > 0 && promotionalText.length <= 170, `Promotional text is ${promotionalText.length} characters`);
assert.ok(description.length > 0 && description.length <= 4000, `Description is ${description.length} characters`);
assert.ok(hook.length >= 225 && hook.length <= 255, `Hook is ${hook.length} characters`);

const versionScanFiles = [
  'README.md',
  'DEPLOY_AI_RU.md',
  'WEB_DEPLOY_RU.md',
  'TEST_ON_IPHONE_RU.md',
  'RELEASE_REPORT.md',
  ...fs.readdirSync(path.join(root, 'docs')).filter((name) => /\.(md|txt)$/.test(name)).map((name) => `docs/${name}`),
];
const brandingText = versionScanFiles
  .map((relativePath) => read(relativePath))
  .join('\n');
assert.doesNotMatch(brandingText, /\bV\d+(?:\.\d+)*\b/i, 'Release-version branding must not appear in user-facing documents');

console.log('Feature contract tests passed.');
