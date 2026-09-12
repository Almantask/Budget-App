const KEY = 'grove-budget-v1'

export function loadJson<T>(fallback: T): T {
  try {
    const raw = localStorage.getItem(KEY)
    if (!raw) return fallback
    return JSON.parse(raw) as T
  } catch {
    return fallback
  }
}

export function saveJson(value: unknown): void {
  localStorage.setItem(KEY, JSON.stringify(value))
}

export function clearJson(): void {
  localStorage.removeItem(KEY)
}
