import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/bootstrap/firebase_setup_status.dart';
import '../../../app/home/app_shell_page.dart';
import '../../../core/services/app_logger.dart';
import '../../../core/services/app_locale_controller.dart';
import '../../../l10n/l10n.dart';
import '../../billing/services/billing_repository.dart';
import '../../clan/services/clan_repository.dart';
import '../../discovery/services/genealogy_discovery_repository.dart';
import '../../events/services/event_repository.dart';
import '../../funds/services/fund_repository.dart';
import '../../genealogy/services/genealogy_read_repository.dart';
import '../../member/services/member_repository.dart';
import '../../notifications/services/push_notification_service.dart';
import '../../profile/services/profile_notification_preferences_repository.dart';
import '../models/auth_entry_method.dart';
import '../models/member_identity_verification.dart';
import '../models/pending_otp_challenge.dart';
import '../models/phone_identity_resolution.dart';
import '../services/auth_analytics_service.dart';
import '../services/auth_gateway.dart';
import '../services/auth_gateway_factory.dart';
import '../services/clan_context_service.dart';
import '../services/auth_session_store.dart';
import '../services/phone_number_formatter.dart';
import '../widgets/phone_country_selector_field.dart';
import 'auth_controller.dart';

part 'auth_experience_sections.dart';

class AuthExperience extends StatefulWidget {
  const AuthExperience({
    super.key,
    required this.status,
    this.authGateway,
    this.authAnalyticsService,
    this.sessionStore,
    this.clanContextService,
    this.clanRepository,
    this.memberRepository,
    this.eventRepository,
    this.fundRepository,
    this.genealogyRepository,
    this.genealogyDiscoveryRepository,
    this.billingRepository,
    this.pushNotificationService,
    this.profileNotificationPreferencesRepository,
    this.localeController,
  });

  final FirebaseSetupStatus status;
  final AuthGateway? authGateway;
  final AuthAnalyticsService? authAnalyticsService;
  final AuthSessionStore? sessionStore;
  final ClanContextService? clanContextService;
  final ClanRepository? clanRepository;
  final MemberRepository? memberRepository;
  final EventRepository? eventRepository;
  final FundRepository? fundRepository;
  final GenealogyReadRepository? genealogyRepository;
  final GenealogyDiscoveryRepository? genealogyDiscoveryRepository;
  final BillingRepository? billingRepository;
  final PushNotificationService? pushNotificationService;
  final ProfileNotificationPreferencesRepository?
  profileNotificationPreferencesRepository;
  final AppLocaleController? localeController;

  @override
  State<AuthExperience> createState() => _AuthExperienceState();
}

class _AuthExperienceState extends State<AuthExperience> {
  late final AuthController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AuthController(
      authGateway: widget.authGateway ?? createDefaultAuthGateway(),
      analyticsService:
          widget.authAnalyticsService ?? createDefaultAuthAnalyticsService(),
      sessionStore: widget.sessionStore ?? SharedPrefsAuthSessionStore(),
    );
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_controller.isRestoring) {
          return _AuthLoadingPage(status: widget.status);
        }

        final session = _controller.session;
        if (session != null) {
          return AppShellPage(
            status: widget.status,
            session: session,
            clanContextService: widget.clanContextService,
            clanRepository:
                widget.clanRepository ??
                createDefaultClanRepository(session: session),
            memberRepository:
                widget.memberRepository ??
                createDefaultMemberRepository(session: session),
            eventRepository: widget.eventRepository,
            fundRepository: widget.fundRepository,
            genealogyRepository: widget.genealogyRepository,
            genealogyDiscoveryRepository: widget.genealogyDiscoveryRepository,
            billingRepository: widget.billingRepository,
            pushNotificationService: widget.pushNotificationService,
            profileNotificationPreferencesRepository:
                widget.profileNotificationPreferencesRepository,
            localeController: widget.localeController,
            onLogoutRequested: _controller.logout,
          );
        }

        return _AuthScaffold(controller: _controller);
      },
    );
  }
}
