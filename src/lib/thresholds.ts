import { addDays, daysInMonth, monthKey, startOfMonth, toDate } from './dates.ts'
import { formatMoney, formatPercent } from './money.ts'
import { expenseActivity, spentInMonth } from './analytics.ts'
import type {
  AlertLevel,
  AppState,
  Budget,
  ThresholdAlert,
} from '../types.ts'

export type BudgetEvaluation = {
  spent: number
  limit: number
  warnAt: number
  ratio: number
  projected: number
  level: AlertLevel
}

export function evaluateBudget(input: {
  spent: number
  limit: number
  warnAt: number
  day: number
  daysInMonth: number
  transactionCount?: number
  recentSpent?: number
  recentDays?: number
}): BudgetEvaluation {
  const { spent, limit, warnAt } = input
  const ratio = limit <= 0 ? 0 : spent / limit
  const recentDays = Math.max(input.recentDays ?? input.day, 1)
  const recentSpent = input.recentSpent ?? spent
  const remainingDays = Math.max(input.daysInMonth - input.day, 0)
  const projected = spent + (recentSpent / recentDays) * remainingDays
  const count = input.transactionCount ?? 3

  let level: AlertLevel = 'ok'
  if (ratio >= 1) {
    level = 'breach'
  } else if (ratio >= warnAt) {
    level = 'warning'
  } else if (shouldFlagPace({ day: input.day, projected, limit, ratio, count, recentSpent })) {
    level = 'pace'
  }

  return { spent, limit, warnAt, ratio, projected, level }
}

function shouldFlagPace(input: {
  day: number
  projected: number
  limit: number
  ratio: number
  count: number
  recentSpent: number
}): boolean {
  if (input.day < 8 || input.count < 2 || input.recentSpent <= 0) return false
  if (input.ratio < 0.4) return false
  return input.projected > input.limit * 1.1
}

export function budgetLabel(budget: Budget, state: AppState): string {
  if (budget.categoryId === 'overall') return 'Overall spending'
  return state.categories.find((category) => category.id === budget.categoryId)?.name ?? 'Category'
}

export function evaluateBudgetRecord(
  state: AppState,
  budget: Budget,
  month: string,
  today: string,
): { evaluation: BudgetEvaluation; label: string } {
  const todayDate = toDate(today)
  const day = monthKey(today) === month ? todayDate.getDate() : daysInMonth(month)
  const inThisMonth = daysInMonth(month)
  const endDate = monthKey(today) === month ? today : `${month}-${String(inThisMonth).padStart(2, '0')}`
  const recentStart = addDays(endDate, -6)
  const windowStart = recentStart < startOfMonth(month) ? startOfMonth(month) : recentStart
  const categoryId = budget.categoryId === 'overall' ? undefined : budget.categoryId
  const spent = spentInMonth(state.transactions, month, categoryId)
  const activity = expenseActivity(state.transactions, month, categoryId, windowStart, endDate)
  return {
    label: budgetLabel(budget, state),
    evaluation: evaluateBudget({
      spent,
      limit: budget.monthlyLimit,
      warnAt: budget.warnAt,
      day,
      daysInMonth: inThisMonth,
      transactionCount: activity.count,
      recentSpent: activity.spent,
      recentDays: Math.min(7, day),
    }),
  }
}

export function collectAlerts(
  state: AppState,
  month: string,
  today: string,
): ThresholdAlert[] {
  return state.budgets
    .map((budget) => {
      const { evaluation, label } = evaluateBudgetRecord(state, budget, month, today)
      if (evaluation.level === 'ok') return null
      return {
        budgetId: budget.id,
        categoryId: budget.categoryId,
        label,
        ...evaluation,
        level: evaluation.level,
        message: alertMessage(label, evaluation),
      } satisfies ThresholdAlert
    })
    .filter((alert): alert is ThresholdAlert => alert !== null)
    .sort((a, b) => rank(b.level) - rank(a.level) || b.ratio - a.ratio)
}

export function alertMessage(label: string, evaluation: BudgetEvaluation): string {
  const warnPct = formatPercent(evaluation.warnAt)
  if (evaluation.level === 'breach') {
    const over = evaluation.spent - evaluation.limit
    return `${label} is over budget by ${formatMoney(over)} (${formatPercent(evaluation.ratio)} of ${formatMoney(evaluation.limit)}).`
  }
  if (evaluation.level === 'warning') {
    return `${label} hit the ${warnPct} warning threshold — ${formatMoney(evaluation.spent)} of ${formatMoney(evaluation.limit)} spent.`
  }
  const overshoot = evaluation.projected - evaluation.limit
  return `At this pace, ${label} will overshoot by ${formatMoney(overshoot)} this month.`
}

function rank(level: Exclude<AlertLevel, 'ok'>): number {
  if (level === 'breach') return 3
  if (level === 'warning') return 2
  return 1
}
