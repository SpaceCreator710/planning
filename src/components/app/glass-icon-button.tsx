import { GlassView, isLiquidGlassAvailable } from 'expo-glass-effect';
import * as Haptics from 'expo-haptics';
import React from 'react';
import { Pressable, View } from 'react-native';

import { AppIcon } from '@/components/app/app-icon';
import { radii } from '@/constants/tokens';
import { useAppTheme } from '@/context/theme-context';

export function GlassIconButton({
  icon,
  onPress,
  accessibilityLabel,
  active = false,
}: {
  icon: Parameters<typeof AppIcon>[0]['name'];
  onPress: () => void;
  accessibilityLabel: string;
  active?: boolean;
}) {
  const { colors } = useAppTheme();
  const content = (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel}
      onPress={() => {
        if (process.env.EXPO_OS === 'ios') Haptics.selectionAsync().catch(() => undefined);
        onPress();
      }}
      style={({ pressed }) => ({
        width: 48,
        height: 48,
        borderRadius: radii.pill,
        alignItems: 'center',
        justifyContent: 'center',
        opacity: pressed ? 0.68 : 1,
        transform: [{ scale: pressed ? 0.94 : 1 }],
      })}>
      <AppIcon name={icon} fallback="•" color={active ? '#FFFFFF' : colors.text} size={21} animated={active} />
    </Pressable>
  );

  if (process.env.EXPO_OS === 'ios' && isLiquidGlassAvailable()) {
    return (
      <GlassView isInteractive style={{ borderRadius: radii.pill, overflow: 'hidden', backgroundColor: active ? colors.accent : 'transparent' }}>
        {content}
      </GlassView>
    );
  }

  return (
    <View style={{ borderRadius: radii.pill, backgroundColor: active ? colors.accent : colors.surfaceMuted, boxShadow: '0 7px 22px rgba(0,0,0,0.10)' }}>
      {content}
    </View>
  );
}
