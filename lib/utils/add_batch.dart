







library;


class AddBatchFailure {
  const AddBatchFailure(this.label, this.reason);

  
  final String label;

  
  final String reason;
}





class AddBatchResult {
  
  final List<String> succeeded = <String>[];

  
  final List<AddBatchFailure> failed = <AddBatchFailure>[];

  
  int get total => succeeded.length + failed.length;

  
  bool get allOk => failed.isEmpty;

  
  bool get isEmpty => total == 0;

  
  void ok(String label) => succeeded.add(label);

  
  void fail(String label, String reason) =>
      failed.add(AddBatchFailure(label, reason));
}







List<String> parseUrlLines(String text) {
  final List<String> out = <String>[];
  final Set<String> seen = <String>{};
  for (final String raw in text.split('\n')) {
    final String u = raw.trim();
    if (u.isEmpty) continue;
    if (!seen.add(u)) continue;
    out.add(u);
  }
  return out;
}






String shortLabel(String s, {int max = 44}) {
  if (s.length <= max) return s;
  if (max <= 1) return '…';
  return '${s.substring(0, max - 1)}…';
}
