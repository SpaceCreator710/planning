import type { AppLanguage } from '@/types/app';

const dictionary = {
  en: {
    today: 'Today',
    coach: 'Coach',
    goals: 'Goals',
    progress: 'Progress',
    me: 'Me',
    buildDay: 'Build my day',
    rescueDay: 'Rescue my day',
    motivate: 'Motivate me',
    nextAction: 'Next best action',
    complete: 'Complete',
    start: 'Start',
    skip: 'Skip',
    addTask: 'Add task',
    aiPlan: 'AI Plan',
    dayChain: 'Day Chain',
    morning: 'Morning',
    day: 'Day',
    evening: 'Evening',
    night: 'Night',
    settings: 'Settings',
    memory: 'AI Memory',
    subscription: 'Subscription',
    signOut: 'Sign out',
    guest: 'Guest',
    free: 'Free',
  },
  ru: {
    today: 'Сегодня',
    coach: 'Коуч',
    goals: 'Цели',
    progress: 'Прогресс',
    me: 'Профиль',
    buildDay: 'Построить день',
    rescueDay: 'Спасти мой день',
    motivate: 'Мотивировать',
    nextAction: 'Следующее действие',
    complete: 'Готово',
    start: 'Начать',
    skip: 'Пропустить',
    addTask: 'Добавить задачу',
    aiPlan: 'AI План',
    dayChain: 'Цепочка дня',
    morning: 'Утро',
    day: 'День',
    evening: 'Вечер',
    night: 'Ночь',
    settings: 'Настройки',
    memory: 'Память AI',
    subscription: 'Подписка',
    signOut: 'Выйти',
    guest: 'Гость',
    free: 'Бесплатно',
  },
} as const;

export type TranslationKey = keyof typeof dictionary.en;

export function translate(language: AppLanguage, key: TranslationKey) {
  return dictionary[language][key] ?? dictionary.en[key];
}
