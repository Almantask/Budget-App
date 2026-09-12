import { Bell, BellRing, X } from 'lucide-react'
import { useEffect, useState } from 'react'
import { monthLabel } from '../lib/dates.ts'
import type { ThresholdNotice } from '../lib/notifications.ts'
import { useBudget } from '../store/BudgetContext.tsx'

function NoticeBody({ notice, onOpen }: { notice: ThresholdNotice; onOpen: () => void }) {
  return (
    <button className="notice-item" onClick={onOpen} type="button">
      <span className={`chip ${notice.level}`}>{notice.level}</span>
      <span>
        <b>{notice.label}</b>
        <small>
          {monthLabel(notice.month)} · {notice.message}
        </small>
      </span>
    </button>
  )
}

export function NotificationCenter() {
  const {
    notices,
    toasts,
    unreadCount,
    desktopPermission,
    dismissToast,
    markAllRead,
    openNotice,
    enableDesktopNotifications,
    setTab,
  } = useBudget()
  const [open, setOpen] = useState(false)
  const toastId = toasts[0]?.id

  useEffect(() => {
    if (!toastId) return
    const timer = window.setTimeout(() => {
      dismissToast(toastId)
    }, 7000)
    return () => window.clearTimeout(timer)
  }, [toastId, dismissToast])

  return (
    <>
      <div className="notify-wrap">
        <button
          className="icon-btn"
          aria-label="Budget notifications"
          onClick={() => setOpen((value) => !value)}
        >
          {unreadCount > 0 ? <BellRing size={16} /> : <Bell size={16} />}
          {unreadCount > 0 && <em className="badge">{unreadCount > 9 ? '9+' : unreadCount}</em>}
        </button>
        {open && (
          <div className="notify-panel">
            <header>
              <div>
                <h3>Threshold notices</h3>
                <p className="muted">Fired after Grove syncs your ledger, if a budget is over its warning line.</p>
              </div>
              <button className="ghost" type="button" onClick={markAllRead}>
                Mark read
              </button>
            </header>
            {desktopPermission !== 'granted' && desktopPermission !== 'unsupported' && (
              <button
                className="ghost"
                type="button"
                onClick={() => {
                  void enableDesktopNotifications()
                }}
              >
                Enable desktop notifications
              </button>
            )}
            {notices.length === 0 ? (
              <p className="empty">No threshold crossings yet. Stay under the gold ticks.</p>
            ) : (
              <div className="notice-list">
                {notices.slice(0, 12).map((notice) => (
                  <NoticeBody
                    key={notice.id}
                    notice={notice}
                    onOpen={() => {
                      openNotice(notice)
                      setOpen(false)
                    }}
                  />
                ))}
              </div>
            )}
            <button
              className="ghost"
              type="button"
              onClick={() => {
                setTab('budgets')
                setOpen(false)
              }}
            >
              Open budgets
            </button>
          </div>
        )}
      </div>
      <div className="toasts" aria-live="polite">
        {toasts.map((toast) => (
          <article className={`toast ${toast.level}`} key={toast.id}>
            <div>
              <b>{toast.level === 'breach' ? 'Over budget after sync' : 'Warning line crossed after sync'}</b>
              <p>{toast.message}</p>
            </div>
            <button className="icon-btn" aria-label="Dismiss notification" onClick={() => dismissToast(toast.id)}>
              <X size={14} />
            </button>
          </article>
        ))}
      </div>
    </>
  )
}
