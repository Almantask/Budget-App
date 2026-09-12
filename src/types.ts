export type TransactionKind = 'expense' | 'income'

export type CategoryId = string

export type Category = {
  id: CategoryId
  name: string
  kind: TransactionKind
  color: string
}

export type Transaction = {
  id: string
  kind: TransactionKind
  categoryId: CategoryId
  amount: number
  date: string
  note: string
}

export type BudgetScope = 'overall' | CategoryId

export type Budget = {
  id: string
  categoryId: BudgetScope
  monthlyLimit: number
  warnAt: number
}

export type AppState = {
  version: 1
  currency: 'EUR'
  demo: boolean
  categories: Category[]
  transactions: Transaction[]
  budgets: Budget[]
}

export type AlertLevel = 'ok' | 'pace' | 'warning' | 'breach'

export type ThresholdAlert = {
  budgetId: string
  categoryId: BudgetScope
  label: string
  spent: number
  limit: number
  warnAt: number
  ratio: number
  projected: number
  level: Exclude<AlertLevel, 'ok'>
  message: string
}

export type MonthPoint = {
  month: string
  label: string
  expenses: number
  gains: number
  net: number
}

export type WeekPoint = {
  key: string
  label: string
  expenses: number
  gains: number
  net: number
}

export type StretchGoal = {
  month: string
  target: number
  baseline: number
  reason: string
}

export type QuestId = 'stretch' | 'under-budget' | 'calm-categories' | 'keep-logging'

export type Quest = {
  id: QuestId
  title: string
  detail: string
  xp: number
  current: number
  target: number
  unit: 'money' | 'count' | 'percent'
  complete: boolean
}

export type AchievementId =
  | 'first-leaf'
  | 'week-streak'
  | 'month-under'
  | 'stretch-rookie'
  | 'stretch-streak'
  | 'big-save'
  | 'quiet-month'
  | 'balanced-grove'
  | 'comeback'
  | 'early-root'

export type Achievement = {
  id: AchievementId
  title: string
  detail: string
  xp: number
  unlocked: boolean
}

export type LevelProgress = {
  level: number
  intoLevel: number
  toNext: number
  progress: number
  totalXp: number
}

export type Tab = 'overview' | 'ledger' | 'budgets' | 'quests'
