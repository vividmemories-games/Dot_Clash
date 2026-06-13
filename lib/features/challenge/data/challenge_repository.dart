import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../services/backend/callable_backend.dart';
import '../domain/challenge_exceptions.dart';
import '../domain/challenge_room.dart';

class ChallengeRepository {
  ChallengeRepository({
    FirebaseFirestore? firestore,
    CallableBackend? backend,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _backend = backend ?? CallableBackend.instance;

  final FirebaseFirestore _firestore;
  final CallableBackend _backend;

  DocumentReference<Map<String, dynamic>> _doc(String code) =>
      _firestore.collection('challenges').doc(_normalizeCode(code));

  static String _normalizeCode(String code) => code.trim().toUpperCase();

  Stream<ChallengeRoom?> watchRoom(String code) {
    final normalized = _normalizeCode(code);
    return _doc(normalized).snapshots().map((snap) {
      if (!snap.exists) return null;
      return ChallengeRoom.fromFirestore(normalized, snap);
    });
  }

  Future<String> createChallenge({String? targetUid}) async {
    final data = <String, dynamic>{};
    if (targetUid != null && targetUid.isNotEmpty) {
      data['targetUid'] = targetUid;
    }
    try {
      final result = await _backend.call('createChallenge', data);
      final code = result['code'] as String?;
      if (code == null || code.isEmpty) {
        throw const ChallengeException('Could not create challenge.');
      }
      return _normalizeCode(code);
    } on FirebaseFunctionsException catch (e) {
      throw ChallengeException.fromFirebase(e);
    }
  }

  Future<String> joinChallenge(String code) async {
    final normalized = _normalizeCode(code);
    try {
      final result = await _backend.call('joinChallenge', {'code': normalized});
      final joined = result['code'] as String? ?? normalized;
      return _normalizeCode(joined);
    } on FirebaseFunctionsException catch (e) {
      throw ChallengeException.fromFirebase(e);
    }
  }

  Future<void> abandonChallenge(String code) async {
    try {
      await _backend.call('abandonChallenge', {'code': _normalizeCode(code)});
    } on FirebaseFunctionsException catch (e) {
      throw ChallengeException.fromFirebase(e);
    }
  }

  Future<void> submitChallengeMove({
    required String code,
    required String edgeKey,
  }) async {
    try {
      await _backend.call('submitChallengeMove', {
        'code': _normalizeCode(code),
        'edgeKey': edgeKey,
      });
    } on FirebaseFunctionsException catch (e) {
      throw ChallengeException.fromFirebase(e);
    }
  }
}
