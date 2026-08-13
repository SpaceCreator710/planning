import * as Haptics from 'expo-haptics';
import React, { useEffect, useState } from 'react';
import { Pressable, View } from 'react-native';
import Animated, { useAnimatedStyle, useSharedValue, withSpring } from 'react-native-reanimated';

import { AppText } from '@/components/app/app-text';
import { radii, spacing } from '@/constants/tokens';
import { useAppTheme } from '@/context/theme-context';

export interface SegmentOption<T extends string> {
  value: T;
  label: string;
}

export function SlidingSegmentedControl<T extends string>({
  value,
  options,
  onChange,
}: {
  value: T;
  options: SegmentOption<T>[];
  onChange: (value: T) => void;
}) {
  const { colors } = useAppTheme();
  const [width, setWidth] = useState(0);
  const index = Math.max(0, options.findIndex((option) => option.value === value));
  const position = useSharedValue(index);
  const innerWidth = Math.max(0, width - 8);
  const itemWidth = options.length ? innerWidth / options.length : 0;

  useEffect(() => {
    position.value = withSpring(index, { damping: 22, stiffness: 240, mass: 0.72 });
  }, [index, position]);

  const indicatorStyle = useAnimatedStyle(() => ({
    transform: [{ translateX: position.value * itemWidth }],
    width: itemWidth,
  }), [itemWidth]);

  return (
    <View
      onLayout={(event) => setWidth(event.nativeEvent.layout.width)}
      style={{ minHeight: 48, padding: 4, borderRadius: radii.pill, borderCurve: 'continuous', backgroundColor: colors.surfaceMuted, flexDirection: 'row', position: 'relative' }}>
      {width > 0 ? (
        <Animated.View
          pointerEvents="none"
          style={[{ position: 'absolute', left: 4, top: 4, bottom: 4, borderRadius: radii.pill, backgroundColor: colors.surface, boxShadow: '0 3px 12px rgba(0,0,0,0.10)' }, indicatorStyle]}
        />
      ) : null}
      {options.map((option) => {
        const selected = option.value === value;
        return (
          <Pressable
            key={option.value}
            accessibilityRole="button"
            accessibilityState={{ selected }}
            onPress={() => {
              if (process.env.EXPO_OS === 'ios') Haptics.selectionAsync().catch(() => undefined);
              onChange(option.value);
            }}
            style={{ flex: 1, minHeight: 40, paddingHorizontal: spacing.xs, alignItems: 'center', justifyContent: 'center', zIndex: 1 }}>
            <AppText variant="caption" style={{ color: selected ? colors.accent : colors.textSecondary, fontWeight: selected ? '800' : '600' }}>
              {option.label}
            </AppText>
          </Pressable>
        );
      })}
    </View>
  );
}
