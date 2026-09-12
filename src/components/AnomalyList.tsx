import { Radar } from 'lucide-react'
import { formatMoney } from '../lib/money.ts'
import type { SpendingAnomaly } from '../types.ts'

export function AnomalyList({
  anomalies,
  onOpenLedger,
}: {
  anomalies: SpendingAnomaly[]
  onOpenLedger?: () => void
}) {
  return (
    <section className="card anomalies-card">
      <header>
        <div>
          <h2>Spending anomalies</h2>
          <p>
            Grove compares this month with your recent history and flags category spikes or
            unusually large charges. Steady bills like rent are left alone.
          </p>
        </div>
        <span className={`chip ${anomalies.length ? 'unusual' : 'ok'}`}>
          {anomalies.length === 0 ? 'Clear' : `${anomalies.length} flagged`}
        </span>
      </header>
      {anomalies.length === 0 ? (
        <p className="empty" style={{ padding: '12px 0' }}>
          No unusual spending versus the last several months.
        </p>
      ) : (
        <div className="rows">
          {anomalies.map((anomaly) => (
            <article className={`anomaly ${anomaly.severity}`} key={anomaly.id}>
              <Radar size={16} />
              <div>
                <div className="meta">
                  <b>{anomaly.label}</b>
                  <span className={`chip ${anomaly.severity}`}>
                    {anomaly.severity === 'unusual' ? 'Unusual' : 'Watch'}
                  </span>
                </div>
                <p className="muted">{anomaly.message}</p>
              </div>
              <strong>{formatMoney(anomaly.amount)}</strong>
            </article>
          ))}
        </div>
      )}
      {anomalies.some((item) => item.transactionId) && onOpenLedger && (
        <button className="ghost" style={{ marginTop: 12 }} onClick={onOpenLedger}>
          Review flagged lines in the ledger
        </button>
      )}
    </section>
  )
}
