import React from 'react';
import { Pressable, type PressableProps } from 'react-native';

import { AppText } from '@/components/app/app-text';
import { radii, spacing } from '@/constants/tokens';
import { useAppTheme } from '@/context/theme-context';

interface ChipProps extends PressableProps {
  label: string;
  selected?: boolean;
  color?: string;
}

export function Chip({ label, selected, color, onPress, style, ...props }: ChipProps) {
  const { colors } = useAppTheme();
  const accent = color ?? colors.accent;
  return (
    <Pressable
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => [
        {
          minHeight: 36,
          paddingHorizontal: spacing.sm,
          paddingVertical: spacing.xs,
          borderRadius: radii.pill,
          borderWidth: 1,
          borderColor: selected ? accent : colors.border,
          backgroundColor: selected ? `${accent}18` : colors.surface,
          opacity: pressed ? 0.7 : 1,
          alignItems: 'center',
          justifyContent: 'center',
        },
        typeof style === 'function' ? style({ pressed }) : style,
      ]}
      {...props}>
      <AppText variant="caption" style={{ color: selected ? accent : colors.textSecondary }}>
        {label}
      </AppText>
    </Pressable>
  );
}
