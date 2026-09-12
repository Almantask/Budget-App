import { describe, expect, it } from 'vitest'
import { noticesAfterSync, snapshotFromAlerts, snapshotKey } from './notifications.ts'
import type { ThresholdAlert } from '../types.ts'

function alert(partial: Partial<ThresholdAlert> & Pick<ThresholdAlert, 'budgetId' | 'level' | 'message'>): ThresholdAlert {
  return {
    categoryId: 'dining',
    label: 'Dining',
    spent: 130,
    limit: 160,
    warnAt: 0.75,
    ratio: 0.81,
    projected: 200,
    ...partial,
  }
}

describe('noticesAfterSync', () => {
  it('opens a notice when a sync finds a budget newly over its warning line', () => {
    const dining = alert({ budgetId: 'b-dining', level: 'warning', message: 'Dining hit 75%' })
    const notices = noticesAfterSync({
      previous: {},
      alerts: [dining],
      month: '2026-09',
      at: '2026-09-12T12:00:00',
      ids: ['n1'],
    })
    expect(notices).toHaveLength(1)
    expect(notices[0]?.label).toBe('Dining')
    expect(notices[0]?.level).toBe('warning')
  })

  it('does not repeat the same warning on a later sync', () => {
    const dining = alert({ budgetId: 'b-dining', level: 'warning', message: 'Dining hit 75%' })
    const previous = snapshotFromAlerts('2026-09', [dining])
    const notices = noticesAfterSync({
      previous,
      alerts: [dining],
      month: '2026-09',
      at: '2026-09-12T12:01:00',
      ids: ['n2'],
    })
    expect(notices).toHaveLength(0)
    expect(snapshotKey('2026-09', 'b-dining')).toBe('2026-09:b-dining')
  })

  it('notifies again when a warning worsens to a breach', () => {
    const previous = snapshotFromAlerts('2026-09', [
      alert({ budgetId: 'b-dining', level: 'warning', message: 'Dining hit 75%' }),
    ])
    const notices = noticesAfterSync({
      previous,
      alerts: [alert({ budgetId: 'b-dining', level: 'breach', message: 'Dining is over budget' })],
      month: '2026-09',
      at: '2026-09-12T12:02:00',
      ids: ['n3'],
    })
    expect(notices).toHaveLength(1)
    expect(notices[0]?.level).toBe('breach')
  })

  it('ignores pace alerts that are not yet over the threshold', () => {
    const notices = noticesAfterSync({
      previous: {},
      alerts: [alert({ budgetId: 'b-dining', level: 'pace', message: 'Dining may overshoot' })],
      month: '2026-09',
      at: '2026-09-12T12:00:00',
      ids: ['n4'],
    })
    expect(notices).toHaveLength(0)
  })
})
