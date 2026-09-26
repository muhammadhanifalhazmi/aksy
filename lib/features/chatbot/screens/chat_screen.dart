import 'package:flutter/material.dart';

import '../../../core/data/app_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_navigation_drawer.dart';
import '../models/chat_message.dart';
import '../providers/chat_controller.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.selectedDestination,
    required this.onDestinationSelected,
  });

  final AppDestination selectedDestination;
  final ValueChanged<AppDestination> onDestinationSelected;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const List<String> _suggestions = [
    'Berapa omzet hari ini?',
    'Produk apa yang paling laris?',
    'Stok apa yang perlu dipesan?',
    'Siapa piutang yang lewat jatuh tempo?',
    'Bandingkan omzet hari ini dengan kemarin',
  ];

  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  ChatController? _controller;
  bool _settingsOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= ChatController(store: AppScope.of(context))
      ..init()
      ..addListener(_scrollToBottom);
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    _controller?.send(text);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _openSettings() async {
    final controller = _controller;
    if (controller == null || _settingsOpen) return;
    _settingsOpen = true;

    final proxyField = TextEditingController(text: controller.proxyUrl);
    final tokenField = TextEditingController(text: controller.appToken);
    final modelField = TextEditingController(text: controller.model);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Pengaturan Asisten'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Biasanya sudah terisi dari build dan tidak perlu diubah. '
                  'Ubah hanya kalau kamu memakai proxy sendiri.',
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: proxyField,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'URL proxy',
                    hintText: 'https://namamu.workers.dev',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tokenField,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Token aplikasi (opsional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: modelField,
                  decoration: const InputDecoration(
                    labelText: 'Model',
                    hintText: 'gemini-3.5-flash',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    _settingsOpen = false;

    if (saved ?? false) {
      controller.saveSettings(
        proxyUrl: proxyField.text,
        appToken: tokenField.text,
        model: modelField.text,
      );
    }

    proxyField.dispose();
    tokenField.dispose();
    modelField.dispose();
  }

  Future<void> _confirmClear() async {
    final controller = _controller;
    if (controller == null || controller.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus riwayat?'),
        content: const Text(
          'Semua pesan asisten akan dihapus dan tidak bisa dikembalikan.',
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
    if (confirmed ?? false) controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final theme = Theme.of(context);

    return Scaffold(
      drawer: AppNavigationDrawer(
        selectedDestination: widget.selectedDestination,
        onDestinationSelected: widget.onDestinationSelected,
      ),
      appBar: AppBar(
        title: const Text('Asisten Kasir'),
        actions: [
          IconButton(
            tooltip: 'Pengaturan asisten',
            onPressed: controller == null ? null : _openSettings,
            icon: const Icon(Icons.tune),
          ),
          IconButton(
            tooltip: 'Hapus riwayat',
            onPressed: controller == null ? null : _confirmClear,
            icon: const Icon(Icons.delete_outline),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: controller == null
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                return Column(
                  children: [
                    Expanded(child: _buildBody(context, theme, controller)),
                    _buildComposer(context, theme, controller),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    ChatController controller,
  ) {
    if (!controller.isConfigured) {
      return _buildNotConfigured(context, theme);
    }
    if (controller.isEmpty) return _buildWelcome(context, theme, controller);

    final messages = controller.messages;
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: messages.length,
      itemBuilder: (context, index) => _MessageBubble(message: messages[index]),
    );
  }

  Widget _buildNotConfigured(BuildContext context, ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 56,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Server asisten belum diatur',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Isi URL proxy asisten agar fitur ini bisa dipakai. '
              'Kalau kamu memakai build resmi, biasanya sudah terisi otomatis.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _openSettings,
              icon: const Icon(Icons.tune),
              label: const Text('Pengaturan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcome(
    BuildContext context,
    ThemeData theme,
    ChatController controller,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 24),
        Icon(Icons.auto_awesome, size: 48, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          'Tanya apa saja tentang tokomu',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Asisten sudah membawa data penjualan, stok, kas, dan hutang piutang '
          'hari ini dari perangkat ini.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 24),
        for (final suggestion in _suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SuggestionChip(
              label: suggestion,
              onTap: () => controller.send(suggestion),
            ),
          ),
      ],
    );
  }

  Widget _buildComposer(
    BuildContext context,
    ThemeData theme,
    ChatController controller,
  ) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  hintText: 'Tanya omzet, stok, atau hutang piutang...',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: controller.isBusy ? null : _submit,
              icon: const Icon(Icons.send),
              style: IconButton.styleFrom(
                minimumSize: const Size(48, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;
    final isError = message.isError;

    final background = isError
        ? theme.colorScheme.errorContainer
        : isUser
        ? theme.colorScheme.primary
        : theme.colorScheme.surface;
    final foreground = isError
        ? theme.colorScheme.onErrorContainer
        : isUser
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    final showTyping = message.text.isEmpty && !isUser && !isError;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(AppTheme.radiusSm),
      topRight: const Radius.circular(AppTheme.radiusSm),
      bottomLeft: Radius.circular(isUser ? AppTheme.radiusSm : AppTheme.radius),
      bottomRight: Radius.circular(
        isUser ? AppTheme.radius : AppTheme.radiusSm,
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: background,
                borderRadius: radius,
                border: isUser || isError
                    ? null
                    : Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showTyping)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    )
                  else ...[
                    Text(
                      message.text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: foreground,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormatter.timeOnly(message.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: foreground.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
