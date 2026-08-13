import type { DayPlan } from '@/types/app';

// Web and Android intentionally no-op. Metro substitutes widget-bridge.ios.ts
// for the native iOS implementation so SwiftUI code never enters a web bundle.
export function updateNextActionWidget(_plan: DayPlan | undefined, _accent: string) {}
