import { describe, expect, it } from 'vitest'
import { monthlySeries, loggingStreak, spentInMonth } from './analytics.ts'
import type { Transaction } from '../types.ts'

const tx = (
  id: string,
  kind: Transaction['kind'],
  amount: number,
  date: string,
  categoryId = 'groceries',
): Transaction => ({
  id,
  kind,
  categoryId,
  amount,
  date,
  note: '',
})

describe('monthlySeries', () => {
  it('builds a continuous expense vs gains series', () => {
    const series = monthlySeries(
      [
        tx('1', 'income', 1000, '2026-07-01', 'salary'),
        tx('2', 'expense', 400, '2026-07-08'),
        tx('3', 'income', 1000, '2026-08-01', 'salary'),
        tx('4', 'expense', 250, '2026-08-04'),
        tx('5', 'expense', 50, '2026-09-02'),
      ],
      '2026-09',
      3,
    )
    expect(series.map((point) => point.month)).toEqual(['2026-07', '2026-08', '2026-09'])
    expect(series[0].gains).toBe(1000)
    expect(series[0].expenses).toBe(400)
    expect(series[0].net).toBe(600)
    expect(series[2].gains).toBe(0)
    expect(series[2].expenses).toBe(50)
  })
})

describe('spentInMonth', () => {
  it('sums only expenses for a category and month', () => {
    const transactions = [
      tx('1', 'expense', 10, '2026-09-01', 'dining'),
      tx('2', 'expense', 20, '2026-09-02', 'groceries'),
      tx('3', 'income', 50, '2026-09-02', 'salary'),
      tx('4', 'expense', 5, '2026-08-30', 'dining'),
    ]
    expect(spentInMonth(transactions, '2026-09', 'dining')).toBe(10)
    expect(spentInMonth(transactions, '2026-09')).toBe(30)
  })
})

describe('loggingStreak', () => {
  it('counts consecutive days ending today or yesterday', () => {
    const transactions = [
      tx('1', 'expense', 1, '2026-09-10'),
      tx('2', 'expense', 1, '2026-09-11'),
      tx('3', 'expense', 1, '2026-09-12'),
    ]
    expect(loggingStreak(transactions, '2026-09-12')).toBe(3)
    expect(loggingStreak(transactions, '2026-09-13')).toBe(3)
    expect(loggingStreak(transactions, '2026-09-14')).toBe(0)
  })
})
