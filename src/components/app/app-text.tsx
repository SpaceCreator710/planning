import React from 'react';
import { Text, type TextProps, type TextStyle } from 'react-native';

import { useAppTheme } from '@/context/theme-context';

type TextVariant = 'display' | 'title' | 'heading' | 'body' | 'small' | 'caption' | 'label';

const variants: Record<TextVariant, TextStyle> = {
  display: { fontSize: 40, lineHeight: 44, fontWeight: '800', letterSpacing: -1.35 },
  title: { fontSize: 30, lineHeight: 35, fontWeight: '800', letterSpacing: -0.85 },
  heading: { fontSize: 20, lineHeight: 26, fontWeight: '700', letterSpacing: -0.3 },
  body: { fontSize: 16, lineHeight: 23, fontWeight: '400' },
  small: { fontSize: 14, lineHeight: 20, fontWeight: '500' },
  caption: { fontSize: 12, lineHeight: 16, fontWeight: '500' },
  label: { fontSize: 13, lineHeight: 17, fontWeight: '700', letterSpacing: 0.2 },
};

interface AppTextProps extends TextProps {
  variant?: TextVariant;
  tone?: 'primary' | 'secondary' | 'tertiary' | 'accent' | 'success' | 'warning';
}

export function AppText({ variant = 'body', tone = 'primary', style, children, ...props }: AppTextProps) {
  const { colors, fontScale } = useAppTheme();
  const base = variants[variant];
  const scaled = {
    ...base,
    fontSize: typeof base.fontSize === 'number' ? Math.round(base.fontSize * fontScale) : base.fontSize,
    lineHeight: typeof base.lineHeight === 'number' ? Math.round(base.lineHeight * fontScale) : base.lineHeight,
  };
  const color =
    tone === 'secondary'
      ? colors.textSecondary
      : tone === 'tertiary'
        ? colors.textTertiary
        : tone === 'accent'
          ? colors.accent
          : tone === 'success'
            ? colors.success
            : tone === 'warning'
              ? colors.warning
              : colors.text;
  return (
    <Text selectable style={[scaled, { color }, style]} {...props}>
      {children}
    </Text>
  );
}
