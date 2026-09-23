import '../data/models/server_data.dart';

class LogScope {
  const LogScope(this.id, this.name);

  final String id;

  final String name;

  @override
  bool operator ==(Object other) =>
      other is LogScope && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'LogScope($id, $name)';
}

extension ServerDataLogScope on ServerData {
  LogScope get logScope => LogScope(id, name);
}

const String kLogServerIdKey = 'logServerId';

const String kLogServerNameKey = 'logServerName';
