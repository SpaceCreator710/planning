import React from 'react';
import { View, type ViewProps } from 'react-native';

import { radii, shadows, spacing } from '@/constants/tokens';
import { useAppTheme } from '@/context/theme-context';

interface CardProps extends ViewProps {
  muted?: boolean;
  bordered?: boolean;
}

export function Card({ muted, bordered = false, style, children, ...props }: CardProps) {
  const { colors } = useAppTheme();
  return (
    <View
      style={[
        {
          backgroundColor: muted ? colors.surfaceMuted : colors.surface,
          borderRadius: radii.lg,
          borderCurve: 'continuous',
          borderWidth: bordered ? 1 : 0,
          borderColor: colors.border,
          padding: spacing.md,
          gap: spacing.sm,
          boxShadow: bordered ? shadows.card : '0 5px 18px rgba(22,22,25,0.045)',
        },
        style,
      ]}
      {...props}>
      {children}
    </View>
  );
}
