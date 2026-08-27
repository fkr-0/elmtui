#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
systems=(cl-events cl-inputs cl-state cl-styles)

for system in "${systems[@]}"; do
  dir="${ROOT_DIR}/${system}"
  printf '\n==> validating standalone CLPM bundle: %s\n' "${system}"

  for required in README.md CHANGELOG.md clpmfile clpmfile.lock; do
    if [ ! -f "${dir}/${required}" ]; then
      echo "subproject bundle missing ${system}/${required}" >&2
      exit 1
    fi
  done

  if grep -Eq '"/|"[A-Za-z]:\\\\' "${dir}/clpmfile" "${dir}/clpmfile.lock"; then
    echo "subproject CLPM metadata contains an absolute local path: ${system}" >&2
    grep -En '"/|"[A-Za-z]:\\\\' "${dir}/clpmfile" "${dir}/clpmfile.lock" >&2
    exit 1
  fi

  (
    cd "${dir}"
    clpm bundle exec --with-client sbcl -- \
      --noinform --non-interactive \
      --eval '(require :asdf)' \
      --eval "(asdf:test-system \"${system}\")"
  )
done

printf '\nAll standalone subsystem bundles passed.\n'
