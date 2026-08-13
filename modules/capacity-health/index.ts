import { requireNativeModule } from 'expo';

export interface NativeHealthSnapshot {
  available: boolean;
  startDate: string;
  endDate: string;
  sleepHours: number;
  steps: number;
  exerciseMinutes: number;
  standMinutes: number;
  distanceKilometers: number;
  restingHeartRate?: number;
  workoutCount: number;
  workoutMinutes: number;
  lastUpdated: string;
}

interface CapacityHealthNativeModule {
  isAvailable(): boolean;
  requestAuthorization(): Promise<boolean>;
  readSnapshot(startDate: string, endDate: string): Promise<NativeHealthSnapshot>;
}

export default requireNativeModule<CapacityHealthNativeModule>('CapacityHealth');
