/// Computer-style folder paths for the library and for sessions.
/// Paths use `/` and can be nested as deep as the user wants.
class FolderTree {
  static const separator = '/';

  static String normalize(String path) {
    return path
        .split(separator)
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(separator);
  }

  static String join(String parent, String name) {
    final base = normalize(parent);
    final child = name.trim();
    if (child.isEmpty) return base;
    if (base.isEmpty) return child;
    return '$base$separator$child';
  }

  static String parentOf(String path) {
    final normalized = normalize(path);
    final index = normalized.lastIndexOf(separator);
    if (index < 0) return '';
    return normalized.substring(0, index);
  }

  static String leafName(String path) {
    final normalized = normalize(path);
    final index = normalized.lastIndexOf(separator);
    return index < 0 ? normalized : normalized.substring(index + 1);
  }

  static bool isUnder(String path, String folder) {
    final normalized = normalize(path);
    final root = normalize(folder);
    if (root.isEmpty) return true;
    return normalized == root || normalized.startsWith('$root$separator');
  }

  /// Next folder name under [current], or null if [path] is not inside it.
  static String? childName(String path, String current) {
    final normalized = normalize(path);
    final root = normalize(current);
    if (normalized.isEmpty) return null;
    if (root.isEmpty) return normalized.split(separator).first;
    if (normalized == root) return null;
    if (!normalized.startsWith('$root$separator')) return null;
    return normalized.substring(root.length + 1).split(separator).first;
  }

  static String renamePrefix(String path, String oldFolder, String newFolder) {
    final normalized = normalize(path);
    final from = normalize(oldFolder);
    final to = normalize(newFolder);
    if (from.isEmpty || normalized == from) return to;
    if (normalized.startsWith('$from$separator')) {
      final rest = normalized.substring(from.length + 1);
      return to.isEmpty ? rest : '$to$separator$rest';
    }
    return normalized;
  }

  static List<String> childFolders(
    Iterable<String> allPaths,
    String current, {
    List<String>? preferredOrder,
  }) {
    final names = <String>{};
    for (final path in allPaths) {
      final child = childName(path, current);
      if (child != null) names.add(child);
    }
    final list = names.toList();
    if (preferredOrder == null || preferredOrder.isEmpty) {
      list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return list;
    }
    final rank = <String, int>{};
    for (var i = 0; i < preferredOrder.length; i++) {
      rank[preferredOrder[i].toLowerCase()] = i;
    }
    list.sort((a, b) {
      final left = rank[a.toLowerCase()];
      final right = rank[b.toLowerCase()];
      if (left != null && right != null) return left.compareTo(right);
      if (left != null) return -1;
      if (right != null) return 1;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return list;
  }

  static String displayPath(String path) {
    final normalized = normalize(path);
    return normalized.isEmpty ? 'Library' : normalized.replaceAll(separator, ' › ');
  }
}
