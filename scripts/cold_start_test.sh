#!/usr/bin/env bash
set -euo pipefail

device_id=${1:?device id is required}
cohort=${2:-returning}
samples=${3:-3}
package_name=com.almarfa.tawheed
output_dir="build/cold-start/${cohort}"
markers_file="${output_dir}/markers.log"
expected_surface=welcome
if [[ "$cohort" == returning ]]; then expected_surface=lectures; fi

case "$cohort" in
  returning|fresh-install) ;;
  *) echo "COHORT must be returning or fresh-install" >&2; exit 2 ;;
esac
if ! [[ "$samples" =~ ^[1-9][0-9]*$ ]]; then
  echo "SAMPLES must be a positive integer" >&2
  exit 2
fi

mkdir -p "$output_dir"
: > "$markers_file"

for sample in $(seq 1 "$samples"); do
  if [[ "$cohort" == fresh-install ]]; then
    # A fresh-install cohort means no persisted prefs/cache for each sample,
    # so every number is comparable and cannot accidentally become a returning
    # user measurement after sample one.
    # The first run may be before the profile APK has been installed; an
    # absent package is already in the desired cleared state. Once installed,
    # pm clear must succeed on every sample.
    if adb -s "$device_id" shell pm path "$package_name" >/dev/null 2>&1; then
      adb -s "$device_id" shell pm clear "$package_name" >/dev/null
    fi
  else
    adb -s "$device_id" shell am force-stop "$package_name"
  fi
  adb -s "$device_id" logcat -c

  log_file="${output_dir}/sample-${sample}.log"
  set +e
  flutter drive \
    --driver=test_driver/perf_driver.dart \
    --target=integration_test/performance_test.dart \
    --profile \
    --dart-define=COLD_START_ONLY=true \
    --dart-define=COLD_START_COHORT="$cohort" \
    -d "$device_id" 2>&1 | tee "$log_file"
  drive_status=${PIPESTATUS[0]}
  set -e
  if (( drive_status != 0 )); then
    echo "flutter drive failed for $cohort sample $sample" >&2
    exit "$drive_status"
  fi

  logcat_file="${output_dir}/sample-${sample}-logcat.log"
  if ! adb -s "$device_id" logcat -d -v brief -s 'TawheedStartup:I' '*:S' \
    > "$logcat_file"; then
    echo "adb logcat failed for $cohort sample $sample" >&2
    exit 1
  fi
  # Android logcat emits section headers (for example,
  # "--------- beginning of main") even with tag filters. Only marker records
  # may reach the strict parser; malformed marker records remain visible to it.
  if ! native_log=$(awk '/COLD_START_INTERACTIVE/ { print }' "$logcat_file"); then
    echo "Failed to filter adb logcat for $cohort sample $sample" >&2
    exit 1
  fi
  if [[ -z "$native_log" ]]; then
    echo "No native COLD_START_INTERACTIVE marker for sample $sample" >&2
    echo "The app did not reach a verified interactive surface." >&2
    exit 1
  fi
  # The report parser rejects any malformed, duplicate, wrong-cohort, or
  # wrong-surface sample, and enforces the exact requested count.
  printf '%s\n' "$native_log" | tee -a "$markers_file"
done

dart run tool/cold_start_report.dart \
  --cohort="$cohort" \
  --surface="$expected_surface" \
  --samples="$samples" < "$markers_file"
