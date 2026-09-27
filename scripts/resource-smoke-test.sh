#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DURATION_SECONDS=300
INTERVAL_SECONDS=1
PROCESS_NAME="Widgify"
OUTPUT_DIR="$ROOT_DIR/reports"
LAUNCH_APP=false
MAX_AVG_CPU="2.0"
MAX_RSS_MB="150"

usage() {
  cat <<'USAGE'
Usage: ./scripts/resource-smoke-test.sh [options]

Samples Widgify CPU and memory usage and writes a small report to reports/.
Run it while Spotify is playing and the Widgify widget is on the desktop.

Options:
  --duration SECONDS       Test duration. Default: 300.
  --interval SECONDS       Sample interval. Default: 1.
  --launch                 Open /Applications/Widgify.app before sampling.
  --max-avg-cpu PERCENT    Fail if average CPU is above this. Default: 2.0.
  --max-rss-mb MB          Fail if max resident memory is above this. Default: 150.
  -h, --help               Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --duration)
      DURATION_SECONDS="${2:-}"
      shift 2
      ;;
    --interval)
      INTERVAL_SECONDS="${2:-}"
      shift 2
      ;;
    --launch)
      LAUNCH_APP=true
      shift
      ;;
    --max-avg-cpu)
      MAX_AVG_CPU="${2:-}"
      shift 2
      ;;
    --max-rss-mb)
      MAX_RSS_MB="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if ! [[ "$DURATION_SECONDS" =~ ^[0-9]+$ && "$INTERVAL_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "Duration and interval must be whole seconds." >&2
  exit 2
fi

mkdir -p "$OUTPUT_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
CSV_PATH="$OUTPUT_DIR/resource-smoke-$STAMP.csv"
REPORT_PATH="$OUTPUT_DIR/resource-smoke-$STAMP.txt"

if [[ "$LAUNCH_APP" == true ]]; then
  open "/Applications/Widgify.app"
  sleep 3
fi

echo "timestamp,pid,cpu_percent,rss_kb" > "$CSV_PATH"

END_TIME=$((SECONDS + DURATION_SECONDS))
while (( SECONDS < END_TIME )); do
  PIDS=()
  while IFS= read -r PID; do
    [[ -n "$PID" ]] && PIDS+=("$PID")
  done < <(pgrep -x "$PROCESS_NAME" 2>/dev/null || true)
  if [[ "${#PIDS[@]}" -eq 0 ]]; then
    echo "$(date -u +%FT%TZ),,0,0" >> "$CSV_PATH"
  else
    for PID in "${PIDS[@]}"; do
      ps -p "$PID" -o pid=,%cpu=,rss= | awk -v now="$(date -u +%FT%TZ)" '{ print now "," $1 "," $2 "," $3 }' >> "$CSV_PATH"
    done
  fi
  sleep "$INTERVAL_SECONDS"
done

awk \
  -F',' \
  -v max_avg_cpu="$MAX_AVG_CPU" \
  -v max_rss_mb="$MAX_RSS_MB" \
  -v duration="$DURATION_SECONDS" \
  -v interval="$INTERVAL_SECONDS" \
  -v csv="$CSV_PATH" \
  '
    NR > 1 {
      samples += 1
      cpu += $3
      if ($4 > max_rss_kb) {
        max_rss_kb = $4
      }
    }
    END {
      avg_cpu = samples ? cpu / samples : 0
      max_rss = max_rss_kb / 1024
      cpu_ok = avg_cpu <= max_avg_cpu
      rss_ok = max_rss <= max_rss_mb

      print "Widgify resource smoke test"
      print ""
      print "Duration: " duration "s"
      print "Interval: " interval "s"
      print "Samples: " samples
      print "Average CPU: " sprintf("%.2f%%", avg_cpu)
      print "Max memory: " sprintf("%.1f MB", max_rss)
      print "CSV: " csv
      print ""
      print "Thresholds:"
      print "- Average CPU <= " max_avg_cpu "%"
      print "- Max memory <= " max_rss_mb " MB"
      print ""
      if (cpu_ok && rss_ok) {
        print "Result: PASS"
        exit 0
      }
      print "Result: FAIL"
      exit 1
    }
  ' "$CSV_PATH" | tee "$REPORT_PATH"
