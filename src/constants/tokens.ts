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
  red: { solid: '#FF4D4F', soft: '#FFE8E8', darkSoft: '#451B1D' },
  coral: { solid: '#FF6B5F', soft: '#FFEAE7', darkSoft: '#48201D' },
  orange: { solid: '#FF861F', soft: '#FFF0E3', darkSoft: '#472716' },
  gold: { solid: '#F3A712', soft: '#FFF2CE', darkSoft: '#46320C' },
  yellow: { solid: '#F5C400', soft: '#FFF7C7', darkSoft: '#453B08' },
  lime: { solid: '#84C83D', soft: '#EDF8DF', darkSoft: '#293D14' },
  green: { solid: '#34B56F', soft: '#E3F8EB', darkSoft: '#133B27' },
  mint: { solid: '#22BFA0', soft: '#DDF9F1', darkSoft: '#103C33' },
  teal: { solid: '#00AAA8', soft: '#DDF8F6', darkSoft: '#103B3B' },
  cyan: { solid: '#16A8E0', soft: '#E0F5FC', darkSoft: '#11384A' },
  blue: { solid: '#3478F6', soft: '#E6EFFF', darkSoft: '#172B50' },
  navy: { solid: '#3E5F9B', soft: '#E7EDF7', darkSoft: '#192943' },
  indigo: { solid: '#5856D6', soft: '#ECEBFF', darkSoft: '#24234D' },
  violet: { solid: '#9356E8', soft: '#F3E7FF', darkSoft: '#342047' },
  purple: { solid: '#C14FCD', soft: '#F8E5FB', darkSoft: '#412047' },
  pink: { solid: '#F04F8B', soft: '#FFE6F0', darkSoft: '#451D2F' },
  magenta: { solid: '#E23B91', soft: '#FCE3F0', darkSoft: '#47162F' },
  brown: { solid: '#A36A45', soft: '#F4E9E1', darkSoft: '#38251A' },
  gray: { solid: '#77777D', soft: '#EEEEF0', darkSoft: '#29292E' },
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
  paper: { light: '#F4F4F7', surface: '#FFFFFF', muted: '#EAEAEE', dark: '#0E0E10', darkSurface: '#19191C', darkMuted: '#25252A', swatch: '#74747C' },
  blush: { light: '#FFF0F4', surface: '#FFF9FB', muted: '#F8DFE8', dark: '#211319', darkSurface: '#2C1A21', darkMuted: '#3A222C', swatch: '#F04F8B' },
  mist: { light: '#EAF7FF', surface: '#F8FCFF', muted: '#D8ECF8', dark: '#0F1B23', darkSurface: '#162731', darkMuted: '#1D3542', swatch: '#16A8E0' },
  sage: { light: '#EAF8EF', surface: '#F8FDF9', muted: '#D7EDDE', dark: '#101E16', darkSurface: '#172A1F', darkMuted: '#20382A', swatch: '#34B56F' },
  lavender: { light: '#F2ECFF', surface: '#FBF9FF', muted: '#E6DBF7', dark: '#1B1326', darkSurface: '#281C36', darkMuted: '#352548', swatch: '#9356E8' },
  midnight: { light: '#E8EEFA', surface: '#F6F8FD', muted: '#D8E0F0', dark: '#080D19', darkSurface: '#111A2B', darkMuted: '#1A2740', swatch: '#3E5F9B' },
} as const;

export const lightColors = {
  background: '#F4F4F7',
  surface: '#FFFFFF',
  surfaceElevated: '#FFFFFF',
  surfaceMuted: '#ECECF0',
  text: '#171719',
  textSecondary: '#68686F',
  textTertiary: '#95959C',
  border: '#DEDEE3',
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
  tabBar: 'rgba(247,247,250,0.88)',
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
  const surface = isDark ? canvas.darkSurface : canvas.surface;
  const surfaceMuted = isDark ? canvas.darkMuted : canvas.muted;
  return {
    ...base,
    background: isDark ? canvas.dark : canvas.light,
    surface,
    surfaceElevated: surface,
    surfaceMuted,
    tabBar: isDark ? `${canvas.darkSurface}EE` : `${canvas.surface}E8`,
  };
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
  sm: 12,
  md: 18,
  lg: 26,
  xl: 34,
  pill: 999,
};

export const shadows = {
  card: '0 7px 24px rgba(22, 22, 25, 0.055)',
  floating: '0 14px 44px rgba(22, 22, 25, 0.16)',
};
