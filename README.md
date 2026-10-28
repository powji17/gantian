# Gantian

Aplikasi Android untuk menandai siapa yang sedang memakai satu akun Free Fire
bersama, supaya teman yang login belakangan tidak lagi "nabrak" sesi yang sedang berjalan.

> Proyek ini tidak berafiliasi dengan Garena. Aplikasi tidak menyentuh server
> maupun data game, hanya mendeteksi apakah aplikasi Free Fire sedang terbuka di
> HP sendiri.

## Masalahnya

Satu akun dipakai bergantian oleh beberapa teman. Login dari perangkat lain
menendang sesi yang sedang aktif, dan pemain yang sedang bermain tidak tahu
kalau ada yang akan masuk.

## Cara kerja

```
Free Fire dibuka di HP Budi
   -> foreground service mendeteksinya (UsageStatsManager)
   -> HP Budi menulis status ke Firestore
   -> HP lain langsung menampilkan "HP Budi sedang menggunakan akun ini"
```

Tidak ada API resmi untuk mengecek status online akun, jadi aplikasi memakai
papan status bersama: setiap HP melaporkan miliknya sendiri.

## Fitur

- Status realtime: bebas, sedang dipakai, atau di latar belakang
- Pemantau otomatis berbasis foreground service, menyala sendiri setelah izin
  diberikan, setelah restart, dan setelah update
- Aturan anti-tabrakan: HP hanya mengubah atau melepas status miliknya sendiri
  dan tidak menimpa pemakai lain yang masih aktif
- Tombol "Saya selesai" untuk melepas akun tanpa menunggu jeda
- Riwayat pemakaian per sesi, dengan ringkasan 7 hari per orang
- Mode terang dan gelap

## Batasan yang diketahui

- Android tidak melaporkan event saat aplikasi ditutup paksa dari recent apps,
  jadi "ditutup" tidak bisa dibedakan dari "di latar belakang". Solusinya jeda
  1 menit (`backgroundGrace` di `lib/decision.dart`) sebelum akun dianggap bebas.
- Hanya mendeteksi "Free Fire terbuka", bukan akun mana yang sedang login.
- Hanya Android. Sebagian merek HP (Xiaomi, Oppo, Vivo, Realme) memerlukan
  pengaturan Autostart dan baterai agar service tidak dimatikan.
- Login anonim Firebase hanya mencegah akses acak, bukan autentikasi pengguna.
  Siapa pun yang memegang APK bisa ikut memakai backend yang sama.

## Teknologi

Flutter, Dart, Cloud Firestore, Firebase Authentication (anonim),
`usage_stats`, `flutter_foreground_task`.

## Menjalankan project

Butuh HP Android asli (deteksi game tidak bisa diuji di emulator).

1. Pasang Flutter SDK.
2. Buat project di Firebase Console, aktifkan **Firestore** dan
   **Authentication, metode Anonymous**.
3. Hubungkan ke project ini (pilih platform Android saja):
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   Perintah ini membuat `lib/firebase_options.dart` dan
   `android/app/google-services.json`, yang sengaja tidak disertakan di repo.
4. Salin isi `firestore.rules` ke tab Rules di Firestore lalu publikasikan.
5. Jalankan:
   ```bash
   flutter pub get
   flutter run
   ```
6. Di aplikasi: isi nama device, lalu aktifkan izin **Usage Access** untuk Gantian.

## Struktur

```
lib/
  main.dart               tampilan utama
  decision.dart           logika keputusan klaim/lepas akun (murni, mudah dites)
  free_fire_detector.dart deteksi Free Fire lewat usage_stats
  account_sync.dart       sinkronisasi ke Firestore (transaksi + sesi)
  sync_service.dart       foreground service
  monitor_switch.dart     saklar dan auto-start pemantau
  riwayat_page.dart       halaman riwayat pemakaian
test/                     tes unit logika keputusan, status, dan riwayat
firestore.rules           aturan keamanan Firestore
```

## Tes

```bash
flutter test
```