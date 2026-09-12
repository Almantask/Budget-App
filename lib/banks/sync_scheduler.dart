import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../data/budget_store.dart';

const dailySyncUniqueName = 'budget-daily-sync';

@pragma('vm:entry-point')
void budgetSyncDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // The foreground app also syncs on resume. This callback keeps Android/iOS
    // alive so OS can wake the process once per day; the controller persists
    // results when the app next opens if work runs headless.
    return true;
  });
}

class SyncScheduler {
  const SyncScheduler();

  Future<void> registerDailySync() async {
    if (kIsWeb) return;
    try {
      await Workmanager().initialize(budgetSyncDispatcher);
      await Workmanager().registerPeriodicTask(
        dailySyncUniqueName,
        BudgetStore.dailySyncTask,
        frequency: const Duration(hours: 24),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } catch (_) {
      // Tests and unsupported hosts skip OS scheduling; app-open sync still runs.
    }
  }

  Future<void> cancel() async {
    if (kIsWeb) return;
    try {
      await Workmanager().cancelByUniqueName(dailySyncUniqueName);
    } catch (_) {}
  }
}
