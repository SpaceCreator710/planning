import React from 'react';
import { View } from 'react-native';

import { AppText } from '@/components/app/app-text';
import { spacing } from '@/constants/tokens';

export function SectionHeader({ title, detail }: { title: string; detail?: string }) {
  return (
    <View style={{ flexDirection: 'row', alignItems: 'baseline', justifyContent: 'space-between', gap: spacing.sm }}>
      <AppText variant="heading">{title}</AppText>
      {detail ? (
        <AppText variant="caption" tone="secondary">
          {detail}
        </AppText>
      ) : null}
    </View>
  );
}
