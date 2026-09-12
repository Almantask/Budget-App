import { describe, expect, it } from 'vitest'
import { evaluateBudget, alertMessage } from './thresholds.ts'

describe('evaluateBudget', () => {
  it('stays ok while spend is below the warning threshold and pace is healthy', () => {
    const result = evaluateBudget({
      spent: 40,
      limit: 200,
      warnAt: 0.8,
      day: 10,
      daysInMonth: 30,
    })
    expect(result.level).toBe('ok')
    expect(result.ratio).toBeCloseTo(0.2)
  })

  it('warns when spend crosses the configured threshold', () => {
    const result = evaluateBudget({
      spent: 165,
      limit: 200,
      warnAt: 0.8,
      day: 18,
      daysInMonth: 30,
    })
    expect(result.level).toBe('warning')
    expect(alertMessage('Dining', result)).toContain('80%')
  })

  it('marks a breach at or above the monthly limit', () => {
    const result = evaluateBudget({
      spent: 210,
      limit: 200,
      warnAt: 0.75,
      day: 20,
      daysInMonth: 30,
    })
    expect(result.level).toBe('breach')
    expect(alertMessage('Dining', result)).toContain('over budget')
  })

  it('flags a pace risk when projected spend will miss the limit', () => {
    const result = evaluateBudget({
      spent: 80,
      limit: 120,
      warnAt: 0.8,
      day: 10,
      daysInMonth: 30,
    })
    expect(result.level).toBe('pace')
    expect(result.projected).toBeCloseTo(240)
    expect(alertMessage('Shopping', result)).toContain('overshoot')
  })

  it('does not pace a single lump-sum bill', () => {
    const result = evaluateBudget({
      spent: 650,
      limit: 700,
      warnAt: 1,
      day: 12,
      daysInMonth: 30,
      transactionCount: 1,
      recentSpent: 0,
      recentDays: 7,
    })
    expect(result.level).toBe('ok')
  })
})
