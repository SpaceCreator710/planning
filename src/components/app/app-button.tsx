import * as Haptics from 'expo-haptics';
import React from 'react';
import { ActivityIndicator, Pressable, type PressableProps, View } from 'react-native';

import { AppIcon } from '@/components/app/app-icon';
import { AppText } from '@/components/app/app-text';
import { radii, spacing } from '@/constants/tokens';
import { useAppTheme } from '@/context/theme-context';

type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger' | 'success';

interface AppButtonProps extends PressableProps {
  title: string;
  variant?: ButtonVariant;
  loading?: boolean;
  compact?: boolean;
  icon?: Parameters<typeof AppIcon>[0]['name'];
}

export function AppButton({
  title,
  variant = 'primary',
  loading,
  compact,
  icon,
  disabled,
  onPress,
  style,
  ...props
}: AppButtonProps) {
  const { colors } = useAppTheme();
  const backgroundColor =
    variant === 'primary' || variant === 'danger'
      ? colors.accent
      : variant === 'success'
        ? colors.success
        : variant === 'secondary'
          ? colors.surfaceMuted
          : 'transparent';
  const foreground =
    variant === 'primary' || variant === 'danger' || variant === 'success' ? '#FFFFFF' : colors.text;

  return (
    <Pressable
      accessibilityRole="button"
      disabled={disabled || loading}
      onPress={(event) => {
        if (process.env.EXPO_OS === 'ios') Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light).catch(() => undefined);
        onPress?.(event);
      }}
      style={({ pressed }) => [
        {
          minHeight: compact ? 40 : 52,
          paddingHorizontal: compact ? spacing.md : spacing.lg,
          paddingVertical: compact ? spacing.xs : spacing.sm,
          borderRadius: compact ? radii.md : radii.lg,
          borderCurve: 'continuous',
          backgroundColor,
          borderWidth: variant === 'ghost' ? 1 : 0,
          borderColor: colors.border,
          opacity: disabled ? 0.45 : pressed ? 0.78 : 1,
          alignItems: 'center',
          justifyContent: 'center',
        },
        typeof style === 'function' ? style({ pressed }) : style,
      ]}
      {...props}>
      {loading ? (
        <ActivityIndicator color={foreground} />
      ) : (
        <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: spacing.xs }}>
          {icon ? <AppIcon name={icon} fallback="•" color={foreground} size={compact ? 15 : 17} /> : null}
          <AppText variant="label" style={{ color: foreground, fontSize: compact ? 13 : 15 }}>
            {title}
          </AppText>
        </View>
      )}
    </Pressable>
  );
}
