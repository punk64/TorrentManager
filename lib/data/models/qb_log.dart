


class QbLog {
  final int id;
  final String message;
  final int timestamp;

  
  final int type;

  const QbLog({
    required this.id,
    required this.message,
    required this.timestamp,
    required this.type,
  });

  factory QbLog.fromJson(Map<String, dynamic> json) {
    return QbLog(
      id: (json['id'] as int?) ?? 0,
      message: (json['message'] as String?) ?? '',
      timestamp: (json['timestamp'] as int?) ?? 0,
      type: (json['type'] as int?) ?? 0,
    );
  }
}
