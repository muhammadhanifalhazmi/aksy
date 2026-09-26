enum ChatRole { user, assistant }

extension ChatRoleLabel on ChatRole {
  String get label {
    switch (this) {
      case ChatRole.user:
        return 'Kamu';
      case ChatRole.assistant:
        return 'Asisten';
    }
  }

  String get apiValue {
    switch (this) {
      case ChatRole.user:
        return 'user';
      case ChatRole.assistant:
        return 'model';
    }
  }
}

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.text,
    required this.createdAt,
    this.isError = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final roleValue = json['role'] as String? ?? ChatRole.user.name;
    return ChatMessage(
      role: ChatRole.values.asNameMap()[roleValue] ?? ChatRole.user,
      text: json['text'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      isError: json['isError'] as bool? ?? false,
    );
  }

  final ChatRole role;
  final String text;
  final DateTime createdAt;
  final bool isError;

  bool get isUser => role == ChatRole.user;

  Map<String, dynamic> toJson() {
    return {
      'role': role.name,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'isError': isError,
    };
  }

  ChatMessage copyWith({String? text}) {
    return ChatMessage(
      role: role,
      text: text ?? this.text,
      createdAt: createdAt,
      isError: isError,
    );
  }
}
