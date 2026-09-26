import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/app_store.dart';
import '../models/chat_message.dart';
import '../services/gemini_service.dart';
import '../services/store_context.dart';

class ChatController extends ChangeNotifier {
  ChatController({required AppStore store, SharedPreferences? prefs})
    : _store = store,
      _prefs = prefs,
      _apiKey = _resolveKey(prefs);

  final AppStore _store;
  SharedPreferences? _prefs;
  final List<ChatMessage> _messages = [];

  static const String _kMessages = 'chatbot.messages';
  static const String _kApiKey = 'chatbot.api_key';

  static String _resolveKey(SharedPreferences? prefs) {
    final stored = prefs?.getString(_kApiKey)?.trim();
    if (stored != null && stored.isNotEmpty) return stored;
    return GeminiConfig.apiKey.trim();
  }

  String _apiKey;
  bool _isBusy = false;
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isBusy => _isBusy;
  bool get isEmpty => _messages.isEmpty;
  bool get hasApiKey => _apiKey.isNotEmpty;
  String get model => GeminiConfig.model;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    _apiKey = _resolveKey(_prefs);
    restore();
  }

  void restore() {
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
              .where((m) => !m.isError),
        );
      notifyListeners();
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

  void setApiKey(String value) {
    _apiKey = value.trim();
    if (_apiKey.isEmpty) {
      _prefs?.remove(_kApiKey);
    } else {
      _prefs?.setString(_kApiKey, _apiKey);
    }
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

    if (!hasApiKey) {
      _append(
        ChatMessage(
          role: ChatRole.assistant,
          text:
              'API key Gemini belum diatur. Tekan ikon kunci di pojok '
              'kanan atas untuk mengaturnya.',
          createdAt: DateTime.now(),
          isError: true,
        ),
      );
      notifyListeners();
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

    final service = GeminiService(apiKey: _apiKey);
    final buffer = StringBuffer();
    try {
      final context = StoreContext.build(_store);
      final stream = service.sendReply(
        systemInstruction: '${StoreContext.systemInstruction}\n\n$context',
        history: _messages.sublist(0, replyIndex),
      );
      await for (final delta in stream) {
        buffer.write(delta);
        _messages[replyIndex] = _messages[replyIndex].copyWith(
          text: buffer.toString(),
        );
        _notifyThrottled();
      }
      if (buffer.isEmpty) {
        _messages[replyIndex] = _messages[replyIndex].copyWith(
          text:
              'Gemini tidak mengembalikan jawaban. Coba ulangi pertanyaannya.',
        );
      }
    } on GeminiException catch (error) {
      _messages.removeRange(replyIndex, _messages.length);
      _append(
        ChatMessage(
          role: ChatRole.assistant,
          text: error.message,
          createdAt: DateTime.now(),
          isError: true,
        ),
      );
    } catch (_) {
      _messages.removeRange(replyIndex, _messages.length);
      _append(
        ChatMessage(
          role: ChatRole.assistant,
          text: 'Terjadi kesalahan tak terduga saat menghubungi Gemini.',
          createdAt: DateTime.now(),
          isError: true,
        ),
      );
    } finally {
      service.dispose();
      _isBusy = false;
      notifyListeners();
      _persist();
    }
  }

  void _append(ChatMessage message) {
    _messages.add(message);
  }

  void _notifyThrottled() {
    final now = DateTime.now();
    if (now.difference(_lastNotify).inMilliseconds < 50) return;
    _lastNotify = now;
    notifyListeners();
  }
}
