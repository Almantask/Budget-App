import { formatMoney, formatSigned } from '../lib/money.ts'
import { monthLabel } from '../lib/dates.ts'
import { loggingStreak } from '../lib/analytics.ts'
import { useBudget } from '../store/BudgetContext.tsx'

export function Quests() {
  const { derived, state } = useBudget()
  const complete = derived.quests.filter((quest) => quest.complete).length
  const liveStreak = loggingStreak(state.transactions, derived.today)

  return (
    <div className="grid split">
      <section className="card">
        <header>
          <div>
            <h2>Monthly stretch</h2>
            <p>{derived.stretch.reason}</p>
          </div>
          <span className="chip">{complete}/4 quests</span>
        </header>
        <div className="ring-wrap">
          <svg className="ring" viewBox="0 0 120 120">
            <circle cx="60" cy="60" r="50" stroke="rgba(255,255,255,0.08)" strokeWidth="10" fill="none" />
            <circle
              cx="60"
              cy="60"
              r="50"
              stroke="#e6c27a"
              strokeWidth="10"
              fill="none"
              strokeLinecap="round"
              strokeDasharray={`${Math.round(derived.stretchProgress * 314)} 314`}
              transform="rotate(-90 60 60)"
            />
            <text x="60" y="56" textAnchor="middle" fill="#e6c27a" fontSize="18" fontFamily="Fraunces">
              {Math.round(derived.stretchProgress * 100)}%
            </text>
            <text x="60" y="74" textAnchor="middle" fill="#9bb0a4" fontSize="10">
              to stretch
            </text>
          </svg>
          <div>
            <p className="muted">Saved so far</p>
            <h3 style={{ fontSize: 36 }}>{formatSigned(derived.monthPoint.net)}</h3>
            <p className="muted">Goal {formatMoney(derived.stretch.target)}</p>
            <p className="help" style={{ marginTop: 10 }}>
              Each new month looks at your last three months and asks for a little more — usually
              8–12% extra — unless you had a hard month, in which case Grove resets to a gentle
              target instead of punishing you.
            </p>
          </div>
        </div>
        <div className="rows" style={{ marginTop: 18 }}>
          {derived.quests.map((quest) => {
            const ratio =
              quest.id === 'under-budget'
                ? Math.min(1, quest.current / quest.target)
                : Math.min(1, quest.current / Math.max(quest.target, 1))
            return (
              <article className={`quest ${quest.complete ? 'complete' : ''}`} key={quest.id}>
                <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8 }}>
                  <b>{quest.title}</b>
                  <span className={`chip ${quest.complete ? 'ok' : ''}`}>
                    {quest.complete ? 'Complete' : `+${quest.xp} XP`}
                  </span>
                </div>
                <p className="muted">{quest.detail}</p>
                <div className="bar">
                  <i
                    style={{
                      width: `${Math.round(ratio * 100)}%`,
                      background: quest.complete ? 'var(--mint)' : 'var(--gold)',
                    }}
                  />
                </div>
              </article>
            )
          })}
        </div>
      </section>

      <div className="grid">
        <section className="card">
          <header>
            <div>
              <h2>Streak and history</h2>
              <p>
                {liveStreak} day logging streak. Stretch hits from earlier months feed
                next month’s challenge.
              </p>
            </div>
          </header>
          <div className="timeline">
            {derived.hits.slice(-8).map((hit) => {
              const current = hit.month === derived.today.slice(0, 7)
              const status = hit.hit ? 'Stretch hit' : current ? 'In progress' : 'Missed'
              const tone = hit.hit ? 'up' : current ? '' : 'down'
              return (
              <div className="hit" key={hit.month}>
                <span>
                  <b>{monthLabel(hit.month)}</b>
                  <div className="muted">target {formatMoney(hit.goal.target)}</div>
                </span>
                <span className={tone}>
                  {status} · {formatSigned(hit.net)}
                </span>
              </div>
              )
            })}
          </div>
        </section>
        <section className="card">
          <header>
            <div>
              <h2>Grove badges</h2>
              <p>Unlocks from saving, staying calm on thresholds, and keeping the ledger alive.</p>
            </div>
          </header>
          <div className="achievements">
            {derived.achievements.map((achievement) => (
              <article className={`achievement ${achievement.unlocked ? 'on' : ''}`} key={achievement.id}>
                <b>{achievement.title}</b>
                <p className="muted">{achievement.detail}</p>
                <small>+{achievement.xp} XP</small>
              </article>
            ))}
          </div>
        </section>
      </div>
    </div>
  )
}
