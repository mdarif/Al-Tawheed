/// Thrown when remote content has no local cache and a network fetch failed.
class NoCachedContentException implements Exception {
  const NoCachedContentException(this.cacheKey);
  final String cacheKey;

  @override
  String toString() =>
      'NoCachedContentException: no cached content for "$cacheKey"';
}
