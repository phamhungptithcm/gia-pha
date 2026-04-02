import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/app_logger.dart';
import '../../../core/services/firebase_services.dart';
import '../../../core/services/firebase_session_access_sync.dart';
import '../../auth/models/auth_session.dart';
import '../models/onboarding_models.dart';

abstract class OnboardingStateRepository {
  Future<OnboardingUserState> load({required AuthSession session});

  Future<void> saveProgress({
    required AuthSession session,
    required OnboardingFlowProgress progress,
  });
}

class InMemoryOnboardingStateRepository implements OnboardingStateRepository {
  InMemoryOnboardingStateRepository({
    Map<String, OnboardingUserState>? initialStateByUid,
  }) : _stateByUid = initialStateByUid ?? <String, OnboardingUserState>{};

  final Map<String, OnboardingUserState> _stateByUid;

  @override
  Future<OnboardingUserState> load({required AuthSession session}) async {
    final uid = session.uid.trim();
    if (uid.isEmpty) {
      return const OnboardingUserState();
    }
    return _stateByUid[uid] ?? const OnboardingUserState();
  }

  @override
  Future<void> saveProgress({
    required AuthSession session,
    required OnboardingFlowProgress progress,
  }) async {
    final uid = session.uid.trim();
    if (uid.isEmpty) {
      return;
    }
    final currentState = _stateByUid[uid] ?? const OnboardingUserState();
    _stateByUid[uid] = currentState.copyWithFlow(progress);
  }
}

class FirestoreOnboardingStateRepository implements OnboardingStateRepository {
  FirestoreOnboardingStateRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseServices.firestore;

  final FirebaseFirestore _firestore;
  String? _cachedUid;
  OnboardingUserState? _cachedState;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  @override
  Future<OnboardingUserState> load({required AuthSession session}) async {
    final uid = session.uid.trim();
    if (uid.isEmpty) {
      return const OnboardingUserState();
    }
    if (_cachedUid == uid && _cachedState != null) {
      return _cachedState!;
    }

    try {
      await FirebaseSessionAccessSync.ensureUserSessionDocument(
        firestore: _firestore,
        session: session,
      );
      final snapshot = await _users
          .doc(uid)
          .collection('preferences')
          .doc('onboarding')
          .get();
      final data = snapshot.data();
      final rawFlows = data?['flows'];
      if (rawFlows is! Map<Object?, Object?>) {
        const empty = OnboardingUserState();
        _cachedUid = uid;
        _cachedState = empty;
        return empty;
      }

      final flows = <String, OnboardingFlowProgress>{};
      for (final entry in rawFlows.entries) {
        final flowId = entry.key?.toString().trim() ?? '';
        final value = entry.value;
        if (flowId.isEmpty || value is! Map<Object?, Object?>) {
          continue;
        }
        flows[flowId] = OnboardingFlowProgress.fromJson(
          flowId,
          value.map((key, entryValue) => MapEntry(key.toString(), entryValue)),
        );
      }

      final state = OnboardingUserState(flows: flows);
      _cachedUid = uid;
      _cachedState = state;
      return state;
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Failed to load onboarding state. Falling back to empty state.',
        error,
        stackTrace,
      );
      return const OnboardingUserState();
    }
  }

  @override
  Future<void> saveProgress({
    required AuthSession session,
    required OnboardingFlowProgress progress,
  }) async {
    final uid = session.uid.trim();
    if (uid.isEmpty) {
      return;
    }

    final nextState =
        (_cachedUid == uid ? _cachedState : null) ??
        await load(session: session);
    _cachedUid = uid;
    _cachedState = nextState.copyWithFlow(progress);

    try {
      await FirebaseSessionAccessSync.ensureUserSessionDocument(
        firestore: _firestore,
        session: session,
      );
      await _users.doc(uid).collection('preferences').doc('onboarding').set({
        'id': 'onboarding',
        'uid': uid,
        'flows': <String, Object?>{progress.flowId: progress.toJson()},
        'updatedBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Failed to persist onboarding progress.',
        error,
        stackTrace,
      );
    }
  }
}

OnboardingStateRepository createDefaultOnboardingStateRepository() {
  return FirestoreOnboardingStateRepository();
}
