import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  Legend,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import { formatMoney } from '../lib/money.ts'
import type { MonthPoint, WeekPoint } from '../types.ts'

type Props = {
  series: MonthPoint[]
  weekly: WeekPoint[]
  mode: 'monthly' | 'weekly'
}

const tooltipStyle = {
  background: '#12291f',
  border: '1px solid rgba(230, 194, 122, 0.28)',
  borderRadius: 12,
  color: '#e7f0ea',
}

export function TrendChart({ series, weekly, mode }: Props) {
  const data = mode === 'monthly' ? series : weekly
  return (
    <div className="chart">
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart data={data} margin={{ top: 8, right: 8, left: 0, bottom: 0 }}>
          <defs>
            <linearGradient id="gainsFill" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#8ee4b5" stopOpacity={0.38} />
              <stop offset="100%" stopColor="#8ee4b5" stopOpacity={0.02} />
            </linearGradient>
            <linearGradient id="expenseFill" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#ff9a7a" stopOpacity={0.32} />
              <stop offset="100%" stopColor="#ff9a7a" stopOpacity={0.02} />
            </linearGradient>
          </defs>
          <CartesianGrid stroke="rgba(255,255,255,0.06)" vertical={false} />
          <XAxis dataKey="label" stroke="#9bb0a4" tick={{ fill: '#9bb0a4', fontSize: 12 }} />
          <YAxis
            stroke="#9bb0a4"
            tick={{ fill: '#9bb0a4', fontSize: 12 }}
            tickFormatter={(value: number) =>
              value >= 1000 ? `${Math.round(value / 100) / 10}k` : String(Math.round(value))
            }
          />
          <Tooltip
            contentStyle={tooltipStyle}
            formatter={(value, name) => [formatMoney(Number(value)), String(name)]}
          />
          <Legend />
          <Area
            type="monotone"
            dataKey="gains"
            name="Gains"
            stroke="#8ee4b5"
            fill="url(#gainsFill)"
            strokeWidth={2.4}
          />
          <Area
            type="monotone"
            dataKey="expenses"
            name="Expenses"
            stroke="#ff9a7a"
            fill="url(#expenseFill)"
            strokeWidth={2.4}
          />
          <Area
            type="monotone"
            dataKey="net"
            name="Net saved"
            stroke="#e6c27a"
            fill="transparent"
            strokeWidth={2}
            strokeDasharray="5 4"
          />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  )
}

export function WeeklyBars({ weekly }: { weekly: WeekPoint[] }) {
  return (
    <div className="chart" style={{ height: 180 }}>
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={weekly}>
          <CartesianGrid stroke="rgba(255,255,255,0.06)" vertical={false} />
          <XAxis dataKey="label" stroke="#9bb0a4" tick={{ fill: '#9bb0a4', fontSize: 12 }} />
          <Tooltip
            contentStyle={tooltipStyle}
            formatter={(value, name) => [formatMoney(Number(value)), String(name)]}
          />
          <Bar dataKey="gains" name="Gains" fill="#8ee4b5" radius={6} />
          <Bar dataKey="expenses" name="Expenses" fill="#ff9a7a" radius={6} />
        </BarChart>
      </ResponsiveContainer>
    </div>
  )
}
