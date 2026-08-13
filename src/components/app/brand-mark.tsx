import React from 'react';
import { Text, View } from 'react-native';

import { palette } from '@/constants/tokens';

export function BrandMark({ size = 48 }: { size?: number }) {
  return (
    <View
      accessibilityLabel="Plan Your Day"
      style={{
        width: size,
        height: size,
        borderRadius: size * 0.3,
        alignItems: 'center',
        justifyContent: 'center',
        backgroundColor: '#FFFFFF',
        borderWidth: Math.max(1, size * 0.025),
        borderColor: `${palette.red}40`,
        borderCurve: 'continuous',
        boxShadow: '0 10px 26px rgba(227,52,47,0.18)',
      }}>
      <Text style={{ color: palette.red, fontSize: size * 0.58, lineHeight: size * 0.68, fontWeight: '900', letterSpacing: -size * 0.035 }}>P</Text>
    </View>
  );
}
