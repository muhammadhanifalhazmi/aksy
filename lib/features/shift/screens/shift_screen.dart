import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/data/app_store.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../models/shift_record.dart';

class ShiftScreen extends StatelessWidget {
  const ShiftScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = AppScope.of(context);
    final active = store.activeShift;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shift Kasir'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (active == null)
            _OpenShiftCard(onOpen: (cash) => store.openShift(cash))
          else
            _ActiveShiftCard(onClose: () => _closeShift(context, store)),
          const SizedBox(height: 20),
          Text(
            'Riwayat Shift',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (store.shifts.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.history,
                      size: 44,
                      color: theme.colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Belum ada shift ditutup',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final shift in store.shifts.reversed)
              _ShiftHistoryCard(shift: shift),
        ],
      ),
    );
  }

  Future<void> _closeShift(BuildContext context, AppStore store) {
    final theme = Theme.of(context);
    final active = store.activeShift;
    if (active == null) return Future.value();
    final controller = TextEditingController();
    final noteController = TextEditingController();
    var actual = active.startingCash;

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Tutup Shift'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Shift dibuka '
                  '${DateFormatter.when(active.openTime)} dengan kas awal '
                  '${CurrencyFormatter.formatIDR(active.startingCash)}.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Kas akhir (Rp)',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setDialogState(
                    () => actual = int.tryParse(value) ?? 0,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Catatan (opsional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Kas awal',
                      style: theme.textTheme.bodySmall,
                    ),
                    const Spacer(),
                    Text(
                      CurrencyFormatter.formatIDR(active.startingCash),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
                SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      Text(
                        'Kas akhir',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        CurrencyFormatter.formatIDR(actual),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () async {
                  final closed = store.closeShift(actual, note: noteController.text.trim());
                  Navigator.of(dialogContext).pop();
                  if (closed != null && dialogContext.mounted) {
                    _showClosingSummary(dialogContext, closed);
                  }
                },
                child: const Text('Tutup Shift'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showClosingSummary(BuildContext context, ShiftRecord shift) {
    final theme = Theme.of(context);
    final difference = shift.difference ?? 0;
    final summary = difference == 0
        ? 'Kondang'
        : difference > 0
            ? 'Surplus'
            : 'Defisit';
    final color = difference == 0
        ? theme.colorScheme.primary
        : difference > 0
            ? Colors.green
            : Colors.orange;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          difference == 0
              ? Icons.check_circle_outline
              : difference > 0
                  ? Icons.trending_up
                  : Icons.trending_down,
          color: color,
          size: 40,
        ),
        title: const Text('Shift Ditutup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SummaryRow(
              label: 'Kas awal',
              value: CurrencyFormatter.formatIDR(shift.startingCash),
            ),
            _SummaryRow(
              label: 'Penjualan selama shift',
              value: CurrencyFormatter.formatIDR(
                shift.expectedCash! - shift.startingCash,
              ),
            ),
            _SummaryRow(
              label: 'Kas diperkirakan',
              value: CurrencyFormatter.formatIDR(shift.expectedCash!),
            ),
            _SummaryRow(
              label: 'Kas aktual',
              value: CurrencyFormatter.formatIDR(shift.actualCash!),
            ),
            Divider(
              height: 24,
              color: theme.colorScheme.outlineVariant,
            ),
            Row(
              children: [
                Text(
                  summary,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const Spacer(),
                Text(
                  '${difference >= 0 ? '+' : '-'}'
                  '${CurrencyFormatter.formatIDR(difference.abs())}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenShiftCard extends StatefulWidget {
  const _OpenShiftCard({required this.onOpen});

  final ValueChanged<int> onOpen;

  @override
  State<_OpenShiftCard> createState() => _OpenShiftCardState();
}

class _OpenShiftCardState extends State<_OpenShiftCard> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open() {
    final cash = int.tryParse(_controller.text.trim()) ?? 0;
    if (cash < 0) return;
    widget.onOpen(cash);
    _controller.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Shift dibuka dengan kas awal ${CurrencyFormatter.formatIDR(cash)}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.play_circle_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Belum ada shift aktif',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Catat uang kas awal sebelum mulai bertransaksi.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Kas awal (Rp)',
                prefixText: 'Rp ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _open,
              icon: const Icon(Icons.login),
              label: const Text('Buka Shift'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveShiftCard extends StatelessWidget {
  const _ActiveShiftCard({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = AppScope.of(context);
    final shift = store.activeShift!;
    final sales = store.currentShiftSales();
    final salesTotal = sales.fold(0, (sum, o) => sum + o.total);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Shift Aktif',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Aktif',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ShiftStat(
              label: 'Dibuka',
              value: DateFormatter.when(shift.openTime),
            ),
            _ShiftStat(
              label: 'Kas awal',
              value: CurrencyFormatter.formatIDR(shift.startingCash),
            ),
            _ShiftStat(
              label: 'Penjualan (${sales.length} transaksi)',
              value: CurrencyFormatter.formatIDR(salesTotal),
            ),
            _ShiftStat(
              label: 'Kas diperkirakan',
              value: CurrencyFormatter.formatIDR(shift.startingCash + salesTotal),
              bold: true,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onClose,
              icon: const Icon(Icons.logout),
              label: const Text('Tutup Shift'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShiftStat extends StatelessWidget {
  const _ShiftStat({required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShiftHistoryCard extends StatelessWidget {
  const _ShiftHistoryCard({required this.shift});

  final ShiftRecord shift;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final difference = shift.difference ?? 0;
    final status = difference == 0
        ? 'Kondang'
        : difference > 0
            ? 'Surplus'
            : 'Defisit';
    final color = difference == 0
        ? theme.colorScheme.primary
        : difference > 0
            ? Colors.green
            : Colors.orange;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(
            difference >= 0 ? Icons.check : Icons.warning_amber,
            color: color,
            size: 22,
          ),
        ),
        title: Text(
          '${shift.id} · ${DateFormatter.reportDate(shift.openTime)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          'Kas ${CurrencyFormatter.formatIDR(shift.actualCash ?? 0)} · '
          '$status ${difference >= 0 ? '+' : '-'}'
          '${CurrencyFormatter.formatIDR(difference.abs())}',
        ),
        isThreeLine: false,
      ),
    );
  }
}