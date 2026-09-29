import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/data/app_store.dart';
import '../../../core/data/store_settings.dart';
import '../../../core/widgets/app_navigation_drawer.dart';
import '../../../core/widgets/section_header.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.selectedDestination,
    required this.onDestinationSelected,
  });

  final AppDestination selectedDestination;
  final ValueChanged<AppDestination> onDestinationSelected;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _footer;
  bool _busy = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final settings = AppScope.of(context).settings;
    _name = TextEditingController(text: settings.name);
    _address = TextEditingController(text: settings.address);
    _phone = TextEditingController(text: settings.phone);
    _footer = TextEditingController(text: settings.footer);
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _footer.dispose();
    super.dispose();
  }

  void _saveSettings() {
    final store = AppScope.of(context);
    store.updateStoreSettings(
      StoreSettings(
        name: _name.text.trim().isEmpty ? 'Toko Saya' : _name.text.trim(),
        address: _address.text.trim(),
        phone: _phone.text.trim(),
        footer: _footer.text.trim(),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pengaturan toko disimpan')),
    );
  }

  Future<void> _exportBackup() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final store = AppScope.of(context);
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(RegExp(r'[:.]'), '-');
      final file = File('${dir.path}/aksy-backup-$stamp.json');
      await file.writeAsString(store.exportBackupJson());
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          text: 'Backup data Aplikasi Kasir Easy',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuat backup')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importBackup() async {
    if (_busy) return;
    final store = AppScope.of(context);
    setState(() => _busy = true);
    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Pilih file backup',
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      final file = result?.files.single;
      if (file == null) return;

      final content = file.bytes != null
          ? utf8.decode(file.bytes!)
          : await File(file.path!).readAsString();

      if (!mounted) return;
      final confirmed = await _showRestoreConfirm();
      if (confirmed != true) return;

      final ok = store.importBackup(content);
      if (!mounted) return;
      if (ok) {
        final settings = store.settings;
        _name.text = settings.name;
        _address.text = settings.address;
        _phone.text = settings.phone;
        _footer.text = settings.footer;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data berhasil dipulihkan')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File bukan backup yang valid')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memulihkan data')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _showRestoreConfirm() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: const Text('Pulihkan data?'),
          content: const Text(
            'Seluruh data saat ini (produk, transaksi, kas, hutang/piutang, '
            'shift, dan pengaturan) akan diganti oleh isi file backup.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Pulihkan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = AppScope.of(context);
    return Scaffold(
      drawer: AppNavigationDrawer(
        selectedDestination: widget.selectedDestination,
        onDestinationSelected: widget.onDestinationSelected,
      ),
      appBar: AppBar(
        title: const Text('Pengaturan'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(title: 'Identitas Toko'),
          const SizedBox(height: 4),
          Text(
            'Identitas ini dipakai di kepala struk dan laporan PDF.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nama toko',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _address,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Alamat',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Telepon',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _footer,
                    decoration: const InputDecoration(
                      labelText: 'Pesan di bagian bawah struk',
                      hintText: 'Opsional, mis. Barang yang dibeli tidak dapat ditukar',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saveSettings,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Simpan Identitas Toko'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Printer'),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.12,
                ),
                child: Icon(
                  Icons.print_outlined,
                  color: theme.colorScheme.primary,
                ),
              ),
              title: const Text('Printer Termal'),
              subtitle: Text(
                store.printer.isConfigured
                    ? '${store.printer.deviceName} · '
                          '${store.printer.wide ? '80' : '58'}mm'
                          '${store.printer.autoPrint ? ' · cetak otomatis' : ''}'
                    : 'Belum ada printer bluetooth yang dipilih',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => widget.onDestinationSelected(
                AppDestination.printer,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Data & Cadangan'),
          const SizedBox(height: 4),
          Text(
            'Semua data disimpan offline di perangkat. Cadangkan secara '
            'berkala agar terhindar dari kehilangan data.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cloud_download_outlined,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Export seluruh data ke file .json, lalu simpan '
                          'di tempat aman.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _BackupButton(
                    busy: _busy,
                    onPressed: _exportBackup,
                    icon: Icons.upload_file_outlined,
                    label: 'Cadangkan Data',
                  ),
                  const SizedBox(height: 8),
                  _BackupButton(
                    busy: _busy,
                    onPressed: _importBackup,
                    icon: Icons.settings_backup_restore,
                    label: 'Pulihkan dari File',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Tentang Aplikasi'),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                child: Icon(Icons.storefront_outlined,
                    color: theme.colorScheme.primary),
              ),
              title: const Text('Aplikasi Kasir Easy'),
              subtitle: const Text('Versi 1.0.0 · Data tersimpan offline'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupButton extends StatelessWidget {
  const _BackupButton({
    required this.busy,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final bool busy;
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 18),
      label: Text(label),
    );
  }
}