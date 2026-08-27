#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
systems=(cl-events cl-inputs cl-state cl-styles)

for system in "${systems[@]}"; do
  dir="${ROOT_DIR}/${system}"
  printf '\n==> validating standalone CLPM bundle: %s\n' "${system}"

  case "${system}" in
    cl-events) test_system=cl-events-tests ;;
    cl-inputs) test_system=cl-inputs/tests ;;
    cl-state) test_system=cl-state-tests ;;
    cl-styles) test_system=cl-styles/tests ;;
    *) echo "unknown subsystem: ${system}" >&2; exit 1 ;;
  esac

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

    printf '%s\n' "-- fresh primary load: ${system}"
    clpm bundle exec --with-client sbcl -- \
      --noinform --non-interactive \
      --eval '(require :asdf)' \
      --eval "(asdf:load-system \"${system}\")" \
      --eval "(let* ((loaded (asdf:already-loaded-systems))
                      (elmtui-packages
                        (remove-if-not
                          (lambda (package)
                            (let ((name (package-name package)))
                              (and (>= (length name) 6)
                                   (string-equal \"ELMTUI\" (subseq name 0 6)))))
                          (list-all-packages))))
                 (when elmtui-packages
                   (error \"~A primary load created ElmTUI packages: ~S\"
                          \"${system}\" (mapcar #'package-name elmtui-packages)))
                 (when (member \"${test_system}\" loaded :test #'string-equal)
                   (error \"~A primary load pulled in its test system ~A\"
                          \"${system}\" \"${test_system}\"))
                 (when (and (string= \"${system}\" \"cl-inputs\")
                            (member \"cl-events\" loaded :test #'string-equal))
                   (error \"cl-inputs primary load unexpectedly pulled in cl-events\"))
                 (format t
                         \"STANDALONE-LOAD system=${system} version=~A test-system=${test_system} elmtui-packages=0~%\"
                         (asdf:component-version (asdf:find-system \"${system}\"))))"

    printf '%s\n' "-- fresh ASDF test-op: ${system}"
    clpm bundle exec --with-client sbcl -- \
      --noinform --non-interactive \
      --eval '(require :asdf)' \
      --eval "(asdf:test-system \"${system}\")"
  )
done

printf '\nAll standalone subsystem bundles passed.\n'
