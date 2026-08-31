/// Decides whether a measured frame average passes the configured regression
/// ceiling. Smoke runs still collect and require timings, but can opt out of
/// device-sensitive threshold failures.
abstract final class PerformanceThresholds {
  static bool passes({
    required double averageMillis,
    required double ceilingMillis,
    required bool enforce,
  }) {
    if (!enforce) return true;
    return averageMillis < ceilingMillis;
  }
}
