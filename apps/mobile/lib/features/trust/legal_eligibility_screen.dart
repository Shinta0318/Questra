import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/layout/questra_responsive_list_view.dart';
import '../../widgets/questra_card.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_state.dart';
import 'legal_eligibility_form.dart';
import 'legal_policy.dart';

class LegalEligibilityScreen extends ConsumerStatefulWidget {
  const LegalEligibilityScreen({super.key});

  @override
  ConsumerState<LegalEligibilityScreen> createState() =>
      _LegalEligibilityScreenState();
}

class _LegalEligibilityScreenState
    extends ConsumerState<LegalEligibilityScreen> {
  bool _reviewFullPolicy = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final acceptanceCheckUnavailable =
        auth.profile?.legalAcceptanceCheckAvailable == false;
    final policyUpdateRequired =
        auth.profile?.legalPolicyUpdateRequired == true;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          acceptanceCheckUnavailable
              ? '接続を確認'
              : policyUpdateRequired
              ? 'アプリの更新が必要'
              : '利用条件の確認',
        ),
      ),
      body: QuestraResponsiveListView(
        maxContentWidth: 680,
        padding: const EdgeInsets.all(20),
        children: [
          if (acceptanceCheckUnavailable)
            QuestraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('同意の記録を確認できませんでした。'),
                  const SizedBox(height: 12),
                  const Text(
                    'ログイン状態は確認できています。登録時に同意済みの方は、もう一度同意する必要はありません。'
                    '記録を確認できるまで先へ進めないため、しばらくしてから再確認してください。',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: auth.isLoading
                        ? null
                        : () => ref
                              .read(authControllerProvider.notifier)
                              .restoreSession(),
                    child: Text(auth.isLoading ? '再確認しています' : 'もう一度確認'),
                  ),
                ],
              ),
            )
          else if (policyUpdateRequired)
            QuestraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '利用条件が更新されました',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'この版のQuestraでは新しい利用条件を表示できません。'
                    'アプリまたはページを更新してから、もう一度お試しください。'
                    '古い内容への再同意は必要ありません。',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: auth.isLoading
                        ? null
                        : () => ref
                              .read(authControllerProvider.notifier)
                              .restoreSession(),
                    child: Text(auth.isLoading ? '確認しています' : 'もう一度確認'),
                  ),
                ],
              ),
            )
          else if (auth.profile?.priorSignupConsentClaimed == true &&
              !_reviewFullPolicy)
            QuestraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '登録時の確認内容を引き継ぐ',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '初回登録時に年齢条件、利用規約、プライバシー、Arcの外部AI処理を確認しています。'
                    'サーバーの同意記録がないため、ここで一度だけ確定します。',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '利用規約 ${QuestraLegalPolicy.termsVersion} / '
                    'Privacy ${QuestraLegalPolicy.privacyVersion}',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: auth.isLoading
                        ? null
                        : () => ref
                              .read(authControllerProvider.notifier)
                              .acceptCurrentLegalPolicy(
                                QuestraLegalPolicy.acceptance(),
                              ),
                    child: Text(auth.isLoading ? '保存しています' : '確認して続ける'),
                  ),
                  TextButton(
                    onPressed: auth.isLoading
                        ? null
                        : () => setState(() => _reviewFullPolicy = true),
                    child: const Text('内容を見直す'),
                  ),
                ],
              ),
            )
          else
            QuestraCard(
              child: LegalEligibilityForm(
                submitLabel: auth.isLoading ? '保存しています' : '同意して続ける',
                onAccepted: auth.isLoading
                    ? (_) {}
                    : (acceptance) => ref
                          .read(authControllerProvider.notifier)
                          .acceptCurrentLegalPolicy(acceptance),
              ),
            ),
          if (auth.errorContext == AuthErrorContext.legalConsent &&
              auth.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              auth.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
