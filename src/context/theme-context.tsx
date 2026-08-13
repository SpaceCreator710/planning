import React, { createContext, useMemo } from 'react';
import { useColorScheme } from 'react-native';

import { colorsForAccent, colorsForCanvas, darkColors, lightColors, type AppColors } from '@/constants/tokens';
import { useApp } from '@/context/app-context';

interface ThemeContextValue {
  colors: AppColors;
  isDark: boolean;
  fontScale: number;
}

const ThemeContext = createContext<ThemeContextValue | null>(null);

export function AppThemeProvider({ children }: React.PropsWithChildren) {
  const system = useColorScheme();
  const { data } = useApp();
  const isDark = data.settings.theme === 'dark' || (data.settings.theme === 'system' && system === 'dark');
  const accentTheme = data.settings.accentTheme;
  const canvasTheme = data.settings.canvasTheme;
  const fontScale = data.settings.fontScale === 'compact' ? 0.9 : data.settings.fontScale === 'large' ? 1.14 : 1;
  const value = useMemo(
    () => ({ colors: colorsForCanvas(colorsForAccent(isDark ? darkColors : lightColors, accentTheme, isDark), canvasTheme, isDark), isDark, fontScale }),
    [accentTheme, canvasTheme, fontScale, isDark],
  );
  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useAppTheme() {
  const value = React.use(ThemeContext);
  if (!value) throw new Error('useAppTheme must be used inside AppThemeProvider');
  return value;
}
