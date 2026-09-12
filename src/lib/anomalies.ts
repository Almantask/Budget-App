import { spentThrough } from './analytics.ts'
import { addMonths, endOfMonth, monthKey, monthLabel } from './dates.ts'
import { formatMoney } from './money.ts'
import type { AppState, SpendingAnomaly, Transaction } from '../types.ts'

export type SampleStats = {
  n: number
  mean: number
  median: number
  stdev: number
}

export function sampleStats(values: number[]): SampleStats {
  const n = values.length
  if (n === 0) return { n: 0, mean: 0, median: 0, stdev: 0 }
  const sorted = [...values].sort((a, b) => a - b)
  const mean = values.reduce((sum, value) => sum + value, 0) / n
  const mid = Math.floor(sorted.length / 2)
  const median = sorted.length % 2 === 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
  const variance =
    n < 2 ? 0 : values.reduce((sum, value) => sum + (value - mean) ** 2, 0) / (n - 1)
  return { n, mean, median, stdev: Math.sqrt(variance) }
}

export function asOfDate(viewMonth: string, today: string): string {
  return today.startsWith(viewMonth) ? today : endOfMonth(viewMonth)
}

function priorMonths(viewMonth: string, count = 8): string[] {
  const months: string[] = []
  for (let i = count; i >= 1; i -= 1) months.push(addMonths(viewMonth, -i))
  return months
}

function isStableBill(stats: SampleStats): boolean {
  return stats.n >= 3 && stats.mean > 0 && stats.stdev / stats.mean < 0.12
}

function classifySpike(current: number, baseline: SampleStats): {
  severity: SpendingAnomaly['severity']
  multiple: number
} | null {
  if (baseline.n < 3 || current < 30) return null
  if (isStableBill(baseline) && current < baseline.mean * 1.18) return null
  const multiple = baseline.median > 0 ? current / baseline.median : 0
  const z = baseline.stdev > 1 ? (current - baseline.mean) / baseline.stdev : 0
  const delta = current - baseline.median
  if (delta < 35) return null
  if (multiple >= 1.9 || z >= 2.15) return { severity: 'unusual', multiple }
  if (multiple >= 1.45 && (z >= 1.15 || multiple >= 1.55)) return { severity: 'watch', multiple }
  return null
}

function classifyCharge(amount: number, baseline: SampleStats): {
  severity: SpendingAnomaly['severity']
  multiple: number
} | null {
  if (baseline.n < 4 || amount < 40) return null
  const multiple = baseline.median > 0 ? amount / baseline.median : 0
  const z = baseline.stdev > 1 ? (amount - baseline.mean) / baseline.stdev : 0
  if (amount - baseline.median < 25) return null
  if (multiple >= 2.5 || z >= 2.4) return { severity: 'unusual', multiple }
  if (multiple >= 2.1 || z >= 2) return { severity: 'watch', multiple }
  return null
}

function monthWindow(viewMonth: string, today: string) {
  const through = asOfDate(viewMonth, today)
  const history = priorMonths(viewMonth)
  const pointInMonth = today.startsWith(viewMonth)
  return { through, history, pointInMonth }
}

export function findSpendingAnomalies(
  state: AppState,
  viewMonth: string,
  today: string,
): SpendingAnomaly[] {
  const { through, history, pointInMonth } = monthWindow(viewMonth, today)
  const anomalies: SpendingAnomaly[] = []
  const expenseCategories = state.categories.filter((category) => category.kind === 'expense')

  const overallHistory = history
    .map((month) => spentThrough(state.transactions, month, endOfMonth(month)))
    .filter((value) => value > 0)
  const overallNow = spentThrough(state.transactions, viewMonth, through)
  const overallStats = sampleStats(overallHistory)
  const overallSpike = classifySpike(overallNow, overallStats)
  if (overallSpike) {
    anomalies.push({
      id: `month-spike:${viewMonth}`,
      kind: 'month-spike',
      severity: overallSpike.severity,
      categoryId: 'overall',
      label: 'Overall spending',
      month: viewMonth,
      amount: overallNow,
      baseline: overallStats.median,
      multiple: overallSpike.multiple,
      message: monthSpikeMessage(overallNow, overallStats.median, overallSpike.multiple, pointInMonth, viewMonth),
    })
  }

  for (const category of expenseCategories) {
    const prior = history
      .map((month) => spentThrough(state.transactions, month, endOfMonth(month), category.id))
      .filter((value) => value > 0)
    const current = spentThrough(state.transactions, viewMonth, through, category.id)
    const stats = sampleStats(prior)
    const spike = classifySpike(current, stats)
    if (spike) {
      anomalies.push({
        id: `category-spike:${category.id}:${viewMonth}`,
        kind: 'category-spike',
        severity: spike.severity,
        categoryId: category.id,
        label: category.name,
        month: viewMonth,
        amount: current,
        baseline: stats.median,
        multiple: spike.multiple,
        message: categorySpikeMessage(category.name, current, stats.median, spike.multiple, pointInMonth),
      })
    }

    const historyCharges = state.transactions
      .filter(
        (transaction) =>
          transaction.kind === 'expense' &&
          transaction.categoryId === category.id &&
          monthKey(transaction.date) < viewMonth,
      )
      .map((transaction) => transaction.amount)
    const chargeStats = sampleStats(historyCharges)
    const monthCharges = state.transactions.filter(
      (transaction) =>
        transaction.kind === 'expense' &&
        transaction.categoryId === category.id &&
        inView(transaction, viewMonth, through),
    )
    for (const transaction of monthCharges) {
      const charge = classifyCharge(transaction.amount, chargeStats)
      if (!charge) continue
      anomalies.push({
        id: `large-charge:${transaction.id}`,
        kind: 'large-charge',
        severity: charge.severity,
        categoryId: category.id,
        label: category.name,
        month: viewMonth,
        amount: transaction.amount,
        baseline: chargeStats.median,
        multiple: charge.multiple,
        message: chargeMessage(category.name, transaction, chargeStats.median, charge.multiple),
        transactionId: transaction.id,
      })
    }
  }

  return anomalies.sort((a, b) => rank(b.severity) - rank(a.severity) || b.amount - a.amount)
}

function inView(transaction: Transaction, viewMonth: string, through: string): boolean {
  return monthKey(transaction.date) === viewMonth && transaction.date <= through
}

function rank(severity: SpendingAnomaly['severity']): number {
  return severity === 'unusual' ? 2 : 1
}

function categorySpikeMessage(
  name: string,
  current: number,
  baseline: number,
  multiple: number,
  pointInMonth: boolean,
): string {
  const timing = pointInMonth ? 'by this point in the month' : 'for a full month'
  return `${name} is ${multiple.toFixed(1)}× the usual ${formatMoney(baseline)} ${timing} (${formatMoney(current)} vs ${formatMoney(baseline)}).`
}

function monthSpikeMessage(
  current: number,
  baseline: number,
  multiple: number,
  pointInMonth: boolean,
  viewMonth: string,
): string {
  const extra = current - baseline
  return pointInMonth
    ? `Total spending is already ${formatMoney(extra)} above a usual month (${formatMoney(current)} vs ${formatMoney(baseline)}).`
    : `${monthLabel(viewMonth)} spending is ${multiple.toFixed(1)}× the usual ${formatMoney(baseline)}.`
}

function chargeMessage(
  name: string,
  transaction: Transaction,
  baseline: number,
  multiple: number,
): string {
  const note = transaction.note ? ` “${transaction.note}”` : ''
  return `${name}${note} has a ${formatMoney(transaction.amount, true)} charge — about ${multiple.toFixed(1)}× a typical ${formatMoney(baseline)} line.`
}
