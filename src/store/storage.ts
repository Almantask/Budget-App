const KEY = 'grove-budget-v1'
const NOTICE_KEY = 'grove-notices-v1'

function read<T>(key: string, fallback: T): T {
  try {
    const raw = localStorage.getItem(key)
    if (!raw) return fallback
    return JSON.parse(raw) as T
  } catch {
    return fallback
  }
}

export function loadJson<T>(fallback: T): T {
  return read(KEY, fallback)
}

export function saveJson(value: unknown): void {
  localStorage.setItem(KEY, JSON.stringify(value))
}

export function clearJson(): void {
  localStorage.removeItem(KEY)
}

export function loadNoticeJson<T>(fallback: T): T {
  return read(NOTICE_KEY, fallback)
}

export function saveNoticeJson(value: unknown): void {
  localStorage.setItem(NOTICE_KEY, JSON.stringify(value))
}

export function clearNoticeJson(): void {
  localStorage.removeItem(NOTICE_KEY)
}
