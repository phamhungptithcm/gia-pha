import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/app_logger.dart';

class OnboardingRemoteSettings {
  const OnboardingRemoteSettings({
    required this.enabled,
    required this.firestoreCatalogEnabled,
    required this.catalogCollection,
    required this.rolloutPercent,
    required this.shellNavigationEnabled,
    required this.memberWorkspaceEnabled,
    required this.genealogyWorkspaceEnabled,
    required this.genealogyDiscoveryEnabled,
    required this.clanDetailEnabled,
  });

  final bool enabled;
  final bool firestoreCatalogEnabled;
  final String catalogCollection;
  final int rolloutPercent;
  final bool shellNavigationEnabled;
  final bool memberWorkspaceEnabled;
  final bool genealogyWorkspaceEnabled;
  final bool genealogyDiscoveryEnabled;
  final bool clanDetailEnabled;

  bool isTriggerEnabled(String triggerId) {
    return switch (triggerId) {
      'app_shell_home' => shellNavigationEnabled,
      'member_workspace_opened' => memberWorkspaceEnabled,
      'genealogy_workspace_opened' => genealogyWorkspaceEnabled,
      'genealogy_discovery_opened' => genealogyDiscoveryEnabled,
      'clan_detail_opened' => clanDetailEnabled,
      _ => true,
    };
  }

  bool includesUser(String uid) {
    if (!enabled) {
      return false;
    }
    final normalized = uid.trim();
    if (normalized.isEmpty) {
      return false;
    }
    final bucket = _stableHash(normalized) % 100;
    return bucket < rolloutPercent.clamp(0, 100).toInt();
  }

  static int _stableHash(String value) {
    var hash = 2166136261;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return hash;
  }
}

abstract class OnboardingRemoteConfigService {
  Future<OnboardingRemoteSettings> load();
}

class FirebaseOnboardingRemoteConfigService
    implements OnboardingRemoteConfigService {
  FirebaseOnboardingRemoteConfigService({FirebaseRemoteConfig? remoteConfig})
    : _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance;

  final FirebaseRemoteConfig _remoteConfig;
  OnboardingRemoteSettings? _cache;
  DateTime? _cacheLoadedAt;

  @override
  Future<OnboardingRemoteSettings> load() async {
    final now = DateTime.now();
    if (_cache != null &&
        _cacheLoadedAt != null &&
        now.difference(_cacheLoadedAt!) < const Duration(minutes: 5)) {
      return _cache!;
    }

    try {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 5),
          minimumFetchInterval: kReleaseMode
              ? const Duration(hours: 6)
              : const Duration(minutes: 5),
        ),
      );
      await _remoteConfig.setDefaults(<String, Object>{
        'onboarding_enabled': true,
        'onboarding_firestore_catalog_enabled': true,
        'onboarding_catalog_collection': 'onboardingFlows',
        'onboarding_rollout_percent': 100,
        'onboarding_shell_navigation_enabled': true,
        'onboarding_member_workspace_enabled': true,
        'onboarding_genealogy_workspace_enabled': true,
        'onboarding_genealogy_discovery_enabled': true,
        'onboarding_clan_detail_enabled': true,
      });
      await _remoteConfig.fetchAndActivate();
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Onboarding Remote Config fetch failed. Falling back to cached/default values.',
        error,
        stackTrace,
      );
    }

    final settings = OnboardingRemoteSettings(
      enabled: _remoteConfig.getBool('onboarding_enabled'),
      firestoreCatalogEnabled: _remoteConfig.getBool(
        'onboarding_firestore_catalog_enabled',
      ),
      catalogCollection:
          _remoteConfig
              .getString('onboarding_catalog_collection')
              .trim()
              .isEmpty
          ? 'onboardingFlows'
          : _remoteConfig.getString('onboarding_catalog_collection').trim(),
      rolloutPercent: _remoteConfig
          .getInt('onboarding_rollout_percent')
          .clamp(0, 100)
          .toInt(),
      shellNavigationEnabled: _remoteConfig.getBool(
        'onboarding_shell_navigation_enabled',
      ),
      memberWorkspaceEnabled: _remoteConfig.getBool(
        'onboarding_member_workspace_enabled',
      ),
      genealogyWorkspaceEnabled: _remoteConfig.getBool(
        'onboarding_genealogy_workspace_enabled',
      ),
      genealogyDiscoveryEnabled: _remoteConfig.getBool(
        'onboarding_genealogy_discovery_enabled',
      ),
      clanDetailEnabled: _remoteConfig.getBool(
        'onboarding_clan_detail_enabled',
      ),
    );
    _cache = settings;
    _cacheLoadedAt = now;
    return settings;
  }
}

OnboardingRemoteConfigService createDefaultOnboardingRemoteConfigService() {
  return FirebaseOnboardingRemoteConfigService();
}
