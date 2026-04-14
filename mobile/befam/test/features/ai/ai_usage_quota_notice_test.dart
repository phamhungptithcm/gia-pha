import 'package:befam/features/ai/presentation/ai_usage_quota_notice.dart';
import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/billing/models/billing_workspace_snapshot.dart';
import 'package:befam/features/billing/services/billing_repository.dart';
import 'package:befam/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AuthSession buildSession() {
    return AuthSession(
      uid: 'debug:+84901234567',
      loginMethod: AuthEntryMethod.phone,
      phoneE164: '+84901234567',
      displayName: 'Nguyen Minh',
      memberId: 'member_demo_parent_001',
      clanId: 'clan_demo_001',
      branchId: 'branch_demo_001',
      primaryRole: 'CLAN_ADMIN',
      accessMode: AuthMemberAccessMode.claimed,
      linkedAuthUid: true,
      isSandbox: true,
      signedInAtIso: DateTime(2026, 4, 4).toIso8601String(),
    );
  }

  Future<void> pumpNotice(
    WidgetTester tester, {
    required BillingRepository repository,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: AiUsageQuotaNotice(
            session: buildSession(),
            billingRepository: repository,
            requestCost: 2,
            usageHint: 'Bạn có thể hỏi nhanh hoặc tìm người thân ngay tại đây.',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('hides quota notice when ai usage summary is unresolved', (
    tester,
  ) async {
    await pumpNotice(
      tester,
      repository: _FakeBillingRepository(
        aiUsageSummary: const BillingAiUsageSummary(
          windowKey: '',
          planCode: 'BASE',
          quotaCredits: 0,
          usedCredits: 0,
          remainingCredits: 0,
          totalRequests: 0,
          featureCounts: <String, int>{},
          featureCredits: <String, int>{},
        ),
      ),
    );

    expect(
      find.text('Tháng này bạn đã dùng hết lượt hỗ trợ AI của mình.'),
      findsNothing,
    );
    expect(find.byType(AiUsageQuotaNotice), findsOneWidget);
  });
}

class _FakeBillingRepository implements BillingRepository {
  const _FakeBillingRepository({required this.aiUsageSummary});

  final BillingAiUsageSummary aiUsageSummary;

  @override
  bool get isSandbox => true;

  @override
  Future<BillingViewerSummary> loadViewerSummary({
    required AuthSession session,
  }) async {
    return BillingViewerSummary(
      clanId: session.clanId ?? 'clan_demo_001',
      scope: BillingScopeContext(
        clanId: session.clanId ?? 'clan_demo_001',
        ownerUid: session.uid,
        ownerDisplayName: session.displayName,
        clanStatus: 'active',
        viewerIsOwner: true,
      ),
      subscription: const BillingSubscription(
        id: 'sub_demo',
        clanId: 'user_scope__debug',
        planCode: 'BASE',
        status: 'active',
        memberCount: 0,
        amountVndYear: 99000,
        vatIncluded: true,
        paymentMode: 'manual',
        autoRenew: false,
        startsAtIso: null,
        expiresAtIso: null,
        nextPaymentDueAtIso: null,
        graceEndsAtIso: null,
        lastPaymentMethod: null,
        lastTransactionId: null,
        updatedAtIso: null,
      ),
      entitlement: const BillingEntitlement(
        planCode: 'BASE',
        status: 'active',
        showAds: true,
        adFree: false,
        hasPremiumAccess: true,
        expiresAtIso: null,
        nextPaymentDueAtIso: null,
      ),
      aiUsageSummary: aiUsageSummary,
      pricingTiers: const <BillingPlanPricing>[],
      memberCount: 0,
    );
  }

  @override
  Future<BillingWorkspaceSnapshot> loadWorkspace({
    required AuthSession session,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<BillingEntitlement> resolveEntitlement({
    required AuthSession session,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<BillingSettings> updatePreferences({
    required AuthSession session,
    required String paymentMode,
    required bool autoRenew,
    List<int>? reminderDaysBefore,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<BillingEntitlement> verifyInAppPurchase({
    required AuthSession session,
    required String platform,
    required String productId,
    required Map<String, dynamic> payload,
  }) {
    throw UnimplementedError();
  }
}
