import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/chat_message.dart';

class GeminiException implements Exception {
  const GeminiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GeminiConfig {
  const GeminiConfig._();

  static const String apiKey = String.fromEnvironment('GEMINI_API_KEY');

  static const String model = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-3.5-flash',
  );
}

class GeminiService {
  GeminiService({
    required this.apiKey,
    this.model = GeminiConfig.model,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const String _host = 'generativelanguage.googleapis.com';
  static const String _path = '/v1beta/interactions';

  final String apiKey;
  final String model;
  final http.Client _client;

  static const int maxHistoryMessages = 14;
  static const Duration requestTimeout = Duration(seconds: 60);

  List<Map<String, dynamic>> _buildInput(List<ChatMessage> history) {
    final trimmed = history.length > maxHistoryMessages
        ? history.sublist(history.length - maxHistoryMessages)
        : history;
    return trimmed
        .where((message) => !message.isError && message.text.trim().isNotEmpty)
        .map(
          (message) => <String, dynamic>{
            'role': message.role.apiValue,
            'content': message.text,
          },
        )
        .toList();
  }

  Stream<String> sendReply({
    required String systemInstruction,
    required List<ChatMessage> history,
  }) async* {
    if (apiKey.trim().isEmpty) {
      throw const GeminiException(
        'API key Gemini belum diatur. Buka pengaturan asisten di menu aplikasi.',
      );
    }

    final uri = Uri.https(_host, _path, const {'alt': 'sse'});
    final request = http.Request('POST', uri)
      ..headers['x-goog-api-key'] = apiKey
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'text/event-stream'
      ..body = jsonEncode({
        'model': model,
        'system_instruction': systemInstruction,
        'input': _buildInput(history),
        'stream': true,
      });

    late final http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(requestTimeout);
    } on SocketException {
      throw const GeminiException(
        'Tidak ada koneksi internet. Periksa jaringan lalu coba lagi.',
      );
    } on http.ClientException {
      throw const GeminiException('Gagal menghubungi server Gemini.');
    } on TimeoutException {
      throw const GeminiException('Permintaan ke Gemini terlalu lama.');
    }

    if (response.statusCode != 200) {
      throw GeminiException(await _describeError(response));
    }

    await for (final line
        in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (!line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload.isEmpty || payload == '[DONE]') continue;

      final dynamic decoded;
      try {
        decoded = jsonDecode(payload);
      } on FormatException {
        continue;
      }
      if (decoded is! Map) continue;

      final eventType = decoded['event_type'];
      if (eventType != null && eventType != 'step.delta') continue;

      final delta = decoded['delta'];
      if (delta is Map && delta['type'] == 'text') {
        final text = delta['text'];
        if (text is String && text.isNotEmpty) yield text;
      }
    }
  }

  Future<String> _describeError(http.StreamedResponse response) async {
    final body = await response.stream.transform(utf8.decoder).join();
    final detail = _extractErrorMessage(body);

    return switch (response.statusCode) {
      400 || 401 || 403 =>
        'API key tidak valid atau belum punya akses. Periksa kembali API key di pengaturan asisten.',
      404 =>
        'Model "$model" tidak ditemukan. Ganti model di pengaturan asisten.',
      429 => 'Batas kuota Gemini tercapai. Tunggu sebentar lalu coba lagi.',
      >= 500 =>
        'Server Gemini sedang bermasalah. Coba lagi beberapa saat lagi.',
      _ =>
        detail == null
            ? 'Gemini gagal merespons (HTTP ${response.statusCode}).'
            : 'Gemini gagal merespons: $detail',
    };
  }

  String? _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map) {
          final message = error['message'];
          if (message is String && message.isNotEmpty) return message;
        }
        final message = decoded['message'];
        if (message is String && message.isNotEmpty) return message;
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  void dispose() => _client.close();
}
