import { daysInMonth, monthKey, toDate } from './dates.ts'
import { formatMoney, formatPercent } from './money.ts'
import { spentInMonth } from './analytics.ts'
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
}): BudgetEvaluation {
  const { spent, limit, warnAt } = input
  const ratio = limit <= 0 ? 0 : spent / limit
  const elapsed = Math.max(input.day, 1)
  const projected = (spent / elapsed) * input.daysInMonth

  let level: AlertLevel = 'ok'
  if (ratio >= 1) {
    level = 'breach'
  } else if (ratio >= warnAt) {
    level = 'warning'
  } else if (input.day >= 5 && projected > limit && ratio >= 0.35) {
    level = 'pace'
  }

  return { spent, limit, warnAt, ratio, projected, level }
}

export function budgetLabel(budget: Budget, state: AppState): string {
  if (budget.categoryId === 'overall') return 'Overall spending'
  return state.categories.find((category) => category.id === budget.categoryId)?.name ?? 'Category'
}

export function collectAlerts(
  state: AppState,
  month: string,
  today: string,
): ThresholdAlert[] {
  const todayDate = toDate(today)
  const day = monthKey(today) === month ? todayDate.getDate() : daysInMonth(month)
  const inThisMonth = daysInMonth(month)

  return state.budgets
    .map((budget) => {
      const spent =
        budget.categoryId === 'overall'
          ? spentInMonth(state.transactions, month)
          : spentInMonth(state.transactions, month, budget.categoryId)
      const evaluation = evaluateBudget({
        spent,
        limit: budget.monthlyLimit,
        warnAt: budget.warnAt,
        day,
        daysInMonth: inThisMonth,
      })
      if (evaluation.level === 'ok') return null

      const label = budgetLabel(budget, state)
      const message = alertMessage(label, evaluation)
      return {
        budgetId: budget.id,
        categoryId: budget.categoryId,
        label,
        ...evaluation,
        level: evaluation.level,
        message,
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
