import { spentInMonth } from '../lib/analytics.ts'
import { daysInMonth, monthKey, toDate } from '../lib/dates.ts'
import { formatMoney, formatPercent } from '../lib/money.ts'
import { budgetLabel, evaluateBudget } from '../lib/thresholds.ts'
import { useBudget } from '../store/BudgetContext.tsx'

export function Budgets() {
  const { state, viewMonth, derived, updateBudget } = useBudget()
  const today = derived.today
  const day = monthKey(today) === viewMonth ? toDate(today).getDate() : daysInMonth(viewMonth)

  return (
    <div className="grid split">
      <section className="card">
        <header>
          <div>
            <h2>Budget thresholds</h2>
            <p>
              Each budget has a limit and a warning line. Grove also watches your pace so a quiet
              start of the month doesn’t hide an overspend later.
            </p>
          </div>
        </header>
        <div className="rows">
          {state.budgets.map((budget) => {
            const spent =
              budget.categoryId === 'overall'
                ? spentInMonth(state.transactions, viewMonth)
                : spentInMonth(state.transactions, viewMonth, budget.categoryId)
            const evaluation = evaluateBudget({
              spent,
              limit: budget.monthlyLimit,
              warnAt: budget.warnAt,
              day,
              daysInMonth: daysInMonth(viewMonth),
            })
            const label = budgetLabel(budget, state)
            const width = Math.min(100, evaluation.ratio * 100)
            const warnMark = budget.warnAt * 100
            return (
              <article className="budget" key={budget.id}>
                <div className="meta">
                  <div>
                    <b>{label}</b>
                    <div className="muted">
                      {formatMoney(spent)} of {formatMoney(budget.monthlyLimit)} · warns at{' '}
                      {formatPercent(budget.warnAt)}
                    </div>
                  </div>
                  <span className={`chip ${evaluation.level}`}>{evaluation.level}</span>
                </div>
                <div className="bar" style={{ position: 'relative' }}>
                  <i
                    style={{
                      width: `${width}%`,
                      background:
                        evaluation.level === 'breach'
                          ? 'var(--rose)'
                          : evaluation.level === 'warning'
                            ? 'var(--warn)'
                            : evaluation.level === 'pace'
                              ? 'var(--pace)'
                              : 'var(--mint)',
                    }}
                  />
                  <span
                    style={{
                      position: 'absolute',
                      left: `${warnMark}%`,
                      top: -3,
                      bottom: -3,
                      width: 2,
                      background: 'var(--gold)',
                    }}
                  />
                </div>
                <div className="fields">
                  <label>
                    Monthly limit
                    <input
                      type="number"
                      min="0"
                      step="10"
                      value={budget.monthlyLimit}
                      onChange={(event) =>
                        updateBudget(budget.id, { monthlyLimit: Number(event.target.value) || 0 })
                      }
                    />
                  </label>
                  <label>
                    Warn at {Math.round(budget.warnAt * 100)}%
                    <input
                      type="range"
                      min="50"
                      max="100"
                      step="5"
                      value={Math.round(budget.warnAt * 100)}
                      onChange={(event) =>
                        updateBudget(budget.id, { warnAt: Number(event.target.value) / 100 })
                      }
                    />
                  </label>
                </div>
              </article>
            )
          })}
        </div>
      </section>
      <section className="card">
        <header>
          <div>
            <h2>How warnings work</h2>
          </div>
        </header>
        <p className="help">
          <b>Pace</b> means your current daily spend would miss the limit if it continues.
          <br />
          <br />
          <b>Warning</b> means you’ve crossed the threshold you chose — the gold tick on each bar.
          <br />
          <br />
          <b>Breach</b> means the month’s limit is already gone.
          <br />
          <br />
          Tighten a threshold if a category tends to sneak up on you (dining and shopping start
          stricter). Housing can sit higher because rent is usually fixed.
        </p>
        <p className="help" style={{ marginTop: 16 }}>
          Alerts also appear on Overview so you don’t have to hunt for them. Changing a limit or
          warning line updates the quest board immediately.
        </p>
      </section>
    </div>
  )
}
