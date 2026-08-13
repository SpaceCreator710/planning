import type { CoachContext } from '@/types/app';

const CRISIS_PATTERNS = [
  /kill myself|suicide|self[- ]harm|don't want to live/i,
  /самоуб|убить себя|не хочу жить|навредить себе/i,
];

function activeGoal(context: CoachContext) {
  return context.goals.find((goal) => !goal.archived)?.title || context.profile.primaryGoal || 'your main goal';
}

function safeResponse(language: 'en' | 'ru') {
  if (language === 'ru') {
    return 'Твоя безопасность сейчас важнее любого плана. Я отключаю жёсткий тон. Пожалуйста, прямо сейчас обратись к взрослому или человеку, которому доверяешь. Если есть непосредственная опасность — позвони в местную экстренную службу. Продуктивность может подождать.';
  }
  return 'Your safety matters more than any plan. I am switching off the intense tone. Please contact a trusted person right now. If there is immediate danger, call your local emergency service. Productivity can wait.';
}

function replyRu(mode: CoachContext['settings']['coachMode'], message: string, goal: string) {
  const slipping = /лень|мотива|прокраст|не могу|сорвал|бросил|отлож/i.test(message);
  if (mode === 'soft') {
    return slipping
      ? `Похоже, сейчас тяжело включиться — это не делает тебя слабым. Давай уменьшим давление: открой задачу, связанную с «${goal}», и удели ей всего пять спокойных минут. После этого решим следующий шаг вместе.`
      : `Я рядом. Давай бережно превратим это в действие: выбери один маленький результат для «${goal}» и начни с пяти минут. Не нужен идеальный день — нужен первый честный шаг.`;
  }
  if (mode === 'strict') {
    return slipping
      ? `Мотивация не требуется. Требуется действие. Ты выбрал цель «${goal}», но сейчас поведение с ней не совпадает. Убери отвлечение, поставь таймер на 10 минут и начни. Оценивать будешь после таймера.`
      : `Хватит размытых намерений. Назови результат, который будет виден через 30 минут, закрой всё лишнее и начинай сейчас. «${goal}» двигается только выполненными действиями.`;
  }
  return slipping
    ? `Опять ждёшь правильного настроения? Оно не придёт и не сделает работу за тебя. Каждая новая отговорка тренирует привычку сдаваться. Либо ты сейчас открываешь задачу по «${goal}» и работаешь 10 минут, либо честно выбираешь ещё один нулевой день. Решай. Сейчас.`
    : `Слова ничего не меняют. «${goal}» не сдвинется от намерений. У тебя два варианта: выполнить один измеримый шаг в ближайшие 15 минут или снова выбрать бездействие. Убери телефон. Открой задачу. Начинай.`;
}

function replyEn(mode: CoachContext['settings']['coachMode'], message: string, goal: string) {
  const slipping = /lazy|motivat|procrast|can't|stuck|quit|failed|later/i.test(message);
  if (mode === 'soft') {
    return slipping
      ? `It sounds hard to get moving right now, and that does not make you weak. Let’s lower the pressure: open the task connected to “${goal}” and give it five calm minutes. Then we will choose the next step together.`
      : `I’m with you. Let’s turn this into one gentle action: choose a small visible result for “${goal}” and begin with five minutes. You do not need a perfect day—only an honest first step.`;
  }
  if (mode === 'strict') {
    return slipping
      ? `Motivation is not required. Action is. You chose “${goal},” but your behavior is not matching it. Remove the distraction, set ten minutes, and begin. Evaluate only after the timer ends.`
      : `Stop keeping it vague. Name the result that will be visible in 30 minutes, close everything unrelated, and start now. “${goal}” moves through completed actions.`;
  }
  return slipping
    ? `Still waiting for the right mood? It will not do the work for you. Every new excuse rehearses quitting. Either open the task for “${goal}” and work for ten minutes now, or admit you are choosing another zero day. Decide. Now.`
    : `Words change nothing. “${goal}” will not move through intention. You have two choices: finish one measurable step in the next 15 minutes, or choose inaction again. Put the phone away. Open the task. Start.`;
}

export function generateMockCoachReply(message: string, context: CoachContext) {
  const language = context.settings.language;
  if (CRISIS_PATTERNS.some((pattern) => pattern.test(message))) {
    return { text: safeResponse(language), safetyOverride: true };
  }
  const goal = activeGoal(context);
  return {
    text: language === 'ru' ? replyRu(context.settings.coachMode, message, goal) : replyEn(context.settings.coachMode, message, goal),
    safetyOverride: false,
  };
}
