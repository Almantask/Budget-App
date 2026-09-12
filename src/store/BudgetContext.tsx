import { createContext, useContext, useEffect, useMemo, useReducer, type ReactNode } from 'react'
import { createDemoState, createEmptyState } from '../data/seed.ts'
import { addMonths, monthKey, toIso } from '../lib/dates.ts'
import { deriveView } from '../lib/derive.ts'
import { loggingStreak } from '../lib/analytics.ts'
import type { AppState, Budget, Tab, Transaction } from '../types.ts'
import { clearJson, loadJson, saveJson } from './storage.ts'

export function createId(): string {
  return crypto.randomUUID()
}

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

  useEffect(() => {
    saveJson(store.state)
  }, [store.state])

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

  return {
    ...store,
    derived,
    streak,
    now,
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
      clearJson()
      dispatch({ type: 'load-demo' })
    },
    startFresh() {
      dispatch({ type: 'start-fresh' })
    },
    dismissDemo() {
      dispatch({ type: 'dismiss-demo' })
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
