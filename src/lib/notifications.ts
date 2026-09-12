import type { AlertLevel, BudgetScope, ThresholdAlert } from '../types.ts'

export type NoticeLevel = 'warning' | 'breach'

export type ThresholdNotice = {
  id: string
  at: string
  month: string
  budgetId: string
  categoryId: BudgetScope
  label: string
  level: NoticeLevel
  message: string
  read: boolean
}

export type AlertSnapshot = Record<string, AlertLevel | 'ok'>

const RANK: Record<AlertLevel | 'ok', number> = {
  ok: 0,
  pace: 1,
  warning: 2,
  breach: 3,
}

export function snapshotKey(month: string, budgetId: string): string {
  return `${month}:${budgetId}`
}

export function snapshotFromAlerts(month: string, alerts: ThresholdAlert[]): AlertSnapshot {
  const snapshot: AlertSnapshot = {}
  for (const alert of alerts) {
    snapshot[snapshotKey(month, alert.budgetId)] = alert.level
  }
  return snapshot
}

export function noticesAfterSync(input: {
  previous: AlertSnapshot
  alerts: ThresholdAlert[]
  month: string
  at: string
  ids: string[]
}): ThresholdNotice[] {
  const notices: ThresholdNotice[] = []
  let idIndex = 0
  for (const alert of input.alerts) {
    if (alert.level !== 'warning' && alert.level !== 'breach') continue
    const key = snapshotKey(input.month, alert.budgetId)
    const before = input.previous[key] ?? 'ok'
    if (RANK[alert.level] <= RANK[before]) continue
    notices.push({
      id: input.ids[idIndex] ?? `${key}-${alert.level}-${input.at}`,
      at: input.at,
      month: input.month,
      budgetId: alert.budgetId,
      categoryId: alert.categoryId,
      label: alert.label,
      level: alert.level,
      message: alert.message,
      read: false,
    })
    idIndex += 1
  }
  return notices
}

export function desktopNotificationTitle(notice: ThresholdNotice): string {
  return notice.level === 'breach' ? `Grove · ${notice.label} is over budget` : `Grove · ${notice.label} hit its warning line`
}

export function pushDesktopNotice(notice: ThresholdNotice): boolean {
  if (typeof Notification === 'undefined') return false
  if (Notification.permission !== 'granted') return false
  new Notification(desktopNotificationTitle(notice), {
    body: notice.message,
    icon: '/favicon.svg',
    tag: `${notice.month}:${notice.budgetId}:${notice.level}`,
  })
  return true
}

export async function requestDesktopPermission(): Promise<NotificationPermission | 'unsupported'> {
  if (typeof Notification === 'undefined') return 'unsupported'
  if (Notification.permission !== 'default') return Notification.permission
  return Notification.requestPermission()
}
