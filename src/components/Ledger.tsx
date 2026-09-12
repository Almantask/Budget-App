import { Trash2 } from 'lucide-react'
import { useMemo, useState } from 'react'
import { formatMoney } from '../lib/money.ts'
import { useBudget } from '../store/BudgetContext.tsx'
import { TransactionForm } from './TransactionForm.tsx'
import type { TransactionKind } from '../types.ts'

export function Ledger() {
  const { state, viewMonth, deleteTransaction, derived } = useBudget()
  const [kind, setKind] = useState<'all' | TransactionKind>('all')
  const flaggedIds = useMemo(() => {
    return new Set(
      derived.anomalies
        .map((anomaly) => anomaly.transactionId)
        .filter((id): id is string => Boolean(id)),
    )
  }, [derived.anomalies])
  const rows = useMemo(() => {
    return state.transactions
      .filter((transaction) => transaction.date.startsWith(viewMonth))
      .filter((transaction) => (kind === 'all' ? true : transaction.kind === kind))
      .sort((a, b) => b.date.localeCompare(a.date) || b.id.localeCompare(a.id))
  }, [state.transactions, viewMonth, kind])

  return (
    <div className="grid split">
      <section className="card">
        <header>
          <div>
            <h2>Ledger</h2>
            <p>Every gain and expense in the selected month.</p>
          </div>
          <div className="segmented">
            <button className={kind === 'all' ? 'active' : ''} onClick={() => setKind('all')}>
              All
            </button>
            <button className={kind === 'expense' ? 'active' : ''} onClick={() => setKind('expense')}>
              Expenses
            </button>
            <button className={kind === 'income' ? 'active' : ''} onClick={() => setKind('income')}>
              Gains
            </button>
          </div>
        </header>
        {rows.length === 0 ? (
          <p className="empty">Nothing logged this month yet.</p>
        ) : (
          <div className="list">
            {rows.map((transaction) => {
              const category = state.categories.find((item) => item.id === transaction.categoryId)
              const chargeFlag = flaggedIds.has(transaction.id)
              return (
                <article className={`tx ${chargeFlag ? 'anomaly' : ''}`} key={transaction.id}>
                  <time>{transaction.date.slice(8)}</time>
                  <div>
                    <b>
                      {category?.name ?? 'Unknown'}
                      {chargeFlag ? <span className="chip unusual">unusual</span> : null}
                    </b>
                    <small>{transaction.note || transaction.kind}</small>
                  </div>
                  <strong className={transaction.kind === 'income' ? 'up' : 'down'}>
                    {transaction.kind === 'income' ? '+' : '−'}
                    {formatMoney(transaction.amount, true)}
                  </strong>
                  <button
                    className="icon-btn"
                    aria-label="Delete transaction"
                    onClick={() => deleteTransaction(transaction.id)}
                  >
                    <Trash2 size={16} />
                  </button>
                </article>
              )
            })}
          </div>
        )}
      </section>
      <section className="card">
        <header>
          <div>
            <h2>Add a line</h2>
            <p>Log a gain or expense. Dates snap to the month you’re viewing.</p>
          </div>
        </header>
        <TransactionForm />
      </section>
    </div>
  )
}
