#!/usr/bin/env bash
set -euo pipefail

device_id=${1:?device id is required}
cohort=${2:-returning}
samples=${3:-3}
package_name=com.almarfa.tawheed
output_dir="build/cold-start/${cohort}"
markers_file="${output_dir}/markers.log"

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

  native_marker=$(adb -s "$device_id" logcat -d -v brief -s 'TawheedStartup:I' '*:S' \
    | grep 'COLD_START_INTERACTIVE' | tail -n 1 || true)
  if [[ -z "$native_marker" ]]; then
    echo "No native COLD_START_INTERACTIVE marker for sample $sample" >&2
    echo "The app did not reach a verified interactive surface." >&2
    exit 1
  fi
  expected_surface=welcome
  if [[ "$cohort" == returning ]]; then expected_surface=lectures; fi
  if [[ "$native_marker" != *"surface=${expected_surface}"* ]]; then
    echo "Expected $cohort startup to reach surface=$expected_surface, got:" >&2
    echo "$native_marker" >&2
    echo "Seed the returning-user state before measuring that cohort." >&2
    exit 1
  fi
  echo "$native_marker" | tee -a "$markers_file"
done

dart run tool/cold_start_report.dart < "$markers_file"
