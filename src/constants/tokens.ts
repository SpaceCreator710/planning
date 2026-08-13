export const palette = {
  red: '#E3342F',
  redDark: '#B8201B',
  redSoft: '#FDEBEA',
  green: '#1E9E69',
  greenSoft: '#E7F7F0',
  amber: '#E79A19',
  amberSoft: '#FFF4DE',
  blue: '#367BF5',
  blueSoft: '#EAF1FF',
  white: '#FFFFFF',
  ink: '#171719',
  black: '#09090B',
};

export const taskPalettes = {
  red: { solid: '#E3342F', soft: '#FDEBEA', darkSoft: '#3B1B1A' },
  orange: { solid: '#E87528', soft: '#FFF0E5', darkSoft: '#3A2418' },
  yellow: { solid: '#C99112', soft: '#FFF6D8', darkSoft: '#382E12' },
  green: { solid: '#278B61', soft: '#E7F7F0', darkSoft: '#143428' },
  teal: { solid: '#16878B', soft: '#E2F6F5', darkSoft: '#123336' },
  blue: { solid: '#367BF5', soft: '#EAF1FF', darkSoft: '#17284B' },
  indigo: { solid: '#5260C9', soft: '#ECEEFE', darkSoft: '#202544' },
  violet: { solid: '#8B57C7', soft: '#F4EBFC', darkSoft: '#30203F' },
  pink: { solid: '#D04F83', soft: '#FCEAF2', darkSoft: '#3C1D2C' },
  gray: { solid: '#74747C', soft: '#EFEFF1', darkSoft: '#29292E' },
} as const;

export const categoryTaskColor = {
  focus: 'violet',
  work: 'blue',
  study: 'indigo',
  fitness: 'green',
  life: 'orange',
  rest: 'teal',
} as const;

export const accentThemes = {
  crimson: { accent: '#E3342F', pressed: '#B8201B', soft: '#FDEBEA', dark: '#FF4B44', darkSoft: '#3B1B1A' },
  ocean: { accent: '#2775D8', pressed: '#185AAE', soft: '#E8F1FD', dark: '#62A4FF', darkSoft: '#172A45' },
  violet: { accent: '#8054C7', pressed: '#6339A7', soft: '#F1EAFB', dark: '#AA7BEA', darkSoft: '#302141' },
  forest: { accent: '#278B61', pressed: '#196D4A', soft: '#E7F7F0', dark: '#53C592', darkSoft: '#143428' },
  sunset: { accent: '#DF6935', pressed: '#BA4D1E', soft: '#FFF0E7', dark: '#FF8A58', darkSoft: '#3B241B' },
  blossom: { accent: '#E76582', pressed: '#C94868', soft: '#FDECF1', dark: '#FF83A0', darkSoft: '#3E202B' },
  sky: { accent: '#3D91C8', pressed: '#2474A9', soft: '#E8F5FC', dark: '#75C8F5', darkSoft: '#173243' },
  lavender: { accent: '#9272D4', pressed: '#7352B6', soft: '#F1EDFC', dark: '#BE9EF8', darkSoft: '#302643' },
  mint: { accent: '#2F9C82', pressed: '#217761', soft: '#E5F7F1', dark: '#61D1B2', darkSoft: '#16382F' },
  amber: { accent: '#C88919', pressed: '#9F6710', soft: '#FFF3D9', dark: '#F3B64E', darkSoft: '#3D2E13' },
} as const;

export const canvasThemes = {
  paper: { light: '#F7F7F8', dark: '#0E0E10', swatch: '#74747C' },
  blush: { light: '#FFF5F6', dark: '#1C1417', swatch: '#E76582' },
  mist: { light: '#F2F7FA', dark: '#11191E', swatch: '#3D91C8' },
  sage: { light: '#F3F8F4', dark: '#121A15', swatch: '#4B9270' },
  lavender: { light: '#F7F4FC', dark: '#18141F', swatch: '#9272D4' },
  midnight: { light: '#EEF1F8', dark: '#090D17', swatch: '#34466F' },
} as const;

export const lightColors = {
  background: '#F7F7F8',
  surface: '#FFFFFF',
  surfaceElevated: '#FFFFFF',
  surfaceMuted: '#F0F0F2',
  text: '#171719',
  textSecondary: '#68686F',
  textTertiary: '#95959C',
  border: '#E5E5E8',
  divider: '#ECECEF',
  accent: palette.red,
  accentPressed: palette.redDark,
  accentSoft: palette.redSoft,
  success: palette.green,
  successSoft: palette.greenSoft,
  warning: palette.amber,
  warningSoft: palette.amberSoft,
  info: palette.blue,
  infoSoft: palette.blueSoft,
  tabBar: 'rgba(255,255,255,0.96)',
  overlay: 'rgba(10,10,12,0.45)',
};

export const darkColors: typeof lightColors = {
  background: '#0E0E10',
  surface: '#17171A',
  surfaceElevated: '#1E1E22',
  surfaceMuted: '#242429',
  text: '#F7F7F8',
  textSecondary: '#B7B7BE',
  textTertiary: '#7F7F88',
  border: '#2C2C31',
  divider: '#242429',
  accent: '#FF4B44',
  accentPressed: '#E3342F',
  accentSoft: '#3B1B1A',
  success: '#4AC58E',
  successSoft: '#123527',
  warning: '#F0AE3B',
  warningSoft: '#3B2B10',
  info: '#6A9BFF',
  infoSoft: '#17284B',
  tabBar: 'rgba(23,23,26,0.96)',
  overlay: 'rgba(0,0,0,0.68)',
};

export type AppColors = typeof lightColors;

export function colorsForAccent(base: AppColors, accentTheme: keyof typeof accentThemes, isDark: boolean): AppColors {
  const theme = accentThemes[accentTheme] ?? accentThemes.crimson;
  return {
    ...base,
    accent: isDark ? theme.dark : theme.accent,
    accentPressed: theme.pressed,
    accentSoft: isDark ? theme.darkSoft : theme.soft,
  };
}

export function colorsForCanvas(base: AppColors, canvasTheme: keyof typeof canvasThemes, isDark: boolean): AppColors {
  const canvas = canvasThemes[canvasTheme] ?? canvasThemes.paper;
  return { ...base, background: isDark ? canvas.dark : canvas.light };
}

export const spacing = {
  xxs: 4,
  xs: 8,
  sm: 12,
  md: 16,
  lg: 20,
  xl: 24,
  xxl: 32,
  huge: 44,
};

export const radii = {
  sm: 10,
  md: 16,
  lg: 22,
  xl: 28,
  pill: 999,
};

export const shadows = {
  card: '0 8px 30px rgba(22, 22, 25, 0.06)',
  floating: '0 12px 40px rgba(22, 22, 25, 0.14)',
};
