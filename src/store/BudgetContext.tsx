import { createContext, useContext, useEffect, useMemo, useReducer, useRef, useState, type ReactNode } from 'react'
import { createDemoState, createEmptyState } from '../data/seed.ts'
import { addMonths, monthKey, toIso } from '../lib/dates.ts'
import { deriveView } from '../lib/derive.ts'
import { loggingStreak } from '../lib/analytics.ts'
import { createId } from '../lib/id.ts'
import {
  noticesAfterSync,
  pushDesktopNotice,
  requestDesktopPermission,
  snapshotFromAlerts,
  type AlertSnapshot,
  type ThresholdNotice,
} from '../lib/notifications.ts'
import { collectAlerts } from '../lib/thresholds.ts'
import type { AppState, Budget, Tab, Transaction } from '../types.ts'
import { clearJson, clearNoticeJson, loadJson, loadNoticeJson, saveJson, saveNoticeJson } from './storage.ts'

type Action =
  | { type: 'add-transaction'; transaction: Omit<Transaction, 'id'> }
  | { type: 'delete-transaction'; id: string }
  | { type: 'update-budget'; id: string; patch: Partial<Pick<Budget, 'monthlyLimit' | 'warnAt'>> }
  | { type: 'set-month'; month: string }
  | { type: 'set-tab'; tab: Tab }
  | { type: 'load-demo' }
  | { type: 'start-fresh' }
  | { type: 'dismiss-demo' }

type Store = {
  state: AppState
  viewMonth: string
  tab: Tab
}

type StoredNotices = {
  snapshot: AlertSnapshot
  notices: ThresholdNotice[]
}

function todayMonth(): string {
  return monthKey(new Date())
}

function initialStore(): Store {
  const fallback = createDemoState(new Date())
  const saved = loadJson<AppState | null>(null)
  const state =
    saved && saved.version === 1 && Array.isArray(saved.transactions) ? saved : fallback
  return { state, viewMonth: todayMonth(), tab: 'overview' }
}

function reducer(store: Store, action: Action): Store {
  switch (action.type) {
    case 'add-transaction':
      return {
        ...store,
        state: {
          ...store.state,
          demo: false,
          transactions: [
            { ...action.transaction, id: createId() },
            ...store.state.transactions,
          ],
        },
      }
    case 'delete-transaction':
      return {
        ...store,
        state: {
          ...store.state,
          transactions: store.state.transactions.filter((transaction) => transaction.id !== action.id),
        },
      }
    case 'update-budget':
      return {
        ...store,
        state: {
          ...store.state,
          budgets: store.state.budgets.map((budget) =>
            budget.id === action.id ? { ...budget, ...action.patch } : budget,
          ),
        },
      }
    case 'set-month':
      return { ...store, viewMonth: action.month }
    case 'set-tab':
      return { ...store, tab: action.tab }
    case 'load-demo':
      return { state: createDemoState(new Date()), viewMonth: todayMonth(), tab: store.tab }
    case 'start-fresh':
      return { state: createEmptyState(), viewMonth: todayMonth(), tab: store.tab }
    case 'dismiss-demo':
      return { ...store, state: { ...store.state, demo: false } }
    default:
      return store
  }
}

const BudgetContext = createContext<ReturnType<typeof useBudgetValue> | null>(null)

function useBudgetValue() {
  const [store, dispatch] = useReducer(reducer, undefined, initialStore)
  const stored = useMemo(
    () => loadNoticeJson<StoredNotices>({ snapshot: {}, notices: [] }),
    [],
  )
  const snapshotRef = useRef(stored.snapshot)
  const noticesRef = useRef<ThresholdNotice[]>(stored.notices)
  const [notices, setNotices] = useState<ThresholdNotice[]>(stored.notices)
  const [toasts, setToasts] = useState<ThresholdNotice[]>([])
  const [desktopPermission, setDesktopPermission] = useState<NotificationPermission | 'unsupported'>(() => {
    if (typeof Notification === 'undefined') return 'unsupported'
    return Notification.permission
  })

  const viewMonthRef = useRef(store.viewMonth)
  viewMonthRef.current = store.viewMonth

  useEffect(() => {
    saveJson(store.state)
    const persisted = loadNoticeJson<StoredNotices>({
      snapshot: snapshotRef.current,
      notices: noticesRef.current,
    })
    const today = toIso(new Date())
    const month = viewMonthRef.current
    const alerts = collectAlerts(store.state, month, today)
    const fresh = noticesAfterSync({
      previous: persisted.snapshot,
      alerts,
      month,
      at: new Date().toISOString(),
      ids: alerts.map(() => createId()),
    })
    const monthSnap = snapshotFromAlerts(month, alerts)
    const nextSnapshot: AlertSnapshot = { ...persisted.snapshot }
    for (const key of Object.keys(nextSnapshot)) {
      if (key.startsWith(`${month}:`)) nextSnapshot[key] = 'ok'
    }
    Object.assign(nextSnapshot, monthSnap)
    snapshotRef.current = nextSnapshot

    if (fresh.length > 0) {
      const nextNotices = [...fresh, ...noticesRef.current].slice(0, 40)
      noticesRef.current = nextNotices
      setNotices(nextNotices)
      setToasts((current) => [...fresh, ...current].slice(0, 4))
      for (const notice of fresh) pushDesktopNotice(notice)
    }
    saveNoticeJson({ snapshot: nextSnapshot, notices: noticesRef.current })
  }, [store.state])

  useEffect(() => {
    noticesRef.current = notices
    saveNoticeJson({ snapshot: snapshotRef.current, notices })
  }, [notices])

  const today = toIso(new Date())
  const now = useMemo(() => new Date(`${today}T12:00:00`), [today])
  const derived = useMemo(
    () => deriveView(store.state, store.viewMonth, now),
    [store.state, store.viewMonth, now],
  )
  const streak = useMemo(
    () => loggingStreak(store.state.transactions, toIso(now)),
    [store.state.transactions, now],
  )

  function resetNotices() {
    snapshotRef.current = {}
    noticesRef.current = []
    setNotices([])
    setToasts([])
    clearNoticeJson()
  }

  return {
    ...store,
    derived,
    streak,
    now,
    notices,
    toasts,
    desktopPermission,
    unreadCount: notices.filter((notice) => !notice.read).length,
    maxMonth: todayMonth(),
    minMonth: addMonths(todayMonth(), -24),
    addTransaction(transaction: Omit<Transaction, 'id'>) {
      dispatch({ type: 'add-transaction', transaction })
    },
    deleteTransaction(id: string) {
      dispatch({ type: 'delete-transaction', id })
    },
    updateBudget(id: string, patch: Partial<Pick<Budget, 'monthlyLimit' | 'warnAt'>>) {
      dispatch({ type: 'update-budget', id, patch })
    },
    setMonth(month: string) {
      dispatch({ type: 'set-month', month })
    },
    setTab(tab: Tab) {
      dispatch({ type: 'set-tab', tab })
    },
    loadDemo() {
      resetNotices()
      clearJson()
      dispatch({ type: 'load-demo' })
    },
    startFresh() {
      resetNotices()
      dispatch({ type: 'start-fresh' })
    },
    dismissDemo() {
      dispatch({ type: 'dismiss-demo' })
    },
    dismissToast(id: string) {
      setToasts((current) => current.filter((toast) => toast.id !== id))
    },
    markNoticeRead(id: string) {
      setNotices((current) => current.map((notice) => (notice.id === id ? { ...notice, read: true } : notice)))
    },
    markAllRead() {
      setNotices((current) => current.map((notice) => ({ ...notice, read: true })))
    },
    openNotice(notice: ThresholdNotice) {
      setNotices((current) => current.map((item) => (item.id === notice.id ? { ...item, read: true } : item)))
      dispatch({ type: 'set-month', month: notice.month })
      dispatch({ type: 'set-tab', tab: 'budgets' })
    },
    async enableDesktopNotifications() {
      const permission = await requestDesktopPermission()
      setDesktopPermission(permission)
      return permission
    },
  }
}

export function BudgetProvider({ children }: { children: ReactNode }) {
  const value = useBudgetValue()
  return <BudgetContext.Provider value={value}>{children}</BudgetContext.Provider>
}

export function useBudget() {
  const value = useContext(BudgetContext)
  if (!value) throw new Error('useBudget must be used inside BudgetProvider')
  return value
}
