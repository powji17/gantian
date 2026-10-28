import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'account_sync.dart';
import 'firebase_options.dart';

import 'auth.dart';

// Harus fungsi top-level.
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(SyncTaskHandler());
}

class SyncTaskHandler extends TaskHandler {
  AccountSync? _sync;
  bool _busy = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await ensureSignedIn();
    final name = await FlutterForegroundTask.getData<String>(key: 'device_name');
    if (name != null && name.isNotEmpty) {
      _sync = AccountSync(deviceName: name);
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    final sync = _sync;
    if (sync == null || _busy) return;
    _busy = true;

    sync.tick().then((action) {
      FlutterForegroundTask.sendDataToMain({
        'game': sync.detector.state.name,
        'action': action?.name ?? '-',
      });
    }).catchError((Object e) {
      FlutterForegroundTask.sendDataToMain({'error': e.toString()});
    }).whenComplete(() => _busy = false);
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    try {
      await _sync?.releaseIfMine(alasan: 'dimatikan');
    } catch (_) {}
  }
}