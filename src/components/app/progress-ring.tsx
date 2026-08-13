import React from 'react';
import { View } from 'react-native';
import Svg, { Circle } from 'react-native-svg';

import { AppText } from '@/components/app/app-text';
import { useAppTheme } from '@/context/theme-context';

export function ProgressRing({ value, size = 76, stroke = 8 }: { value: number; size?: number; stroke?: number }) {
  const { colors } = useAppTheme();
  const radius = (size - stroke) / 2;
  const circumference = 2 * Math.PI * radius;
  const normalized = Math.max(0, Math.min(100, value));
  return (
    <View style={{ width: size, height: size, alignItems: 'center', justifyContent: 'center' }}>
      <Svg width={size} height={size} style={{ position: 'absolute', transform: [{ rotate: '-90deg' }] }}>
        <Circle cx={size / 2} cy={size / 2} r={radius} stroke={colors.surfaceMuted} strokeWidth={stroke} fill="none" />
        <Circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          stroke={colors.accent}
          strokeWidth={stroke}
          strokeLinecap="round"
          fill="none"
          strokeDasharray={`${circumference} ${circumference}`}
          strokeDashoffset={circumference - (normalized / 100) * circumference}
        />
      </Svg>
      <AppText variant="heading" style={{ fontVariant: ['tabular-nums'], fontSize: size * 0.25 }}>
        {Math.round(normalized)}%
      </AppText>
    </View>
  );
}
