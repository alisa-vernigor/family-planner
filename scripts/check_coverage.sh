#!/usr/bin/env bash
set -euo pipefail

readonly MIN_COVERAGE="${1:-80}"
readonly REPORT_DIR="coverage/report"
readonly LCOV_FILE="coverage/lcov.info"
readonly LCOV_FILTERED="coverage/lcov.filtered.info"

echo "━━━ Running tests with coverage ━━━"
flutter test --coverage --no-pub

# Исключаем сгенерированный код (*.g.dart) из расчёта покрытия:
# он порождается build_runner, и покрывать его тестами бессмысленно.
lcov --remove "$LCOV_FILE" '*.g.dart' -o "$LCOV_FILTERED" --quiet

echo ""
echo "━━━ Generating HTML report ━━━"
mkdir -p "$REPORT_DIR"

genhtml "$LCOV_FILTERED" \
  -o "$REPORT_DIR" \
  --no-function-coverage \
  --title "Family Planner" \
  --quiet || true  # genhtml warns on no-ops, ignore

echo ""
echo "━━━ Coverage summary ━━━"
lcov --summary "$LCOV_FILTERED" 2>&1 | grep -E 'lines\.*:' | sed 's/^/  /'

# Extract the line coverage percentage (e.g. "64.4%" from "lines.......: 64.4% (541 of 840 lines)")
COVERAGE_PCT=$(lcov --summary "$LCOV_FILTERED" 2>&1 | grep -E 'lines\.*:' | awk '{print $2}' | tr -d '%')

echo ""
echo "━━━ Threshold check ━━━"
echo "  Min required: ${MIN_COVERAGE}%"
echo "  Actual:       ${COVERAGE_PCT}%"

if awk "BEGIN {exit !($COVERAGE_PCT < $MIN_COVERAGE)}"; then
  echo ""
  echo "❌ FAILED: Coverage ${COVERAGE_PCT}% is below ${MIN_COVERAGE}%"
  echo "   Open ${REPORT_DIR}/index.html to see whats uncovered."
  exit 1
fi

echo "✅ PASSED: Coverage ${COVERAGE_PCT}% meets ${MIN_COVERAGE}% threshold"
echo ""
echo "📊 HTML report: ${REPORT_DIR}/index.html"
