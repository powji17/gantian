import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gantian/account_status.dart';

void main() {
  final now = DateTime(2026, 10, 27, 20, 0, 0);

  Map<String, dynamic> data(String status, {String device = 'HP A', int ago = 10}) => {
        'status': status,
        'device': device,
        'lastHeartbeat': Timestamp.fromDate(now.subtract(Duration(seconds: ago))),
      };

  AccountStatus parse(Map<String, dynamic>? d, {bool pending = false}) =>
      AccountStatus.fromData(d, now: now, pendingWrites: pending);

  test('dokumen belum ada → bebas', () {
    expect(parse(null).state, AccountState.free);
  });

  test('IN_USE dengan detak segar → sedang dipakai', () {
    expect(parse(data('IN_USE')).state, AccountState.inUse);
  });

  test('IN_USE tapi detak basi (5 menit) → bebas', () {
    expect(parse(data('IN_USE', ago: 300)).state, AccountState.free);
  });

  test('BACKGROUND dengan detak segar → di latar belakang', () {
    expect(parse(data('BACKGROUND')).state, AccountState.background);
  });

  test('FREE → bebas', () {
    expect(parse(data('FREE')).state, AccountState.free);
  });

  test('tulisan lokal belum dikonfirmasi (timestamp null) tidak dianggap basi', () {
    final d = {'status': 'IN_USE', 'device': 'HP A', 'lastHeartbeat': null};
    expect(parse(d, pending: true).state, AccountState.inUse);
    expect(parse(d, pending: false).state, AccountState.free);
  });

  test('isMine hanya benar untuk pemilik yang aktif', () {
    expect(parse(data('IN_USE')).isMine('HP A'), isTrue);
    expect(parse(data('IN_USE')).isMine('HP B'), isFalse);
    expect(parse(data('FREE')).isMine('HP A'), isFalse);
    expect(parse(data('IN_USE')).isMine(null), isFalse);
  });
}