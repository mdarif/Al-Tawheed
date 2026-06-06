enum PlaybackSource {
  /// Playing audio streamed from the CDN.
  stream,

  /// Playing audio from a locally downloaded file.
  local,

  /// Load was blocked because device is offline and lecture is not downloaded.
  blocked,
}
