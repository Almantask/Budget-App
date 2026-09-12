import type { Budget, Category } from '../types.ts'

export const CATEGORIES: Category[] = [
  { id: 'salary', name: 'Salary', kind: 'income', color: '#8ee4b5' },
  { id: 'freelance', name: 'Freelance', kind: 'income', color: '#7ec8e8' },
  { id: 'other-in', name: 'Other income', kind: 'income', color: '#b7d89a' },
  { id: 'housing', name: 'Housing', kind: 'expense', color: '#c4a574' },
  { id: 'groceries', name: 'Groceries', kind: 'expense', color: '#8fbf7a' },
  { id: 'dining', name: 'Dining', kind: 'expense', color: '#e89b6c' },
  { id: 'transport', name: 'Transport', kind: 'expense', color: '#6ea8d8' },
  { id: 'utilities', name: 'Utilities', kind: 'expense', color: '#9bb0c9' },
  { id: 'health', name: 'Health', kind: 'expense', color: '#e07a8d' },
  { id: 'fun', name: 'Fun', kind: 'expense', color: '#c48ad8' },
  { id: 'shopping', name: 'Shopping', kind: 'expense', color: '#e8c76c' },
  { id: 'other-ex', name: 'Other', kind: 'expense', color: '#a0a8a4' },
]

export const DEFAULT_BUDGETS: Budget[] = [
  { id: 'b-overall', categoryId: 'overall', monthlyLimit: 1600, warnAt: 0.8 },
  { id: 'b-housing', categoryId: 'housing', monthlyLimit: 700, warnAt: 0.9 },
  { id: 'b-groceries', categoryId: 'groceries', monthlyLimit: 340, warnAt: 0.8 },
  { id: 'b-dining', categoryId: 'dining', monthlyLimit: 160, warnAt: 0.75 },
  { id: 'b-transport', categoryId: 'transport', monthlyLimit: 120, warnAt: 0.8 },
  { id: 'b-utilities', categoryId: 'utilities', monthlyLimit: 140, warnAt: 0.85 },
  { id: 'b-health', categoryId: 'health', monthlyLimit: 80, warnAt: 0.8 },
  { id: 'b-fun', categoryId: 'fun', monthlyLimit: 140, warnAt: 0.7 },
  { id: 'b-shopping', categoryId: 'shopping', monthlyLimit: 120, warnAt: 0.7 },
]
