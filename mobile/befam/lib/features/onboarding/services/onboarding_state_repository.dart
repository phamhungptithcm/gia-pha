import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/app_environment.dart';
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

  static const String _prefsKeyPrefix = 'befam.onboarding.state';

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

    final localState = await _loadLocalState(uid);
    if (AppEnvironment.useLocalFirebaseFallbacks) {
      return _cacheAndPersistLocalState(uid, localState);
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
        return _cacheAndPersistLocalState(
          uid,
          localState.flows.isNotEmpty
              ? localState
              : const OnboardingUserState(),
        );
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

      final remoteState = OnboardingUserState(flows: flows);
      final resolvedState =
          remoteState.flows.isEmpty && localState.flows.isNotEmpty
          ? localState
          : remoteState;
      return _cacheAndPersistLocalState(uid, resolvedState);
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Failed to load onboarding state. Falling back to local state.',
        error,
        stackTrace,
      );
      return _cacheAndPersistLocalState(uid, localState);
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
    await _saveLocalState(uid, _cachedState!);
    if (AppEnvironment.useLocalFirebaseFallbacks) {
      return;
    }

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

  Future<OnboardingUserState> _cacheAndPersistLocalState(
    String uid,
    OnboardingUserState state,
  ) async {
    _cachedUid = uid;
    _cachedState = state;
    await _saveLocalState(uid, state);
    return state;
  }

  Future<OnboardingUserState> _loadLocalState(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString(_prefsKey(uid));
      if (encoded == null || encoded.trim().isEmpty) {
        return const OnboardingUserState();
      }
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) {
        return const OnboardingUserState();
      }
      final rawFlows = decoded['flows'];
      if (rawFlows is! Map<String, dynamic>) {
        return const OnboardingUserState();
      }
      final flows = <String, OnboardingFlowProgress>{};
      for (final entry in rawFlows.entries) {
        final rawProgress = entry.value;
        if (rawProgress is! Map) {
          continue;
        }
        flows[entry.key] = OnboardingFlowProgress.fromJson(
          entry.key,
          rawProgress.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
      return OnboardingUserState(flows: flows);
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Failed to load local onboarding state. Falling back to empty state.',
        error,
        stackTrace,
      );
      return const OnboardingUserState();
    }
  }

  Future<void> _saveLocalState(String uid, OnboardingUserState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(<String, Object?>{
        'flows': state.flows.map(
          (flowId, progress) =>
              MapEntry(flowId, _normalizeJsonValue(progress.toJson())),
        ),
      });
      await prefs.setString(_prefsKey(uid), encoded);
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Failed to persist onboarding progress locally.',
        error,
        stackTrace,
      );
    }
  }

  String _prefsKey(String uid) => '$_prefsKeyPrefix.$uid';

  Object? _normalizeJsonValue(Object? value) {
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is Map<Object?, Object?>) {
      return value.map(
        (key, entryValue) =>
            MapEntry(key.toString(), _normalizeJsonValue(entryValue)),
      );
    }
    if (value is Iterable<Object?>) {
      return value.map(_normalizeJsonValue).toList(growable: false);
    }
    return value;
  }
}

OnboardingStateRepository createDefaultOnboardingStateRepository() {
  return FirestoreOnboardingStateRepository();
}
