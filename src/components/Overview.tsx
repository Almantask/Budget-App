import { formatMoney, formatSigned } from '../lib/money.ts'
import { monthLabel } from '../lib/dates.ts'
import { useBudget } from '../store/BudgetContext.tsx'
import { Alerts } from './Alerts.tsx'
import { TransactionForm } from './TransactionForm.tsx'
import { TrendChart, WeeklyBars } from './TrendChart.tsx'
import { useState } from 'react'

export function Overview() {
  const { derived, viewMonth, setTab } = useBudget()
  const [mode, setMode] = useState<'monthly' | 'weekly'>('monthly')
  const netClass = derived.monthPoint.net >= 0 ? 'up' : 'down'

  return (
    <div>
      <Alerts alerts={derived.alerts} />
      <div className="grid stats">
        <article className="card stat">
          <span className="kicker">Gains</span>
          <strong className="up">{formatMoney(derived.monthPoint.gains)}</strong>
          <p className="muted">Income in {monthLabel(viewMonth)}</p>
        </article>
        <article className="card stat">
          <span className="kicker">Expenses</span>
          <strong className="down">{formatMoney(derived.monthPoint.expenses)}</strong>
          <p className="muted">Money leaving this month</p>
        </article>
        <article className="card stat">
          <span className="kicker">Net</span>
          <strong className={netClass}>{formatSigned(derived.monthPoint.net)}</strong>
          <p className="muted">Saved after expenses</p>
        </article>
        <article className="card stat">
          <span className="kicker">Stretch</span>
          <strong>{formatMoney(derived.stretch.target)}</strong>
          <p className="muted">{Math.round(derived.stretchProgress * 100)}% of this month’s extra save</p>
        </article>
      </div>

      <div className="grid split" style={{ marginTop: 16 }}>
        <section className="card">
          <header>
            <div>
              <h2>Expenses and gains over time</h2>
              <p>Compare money in, money out, and what actually stayed saved.</p>
            </div>
            <div className="segmented">
              <button className={mode === 'monthly' ? 'active' : ''} onClick={() => setMode('monthly')}>
                Monthly
              </button>
              <button className={mode === 'weekly' ? 'active' : ''} onClick={() => setMode('weekly')}>
                This month
              </button>
            </div>
          </header>
          <TrendChart series={derived.series} weekly={derived.weekly} mode={mode} />
          {mode === 'weekly' && <WeeklyBars weekly={derived.weekly} />}
        </section>

        <section className="card">
          <header>
            <div>
              <h2>This month’s stretch</h2>
              <p>{derived.stretch.reason}</p>
            </div>
          </header>
          <div className="bar" style={{ height: 12, margin: '8px 0 16px' }}>
            <i style={{ width: `${Math.round(derived.stretchProgress * 100)}%` }} />
          </div>
          <div className="rows">
            {derived.quests.map((quest) => (
              <div className="quest" key={quest.id}>
                <div className="meta" style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <b>{quest.title}</b>
                  <span className={`chip ${quest.complete ? 'ok' : ''}`}>{quest.complete ? 'Done' : `+${quest.xp} XP`}</span>
                </div>
                <p className="muted">{quest.detail}</p>
              </div>
            ))}
          </div>
          <button className="ghost" style={{ marginTop: 12 }} onClick={() => setTab('quests')}>
            Open quest board
          </button>
        </section>
      </div>

      <div className="grid split" style={{ marginTop: 16 }}>
        <section className="card">
          <header>
            <div>
              <h2>Where {monthLabel(viewMonth)} went</h2>
              <p>Category spend for the selected month.</p>
            </div>
          </header>
          {derived.expenses.length === 0 ? (
            <p className="empty">No expenses logged yet.</p>
          ) : (
            <div className="rows">
              {derived.expenses.map(({ category, total }) => (
                <div className="row" key={category.id}>
                  <span className="swatch" style={{ background: category.color }} />
                  <div>
                    <b>{category.name}</b>
                    <div className="bar">
                      <i
                        style={{
                          width: `${Math.min(100, (total / derived.monthPoint.expenses) * 100)}%`,
                          background: category.color,
                        }}
                      />
                    </div>
                  </div>
                  <span>{formatMoney(total)}</span>
                </div>
              ))}
            </div>
          )}
        </section>
        <section className="card">
          <header>
            <div>
              <h2>Quick add</h2>
              <p>Keep the ledger warm — every log feeds your streak and stretch.</p>
            </div>
          </header>
          <TransactionForm />
        </section>
      </div>
    </div>
  )
}
