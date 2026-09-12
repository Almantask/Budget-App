import { BudgetProvider } from './store/BudgetContext.tsx'
import { Shell } from './components/Shell.tsx'

export default function App() {
  return (
    <BudgetProvider>
      <Shell />
    </BudgetProvider>
  )
}
