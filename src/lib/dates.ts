const MONTHS = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
] as const

export function toDate(iso: string): Date {
  const [year, month, day] = iso.split('-').map(Number)
  return new Date(year, month - 1, day)
}

export function toIso(date: Date): string {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

export function monthKey(value: string | Date): string {
  const date = typeof value === 'string' ? toDate(value) : value
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`
}

export function monthLabel(month: string): string {
  const [year, monthPart] = month.split('-')
  const index = Number(monthPart) - 1
  return `${MONTHS[index]} ${year}`
}

export function addMonths(month: string, delta: number): string {
  const [year, monthPart] = month.split('-').map(Number)
  const date = new Date(year, monthPart - 1 + delta, 1)
  return monthKey(date)
}

export function monthsUntil(endMonth: string, count: number): string[] {
  const keys: string[] = []
  for (let i = count - 1; i >= 0; i -= 1) {
    keys.push(addMonths(endMonth, -i))
  }
  return keys
}

export function daysInMonth(month: string): number {
  const [year, monthPart] = month.split('-').map(Number)
  return new Date(year, monthPart, 0).getDate()
}

export function startOfMonth(month: string): string {
  return `${month}-01`
}

export function endOfMonth(month: string): string {
  return `${month}-${String(daysInMonth(month)).padStart(2, '0')}`
}

export function clampDateToMonth(iso: string, month: string, today: string): string {
  const start = startOfMonth(month)
  const end = iso < today ? iso : today
  const monthEnd = endOfMonth(month)
  const last = end < monthEnd ? end : monthEnd
  if (iso < start) return start
  if (iso > last) return last
  return iso
}

export function compareIso(a: string, b: string): number {
  return a.localeCompare(b)
}

export function uniqueSortedDates(dates: string[]): string[] {
  return [...new Set(dates)].sort(compareIso)
}
