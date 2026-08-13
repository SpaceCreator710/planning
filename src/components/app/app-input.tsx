import React from 'react';
import { TextInput, type TextInputProps } from 'react-native';

import { radii, spacing } from '@/constants/tokens';
import { useAppTheme } from '@/context/theme-context';

export function AppInput({ style, multiline, ...props }: TextInputProps) {
  const { colors } = useAppTheme();
  return (
    <TextInput
      placeholderTextColor={colors.textTertiary}
      multiline={multiline}
      style={[
        {
          minHeight: multiline ? 112 : 52,
          backgroundColor: colors.surface,
          borderWidth: 1,
          borderColor: colors.border,
          color: colors.text,
          borderRadius: radii.md,
          borderCurve: 'continuous',
          paddingHorizontal: spacing.md,
          paddingVertical: spacing.sm,
          fontSize: 16,
          lineHeight: 22,
          textAlignVertical: multiline ? 'top' : 'center',
        },
        style,
      ]}
      {...props}
    />
  );
}
