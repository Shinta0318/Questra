import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/questra_colors.dart';
import '../../widgets/layout/questra_screen_surface.dart';
import '../../widgets/questra_card.dart';
import '../auth/auth_controller.dart';
import 'beta_feedback_model.dart';
import 'beta_feedback_service.dart';

class BetaFeedbackScreen extends ConsumerStatefulWidget {
  const BetaFeedbackScreen({super.key});

  @override
  ConsumerState<BetaFeedbackScreen> createState() => _BetaFeedbackScreenState();
}

class _BetaFeedbackScreenState extends ConsumerState<BetaFeedbackScreen> {
  static const _buildVersion = String.fromEnvironment(
    'QUESTRA_BUILD_VERSION',
    defaultValue: 'local-beta',
  );

  final _formKey = GlobalKey<FormState>();
  final _summaryController = TextEditingController();
  final _stepsController = TextEditingController();
  final _expectedController = TextEditingController();
  final _actualController = TextEditingController();
  BetaFeedbackSurface _surface = BetaFeedbackSurface.home;
  BetaFeedbackType _type = BetaFeedbackType.brokenFlow;
  BetaFeedbackSeverity _severity = BetaFeedbackSeverity.s2;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _summaryController.dispose();
    _stepsController.dispose();
    _expectedController.dispose();
    _actualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destination = ref.watch(betaFeedbackDestinationProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Betaフィードバック')),
      body: QuestraScreenSurface(
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              QuestraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.rate_review_outlined,
                          color: QuestraColors.cosmicBlue,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '航路で気づいたことを教えてください',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(destination.guidance),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const _PrivacyNotice(),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              QuestraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '報告内容',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    DropdownButtonFormField<BetaFeedbackSurface>(
                      initialValue: _surface,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '画面・機能'),
                      items: BetaFeedbackSurface.values
                          .map(
                            (surface) => DropdownMenuItem(
                              value: surface,
                              child: Text(surface.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) setState(() => _surface = value);
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<BetaFeedbackType>(
                      initialValue: _type,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '種類'),
                      items: BetaFeedbackType.values
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) setState(() => _type = value);
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<BetaFeedbackSeverity>(
                      initialValue: _severity,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '重要度'),
                      items: BetaFeedbackSeverity.values
                          .map(
                            (severity) => DropdownMenuItem(
                              value: severity,
                              child: Text(severity.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) setState(() => _severity = value);
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _FeedbackField(
                      controller: _summaryController,
                      label: '概要',
                      hint: '何が起きたかを一文で',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _FeedbackField(
                      controller: _stepsController,
                      label: '再現手順',
                      hint: '1. Homeを開く\n2. Questを選ぶ\n3. ...',
                      minLines: 4,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _FeedbackField(
                      controller: _expectedController,
                      label: '期待した結果',
                      hint: '本来どうなると思ったか',
                      minLines: 2,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _FeedbackField(
                      controller: _actualController,
                      label: '実際の結果',
                      hint: '画面で実際に起きたこと',
                      minLines: 2,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isSubmitting ? null : _copyReport,
                        icon: _isSubmitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.copy_all_outlined),
                        label: const Text('報告内容をコピー'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copyReport() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _isSubmitting = true);
    final profile = ref.read(authControllerProvider).profile;
    final draft = BetaFeedbackDraft(
      surface: _surface,
      type: _type,
      severity: _severity,
      summary: _summaryController.text,
      steps: _stepsController.text,
      expected: _expectedController.text,
      actual: _actualController.text,
    );
    try {
      final report = ref.read(betaFeedbackServiceProvider).createReport(
            draft: draft,
            testerId: profile?.id ?? 'anonymous-beta',
            buildVersion: _buildVersion,
          );
      await ref.read(betaFeedbackSinkProvider).submit(report);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(betaFeedbackDestinationProvider).copiedMessage,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('コピーできませんでした。もう一度試してください。')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _FeedbackField extends StatelessWidget {
  const _FeedbackField({
    required this.controller,
    required this.label,
    required this.hint,
    this.minLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final int minLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      minLines: minLines,
      maxLines: minLines + 2,
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator: (value) =>
          value == null || value.trim().isEmpty ? '$labelを入力してください。' : null,
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: QuestraColors.gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.privacy_tip_outlined, size: 20),
          SizedBox(width: AppSpacing.sm),
          Expanded(child: Text('パスワード、住所、電話番号などの個人情報は入力しないでください。')),
        ],
      ),
    );
  }
}
