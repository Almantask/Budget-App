import { describe, expect, it } from 'vitest'
import { createDemoState } from '../data/seed.ts'
import { deriveView } from './derive.ts'

describe('demo September 2026', () => {
  it('shows over-time history, dining warnings, and a stretch target', () => {
    const now = new Date(2026, 8, 12)
    const state = createDemoState(now)
    const view = deriveView(state, '2026-09', now)

    expect(view.series.length).toBe(12)
    expect(view.series.some((point) => point.gains > 0 && point.month < '2026-09')).toBe(true)
    expect(view.stretch.target).toBeGreaterThan(0)
    expect(view.alerts.some((alert) => alert.categoryId === 'dining')).toBe(true)
    expect(view.quests).toHaveLength(4)
    expect(view.achievements.some((achievement) => achievement.unlocked)).toBe(true)
  })
})
