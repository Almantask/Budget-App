import { describe, expect, it } from 'vitest'
import { findSpendingAnomalies, sampleStats } from './anomalies.ts'
import type { AppState, Category, Transaction } from '../types.ts'

function tx(
  id: string,
  categoryId: string,
  amount: number,
  date: string,
  note = '',
): Transaction {
  return { id, kind: 'expense', categoryId, amount, date, note }
}

const categories: Category[] = [
  { id: 'housing', name: 'Housing', kind: 'expense', color: '#c4a574' },
  { id: 'dining', name: 'Dining', kind: 'expense', color: '#e89b6c' },
  { id: 'fun', name: 'Fun', kind: 'expense', color: '#c48ad8' },
]

function state(transactions: Transaction[]): AppState {
  return {
    version: 1,
    currency: 'EUR',
    demo: false,
    categories,
    budgets: [],
    transactions,
  }
}

describe('sampleStats', () => {
  it('computes mean, median, and sample stdev', () => {
    const stats = sampleStats([10, 20, 30, 40])
    expect(stats.n).toBe(4)
    expect(stats.mean).toBe(25)
    expect(stats.median).toBe(25)
    expect(stats.stdev).toBeCloseTo(12.91, 1)
  })
})

describe('findSpendingAnomalies', () => {
  it('flags a category that is far above recent months', () => {
    const transactions = [
      tx('d1', 'dining', 50, '2026-05-04'),
      tx('d2', 'dining', 55, '2026-06-04'),
      tx('d3', 'dining', 48, '2026-07-04'),
      tx('d4', 'dining', 52, '2026-08-04'),
      tx('d5', 'dining', 160, '2026-09-03'),
    ]
    const anomalies = findSpendingAnomalies(state(transactions), '2026-09', '2026-09-12')
    const dining = anomalies.find((item) => item.kind === 'category-spike' && item.categoryId === 'dining')
    expect(dining).toBeTruthy()
    expect(dining?.severity).toBe('unusual')
    expect(dining?.message).toContain('Dining')
  })

  it('does not flag a stable rent payment', () => {
    const transactions = ['2026-04', '2026-05', '2026-06', '2026-07', '2026-08', '2026-09'].map(
      (month, index) => tx(`h${index}`, 'housing', 650, `${month}-02`),
    )
    const anomalies = findSpendingAnomalies(state(transactions), '2026-09', '2026-09-12')
    expect(anomalies.some((item) => item.categoryId === 'housing')).toBe(false)
  })

  it('does not flag a modest grocery bump on an otherwise steady category', () => {
    const transactions = [
      tx('g1', 'dining', 290, '2026-05-04'),
      tx('g2', 'dining', 294, '2026-06-04'),
      tx('g3', 'dining', 288, '2026-07-04'),
      tx('g4', 'dining', 300, '2026-08-04'),
      tx('g5', 'dining', 340, '2026-09-04'),
    ]
    const anomalies = findSpendingAnomalies(state(transactions), '2026-09', '2026-09-12')
    expect(anomalies.some((item) => item.categoryId === 'dining')).toBe(false)
  })

  it('flags a single charge that is much larger than typical lines in that category', () => {
    const transactions = [
      tx('f1', 'fun', 18, '2026-05-14'),
      tx('f2', 'fun', 22, '2026-06-14'),
      tx('f3', 'fun', 20, '2026-07-14'),
      tx('f4', 'fun', 24, '2026-08-14'),
      tx('f5', 'fun', 19, '2026-08-20'),
      tx('f6', 'fun', 96, '2026-09-10', 'Concert tickets'),
    ]
    const anomalies = findSpendingAnomalies(state(transactions), '2026-09', '2026-09-12')
    const charge = anomalies.find((item) => item.kind === 'large-charge' && item.transactionId === 'f6')
    expect(charge).toBeTruthy()
    expect(charge?.message).toContain('Concert tickets')
  })
})
