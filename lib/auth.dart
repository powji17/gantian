import 'package:firebase_auth/firebase_auth.dart';

/// Pastikan HP ini sudah "login anonim". Aman dipanggil berkali-kali.
Future<void> ensureSignedIn() async {
  final auth = FirebaseAuth.instance;
  final user = await auth.authStateChanges().first;
  if (user == null) await auth.signInAnonymously();
}