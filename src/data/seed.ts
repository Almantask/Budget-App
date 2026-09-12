import { CATEGORIES, DEFAULT_BUDGETS } from './defaults.ts'
import { addMonths, daysInMonth, monthKey, toIso } from '../lib/dates.ts'
import { roundMoney } from '../lib/money.ts'
import type { AppState, Transaction } from '../types.ts'

function mulberry32(seed: number) {
  let a = seed >>> 0
  return () => {
    a += 0x6d2b79f5
    let t = a
    t = Math.imul(t ^ (t >>> 15), t | 1)
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

function pick(rng: () => number, min: number, max: number): number {
  return roundMoney(min + rng() * (max - min))
}

function dayIso(month: string, day: number): string {
  return `${month}-${String(day).padStart(2, '0')}`
}

export function createDemoState(now = new Date()): AppState {
  const rng = mulberry32(20260912)
  const today = toIso(now)
  const current = monthKey(now)
  const start = addMonths(current, -8)
  const transactions: Transaction[] = []
  let n = 0

  const push = (
    kind: Transaction['kind'],
    categoryId: string,
    amount: number,
    date: string,
    note: string,
  ) => {
    if (date > today) return
    transactions.push({
      id: `seed-${n}`,
      kind,
      categoryId,
      amount: roundMoney(amount),
      date,
      note,
    })
    n += 1
  }

  let month = start
  while (month <= current) {
    const lastDay = daysInMonth(month)
    const isJune = month.endsWith('-06')
    const isAugust = month.endsWith('-08')
    const isMarch = month.endsWith('-03')
    const isCurrent = month === current

    push('income', 'salary', 2450, dayIso(month, 1), 'Monthly salary')
    if (isMarch) push('income', 'freelance', 420, dayIso(month, 18), 'Illustration gig')
    if (isAugust) push('income', 'freelance', 260, dayIso(month, 12), 'Weekend workshop')

    push('expense', 'housing', 650, dayIso(month, 2), 'Rent')
    push('expense', 'utilities', pick(rng, 88, 128), dayIso(month, 6), 'Power, water, internet')

    const groceryDays = [4, 11, 18, 25].filter((day) => day <= lastDay)
    for (const day of groceryDays) {
      const bump = isJune ? 18 : 0
      push('expense', 'groceries', pick(rng, 58, 88) + bump, dayIso(month, day), 'Weekly shop')
    }

    const diningCount = isJune ? 8 : isAugust ? 3 : 5
    for (let i = 0; i < diningCount; i += 1) {
      const day = 3 + i * 4
      if (day > lastDay) continue
      push(
        'expense',
        'dining',
        pick(rng, 12, isJune ? 42 : 28),
        dayIso(month, day),
        i % 2 === 0 ? 'Lunch out' : 'Dinner with friends',
      )
    }

    push('expense', 'transport', pick(rng, 28, 48), dayIso(month, 8), 'Transit pass top-up')
    if (rng() > 0.35) {
      push('expense', 'transport', pick(rng, 14, 32), dayIso(month, 21), 'Fuel / rides')
    }

    if (!isAugust) {
      push('expense', 'fun', pick(rng, 18, 54), dayIso(month, 14), 'Cinema, games, plans')
    }
    if (isJune) {
      push('expense', 'fun', 86, dayIso(month, 22), 'Concert tickets')
    }

    if (isJune || rng() > 0.45) {
      push(
        'expense',
        'shopping',
        pick(rng, 24, isJune ? 110 : 70),
        dayIso(month, isJune ? 16 : 19),
        isJune ? 'Holiday clothes' : 'Household bits',
      )
    }

    if (rng() > 0.55) {
      push('expense', 'health', pick(rng, 16, 62), dayIso(month, 10), 'Pharmacy / checkup')
    }

    if (isCurrent) {
      push('expense', 'dining', 36, dayIso(month, Math.min(9, lastDay)), 'Birthday dinner')
      push('expense', 'dining', 22, dayIso(month, Math.min(11, lastDay)), 'Takeaway after work')
      push('expense', 'dining', 40, dayIso(month, Math.min(10, lastDay)), 'Weekend brunch')
      push('expense', 'shopping', 79, dayIso(month, Math.min(8, lastDay)), 'New headphones case')
      push('expense', 'groceries', 44, dayIso(month, Math.min(7, lastDay)), 'Mid-week restock')
    }

    month = addMonths(month, 1)
  }

  return {
    version: 1,
    currency: 'EUR',
    demo: true,
    categories: CATEGORIES,
    budgets: DEFAULT_BUDGETS.map((budget) => ({ ...budget })),
    transactions,
  }
}

export function createEmptyState(): AppState {
  return {
    version: 1,
    currency: 'EUR',
    demo: false,
    categories: CATEGORIES,
    budgets: DEFAULT_BUDGETS.map((budget) => ({ ...budget })),
    transactions: [],
  }
}
