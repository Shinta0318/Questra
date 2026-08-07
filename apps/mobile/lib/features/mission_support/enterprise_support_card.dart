import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import 'mission_support_model.dart';

class EnterpriseSupportCard extends StatelessWidget {
  const EnterpriseSupportCard({
    super.key,
    required this.proposal,
    required this.onDismiss,
    required this.onReport,
  });

  final EnterpriseSupportProposal proposal;
  final VoidCallback onDismiss;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    if (!proposal.canDisplay) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${proposal.enterpriseName} / ${_roleLabel(proposal.role)}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(proposal.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(proposal.description),
          const SizedBox(height: 10),
          Text('受けられる支援: ${proposal.benefit}'),
          Text('費用: ${proposal.userCost}'),
          Text('条件: ${proposal.eligibility}'),
          Text('選ばれた理由: ${proposal.selectionReason}'),
          const SizedBox(height: 8),
          Text(
            proposal.disclosure,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => launchUrl(
                  proposal.destination,
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new),
                label: const Text('条件を確認'),
              ),
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.visibility_off_outlined),
                tooltip: '表示しない',
              ),
              IconButton(
                onPressed: onReport,
                icon: const Icon(Icons.flag_outlined),
                tooltip: '報告',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _roleLabel(EnterpriseSupportRole role) => switch (role) {
        EnterpriseSupportRole.sponsor => 'Sponsor',
        EnterpriseSupportRole.coach => 'Coach',
        EnterpriseSupportRole.partner => 'Partner',
        EnterpriseSupportRole.officialEventHost => 'Official Event Host',
      };
}
