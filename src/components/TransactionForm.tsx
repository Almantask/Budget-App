import { useState, type FormEvent } from 'react'
import { clampDateToMonth, toIso } from '../lib/dates.ts'
import { useBudget } from '../store/BudgetContext.tsx'
import type { TransactionKind } from '../types.ts'

export function TransactionForm({ onSaved }: { onSaved?: () => void }) {
  const { state, viewMonth, addTransaction, now } = useBudget()
  const today = toIso(now)
  const fallbackDate = clampDateToMonth(today, viewMonth, today)
  const [kind, setKind] = useState<TransactionKind>('expense')
  const categories = state.categories.filter((category) => category.kind === kind)
  const [categoryId, setCategoryId] = useState(categories[0]?.id ?? '')
  const [amount, setAmount] = useState('')
  const [date, setDate] = useState(fallbackDate)
  const [dateMonth, setDateMonth] = useState(viewMonth)
  const [note, setNote] = useState('')

  if (dateMonth !== viewMonth) {
    setDateMonth(viewMonth)
    setDate(fallbackDate)
  }

  function switchKind(next: TransactionKind) {
    setKind(next)
    const nextCategories = state.categories.filter((category) => category.kind === next)
    setCategoryId(nextCategories[0]?.id ?? '')
  }

  function submit(event: FormEvent) {
    event.preventDefault()
    const value = Number(amount)
    if (!Number.isFinite(value) || value <= 0 || !categoryId) return
    addTransaction({
      kind,
      categoryId,
      amount: Math.round(value * 100) / 100,
      date: clampDateToMonth(date, viewMonth, today),
      note: note.trim(),
    })
    setAmount('')
    setNote('')
    onSaved?.()
  }

  return (
    <form className="form" onSubmit={submit}>
      <div className="segmented">
        <button type="button" className={kind === 'expense' ? 'active' : ''} onClick={() => switchKind('expense')}>
          Expense
        </button>
        <button type="button" className={kind === 'income' ? 'active' : ''} onClick={() => switchKind('income')}>
          Gain
        </button>
      </div>
      <div className="fields">
        <label>
          Amount
          <input
            required
            inputMode="decimal"
            min="0.01"
            step="0.01"
            value={amount}
            onChange={(event) => setAmount(event.target.value)}
            placeholder="0.00"
          />
        </label>
        <label>
          Category
          <select value={categoryId} onChange={(event) => setCategoryId(event.target.value)}>
            {categories.map((category) => (
              <option key={category.id} value={category.id}>
                {category.name}
              </option>
            ))}
          </select>
        </label>
        <label>
          Date
          <input type="date" value={date} onChange={(event) => setDate(event.target.value)} />
        </label>
        <label>
          Note
          <input value={note} onChange={(event) => setNote(event.target.value)} placeholder="Optional" />
        </label>
      </div>
      <button className="primary" type="submit">
        Add to ledger
      </button>
    </form>
  )
}
