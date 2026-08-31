#!/usr/bin/env bash
set -euo pipefail

device_id=${1:?device id is required}
cohort=${2:-returning}
samples=${3:-3}
package_name=com.almarfa.tawheed
output_dir="build/cold-start/${cohort}"
markers_file="${output_dir}/markers.log"
timeout_seconds=${COLD_START_TIMEOUT_SECONDS:-180}
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
if ! [[ "$timeout_seconds" =~ ^[1-9][0-9]*$ ]]; then
  echo "COLD_START_TIMEOUT_SECONDS must be a positive integer" >&2
  exit 2
fi

mkdir -p "$output_dir"
: > "$markers_file"

if ! android_api=$(adb -s "$device_id" shell getprop ro.build.version.sdk); then
  echo "Unable to read Android API level from device $device_id" >&2
  exit 1
fi
android_api=$(printf '%s' "$android_api" | tr -d '[:space:]')
if ! [[ "$android_api" =~ ^[0-9]+$ ]]; then
  echo "Invalid Android API level from device $device_id: $android_api" >&2
  exit 1
fi

# flutter drive can leave a Dart VM/adb child behind when it is interrupted.
# Walk the local process tree so a timed-out sample cannot contaminate the next
# launch. pgrep -P is available in the macOS and common Linux toolchains.
terminate_process_tree() {
  local root_pid="$1"
  local signal="$2"
  local child_pids
  local child_pid
  if child_pids=$(pgrep -P "$root_pid" 2>/dev/null); then
    while IFS= read -r child_pid; do
      if [[ -n "$child_pid" ]]; then
        terminate_process_tree "$child_pid" "$signal"
      fi
    done <<< "$child_pids"
  fi
  if kill "-$signal" "$root_pid" 2>/dev/null; then :; fi
}

if ! package_path=$(adb -s "$device_id" shell pm path "$package_name"); then
  echo "Unable to query $package_name on device $device_id" >&2
  exit 1
fi
if [[ -z "$(printf '%s' "$package_path" | tr -d '[:space:]')" ]]; then
  echo "Installing the profile APK before the first cold-start sample..."
  flutter build apk --profile
  profile_apk=build/app/outputs/flutter-apk/app-profile.apk
  if [[ ! -f "$profile_apk" ]]; then
    echo "Profile APK was not produced at $profile_apk" >&2
    exit 1
  fi
  if ! adb -s "$device_id" install -r "$profile_apk" >/dev/null; then
    echo "Unable to install the profile APK on $device_id" >&2
    exit 1
  fi
fi

grant_notifications() {
  # POST_NOTIFICATIONS was introduced in API 33. On older APIs there is no
  # runtime permission to grant; on API 33+ any grant error is actionable.
  if (( android_api < 33 )); then return; fi
  if ! adb -s "$device_id" shell pm grant "$package_name" \
    android.permission.POST_NOTIFICATIONS >/dev/null; then
    echo "Unable to grant POST_NOTIFICATIONS on API $android_api" >&2
    exit 1
  fi
}

for sample in $(seq 1 "$samples"); do
  if [[ "$cohort" == fresh-install ]]; then
    # A fresh-install cohort means no persisted prefs/cache for each sample,
    # so every number is comparable and cannot accidentally become a returning
    # user measurement after sample one.
    # The profile APK is installed before the loop, so pm clear must succeed
    # on every fresh-install sample.
    if ! adb -s "$device_id" shell pm clear "$package_name" >/dev/null; then
      echo "Unable to clear $package_name before fresh sample $sample" >&2
      exit 1
    fi
  else
    adb -s "$device_id" shell am force-stop "$package_name"
  fi
  # Grant after every clear and immediately before the measured launch. This
  # keeps the notification permission dialog out of the startup measurement.
  grant_notifications
  adb -s "$device_id" logcat -c

  log_file="${output_dir}/sample-${sample}.log"
  flutter drive \
    --driver=test_driver/perf_driver.dart \
    --target=integration_test/performance_test.dart \
    --profile \
    --dart-define=COLD_START_ONLY=true \
    --dart-define=COLD_START_COHORT="$cohort" \
    -d "$device_id" > "$log_file" 2>&1 &
  drive_pid=$!
  elapsed_seconds=0
  timed_out=false
  while kill -0 "$drive_pid" 2>/dev/null; do
    if (( elapsed_seconds >= timeout_seconds )); then
      timed_out=true
      terminate_process_tree "$drive_pid" TERM
      sleep 1
      terminate_process_tree "$drive_pid" KILL
      if wait "$drive_pid"; then :; fi
      break
    fi
    sleep 1
    elapsed_seconds=$((elapsed_seconds + 1))
  done
  if [[ "$timed_out" == true ]]; then
    cat "$log_file"
    echo "flutter drive timed out after ${timeout_seconds}s for $cohort sample $sample" >&2
    exit 124
  fi
  if wait "$drive_pid"; then
    drive_status=0
  else
    drive_status=$?
  fi
  cat "$log_file"
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
