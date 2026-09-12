const money = new Intl.NumberFormat('en-IE', {
  style: 'currency',
  currency: 'EUR',
  maximumFractionDigits: 0,
})

const moneyPrecise = new Intl.NumberFormat('en-IE', {
  style: 'currency',
  currency: 'EUR',
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
})

export function formatMoney(value: number, precise = false): string {
  return (precise ? moneyPrecise : money).format(value)
}

export function formatSigned(value: number): string {
  if (value > 0) return `+${formatMoney(value)}`
  if (value < 0) return `−${formatMoney(Math.abs(value))}`
  return formatMoney(0)
}

export function formatPercent(ratio: number): string {
  return `${Math.round(ratio * 100)}%`
}

export function roundMoney(value: number): number {
  return Math.round(value * 100) / 100
}

export function niceAmount(value: number): number {
  if (value <= 0) return 0
  if (value < 50) return Math.round(value)
  return Math.round(value / 10) * 10
}
