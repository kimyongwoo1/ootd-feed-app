import 'package:flutter/material.dart';

import '../models/report_reason.dart';

/// 신고 시트에서 고른 결과
class ReportInput {
  final ReportReason reason;
  final String detail;
  const ReportInput(this.reason, this.detail);
}

/// 신고 사유 선택 시트. 사유를 골라야 [신고하기]가 켜진다.
Future<ReportInput?> showReportSheet(BuildContext context) {
  return showModalBottomSheet<ReportInput>(
    context: context,
    isScrollControlled: true, // 키보드가 올라와도 가려지지 않게
    showDragHandle: true,
    builder: (_) => const _ReportSheet(),
  );
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet();

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ReportReason? _reason;
  final _detail = TextEditingController();

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('게시글 신고', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('신고 사유를 골라 주세요. 신고한 사람은 작성자에게 공개되지 않아요.',
                style: TextStyle(fontSize: 13, color: scheme.outline)),
            const SizedBox(height: 8),
            for (final r in ReportReason.values)
              ListTile(
                key: Key('reason_${r.code}'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _reason == r ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: _reason == r ? scheme.primary : scheme.outline,
                ),
                title: Text(r.label),
                subtitle: Text(r.description, style: const TextStyle(fontSize: 12)),
                onTap: () => setState(() => _reason = r),
              ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('report_detail'),
              controller: _detail,
              maxLength: 200,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '자세한 설명 (선택)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('report_submit'),
              style: FilledButton.styleFrom(backgroundColor: scheme.error),
              onPressed: _reason == null
                  ? null
                  : () => Navigator.pop(context, ReportInput(_reason!, _detail.text)),
              child: const Text('신고하기'),
            ),
          ],
        ),
      ),
    );
  }
}
