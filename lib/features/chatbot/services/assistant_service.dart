import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import 'assistant_config.dart';

class AssistantException implements Exception {
  const AssistantException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AssistantService {
  AssistantService({
    required this.proxyUrl,
    required this.model,
    this.appToken = '',
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String proxyUrl;
  final String model;
  final String appToken;
  final http.Client _client;

  static const Duration requestTimeout = Duration(seconds: 60);
  static const int maxHistoryMessages = 14;

  Uri get _endpoint {
    final base = AssistantConfig.normalizeBaseUrl(proxyUrl);
    return Uri.parse('$base/chat');
  }

  Map<String, dynamic> _buildPayload({
    required String systemInstruction,
    required List<ChatMessage> history,
  }) {
    final trimmed = history.length > maxHistoryMessages
        ? history.sublist(history.length - maxHistoryMessages)
        : history;

    final messages = trimmed
        .where((message) => !message.isError && message.text.trim().isNotEmpty)
        .map(
          (message) => <String, dynamic>{
            'role': message.role.apiValue,
            'text': message.text,
          },
        )
        .toList();

    return {
      'model': model,
      'systemInstruction': systemInstruction,
      'messages': messages,
    };
  }

  Stream<String> sendMessage({
    required String systemInstruction,
    required List<ChatMessage> history,
  }) async* {
    if (proxyUrl.trim().isEmpty) {
      throw const AssistantException(
        'URL proxy asisten belum diatur. Buka pengaturan asisten.',
      );
    }

    final request = http.Request('POST', _endpoint)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'text/event-stream'
      ..body = jsonEncode(
        _buildPayload(systemInstruction: systemInstruction, history: history),
      );
    if (appToken.trim().isNotEmpty) {
      request.headers['X-Assistant-Token'] = appToken.trim();
    }

    late final http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(requestTimeout);
    } on SocketException {
      throw const AssistantException(
        'Tidak ada koneksi internet. Periksa jaringan lalu coba lagi.',
      );
    } on http.ClientException {
      throw const AssistantException('Gagal menghubungi server asisten.');
    } on TimeoutException {
      throw const AssistantException('Permintaan terlalu lama. Coba lagi.');
    } on FormatException {
      throw const AssistantException('URL proxy tidak valid.');
    }

    if (response.statusCode != 200) {
      throw AssistantException(await _describeError(response));
    }

    var received = false;
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
        if (text is String && text.isNotEmpty) {
          received = true;
          yield text;
        }
      }
    }

    if (!received) {
      throw const AssistantException(
        'Asisten tidak mengembalikan jawaban. Coba ulangi pertanyaannya.',
      );
    }
  }

  Future<String> _describeError(http.StreamedResponse response) async {
    final body = await response.stream.transform(utf8.decoder).join();
    final detail = _extractMessage(body);

    return switch (response.statusCode) {
      401 || 403 => detail ?? 'Token aplikasi ditolak oleh server asisten.',
      429 =>
        detail ?? 'Batas permintaan tercapai. Tunggu sebentar lalu coba lagi.',
      >= 500 =>
        detail ??
            'Server asisten sedang bermasalah. Coba lagi beberapa saat lagi.',
      _ =>
        detail ??
            'Server asisten gagal merespons (HTTP ${response.statusCode}).',
    };
  }

  String? _extractMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final message = decoded['error'];
        if (message is String && message.isNotEmpty) return message;
        final error = decoded['error'];
        if (error is Map) {
          final nested = error['message'];
          if (nested is String && nested.isNotEmpty) return nested;
        }
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  void dispose() => _client.close();
}
