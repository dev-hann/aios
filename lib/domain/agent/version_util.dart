int compareVersions(String a, String b) {
  final partsA = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  final partsB = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();

  for (var i = 0; i < partsA.length || i < partsB.length; i++) {
    final valA = i < partsA.length ? partsA[i] : 0;
    final valB = i < partsB.length ? partsB[i] : 0;
    if (valA != valB) {
      return valA.compareTo(valB);
    }
  }
  return 0;
}

String stripVersionPrefix(String version) {
  if (version.startsWith('v')) {
    return version.substring(1);
  }
  return version;
}
