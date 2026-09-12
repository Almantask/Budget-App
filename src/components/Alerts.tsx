import { AlertTriangle, Gauge, ShieldAlert } from 'lucide-react'
import type { ThresholdAlert } from '../types.ts'

const icons = {
  warning: AlertTriangle,
  breach: ShieldAlert,
  pace: Gauge,
}

export function Alerts({ alerts }: { alerts: ThresholdAlert[] }) {
  if (alerts.length === 0) return null
  return (
    <div className="alerts">
      {alerts.map((alert) => {
        const Icon = icons[alert.level]
        return (
          <div className={`alert ${alert.level}`} key={alert.budgetId}>
            <span className={`dot ${alert.level}`} />
            <div>
              <strong>
                <Icon size={14} style={{ marginRight: 6, verticalAlign: '-2px' }} />
                {alert.label}
              </strong>
              <p className="muted">{alert.message}</p>
            </div>
          </div>
        )
      })}
    </div>
  )
}
