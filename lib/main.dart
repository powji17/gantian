import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'account_status.dart';
import 'account_sync.dart';
import 'auth.dart';
import 'detector_test_page.dart';
import 'device_name.dart';
import 'firebase_options.dart';
import 'monitor_switch.dart';
import 'status_repository.dart';
import 'riwayat_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try {
    await ensureSignedIn();
  } catch (_) {
    // Offline saat pertama buka: dicoba lagi di peluncuran berikutnya.
  }
  FlutterForegroundTask.initCommunicationPort();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gantian',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.deepOrange,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const StatusPage(),
    );
  }
}

class StatusPage extends StatefulWidget {
  const StatusPage({super.key});

  @override
  State<StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  Timer? _ticker;
  String? _deviceName;

  @override
  void initState() {
    super.initState();
    // Segarkan tampilan tiap 15 detik agar durasi dan pengecekan "basi" ikut jalan.
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
    _loadDeviceName();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadDeviceName() async {
    final name = await DeviceName.load();
    if (!mounted) return;
    setState(() => _deviceName = name);
    if (name == null || name.isEmpty) await _askDeviceName();
  }

  Future<void> _askDeviceName() async {
    final controller = TextEditingController(text: _deviceName ?? '');
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Nama device ini'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'contoh: HP Budi'),
        ),
        actions: [
          if (_deviceName != null)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.pop(context, text);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (result != null) {
      await DeviceName.save(result);
      if (mounted) setState(() => _deviceName = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _deviceName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gantian'),
        actions: [
          IconButton(
            tooltip: 'Riwayat',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RiwayatPage()),
            ),
          ),
          if (kDebugMode)
          IconButton(
            tooltip: 'Uji deteksi',
            icon: const Icon(Icons.bug_report),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DetectorTestPage()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: StatusRepository.doc.snapshots(
              includeMetadataChanges: true,
            ),
            builder: (context, snap) {
              if (snap.hasError) return _ErrorCard(error: '${snap.error}');
              final doc = snap.data;
              if (doc == null) {
                return const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final status = AccountStatus.fromData(
                doc.data(),
                pendingWrites: doc.metadata.hasPendingWrites,
              );
              return Column(
                children: [
                  _StatusCard(status: status, me: name),
                  if (status.isMine(name)) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () =>
                          AccountSync(deviceName: name!).releaseIfMine(),
                      icon: const Icon(Icons.check),
                      label: const Text('Saya selesai'),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          MonitorSwitch(deviceName: name),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.smartphone),
              title: const Text('Device ini'),
              subtitle: Text(name ?? '(belum diisi)'),
              trailing: const Icon(Icons.edit),
              onTap: _askDeviceName,
            ),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.tonal(
                      onPressed: name == null
                          ? null
                          : () => StatusRepository.setInUse(name),
                      child: const Text('Tes: mulai main'),
                    ),
                    FilledButton.tonal(
                      onPressed: name == null
                          ? null
                          : () => StatusRepository.setBackground(name),
                      child: const Text('Tes: background'),
                    ),
                    FilledButton.tonal(
                      onPressed: StatusRepository.setFree,
                      child: const Text('Tes: selesai'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status, required this.me});

  final AccountStatus status;
  final String? me;

  (Color, Color) _palette(bool dark) => switch (status.state) {
    AccountState.free =>
      dark
          ? (const Color(0xFF12391C), const Color(0xFFB7F0C2))
          : (const Color(0xFFD6F5DC), const Color(0xFF0B5A1D)),
    AccountState.inUse =>
      dark
          ? (const Color(0xFF5C1A16), const Color(0xFFFFDAD6))
          : (const Color(0xFFFFDAD6), const Color(0xFF8C1D18)),
    AccountState.background =>
      dark
          ? (const Color(0xFF4A3A00), const Color(0xFFFFE08A))
          : (const Color(0xFFFFE9B3), const Color(0xFF5C4200)),
  };

  String _durasi(Duration d) {
    if (d.inMinutes < 1) return 'baru saja';
    if (d.inMinutes < 60) return '${d.inMinutes} menit';
    final jam = d.inHours;
    final menit = d.inMinutes % 60;
    return menit == 0 ? '$jam jam' : '$jam jam $menit menit';
  }

  String _detail(BuildContext context) {
    switch (status.state) {
      case AccountState.free:
        return 'Aman untuk login';
      case AccountState.background:
        return 'Mungkin masih terhubung ke game';
      case AccountState.inUse:
        final since = status.since;
        if (since == null) return 'Sedang bermain';
        final jam = TimeOfDay.fromDateTime(since).format(context);
        return 'sejak $jam · ${_durasi(DateTime.now().difference(since))}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (bg, fg) = _palette(dark);
    final text = Theme.of(context).textTheme;
    final mine = status.isMine(me);

    final (icon, title) = switch (status.state) {
      AccountState.free => (Icons.check_circle_rounded, 'Akun bebas'),
      AccountState.inUse => (Icons.sports_esports_rounded, 'Sedang dipakai'),
      AccountState.background => (
        Icons.hourglass_bottom_rounded,
        'Di latar belakang',
      ),
    };

    return Card(
      elevation: 0,
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
          child: Column(
            children: [
              Icon(icon, size: 72, color: fg),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: text.headlineMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (status.state != AccountState.free) ...[
                const SizedBox(height: 8),
                Text(
                  mine ? '${status.device} (kamu)' : (status.device ?? '?'),
                  textAlign: TextAlign.center,
                  style: text.titleLarge?.copyWith(color: fg),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                _detail(context),
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_off, color: scheme.onErrorContainer),
                const SizedBox(width: 8),
                Text(
                  'Tidak bisa terhubung ke server',
                  style: TextStyle(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(color: scheme.onErrorContainer, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
