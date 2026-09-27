/// One chat message as sent by the server.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.name,
    this.senderId,
    required this.text,
    required this.sentAt,
  });

  final String id;
  final String name;

  /// Stable per-device id of the sender; null on messages sent before the
  /// server recorded one.
  final String? senderId;
  final String text;

  /// Always stored in UTC; convert with [DateTime.toLocal] for display.
  final DateTime sentAt;

  /// Parses a server message map, returning null when it is malformed.
  static ChatMessage? tryParse(dynamic json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    final text = json['text'];
    final sentAtRaw = json['sent_at'];
    final senderId = json['sender_id'];
    if (id == null || name is! String || text is! String) return null;
    DateTime? sentAt;
    if (sentAtRaw is String) sentAt = DateTime.tryParse(sentAtRaw);
    return ChatMessage(
      id: id.toString(),
      name: name,
      senderId: senderId is String ? senderId : null,
      text: text,
      sentAt: (sentAt ?? DateTime.now()).toUtc(),
    );
  }

  ChatMessage withName(String newName) => ChatMessage(
    id: id,
    name: newName,
    senderId: senderId,
    text: text,
    sentAt: sentAt,
  );
}
