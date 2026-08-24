import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/layout/questra_responsive_list_view.dart';
import '../../widgets/questra_card.dart';
import '../auth/auth_controller.dart';
import 'legal_eligibility_form.dart';

class LegalEligibilityScreen extends ConsumerWidget {
  const LegalEligibilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('利用条件の確認')),
      body: QuestraResponsiveListView(
        maxContentWidth: 680,
        padding: const EdgeInsets.all(20),
        children: [
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
          if (auth.errorMessage case final message?) ...[
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
