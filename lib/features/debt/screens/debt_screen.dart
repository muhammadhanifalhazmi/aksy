import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/data/app_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_navigation_drawer.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/summary_card.dart';
import '../models/debt.dart';

class DebtScreen extends StatefulWidget {
  const DebtScreen({
    super.key,
    required this.selectedDestination,
    required this.onDestinationSelected,
  });

  final AppDestination selectedDestination;
  final ValueChanged<AppDestination> onDestinationSelected;

  @override
  State<DebtScreen> createState() => _DebtScreenState();
}

class _DebtScreenState extends State<DebtScreen> {
  DebtType _selected = DebtType.receivable;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final debts = store.debts
        .where((d) => d.type == _selected)
        .toList()
      ..sort((a, b) => a.isPaid == b.isPaid
          ? b.createdAt.compareTo(a.createdAt)
          : (a.isPaid ? 1 : -1));
    final outstanding = debts.fold(0, (sum, d) => sum + d.remaining);

    return Scaffold(
      drawer: AppNavigationDrawer(
        selectedDestination: widget.selectedDestination,
        onDestinationSelected: widget.onDestinationSelected,
      ),
      appBar: AppBar(
        title: const Text('Hutang & Piutang'),
        actions: [
          IconButton(
            onPressed: () => _showForm(context, store),
            tooltip: 'Catat Baru',
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SegmentedButton<DebtType>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: DebtType.receivable,
                  label: Text('Piutang'),
                ),
                ButtonSegment(
                  value: DebtType.payable,
                  label: Text('Hutang'),
                ),
              ],
              selected: {_selected},
              onSelectionChanged: (selection) =>
                  setState(() => _selected = selection.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SummaryCard(
              icon: _selected == DebtType.receivable
                  ? Icons.savings_outlined
                  : Icons.wallet_outlined,
              label: 'Sisa tagihan ${_selected.label}',
              value: CurrencyFormatter.formatIDR(outstanding),
            ),
          ),
          Expanded(
            child: debts.isEmpty
                ? const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Belum ada catatan',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: debts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final debt = debts[index];
                      return _DebtCard(
                        debt: debt,
                        onTap: () => _showDetail(context, store, debt),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showForm(BuildContext context, AppStore store) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DebtFormSheet(store: store),
    );
  }

  Future<void> _showDetail(BuildContext context, AppStore store, Debt debt) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DebtDetailSheet(store: store, debt: debt),
    );
  }
}

class _DebtCard extends StatelessWidget {
  const _DebtCard({required this.debt, required this.onTap});

  final Debt debt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      debt.partyName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (debt.isPaid)
                    const StatusChip(
                      label: 'Lunas',
                      color: AppTheme.successGreen,
                    )
                  else if (debt.isOverdue)
                    StatusChip(
                      label: 'Jatuh tempo',
                      color: theme.colorScheme.error,
                    )
                  else
                    const StatusChip(
                      label: 'Belum lunas',
                      color: AppTheme.warningOrange,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                CurrencyFormatter.formatIDR(debt.amount),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (debt.paidAmount > 0)
                Text(
                  'Dibayar ${CurrencyFormatter.formatIDR(debt.paidAmount)} · '
                  'Sisa ${CurrencyFormatter.formatIDR(debt.remaining)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                debt.dueDate == null
                    ? 'Tanpa jatuh tempo'
                    : 'Jatuh tempo: ${DateFormatter.reportDate(debt.dueDate!)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: debt.isOverdue
                      ? theme.colorScheme.error
                      : theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DebtFormSheet extends StatefulWidget {
  const _DebtFormSheet({required this.store});

  final AppStore store;

  @override
  State<_DebtFormSheet> createState() => _DebtFormSheetState();
}

class _DebtFormSheetState extends State<_DebtFormSheet> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DebtType _type = DebtType.receivable;
  DateTime? _dueDate;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  void _save() {
    final name = _nameController.text.trim();
    final amount = int.tryParse(_amountController.text.trim());
    if (name.isEmpty || amount == null || amount <= 0) return;
    widget.store.addDebt(
      Debt(
        id: 'D${DateTime.now().millisecondsSinceEpoch}',
        type: _type,
        partyName: name,
        amount: amount,
        createdAt: DateTime.now(),
        dueDate: _dueDate,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      ),
    );
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_type.label} tercatat')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Catat ${_type.label} Baru',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<DebtType>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: DebtType.receivable,
                    label: Text('Piutang'),
                    icon: Icon(Icons.savings_outlined),
                  ),
                  ButtonSegment(
                    value: DebtType.payable,
                    label: Text('Hutang'),
                    icon: Icon(Icons.wallet_outlined),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (selection) =>
                    setState(() => _type = selection.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: _type == DebtType.receivable
                      ? 'Nama pelanggan'
                      : 'Nama supplier',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Nominal (Rp)',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Jatuh tempo',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _dueDate == null
                        ? 'Pilih tanggal (opsional)'
                        : DateFormatter.reportDate(_dueDate!),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Catatan',
                  hintText: 'Opsional',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DebtDetailSheet extends StatefulWidget {
  const _DebtDetailSheet({required this.store, required this.debt});

  final AppStore store;
  final Debt debt;

  @override
  State<_DebtDetailSheet> createState() => _DebtDetailSheetState();
}

class _DebtDetailSheetState extends State<_DebtDetailSheet> {
  late final TextEditingController _paymentController;

  @override
  void initState() {
    super.initState();
    _paymentController = TextEditingController(
      text: '${widget.debt.remaining}',
    );
  }

  @override
  void dispose() {
    _paymentController.dispose();
    super.dispose();
  }

  void _makePayment() {
    final amount = int.tryParse(_paymentController.text.trim());
    final debt = widget.debt;
    if (amount == null || amount <= 0 || amount > debt.remaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal pembayaran tidak valid')),
      );
      return;
    }
    widget.store.recordDebtPayment(debt.id, amount);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Pembayaran ${CurrencyFormatter.formatIDR(amount)} tercatat',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final debt = widget.debt;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
              children: [
                Expanded(
                  child: Text(
                    debt.partyName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (debt.isPaid)
                  const StatusChip(
                    label: 'Lunas',
                    color: AppTheme.successGreen,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${debt.type.label} sejak ${DateFormatter.reportDate(debt.createdAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            _InfoRow(
              label: 'Total tagihan',
              value: CurrencyFormatter.formatIDR(debt.amount),
            ),
            _InfoRow(
              label: 'Sudah dibayar',
              value: CurrencyFormatter.formatIDR(debt.paidAmount),
            ),
            _InfoRow(
              label: 'Sisa',
              value: CurrencyFormatter.formatIDR(debt.remaining),
              valueColor: theme.colorScheme.primary,
            ),
            if (debt.dueDate != null)
              _InfoRow(
                label: 'Jatuh tempo',
                value: DateFormatter.reportDate(debt.dueDate!),
                valueColor: debt.isOverdue
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurface,
              ),
            if (debt.note != null)
              _InfoRow(label: 'Catatan', value: debt.note!),
            const SizedBox(height: 16),
            if (debt.payments.isNotEmpty)
              Text(
                'Riwayat pembayaran',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            for (final payment in debt.payments)
              _InfoRow(
                label: DateFormatter.when(payment.at),
                value: CurrencyFormatter.formatIDR(payment.amount),
              ),
            const SizedBox(height: 8),
            if (!debt.isPaid) ...[
              TextField(
                controller: _paymentController,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Nominal bayar (Rp)',
                  prefixText: 'Rp ',
                  border: const OutlineInputBorder(),
                  helperText:
                      'Maksimal sisa ${CurrencyFormatter.formatIDR(debt.remaining)}',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _makePayment,
                icon: const Icon(Icons.payments_outlined),
                label: Text(
                  debt.remaining == debt.amount ? 'Bayar Sekarang' : 'Bayar Sebagian',
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}