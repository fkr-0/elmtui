#!/usr/bin/env bash
set -euo pipefail

# Run coverage from a cold SBCL process, retain diagnostics under the project,
# and fail the workflow on compiler warning markers or a missing HTML report.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ELMTUI_TEST_OUTPUT_DIR:-${ROOT_DIR}/test-output}"
mkdir -p "${OUT_DIR}"

STAMP="${ELMTUI_TEST_RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
STDOUT_LOG="${OUT_DIR}/coverage-${STAMP}.stdout.log"
STDERR_LOG="${OUT_DIR}/coverage-${STAMP}.stderr.log"
REPORT="${ROOT_DIR}/coverage/cover-index.html"
# A failed run must not leave success-looking generated evidence behind.
rm -f "${ROOT_DIR}/coverage/coverage-summary.csv" "${ROOT_DIR}/coverage/coverage-summary.txt" "${ROOT_DIR}/coverage/coverage-summary.json"

cd "${ROOT_DIR}"

# Reject results from a source tree edited while SBCL was measuring it.
BEFORE_HASHES="$(mktemp "${OUT_DIR}/coverage-sources-before.XXXXXX")"
AFTER_HASHES="$(mktemp "${OUT_DIR}/coverage-sources-after.XXXXXX")"
FASL_DIR="$(mktemp -d "${OUT_DIR}/coverage-fasl.XXXXXX")"
trap 'rm -f "${BEFORE_HASHES}" "${AFTER_HASHES}"; rm -rf -- "${FASL_DIR}"' EXIT
find src -type f -name '*.lisp' -print0 | sort -z | xargs -0 -r sha256sum > "${BEFORE_HASHES}"

set +e
ELMTUI_COVERAGE_FASL_DIR="${FASL_DIR}/" \
  clpm bundle exec --with-client sbcl -- --noinform --non-interactive --load scripts/coverage.lisp \
  >"${STDOUT_LOG}" 2>"${STDERR_LOG}"
rc=$?
set -e

if [ "${rc}" -ne 0 ]; then
  echo "coverage: analysis failed with exit code ${rc}" >&2
  echo "coverage: stdout log: ${STDOUT_LOG}" >&2
  echo "coverage: stderr log: ${STDERR_LOG}" >&2
  exit "${rc}"
fi

warning_pattern='STYLE-WARNING|caught WARNING|caught ERROR|undefined variable|undefined function|compilation had style-warnings|compilation unit finished.*warning'
if grep -Ei "${warning_pattern}" "${STDERR_LOG}" "${STDOUT_LOG}" >/dev/null; then
  echo "coverage: unexpected compiler warning markers" >&2
  grep -niE "${warning_pattern}" "${STDERR_LOG}" "${STDOUT_LOG}" >&2
  echo "coverage: stdout log: ${STDOUT_LOG}" >&2
  exit 1
fi

if [ ! -s "${REPORT}" ]; then
  echo "coverage: expected report was not generated: ${REPORT}" >&2
  echo "coverage: stdout log: ${STDOUT_LOG}" >&2
  echo "coverage: stderr log: ${STDERR_LOG}" >&2
  exit 1
fi

find src -type f -name '*.lisp' -print0 | sort -z | xargs -0 -r sha256sum > "${AFTER_HASHES}"
if ! cmp -s "${BEFORE_HASHES}" "${AFTER_HASHES}"; then
  echo "coverage: primary sources changed during measurement" >&2
  exit 1
fi
python3 scripts/coverage-gate.py

echo "coverage: ok"
echo "coverage: report: ${REPORT}"
echo "coverage: stdout log: ${STDOUT_LOG}"
echo "coverage: stderr log: ${STDERR_LOG}"
