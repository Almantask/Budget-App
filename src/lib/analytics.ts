import { addMonths, daysInMonth, monthKey, monthLabel, monthsUntil } from './dates.ts'
import { roundMoney } from './money.ts'
import type { Category, MonthPoint, Transaction, WeekPoint } from '../types.ts'

export function inMonth(transaction: Transaction, month: string): boolean {
  return monthKey(transaction.date) === month
}

export function sumBy(
  transactions: Transaction[],
  predicate: (transaction: Transaction) => boolean,
): number {
  return roundMoney(
    transactions.reduce((total, transaction) => {
      return predicate(transaction) ? total + transaction.amount : total
    }, 0),
  )
}

export function monthTotals(transactions: Transaction[], month: string): MonthPoint {
  const monthTx = transactions.filter((transaction) => inMonth(transaction, month))
  const expenses = sumBy(monthTx, (transaction) => transaction.kind === 'expense')
  const gains = sumBy(monthTx, (transaction) => transaction.kind === 'income')
  return {
    month,
    label: monthLabel(month),
    expenses,
    gains,
    net: roundMoney(gains - expenses),
  }
}

export function monthlySeries(
  transactions: Transaction[],
  throughMonth: string,
  count = 12,
): MonthPoint[] {
  return monthsUntil(throughMonth, count).map((month) => monthTotals(transactions, month))
}

export function historyBefore(series: MonthPoint[], month: string): MonthPoint[] {
  return series.filter((point) => point.month < month)
}

export function firstTransactionMonth(transactions: Transaction[], fallback: string): string {
  if (transactions.length === 0) return fallback
  return transactions.reduce((earliest, transaction) => {
    const month = monthKey(transaction.date)
    return month < earliest ? month : earliest
  }, monthKey(transactions[0].date))
}

export function fullHistory(transactions: Transaction[], throughMonth: string): MonthPoint[] {
  const start = firstTransactionMonth(transactions, throughMonth)
  let count = 1
  let cursor = start
  while (cursor < throughMonth) {
    cursor = addMonths(cursor, 1)
    count += 1
  }
  return monthlySeries(transactions, throughMonth, count)
}

export function weeklySeries(transactions: Transaction[], month: string): WeekPoint[] {
  const lastDay = daysInMonth(month)
  const buckets: WeekPoint[] = []
  for (let start = 1; start <= lastDay; start += 7) {
    const end = Math.min(start + 6, lastDay)
    const startIso = `${month}-${String(start).padStart(2, '0')}`
    const endIso = `${month}-${String(end).padStart(2, '0')}`
    const slice = transactions.filter(
      (transaction) => transaction.date >= startIso && transaction.date <= endIso,
    )
    const expenses = sumBy(slice, (transaction) => transaction.kind === 'expense')
    const gains = sumBy(slice, (transaction) => transaction.kind === 'income')
    buckets.push({
      key: `${start}-${end}`,
      label: `${start}–${end}`,
      expenses,
      gains,
      net: roundMoney(gains - expenses),
    })
  }
  return buckets
}

export function spentInMonth(
  transactions: Transaction[],
  month: string,
  categoryId?: string,
): number {
  return sumBy(transactions, (transaction) => {
    if (!inMonth(transaction, month) || transaction.kind !== 'expense') return false
    return categoryId ? transaction.categoryId === categoryId : true
  })
}

export function categoryBreakdown(
  transactions: Transaction[],
  categories: Category[],
  month: string,
  kind: Transaction['kind'],
): { category: Category; total: number }[] {
  return categories
    .filter((category) => category.kind === kind)
    .map((category) => ({
      category,
      total: sumBy(
        transactions,
        (transaction) =>
          inMonth(transaction, month) &&
          transaction.kind === kind &&
          transaction.categoryId === category.id,
      ),
    }))
    .filter((row) => row.total > 0)
    .sort((a, b) => b.total - a.total)
}

export function loggingDates(transactions: Transaction[]): string[] {
  return [...new Set(transactions.map((transaction) => transaction.date))].sort()
}

export function loggingStreak(transactions: Transaction[], today: string): number {
  const dates = new Set(loggingDates(transactions))
  let streak = 0
  const cursor = new Date(`${today}T00:00:00`)
  if (!dates.has(today)) {
    cursor.setDate(cursor.getDate() - 1)
  }
  while (dates.has(toIsoLocal(cursor))) {
    streak += 1
    cursor.setDate(cursor.getDate() - 1)
  }
  return streak
}

export function datesLoggedInMonth(
  transactions: Transaction[],
  month: string,
  throughDate: string,
): number {
  return new Set(
    transactions
      .filter((transaction) => inMonth(transaction, month) && transaction.date <= throughDate)
      .map((transaction) => transaction.date),
  ).size
}

function toIsoLocal(date: Date): string {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
}
