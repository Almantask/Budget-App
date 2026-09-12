import { loggingDates, monthTotals } from './analytics.ts'
import { collectAlerts } from './thresholds.ts'
import {
  collectAchievements,
  computeXp,
  levelFromXp,
  monthQuests,
  pastUnderBudgetCount,
  stretchGoalForMonth,
  stretchHits,
} from './gamification.ts'
import { categoryBreakdown, fullHistory, monthlySeries, trimSeries, weeklySeries } from './analytics.ts'
import { findSpendingAnomalies } from './anomalies.ts'
import { monthKey, toIso } from './dates.ts'
import type { AppState, ThresholdAlert } from '../types.ts'

export function deriveView(state: AppState, viewMonth: string, now = new Date()) {
  const today = toIso(now)
  const history = fullHistory(state.transactions, viewMonth)
  const series = trimSeries(monthlySeries(state.transactions, viewMonth, 12))
  const weekly = weeklySeries(state.transactions, viewMonth)
  const monthPoint = monthTotals(state.transactions, viewMonth)
  const stretch = stretchGoalForMonth(
    history.filter((point) => point.month < viewMonth),
    viewMonth,
  )
  const alerts: ThresholdAlert[] = collectAlerts(state, viewMonth, today)
  const quests = monthQuests({ state, month: viewMonth, today, stretch, monthPoint })
  const hits = stretchHits(history.filter((point) => point.month <= viewMonth))
  const completedHits = hits.filter((hit) => hit.month < monthKey(today))
  const achievements = collectAchievements({ state, today, history, hits: completedHits })
  const underBudgetMonths = pastUnderBudgetCount(state, history, today)
  const currentQuestsComplete =
    monthKey(today) === viewMonth ? 0 : quests.filter((quest) => quest.complete).length
  const xp = computeXp({
    transactionCount: state.transactions.length,
    uniqueDays: loggingDates(state.transactions).length,
    hits: completedHits,
    underBudgetMonths,
    questsComplete: currentQuestsComplete + hits.filter((hit) => hit.hit).length,
    achievements,
  })
  const level = levelFromXp(xp)
  const expenses = categoryBreakdown(state.transactions, state.categories, viewMonth, 'expense')
  const gains = categoryBreakdown(state.transactions, state.categories, viewMonth, 'income')
  const anomalies = findSpendingAnomalies(state, viewMonth, today)

  return {
    today,
    history,
    series,
    weekly,
    monthPoint,
    stretch,
    alerts,
    quests,
    hits,
    achievements,
    level,
    expenses,
    gains,
    anomalies,
    stretchProgress: Math.min(1, Math.max(0, monthPoint.net) / stretch.target),
  }
}
