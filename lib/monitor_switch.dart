import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'free_fire_detector.dart';
import 'sync_service.dart';

class MonitorSwitch extends StatefulWidget {
  const MonitorSwitch({super.key, required this.deviceName});

  final String? deviceName;

  @override
  State<MonitorSwitch> createState() => _MonitorSwitchState();
}

class _MonitorSwitchState extends State<MonitorSwitch>
    with WidgetsBindingObserver {
  static const _kEnabled = 'monitor_enabled'; // pilihan pengguna, default: nyala
  static const _kBatteryAsked = 'battery_asked';
  static const _kUsageExplained = 'usage_explained';

  bool _running = false;
  bool _needUsage = false;
  bool _busy = false;
  String _info = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FlutterForegroundTask.addTaskDataCallback(_onData);
    _autoStart();
  }

  @override
  void didUpdateWidget(MonitorSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deviceName != widget.deviceName) {
      // Nama berubah: hentikan service lama (ia melepas akun atas nama lama),
      // lalu nyalakan lagi dengan nama baru.
      _restartWithNewName();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FlutterForegroundTask.removeTaskDataCallback(_onData);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kembali dari layar pengaturan (atau aplikasi dibuka lagi) → coba nyalakan.
    if (state == AppLifecycleState.resumed) _autoStart();
  }

  void _onData(Object data) {
    if (data is! Map || !mounted) return;
    final game = switch (data['game']) {
      'foreground' => 'Free Fire terbuka',
      'background' => 'Free Fire di latar belakang',
      _ => 'Free Fire tidak terbuka',
    };
    setState(() {
      _info = data['error'] != null
          ? 'Gangguan: ${data['error']}'
          : kDebugMode
              ? '$game · aksi: ${data['action']}'
              : game;
    });
  }

  Future<void> _refresh() async {
    final running = await FlutterForegroundTask.isRunningService;
    if (mounted) setState(() => _running = running);
  }

  Future<void> _restartWithNewName() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
    await _autoStart();
  }

  /// Menyalakan pemantau otomatis kalau semua syarat terpenuhi.
  Future<void> _autoStart() async {
    if (_busy) return;
    _busy = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_kEnabled) ?? true)) return; // sengaja dimatikan

      if (await FlutterForegroundTask.isRunningService) {
        await _refresh();
        return;
      }

      final name = widget.deviceName;
      if (name == null || name.isEmpty) return; // menunggu nama diisi

      if (!await FreeFireDetector().hasPermission()) {
        if (mounted) setState(() => _needUsage = true);
        if (!(prefs.getBool(_kUsageExplained) ?? false)) {
          await prefs.setBool(_kUsageExplained, true);
          await _explainUsageAccess();
        }
        return;
      }

      if (mounted) setState(() => _needUsage = false);
      await _startService(name, prefs);
    } finally {
      _busy = false;
    }
  }

  Future<void> _explainUsageAccess() async {
    if (!mounted) return;
    final lanjut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Satu izin lagi'),
        content: const Text(
          'Gantian perlu izin "Usage Access" untuk mengetahui apakah Free Fire '
          'sedang dibuka. Hanya itu yang dicek, data aplikasi lain tidak dibaca.\n\n'
          'Di layar berikutnya, pilih Gantian lalu aktifkan izinnya.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Nanti'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Buka pengaturan'),
          ),
        ],
      ),
    );
    if (lanjut == true) await FreeFireDetector().openSettings();
  }

  Future<void> _startService(String name, SharedPreferences prefs) async {
    // Izin pengecualian baterai: ditanyakan sekali saja.
    if (!(prefs.getBool(_kBatteryAsked) ?? false)) {
      await prefs.setBool(_kBatteryAsked, true);
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    }

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'gantian_monitor_v2',
        channelName: 'Pemantau akun',
        channelDescription: 'Diperlukan Android agar pemantau tetap berjalan.',
        channelImportance: NotificationChannelImportance.MIN,
        priority: NotificationPriority.MIN,
        onlyAlertOnce: true,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    await FlutterForegroundTask.saveData(key: 'device_name', value: name);

    Future<ServiceRequestResult> mulai() => FlutterForegroundTask.startService(
          serviceId: 256,
          notificationTitle: 'Gantian',
          notificationText: 'Pemantau berjalan',
          callback: startCallback,
        );

    final hasil = await mulai();
    if (hasil is! ServiceRequestSuccess) {
      // Cadangan: sebagian HP Android 13+ menolak mulai tanpa izin notifikasi.
      await FlutterForegroundTask.requestNotificationPermission();
      await mulai();
    }
    await _refresh();
  }

  Future<void> _toggle(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, on);

    if (!on) {
      await FlutterForegroundTask.stopService();
      await _refresh();
      return;
    }

    final name = widget.deviceName;
    if (name == null || name.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Isi nama device dulu.')),
        );
      }
      return;
    }
    if (!await FreeFireDetector().hasPermission()) {
      if (mounted) setState(() => _needUsage = true);
      await _explainUsageAccess();
      return;
    }
    await _autoStart();
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _needUsage
        ? 'Butuh izin Usage Access. Nyalakan saklar untuk mengaktifkannya.'
        : _running
            ? (_info.isEmpty ? 'Aktif, menunggu data…' : _info)
            : 'Mati. Nyalakan agar status terdeteksi otomatis.';

    return Card(
      child: SwitchListTile(
        secondary: Icon(_running ? Icons.visibility : Icons.visibility_off),
        title: const Text('Pemantau otomatis'),
        subtitle: Text(subtitle),
        value: _running,
        onChanged: _toggle,
      ),
    );
  }
}