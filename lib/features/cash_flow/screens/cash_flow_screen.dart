import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/data/app_store.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_navigation_drawer.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/summary_card.dart';
import '../models/cash_entry.dart';

class CashFlowScreen extends StatefulWidget {
  const CashFlowScreen({
    super.key,
    required this.selectedDestination,
    required this.onDestinationSelected,
  });

  final AppDestination selectedDestination;
  final ValueChanged<AppDestination> onDestinationSelected;

  @override
  State<CashFlowScreen> createState() => _CashFlowScreenState();
}

class _CashFlowScreenState extends State<CashFlowScreen> {
  CashFlowType _selected = CashFlowType.cashIn;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final entries = store.cashEntries
        .where((e) => e.type == _selected)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final total = entries.fold(0, (sum, e) => sum + e.amount);

    return Scaffold(
      drawer: AppNavigationDrawer(
        selectedDestination: widget.selectedDestination,
        onDestinationSelected: widget.onDestinationSelected,
      ),
      appBar: AppBar(
        title: const Text('Kas Masuk / Keluar'),
        actions: [
          IconButton(
            onPressed: () => _showForm(context, store),
            tooltip: 'Catat Kas',
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SegmentedButton<CashFlowType>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: CashFlowType.cashIn,
                  label: Text('Kas Masuk'),
                  icon: Icon(Icons.south_west),
                ),
                ButtonSegment(
                  value: CashFlowType.cashOut,
                  label: Text('Kas Keluar'),
                  icon: Icon(Icons.north_east),
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
              icon: _selected == CashFlowType.cashIn
                  ? Icons.trending_up
                  : Icons.trending_down,
              label: 'Total ${_selected.label}',
              value: CurrencyFormatter.formatIDR(total),
              color: _selected == CashFlowType.cashIn
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? const EmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Belum ada catatan',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _CashCard(
                        entry: entry,
                        onEdit: entry.isEditable
                            ? () => _showForm(context, store, entry: entry)
                            : null,
                        onDelete: entry.isEditable
                            ? () => _confirmDelete(context, store, entry)
                            : null,
                        onLocked: entry.isEditable
                            ? null
                            : () => _showLocked(context, entry),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showForm(
    BuildContext context,
    AppStore store, {
    CashEntry? entry,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CashFormSheet(store: store, existing: entry),
    );
  }

  void _showLocked(BuildContext context, CashEntry entry) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(entry.source.lockedReason ?? 'Catatan terkunci'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AppStore store,
    CashEntry entry,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus catatan kas?'),
        content: Text(
          '${entry.category} sebesar '
          '${CurrencyFormatter.formatIDR(entry.amount)} akan dihapus dari '
          '${entry.type.label} dan laporan kas ikut berubah. '
          'Tindakan ini tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    store.removeCashEntry(entry.id);
    messenger.showSnackBar(
      SnackBar(content: Text('Catatan ${entry.category} dihapus')),
    );
  }
}

class _CashCard extends StatelessWidget {
  const _CashCard({
    required this.entry,
    this.onEdit,
    this.onDelete,
    this.onLocked,
  });

  final CashEntry entry;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onLocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIn = entry.type == CashFlowType.cashIn;
    final color = isIn ? theme.colorScheme.primary : theme.colorScheme.error;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(
            isIn ? Icons.south_west : Icons.north_east,
            color: color,
          ),
        ),
        title: Text(
          entry.category,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          entry.note?.isNotEmpty == true
              ? '${entry.note} · ${DateFormatter.when(entry.createdAt)}'
              : DateFormatter.when(entry.createdAt),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${isIn ? '+' : '-'}${CurrencyFormatter.formatIDR(entry.amount)}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (onEdit != null && onDelete != null)
              PopupMenuButton<String>(
                tooltip: 'Ubah catatan',
                onSelected: (value) {
                  if (value == 'edit') onEdit!();
                  if (value == 'delete') onDelete!();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Ubah'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Hapus'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              )
            else
              IconButton(
                tooltip: 'Catatan otomatis',
                onPressed: onLocked,
                icon: Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: theme.colorScheme.outline,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CashFormSheet extends StatefulWidget {
  const _CashFormSheet({required this.store, this.existing});

  final AppStore store;
  final CashEntry? existing;

  @override
  State<_CashFormSheet> createState() => _CashFormSheetState();
}

class _CashFormSheetState extends State<_CashFormSheet> {
  static const _inCategories = [
    'Penjualan',
    'Pembayaran Piutang',
    'Modal Masuk',
    'Lainnya',
  ];
  static const _outCategories = [
    'Belanja Stok',
    'Biaya Operasional',
    'Pembayaran Hutang',
    'Gaji',
    'Lainnya',
  ];

  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  CashFlowType _type = CashFlowType.cashIn;
  String _category = _inCategories.first;
  String? _amountError;

  List<String> get _categories =>
      _type == CashFlowType.cashIn ? _inCategories : _outCategories;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) return;
    _type = existing.type;
    _category = _categories.contains(existing.category)
        ? existing.category
        : _categories.first;
    _amountController.text = existing.amount.toString();
    _noteController.text = existing.note ?? '';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _amountError = 'Nominal harus lebih dari 0');
      return;
    }
    final note = _noteController.text.trim();
    final existing = widget.existing;
    if (existing == null) {
      widget.store.addCashEntry(
        CashEntry(
          id: widget.store.nextId('CF'),
          type: _type,
          amount: amount,
          category: _category,
          note: note.isEmpty ? null : note,
          createdAt: DateTime.now(),
        ),
      );
    } else {
      final updated = existing.copyWith(
        type: _type,
        amount: amount,
        category: _category,
        note: note.isEmpty ? '' : note,
      );
      if (!widget.store.updateCashEntry(updated)) {
        setState(() => _amountError = 'Gagal menyimpan, catatan terkunci');
        return;
      }
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _isEditing ? 'Catatan kas diperbarui' : '${_type.label} tercatat',
        ),
      ),
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
                _isEditing ? 'Ubah Catatan Kas' : 'Catat Kas',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<CashFlowType>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: CashFlowType.cashIn,
                    label: Text('Masuk'),
                    icon: Icon(Icons.south_west),
                  ),
                  ButtonSegment(
                    value: CashFlowType.cashOut,
                    label: Text('Keluar'),
                    icon: Icon(Icons.north_east),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (selection) {
                  setState(() {
                    _type = selection.first;
                    _category = _categories.first;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) {
                  if (_amountError != null) {
                    setState(() => _amountError = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Nominal (Rp)',
                  prefixText: 'Rp ',
                  errorText: _amountError,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _category,
                items: [
                  for (final category in _categories)
                    DropdownMenuItem(value: category, child: Text(category)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Catatan',
                  hintText: 'Opsional, mis. beli stok Nescafe',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Simpan Catatan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}