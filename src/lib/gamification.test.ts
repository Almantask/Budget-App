import { describe, expect, it } from 'vitest'
import { stretchGoalForMonth, levelFromXp, monthQuests } from './gamification.ts'
import { createEmptyState } from '../data/seed.ts'
import { DEFAULT_BUDGETS } from '../data/defaults.ts'
import type { MonthPoint } from '../types.ts'

function point(month: string, net: number): MonthPoint {
  return { month, label: month, expenses: Math.max(0, 2000 - net), gains: 2000, net }
}

describe('stretchGoalForMonth', () => {
  it('uses a starter target when there is no history', () => {
    const goal = stretchGoalForMonth([], '2026-09')
    expect(goal.target).toBe(200)
  })

  it('asks for a modest reset after negative months', () => {
    const goal = stretchGoalForMonth(
      [point('2026-07', -40), point('2026-08', -120)],
      '2026-09',
    )
    expect(goal.target).toBe(80)
  })

  it('stretches about 8–20% above a healthy last month', () => {
    const goal = stretchGoalForMonth(
      [point('2026-06', 400), point('2026-07', 420), point('2026-08', 500)],
      '2026-09',
    )
    expect(goal.target).toBeGreaterThanOrEqual(540)
    expect(goal.target).toBeLessThanOrEqual(600)
  })
})

describe('levelFromXp', () => {
  it('starts at level 1 and climbs as XP accumulates', () => {
    expect(levelFromXp(0).level).toBe(1)
    expect(levelFromXp(119).level).toBe(1)
    expect(levelFromXp(120).level).toBe(2)
    expect(levelFromXp(4000).level).toBeGreaterThan(8)
  })
})

describe('monthQuests', () => {
  it('completes the stretch quest when net savings clear the target', () => {
    const state = createEmptyState()
    state.budgets = DEFAULT_BUDGETS
    state.transactions = [
      {
        id: '1',
        kind: 'income',
        categoryId: 'salary',
        amount: 2000,
        date: '2026-09-01',
        note: 'pay',
      },
      {
        id: '2',
        kind: 'expense',
        categoryId: 'housing',
        amount: 600,
        date: '2026-09-02',
        note: 'rent',
      },
    ]
    const quests = monthQuests({
      state,
      month: '2026-09',
      today: '2026-09-12',
      stretch: { month: '2026-09', target: 1000, baseline: 800, reason: 'test' },
      monthPoint: { month: '2026-09', label: 'Sep 2026', expenses: 600, gains: 2000, net: 1400 },
    })
    expect(quests.find((quest) => quest.id === 'stretch')?.complete).toBe(true)
    expect(quests.find((quest) => quest.id === 'under-budget')?.complete).toBe(true)
  })
})
