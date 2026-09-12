import { ChevronLeft, ChevronRight, Leaf, RotateCcw, Sprout } from 'lucide-react'
import { addMonths, monthLabel } from '../lib/dates.ts'
import { formatMoney } from '../lib/money.ts'
import { useBudget } from '../store/BudgetContext.tsx'
import { Budgets } from './Budgets.tsx'
import { Ledger } from './Ledger.tsx'
import { Overview } from './Overview.tsx'
import { Quests } from './Quests.tsx'
import type { Tab } from '../types.ts'

const TABS: { id: Tab; label: string }[] = [
  { id: 'overview', label: 'Overview' },
  { id: 'ledger', label: 'Ledger' },
  { id: 'budgets', label: 'Budgets' },
  { id: 'quests', label: 'Quests' },
]

export function Shell() {
  const {
    tab,
    setTab,
    viewMonth,
    setMonth,
    minMonth,
    maxMonth,
    derived,
    state,
    loadDemo,
    startFresh,
    dismissDemo,
  } = useBudget()

  function shift(delta: number) {
    const next = addMonths(viewMonth, delta)
    if (next < minMonth || next > maxMonth) return
    setMonth(next)
  }

  return (
    <div className="app">
      <header className="topbar">
        <div className="brand">
          <div className="logo">
            <Sprout size={22} />
          </div>
          <div>
            <h1>Grove</h1>
            <small>Save a little more than last month.</small>
          </div>
        </div>
        <div className="top-actions">
          <div className="month-nav">
            <button aria-label="Previous month" onClick={() => shift(-1)}>
              <ChevronLeft size={18} />
            </button>
            <div className="label">{monthLabel(viewMonth)}</div>
            <button aria-label="Next month" onClick={() => shift(1)}>
              <ChevronRight size={18} />
            </button>
          </div>
          <div className="level-chip" title={`${derived.level.totalXp} XP`}>
            <div className="level-badge">{derived.level.level}</div>
            <div className="level-meta">
              <b>Grove level {derived.level.level}</b>
              <span>
                {derived.level.intoLevel}/{derived.level.toNext} XP
              </span>
              <div className="bar">
                <i style={{ width: `${Math.round(derived.level.progress * 100)}%` }} />
              </div>
            </div>
          </div>
        </div>
      </header>

      {state.demo && (
        <div className="banner">
          <span>
            <Leaf size={16} style={{ marginRight: 8, verticalAlign: '-3px' }} />
            Sample history is loaded so the graph, warnings, and stretch quests have something to
            show. Your edits replace the demo.
          </span>
          <span style={{ display: 'flex', gap: 8 }}>
            <button className="ghost" onClick={dismissDemo}>
              Dismiss
            </button>
            <button className="ghost" onClick={startFresh}>
              Start fresh
            </button>
          </span>
        </div>
      )}

      <nav className="nav">
        {TABS.map((item) => (
          <button
            key={item.id}
            className={tab === item.id ? 'active' : ''}
            onClick={() => setTab(item.id)}
          >
            {item.label}
          </button>
        ))}
      </nav>

      {tab === 'overview' && <Overview />}
      {tab === 'ledger' && <Ledger />}
      {tab === 'budgets' && <Budgets />}
      {tab === 'quests' && <Quests />}

      <p className="muted" style={{ marginTop: 28, display: 'flex', gap: 12, flexWrap: 'wrap' }}>
        <span>{formatMoney(derived.level.totalXp)} equivalent XP grown from real ledger habits.</span>
        <button className="ghost" onClick={loadDemo}>
          <RotateCcw size={14} style={{ verticalAlign: '-2px', marginRight: 6 }} />
          Reload sample months
        </button>
        <button className="ghost" onClick={startFresh}>
          Clear ledger
        </button>
      </p>
    </div>
  )
}
