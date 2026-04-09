// Fonctions utilitaires
String anonName(String id, {String? alias}) {
  if (alias != null && alias.trim().isNotEmpty) return alias.trim();
  return '👤 Anonyme';
}

String fmtDate(dynamic d) {
  if (d == null) return '';
  final dt = DateTime.tryParse(d.toString());
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return "à l'instant";
  if (diff.inMinutes < 60) return '${diff.inMinutes} min';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}j';
  return '${(diff.inDays / 7).floor()}sem';
}

Map<String, dynamic> deepCastComment(dynamic raw) {
  final m = Map<String, dynamic>.from(raw as Map);
  m['replies'] = (m['replies'] as List? ?? []).map((r) => deepCastComment(r)).toList();
  return m;
}