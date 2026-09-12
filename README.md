# Budget-App

Grove is a personal budget tracker that makes saving feel like a game you can actually win.

It keeps a local ledger of expenses and gains, graphs them over time, warns you before a budget slips, and sets a fresh stretch savings goal every month.

## Features

- **Over-time graph** — monthly (and weekly) view of expenses, gains, and net savings.
- **Budget thresholds** — per-category and overall monthly limits with a warning line you choose. Grove also flags *pace* risk when the current daily spend would miss the limit.
- **Spending anomalies** — Grove compares this month with recent history and flags category spikes or unusually large charges. Stable bills like rent are ignored.
- **Monthly stretch goals** — each month looks at your recent savings and asks for a little more (usually 8–12%). A hard month resets to a gentler target instead of stacking punishment. Quests, XP, levels, streaks, and badges keep the habit going.

Data stays in your browser (`localStorage`). There is no server.

## Run locally

```bash
npm install
npm run dev
```

Then open the URL Vite prints (default `http://localhost:5173`).

```bash
npm test      # unit tests for charts, thresholds, and stretch goals
npm run build # production build
```

On first launch the app loads sample months so the graph, warnings, and quest board have history. Use **Start fresh** to begin with an empty ledger, or **Reload sample months** to restore the demo.

## How stretch goals are set

1. Look at net savings (gains minus expenses) for the last three complete months.
2. Stretch about 10% above the stronger of last month and that average, capped so the jump is never more than 20%.
3. If recent months were negative, the quest becomes a small reset target (€80) rather than an even deeper hole.
