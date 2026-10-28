import 'package:cloud_firestore/cloud_firestore.dart';

class StatusRepository {
  static final doc =
      FirebaseFirestore.instance.collection('akun').doc('freefire');

  static Future<void> setInUse(String device) => doc.set({
        'status': 'IN_USE',
        'device': device,
        'since': FieldValue.serverTimestamp(),
        'lastHeartbeat': FieldValue.serverTimestamp(),
      });

  static Future<void> setBackground(String device) => doc.set({
        'status': 'BACKGROUND',
        'device': device,
        'lastHeartbeat': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  static Future<void> setFree() => doc.set({
        'status': 'FREE',
        'lastHeartbeat': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
}