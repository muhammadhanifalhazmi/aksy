import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/app_store.dart';
import '../models/chat_message.dart';
import '../services/assistant_config.dart';
import '../services/assistant_service.dart';
import '../services/store_context.dart';

class ChatController extends ChangeNotifier {
  ChatController({required AppStore store, SharedPreferences? prefs})
    : _store = store,
      _prefs = prefs;

  final AppStore _store;
  SharedPreferences? _prefs;
  final List<ChatMessage> _messages = [];

  static const String _kMessages = 'chatbot.messages';

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isBusy => _isBusy;
  bool get isEmpty => _messages.isEmpty;

  String get proxyUrl => _proxyUrl;
  String get appToken => _appToken;
  String get model => _model;
  bool get isConfigured => _proxyUrl.trim().isNotEmpty;

  String _proxyUrl = AssistantConfig.proxyUrl;
  String _appToken = AssistantConfig.appToken;
  String _model = AssistantConfig.model;
  bool _isBusy = false;
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    _readSettings();
    _restore();
    notifyListeners();
  }

  void _readSettings() {
    final prefs = _prefs;
    if (prefs == null) return;
    _proxyUrl = AssistantConfig.proxyUrlOf(prefs);
    _appToken = AssistantConfig.appTokenOf(prefs);
    _model = AssistantConfig.modelOf(prefs);
  }

  void _restore() {
    final raw = _prefs?.getString(_kMessages);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _messages
        ..clear()
        ..addAll(
          decoded
              .whereType<Map<String, dynamic>>()
              .map(ChatMessage.fromJson)
              .where((message) => !message.isError),
        );
    } on FormatException {
      return;
    }
  }

  void _persist() {
    _prefs?.setString(
      _kMessages,
      jsonEncode(_messages.map((m) => m.toJson()).toList()),
    );
  }

  void saveSettings({
    required String proxyUrl,
    required String appToken,
    required String model,
  }) {
    final prefs = _prefs;
    if (prefs == null) return;

    AssistantConfig.saveSettings(
      prefs,
      proxyUrl: proxyUrl,
      appToken: appToken,
      model: model,
    );
    _readSettings();
    notifyListeners();
  }

  void clear() {
    _messages.clear();
    _persist();
    notifyListeners();
  }

  Future<void> send(String prompt) async {
    final text = prompt.trim();
    if (text.isEmpty || _isBusy) return;

    if (!isConfigured) {
      _appendError(
        'URL proxy asisten belum diatur. Buka pengaturan asisten di pojok '
        'kanan atas.',
      );
      return;
    }

    _messages.add(
      ChatMessage(role: ChatRole.user, text: text, createdAt: DateTime.now()),
    );
    final replyIndex = _messages.length;
    _messages.add(
      ChatMessage(
        role: ChatRole.assistant,
        text: '',
        createdAt: DateTime.now(),
      ),
    );
    _isBusy = true;
    notifyListeners();

    final service = AssistantService(
      proxyUrl: _proxyUrl,
      appToken: _appToken,
      model: _model,
    );
    final buffer = StringBuffer();
    try {
      final stream = service.sendMessage(
        systemInstruction:
            '${StoreContext.systemInstruction}\n\n${StoreContext.build(_store)}',
        history: _messages.sublist(0, replyIndex),
      );
      await for (final delta in stream) {
        buffer.write(delta);
        _messages[replyIndex] = _messages[replyIndex].copyWith(
          text: buffer.toString(),
        );
        _notifyThrottled();
      }
    } on AssistantException catch (error) {
      _replaceWithError(replyIndex, error.message);
    } catch (_) {
      _replaceWithError(
        replyIndex,
        'Terjadi kesalahan tak terduga saat menghubungi asisten.',
      );
    } finally {
      service.dispose();
      _isBusy = false;
      notifyListeners();
      _persist();
    }
  }

  void _appendError(String text) {
    _messages.add(
      ChatMessage(
        role: ChatRole.assistant,
        text: text,
        createdAt: DateTime.now(),
        isError: true,
      ),
    );
    notifyListeners();
  }

  void _replaceWithError(int index, String text) {
    _messages.removeRange(index, _messages.length);
    _appendError(text);
  }

  void _notifyThrottled() {
    final now = DateTime.now();
    if (now.difference(_lastNotify).inMilliseconds < 50) return;
    _lastNotify = now;
    notifyListeners();
  }
}
