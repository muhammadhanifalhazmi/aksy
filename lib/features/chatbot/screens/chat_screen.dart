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
  bool _keyDialogOpen = false;

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

  Future<void> _openKeyDialog() async {
    final controller = _controller;
    if (controller == null || _keyDialogOpen) return;
    _keyDialogOpen = true;

    final field = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('API Key Gemini'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Buat key di Google AI Studio, lalu tempel di sini. '
                'Key tersimpan di perangkat ini saja.',
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: field,
                autofocus: true,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'API key',
                  hintText: 'AIza...',
                ),
              ),
            ],
          ),
          actions: [
            if (controller.hasApiKey)
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(''),
                child: const Text('Hapus'),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(field.text),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    _keyDialogOpen = false;
    field.dispose();

    if (result == null) return;
    controller.setApiKey(result);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.trim().isEmpty
              ? 'API key dihapus.'
              : 'API key tersimpan di perangkat ini.',
        ),
      ),
    );
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
            tooltip: controller?.hasApiKey ?? false
                ? 'Ganti API key'
                : 'Atur API key',
            onPressed: controller == null ? null : _openKeyDialog,
            icon: Icon(
              (controller?.hasApiKey ?? false)
                  ? Icons.key
                  : Icons.key_off_outlined,
            ),
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
    if (!controller.hasApiKey) return _buildKeySetup(context, theme);
    if (controller.isEmpty) return _buildWelcome(context, theme, controller);

    final messages = controller.messages;
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: messages.length,
      itemBuilder: (context, index) => _MessageBubble(message: messages[index]),
    );
  }

  Widget _buildKeySetup(BuildContext context, ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.key_off_outlined,
              size: 56,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'API key belum diatur',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Buat API key gratis di Google AI Studio, lalu tempel di sini '
              'agar asisten bisa menganalisis data toko.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _openKeyDialog,
              icon: const Icon(Icons.vpn_key),
              label: const Text('Atur API Key'),
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
          'hari ini. Model: ${controller.model}',
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
