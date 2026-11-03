#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

# Fail-fast evidence is retained even when a release-blocking gate aborts.
receipt_dir="$(mktemp -d /tmp/elmtui-release-check.XXXXXXXX)"
if [[ -v ELMTUI_RELEASE_RECEIPT_DIR && -n "$ELMTUI_RELEASE_RECEIPT_DIR" ]]; then
  receipt_dir="$ELMTUI_RELEASE_RECEIPT_DIR"
fi
mkdir -p "$receipt_dir"
receipt_dir="$(realpath "$receipt_dir")"
allow_dirty=0
if [[ -v ELMTUI_RELEASE_ALLOW_DIRTY ]]; then allow_dirty="$ELMTUI_RELEASE_ALLOW_DIRTY"; fi
printf 'gate\texit\tseconds\tlog\n' > "$receipt_dir/matrix.tsv"
{
  git rev-parse HEAD | sed 's/^/root /'
  for lib in cl-events cl-inputs cl-state cl-styles; do
    printf '%s %s\n' "$lib" "$(git rev-parse "HEAD:$lib")"
  done
} > "$receipt_dir/frozen-head-vector.txt"
on_exit() {
  code="$1"
  result=NOT_QUALIFIED
  if [[ "$code" == 0 && "$allow_dirty" != 1 ]]; then result=QUALIFIED; fi
  printf 'exit=%s\nresult=%s\nreceipt=%s\n' "$code" "$result" "$receipt_dir" > "$receipt_dir/result.txt"
  echo "release-check: exit=$code result=$result receipts=$receipt_dir" >&2
}
trap 'on_exit "$?"' EXIT
run_gate() {
  local name="$1" begin end rc
  shift
  begin="$(date +%s)"
  if "$@" > "$receipt_dir/$name.log" 2>&1; then rc=0; else rc=$?; fi
  end="$(date +%s)"
  printf '%s\t%s\t%s\t%s\n' "$name" "$rc" "$((end-begin))" "$receipt_dir/$name.log" >> "$receipt_dir/matrix.tsv"
  echo "release-check: $name exit=$rc log=$receipt_dir/$name.log"
  if [[ "$rc" != 0 ]]; then tail -60 "$receipt_dir/$name.log" >&2; fi
  return "$rc"
}

preflight() {
printf '==> checking repository topology and release manifest\n'

# Standalone libraries are pinned Git submodules, not ordinary tracked files.
# A plain git archive omits gitlinks: the release distribution must bundle them.
test -f .gitmodules || { echo 'release-check: missing .gitmodules' >&2; return 1; }
for library in cl-events cl-inputs cl-state cl-styles; do
  mode="$(git ls-files --stage -- "${library}" | awk '{print $1}')"
  if [ "${mode}" != 160000 ]; then
    echo "release-check: ${library} is not a tracked submodule (mode=${mode})" >&2
    return 1
  fi
  pinned="$(git rev-parse "HEAD:${library}")"
  actual="$(git -C "${library}" rev-parse HEAD 2>/dev/null || true)"
  if [ -z "${actual}" ] || [ "${actual}" != "${pinned}" ]; then
    echo "release-check: ${library} is missing or not at pinned revision ${pinned} (actual=${actual})" >&2
    return 1
  fi
  git config -f .gitmodules --get "submodule.${library}.url" >/dev/null ||
    { echo "release-check: missing URL for ${library}" >&2; return 1; }
done

required_files=(
  LICENSE
  CHANGELOG.md
  README.org
  scripts/examples.sh
  scripts/run-glider.sh
  scripts/run-tests-clpm.lisp
  scripts/coverage.lisp
  scripts/run-slynk.lisp
  scripts/history-purge-paths.txt
  clpmfile
  clpmfile.lock
  dev/clpmfile
  dev/clpmfile.lock
  elmtui.asd
  elmtui-tests.asd
  elmtui-api-contract-tests.asd
  elmtui-core-slim-tests.asd
  elmtui-example-widgets.asd
  elmtui-dev.asd
  elmtui-workbench.asd
  elmtui-examples.asd
  elmtui-examples-fzy.asd
  elmtui-widgets-enhanced.asd
  docs/architecture/library-boundaries.md
  examples/README.md
  scripts/release-check.sh
  scripts/test-subsystems.sh
  scripts/test-subproject-bundles.sh
  scripts/run-tests-warning-clean.sh
  cl-events/LICENSE
  cl-events/README.md
  cl-events/CHANGELOG.md
  cl-events/clpmfile
  cl-events/clpmfile.lock
  cl-events/cl-events.asd
  cl-events/cl-events-tests.asd
  cl-inputs/LICENSE
  cl-inputs/README.md
  cl-inputs/CHANGELOG.md
  cl-inputs/clpmfile
  cl-inputs/clpmfile.lock
  cl-inputs/cl-inputs.asd
  cl-inputs/tests/ansii-tests.lisp
  cl-state/LICENSE
  cl-state/README.md
  cl-state/CHANGELOG.md
  cl-state/clpmfile
  cl-state/clpmfile.lock
  cl-state/cl-state.asd
  cl-state/cl-state-tests.asd
  cl-styles/LICENSE
  cl-styles/README.md
  cl-styles/CHANGELOG.md
  cl-styles/clpmfile
  cl-styles/clpmfile.lock
  cl-styles/cl-styles.asd
)

for file in "${required_files[@]}"; do
  if [ ! -f "${file}" ]; then
    echo "release-check: required file is missing: ${file}" >&2
    return 1
  fi
  # Git tracks the submodule gitlink, not individual files inside it.
  case "${file}" in
    cl-events/*|cl-inputs/*|cl-state/*|cl-styles/*) ;;
    *)
      if ! git ls-files --error-unmatch "${file}" >/dev/null 2>&1; then
        echo "release-check: required file is not tracked: ${file}" >&2
        return 1
      fi ;;
  esac
done

if grep -Eq '"/|"[A-Za-z]:\\\\' \
     clpmfile clpmfile.lock dev/clpmfile dev/clpmfile.lock; then
  echo 'release-check: CLPM metadata contains an absolute local path' >&2
  grep -En '"/|"[A-Za-z]:\\\\' \
    clpmfile clpmfile.lock dev/clpmfile dev/clpmfile.lock >&2
  return 1
fi

printf '\n==> requiring a clean root and dependency tree for the qualified artifact\n'
# A qualification result only describes the exact revision it ran against.
# Development checkouts may opt out explicitly; the result is then non-citable.
require_clean_tree() {
  if [ "${ELMTUI_RELEASE_ALLOW_DIRTY:-0}" = 1 ]; then
    echo 'release-check: ELMTUI_RELEASE_ALLOW_DIRTY=1; result is NOT a release qualification' >&2
    return 0
  fi
  if [ -n "$(git status --porcelain --ignore-submodules=none)" ]; then
    echo "release-check: working tree ($1) is not clean; commit or stash, or set ELMTUI_RELEASE_ALLOW_DIRTY=1 for a non-qualifying dry run" >&2
    git status --short --ignore-submodules=none >&2
    return 1
  fi
}
require_clean_tree 'before checks'

}
run_gate preflight preflight

# This is the local release matrix; CI must invoke this exact entrypoint
# or satisfy every lane asserted by release-matrix-test.py contract.
run_gate release_engineering_tests python3 -m unittest discover -s tests -p test_release_engineering.py -v
run_gate xvfb_ci_contract python3 -m unittest discover -s tests -p test_release_ci_xvfb_20261027.py -v
run_gate release_contract python3 scripts/release-matrix-test.py contract
run_gate release_tree python3 -m unittest discover -s tests -p test_release_tree.py -v
run_gate runner_contracts python3 tests/test_runner_contracts.py
run_gate whitespace git diff --check
run_gate whitespace_staged git diff --cached --check
run_gate cold_compile clpm bundle exec --with-client sbcl -- --noinform --non-interactive --eval '(asdf:compile-system :elmtui :force t)'
run_gate facade python3 scripts/audit-facade-exports.py
run_gate docstrings scripts/check-docstrings.sh
# Exported symbols with no binding may not increase (scripts/audit-api-bindings.lisp).
run_gate api_bindings env ELMTUI_API_PHANTOM_MAX="${ELMTUI_API_PHANTOM_MAX:-0}" \
  clpm bundle exec --with-client sbcl -- --noinform --non-interactive --load scripts/audit-api-bindings.lisp
run_gate standalone_subsystems scripts/test-subproject-bundles.sh
run_gate integrated_subsystems scripts/test-subsystems.sh
run_gate warning_clean scripts/run-tests-warning-clean.sh
run_gate asdf_acceptance python3 -m unittest discover -s tests -p test_asdf_acceptance.py -v
run_gate workbench_independent env ELMTUI_WORKBENCH_TEST_CMD='./scripts/examples.sh run repl' \
  python3 -m unittest discover -s tests/workbench/independent -p 'test_*.py' -v
run_gate workbench_pty python3 tests/workbench/pty-workbench.py
run_gate coverage scripts/run-coverage-warning-clean.sh
run_gate packaged_executable_pty python3 tests/e2e/release-gate-packager-pty.py
run_gate neon clpm bundle exec --with-client sbcl -- --noinform --non-interactive \
  --eval '(asdf:test-system "elmtui-neon-tests")'
run_gate neon_pty python3 tests/e2e/test-neon-terminal-restoration.py
run_gate terminal_tmux python3 scripts/test-terminal-apps.py --terminal tmux --output "$receipt_dir/terminal-tmux"
run_gate terminal_urxvt xvfb-run -a python3 scripts/test-terminal-apps.py --terminal urxvt --output "$receipt_dir/terminal-urxvt"
# Normal-screen tmux contracts: physical B2 overlay and lossless resize history.
run_gate normal_screen_contracts python3 tests/e2e/example-overhaul-tmux-review-contracts.py
run_gate normal_screen_hover python3 tests/e2e/tmux-hover-defect-regressions.py
run_gate normal_screen_resize python3 tests/e2e/tmux-normal-compositor-resize.py
# Every launcher example must restore stty, cursor and history on quit.
run_gate example_shutdown_sweep python3 tests/e2e/all-examples-shutdown-restoration.py
run_gate packager_tool_executable python3 tests/e2e/packager-executable.py
# The README Quickstart application must run exactly as documented.
run_gate readme_quickstart python3 tests/e2e/readme-quickstart.py
# DEFTEA-APP applications must run, not only macroexpand.
run_gate deftea_app python3 tests/e2e/deftea-app-pty.py
run_gate site_tests python3 -m unittest discover -s tests -p test_prepare_site.py -v
run_gate coverage_negative python3 -m unittest discover -s tests -p test_coverage_gate.py -v
run_gate badge_negative python3 -m unittest discover -s tests -p test_coverage_badge.py -v
run_gate reference_tests python3 -m unittest discover -s tests/reference -p 'test_*.py' -v
run_gate reference_fresh bash -c 'old="$(sha256sum docs/api/generated/api.md docs/api/generated/api.html)"; scripts/build-api-docs.sh; new="$(sha256sum docs/api/generated/api.md docs/api/generated/api.html)"; test "$old" = "$new"'
run_gate reference_structure python3 scripts/qualify-api-reference.py --structure-only
run_gate strict_site bash -c 'python3 scripts/prepare-site.py && if python3 -c "import mkdocs, material" >/dev/null 2>&1; then python3 -m mkdocs build --strict; else uv run --with "mkdocs-material>=9.5,<10" mkdocs build --strict; fi'
run_gate archive python3 scripts/release-matrix-test.py archive "$receipt_dir/elmtui-source.tar.gz"
run_gate archive_verify python3 scripts/release-matrix-test.py verify-archive "$receipt_dir/elmtui-source.tar.gz"
run_gate cold_install python3 scripts/release-matrix-test.py cold "$receipt_dir/elmtui-source.tar.gz"
run_gate public_pins python3 scripts/release-matrix-test.py pins "$receipt_dir/public-pins.json"
run_gate tree_final require_clean_tree 'after checks'
if [[ "$allow_dirty" == 1 ]]; then
  echo "release-check: development-only dirty override is never a release qualification" >&2
  exit 3
fi
printf '\nElmTUI release checks passed for frozen revision vector.\n'
