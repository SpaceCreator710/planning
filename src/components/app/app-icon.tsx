import { SymbolView, type SFSymbol } from 'expo-symbols';
import React from 'react';
import { Text, type ColorValue, type StyleProp, type ViewStyle } from 'react-native';

interface AppIconProps {
  name: SFSymbol;
  color: ColorValue;
  size?: number;
  fallback?: string;
  style?: StyleProp<ViewStyle>;
  animated?: boolean;
}

export function AppIcon({ name, color, size = 22, fallback = '•', style, animated }: AppIconProps) {
  return (
    <SymbolView
      name={{ ios: name }}
      size={size}
      tintColor={color}
      weight="semibold"
      type="hierarchical"
      animationSpec={animated ? { effect: { type: 'bounce', wholeSymbol: true }, speed: 1.25 } : undefined}
      fallback={<Text style={{ color, fontSize: size, fontWeight: '700' }}>{fallback}</Text>}
      style={style}
    />
  );
}
