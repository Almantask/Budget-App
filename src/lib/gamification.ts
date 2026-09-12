import { datesLoggedInMonth, loggingStreak, spentInMonth } from './analytics.ts'
import { daysInMonth, monthKey } from './dates.ts'
import { formatMoney, niceAmount } from './money.ts'
import { collectAlerts } from './thresholds.ts'
import type {
  Achievement,
  AchievementId,
  AppState,
  LevelProgress,
  MonthPoint,
  Quest,
  StretchGoal,
} from '../types.ts'

export function stretchGoalForMonth(history: MonthPoint[], month: string): StretchGoal {
  const recent = history.filter((point) => point.month < month).slice(-3)

  if (recent.length === 0) {
    return {
      month,
      target: 200,
      baseline: 0,
      reason: 'First month in Grove — stash €200 and start the savings habit.',
    }
  }

  const last = recent[recent.length - 1]
  const average = recent.reduce((sum, point) => sum + point.net, 0) / recent.length
  const best = Math.max(...recent.map((point) => point.net))

  if (last.net <= 0 && average <= 0) {
    return {
      month,
      target: 80,
      baseline: last.net,
      reason: 'A clean reset: finish this month €80 in the black and rebuild momentum.',
    }
  }

  const reference = Math.max(last.net, average, 0)
  let target = reference * 1.1

  if (last.net > 0) {
    target = Math.max(target, last.net * 1.08)
    target = Math.min(target, last.net * 1.2)
  }

  if (last.net > 0 && best > average * 1.35 && last.net === best && average > 0) {
    target = last.net * 1.05
  }

  target = Math.max(50, niceAmount(target))

  const extra = Math.max(0, target - Math.max(last.net, 0))
  const perDay = extra / daysInMonth(month)
  const extraText =
    extra > 0
      ? ` That’s about ${formatMoney(perDay)} extra per day versus last month.`
      : ''

  return {
    month,
    target,
    baseline: niceAmount(reference),
    reason: `Recent savings sit around ${formatMoney(reference)}. Stretch to ${formatMoney(target)} this month.${extraText}`,
  }
}

export function monthQuests(input: {
  state: AppState
  month: string
  today: string
  stretch: StretchGoal
  monthPoint: MonthPoint
}): Quest[] {
  const { state, month, today, stretch, monthPoint } = input
  const through = monthKey(today) === month ? today : `${month}-31`
  const logged = datesLoggedInMonth(state.transactions, month, through)
  const logTarget = Math.min(10, Math.max(6, Math.ceil(daysInMonth(month) / 4)))
  const alerts = collectAlerts(state, month, today)
  const warningCount = alerts.filter((alert) => alert.level !== 'pace').length
  const overall = state.budgets.find((budget) => budget.categoryId === 'overall')
  const overallSpent = spentInMonth(state.transactions, month)
  const overallLimit = overall?.monthlyLimit ?? 0

  const stretchProgress = Math.max(0, monthPoint.net)

  return [
    {
      id: 'stretch',
      title: 'Stretch save',
      detail: `Put aside ${formatMoney(stretch.target)} after expenses.`,
      xp: 120,
      current: stretchProgress,
      target: stretch.target,
      unit: 'money',
      complete: monthPoint.net >= stretch.target,
    },
    {
      id: 'under-budget',
      title: 'Stay inside the fence',
      detail: overall
        ? `Keep overall spending at or under ${formatMoney(overall.monthlyLimit)}.`
        : 'Set an overall budget to activate this quest.',
      xp: 60,
      current: overallSpent,
      target: overallLimit || 1,
      unit: 'money',
      complete: Boolean(overall) && overallSpent <= overallLimit,
    },
    {
      id: 'calm-categories',
      title: 'Quiet categories',
      detail: 'Trigger no warning or breach on category budgets.',
      xp: 50,
      current: warningCount === 0 ? 1 : 0,
      target: 1,
      unit: 'count',
      complete: warningCount === 0,
    },
    {
      id: 'keep-logging',
      title: 'Keep the ledger warm',
      detail: `Log activity on ${logTarget} different days this month.`,
      xp: 40,
      current: logged,
      target: logTarget,
      unit: 'count',
      complete: logged >= logTarget,
    },
  ]
}

export function stretchHits(history: MonthPoint[]): { month: string; hit: boolean; goal: StretchGoal; net: number }[] {
  return history.map((point, index) => {
    const goal = stretchGoalForMonth(history.slice(0, index), point.month)
    return { month: point.month, hit: point.net >= goal.target, goal, net: point.net }
  })
}

export function collectAchievements(input: {
  state: AppState
  today: string
  history: MonthPoint[]
  hits: { month: string; hit: boolean }[]
}): Achievement[] {
  const { state, today, history, hits } = input
  const streak = loggingStreak(state.transactions, today)
  const completedMonths = history.filter((point) => point.month < monthKey(today))
  const overall = state.budgets.find((budget) => budget.categoryId === 'overall')
  const underBudgetMonths = completedMonths.filter((point) => {
    const spent = spentInMonth(state.transactions, point.month)
    return overall ? spent <= overall.monthlyLimit : point.net > 0
  })
  const quietMonths = completedMonths.filter((point) => {
    const monthEnd = `${point.month}-28`
    const alerts = collectAlerts(state, point.month, monthEnd)
    return alerts.filter((alert) => alert.level !== 'pace').length === 0
  })
  const balancedMonths = completedMonths.filter((point) => {
    const monthEnd = `${point.month}-28`
    const alerts = collectAlerts(state, point.month, monthEnd).filter(
      (alert) => alert.categoryId !== 'overall' && alert.level !== 'pace',
    )
    return alerts.length === 0
  })
  const hitMonths = hits.filter((hit) => hit.hit)
  let longestStretchRun = 0
  let run = 0
  for (const hit of hits) {
    run = hit.hit ? run + 1 : 0
    longestStretchRun = Math.max(longestStretchRun, run)
  }
  const cameBack = hits.some((hit, index) => index > 0 && hit.hit && !hits[index - 1].hit)
  const earlyRoot = state.transactions.some((transaction) => transaction.date.endsWith('-01'))
  const unlocked = new Set<AchievementId>()

  if (state.transactions.length > 0) unlocked.add('first-leaf')
  if (streak >= 7) unlocked.add('week-streak')
  if (underBudgetMonths.length > 0) unlocked.add('month-under')
  if (hitMonths.length > 0) unlocked.add('stretch-rookie')
  if (longestStretchRun >= 3) unlocked.add('stretch-streak')
  if (history.some((point) => point.net >= 500)) unlocked.add('big-save')
  if (quietMonths.length > 0) unlocked.add('quiet-month')
  if (balancedMonths.length > 0) unlocked.add('balanced-grove')
  if (cameBack) unlocked.add('comeback')
  if (earlyRoot) unlocked.add('early-root')

  return achievementCatalog().map((achievement) => ({
    ...achievement,
    unlocked: unlocked.has(achievement.id),
  }))
}

export function achievementCatalog(): Omit<Achievement, 'unlocked'>[] {
  return [
    { id: 'first-leaf', title: 'First leaf', detail: 'Log your first transaction.', xp: 15 },
    { id: 'early-root', title: 'Early root', detail: 'Log something on the first day of a month.', xp: 20 },
    { id: 'week-streak', title: 'Seven suns', detail: 'Keep a 7-day logging streak.', xp: 40 },
    { id: 'month-under', title: 'Inside the fence', detail: 'Finish a month under your overall budget.', xp: 50 },
    { id: 'quiet-month', title: 'Quiet canopy', detail: 'Finish a month with no warning thresholds tripped.', xp: 55 },
    { id: 'balanced-grove', title: 'Balanced grove', detail: 'Keep every category budget calm for a month.', xp: 60 },
    { id: 'stretch-rookie', title: 'Stretch sprout', detail: 'Hit a monthly stretch savings goal.', xp: 70 },
    { id: 'stretch-streak', title: 'Triple stretch', detail: 'Hit stretch goals three months in a row.', xp: 120 },
    { id: 'big-save', title: 'Deep roots', detail: 'Save at least €500 in a single month.', xp: 80 },
    { id: 'comeback', title: 'Second spring', detail: 'Hit a stretch goal after missing one.', xp: 45 },
  ]
}

export function computeXp(input: {
  transactionCount: number
  uniqueDays: number
  hits: { hit: boolean }[]
  underBudgetMonths: number
  questsComplete: number
  achievements: Achievement[]
}): number {
  const stretchXp = input.hits.filter((hit) => hit.hit).length * 120
  const achievementXp = input.achievements
    .filter((achievement) => achievement.unlocked)
    .reduce((sum, achievement) => sum + achievement.xp, 0)
  return (
    input.transactionCount * 6 +
    input.uniqueDays * 8 +
    stretchXp +
    input.underBudgetMonths * 40 +
    input.questsComplete * 20 +
    achievementXp
  )
}

export function levelFromXp(totalXp: number): LevelProgress {
  let remaining = Math.max(0, totalXp)
  let level = 1
  let need = 120
  while (remaining >= need) {
    remaining -= need
    level += 1
    need = Math.round(need * 1.18)
  }
  return {
    level,
    intoLevel: remaining,
    toNext: need,
    progress: need === 0 ? 1 : remaining / need,
    totalXp,
  }
}

export function pastUnderBudgetCount(state: AppState, history: MonthPoint[], today: string): number {
  const overall = state.budgets.find((budget) => budget.categoryId === 'overall')
  return history.filter((point) => {
    if (point.month >= monthKey(today)) return false
    const spent = spentInMonth(state.transactions, point.month)
    return overall ? spent <= overall.monthlyLimit : false
  }).length
}
