import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/data/app_store.dart';
import '../../../core/theme/app_theme.dart';
import '../models/report_period.dart';
import '../services/report_pdf_generator.dart';
import 'pdf_report_preview_screen.dart';

class ReportExportSheet extends StatefulWidget {
  const ReportExportSheet({super.key, required this.store});

  final AppStore store;

  @override
  State<ReportExportSheet> createState() => _ReportExportSheetState();
}

class _ReportExportSheetState extends State<ReportExportSheet> {
  ReportPeriodType _type = ReportPeriodType.daily;
  DateTime _anchor = DateTime.now();
  bool _busy = false;

  ReportPeriod get _period => ReportPeriod(type: _type, anchor: _anchor);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final period = _period;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unduh Laporan PDF',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pilih jenis laporan dan periode, lalu unduh dalam format PDF.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Jenis laporan',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in ReportPeriodType.values)
                ChoiceChip(
                  label: Text(type.label),
                  selected: _type == type,
                  avatar: _type == type
                      ? Icon(type.icon, size: 16)
                      : null,
                  onSelected: (_) => setState(() {
                    _type = type;
                    _anchor = _snap(anchoredTo: type);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Periode',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ..._buildPeriodControls(),
          const SizedBox(height: 18),
          Card(
            color: theme.colorScheme.secondaryContainer.withValues(alpha: .5),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      period.icon,
                      color: theme.colorScheme.onPrimary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          period.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          period.rangeLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _download,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_download_outlined),
              label: Text(_busy ? 'Menyiapkan...' : 'Unduh PDF'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPeriodControls() {
    switch (_type) {
      case ReportPeriodType.daily:
      case ReportPeriodType.weekly:
      case ReportPeriodType.monthly:
        return [
          _PickerButton(
            icon: _period.icon,
            label: _period.anchorLabel,
            onTap: _busy ? null : _pickDate,
          ),
        ];
      case ReportPeriodType.quarterly:
        final quarter = (_anchor.month - 1) ~/ 3 + 1;
        return [
          Wrap(
            spacing: 8,
            children: [
              for (var q = 1; q <= 4; q++)
                ChoiceChip(
                  label: Text('Q$q'),
                  selected: quarter == q,
                  onSelected: (_) => setState(() {
                    _anchor = DateTime(_anchor.year, (q - 1) * 3 + 1, 1);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _PickerButton(
            icon: Icons.event_outlined,
            label: '${_anchor.year}',
            onTap: _busy ? null : _pickYear,
          ),
        ];
      case ReportPeriodType.yearly:
        return [
          _PickerButton(
            icon: Icons.event_outlined,
            label: '${_anchor.year}',
            onTap: _busy ? null : _pickYear,
          ),
        ];
    }
  }

  DateTime _snap({required ReportPeriodType anchoredTo}) {
    final now = DateTime.now();
    switch (anchoredTo) {
      case ReportPeriodType.daily:
      case ReportPeriodType.monthly:
      case ReportPeriodType.weekly:
        return now;
      case ReportPeriodType.quarterly:
        return DateTime(now.year, now.month, 1);
      case ReportPeriodType.yearly:
        return DateTime(now.year, 6, 1);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchor.isAfter(now) ? now : _anchor,
      firstDate: DateTime(now.year - 10, 1, 1),
      lastDate: now,
      helpText: 'Pilih Periode',
    );
    if (picked == null || !mounted) return;
    setState(() {
      switch (_type) {
        case ReportPeriodType.monthly:
          _anchor = DateTime(picked.year, picked.month, 1);
        case ReportPeriodType.daily:
        case ReportPeriodType.weekly:
          _anchor = DateTime(picked.year, picked.month, picked.day);
        case ReportPeriodType.quarterly:
        case ReportPeriodType.yearly:
          break;
      }
    });
  }

  Future<void> _pickYear() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_anchor.year, now.month, now.day),
      firstDate: DateTime(now.year - 10, 1, 1),
      lastDate: now,
      helpText: 'Pilih Tahun',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _anchor = DateTime(picked.year, _anchor.month, 1);
    });
  }

  Future<void> _download() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final period = _period;

    setState(() {
      _busy = true;
    });

    Uint8List bytes;
    try {
      bytes = await generateReportPdf(store: widget.store, period: period);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
      });
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal membuat laporan: $e')),
      );
      return;
    }

    if (!mounted) return;
    navigator.pop();
    navigator.push(
      MaterialPageRoute(
        builder: (_) => PdfReportPreviewScreen(
          bytes: bytes,
          fileName: '${period.fileName}.pdf',
        ),
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}