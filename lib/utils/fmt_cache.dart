import 'dart:collection';

class FmtCache<V> {
  FmtCache(this.limit);

  final int limit;

  final LinkedHashMap<Object, V> _map = LinkedHashMap<Object, V>();

  V? get(Object key) => _map[key];

  void put(Object key, V value) {
    if (_map.length >= limit && !_map.containsKey(key)) {
      _map.remove(_map.keys.first);
    }
    _map[key] = value;
  }

  int get length => _map.length;

  void clear() => _map.clear();
}
