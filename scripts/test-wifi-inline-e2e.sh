#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

command -v tmux >/dev/null || { echo 'wifi-inline e2e: tmux is required' >&2; exit 77; }

TMP_DIR="$(mktemp -d)"
SESSION="elmtui-wifi-inline-$$"
BINARY="${TMP_DIR}/wifi-inline"
FAKE_NMCLI="${TMP_DIR}/nmcli-fake"
CALL_LOG="${TMP_DIR}/nmcli.calls"
RUNNER="${TMP_DIR}/run-wifi-inline"
INITIAL_CAPTURE="${TMP_DIR}/initial.capture"
CONNECTED_CAPTURE="${TMP_DIR}/connected.capture"
FINAL_CAPTURE="${TMP_DIR}/final.capture"

cleanup() {
  tmux kill-session -t "${SESSION}" 2>/dev/null || true
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT HUP INT TERM

cat >"${FAKE_NMCLI}" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
: "${ELMTUI_NMCLI_LOG:?ELMTUI_NMCLI_LOG is required}"
{
  printf 'CALL'
  for arg in "$@"; do printf '\t%s' "$arg"; done
  printf '\n'
} >>"${ELMTUI_NMCLI_LOG}"

joined=" $* "
if [[ "${joined}" == *" device wifi list "* ]]; then
  sleep 0.15
  printf ' :Cafe\\:Lab:82:WPA2\n'
  printf '*:OfficeNet:71:WPA2\n'
  printf ' :Guest:44:--\n'
elif [[ "${joined}" == *" device wifi connect "* ]]; then
  ssid="${@: -1}"
  printf 'CONNECTED\t%s\n' "${ssid}" >>"${ELMTUI_NMCLI_LOG}"
  sleep 0.10
  printf "Device 'wlan0' successfully activated for %s.\n" "${ssid}"
else
  printf 'unexpected fake nmcli invocation: %s\n' "$*" >&2
  exit 64
fi
FAKE
chmod +x "${FAKE_NMCLI}"

printf '==> building standalone wifi-inline example image\n'
clpm bundle exec --with-client sbcl -- \
  --noinform --non-interactive \
  --eval '(require :asdf)' \
  --eval '(asdf:load-system :elmtui-tools)' \
  --eval "(elmtui.examples.runner::build-example-binary \"wifi-inline\" :output-path #P\"${BINARY}\" :backend-type :terminal)" \
  >"${TMP_DIR}/build.stdout" 2>"${TMP_DIR}/build.stderr"
[[ -x "${BINARY}" ]] || { cat "${TMP_DIR}/build.stderr" >&2; exit 1; }

cat >"${RUNNER}" <<RUN
#!/usr/bin/env bash
set +e
printf 'INLINE-SENTINEL\\n'
printf 'cursor> '
ELMTUI_NMCLI='${FAKE_NMCLI}' ELMTUI_NMCLI_LOG='${CALL_LOG}' '${BINARY}'
rc=\$?
printf '\\nINLINE-RC=%s\\n' "\${rc}"
sleep 8
exit "\${rc}"
RUN
chmod +x "${RUNNER}"

capture_pane() {
  tmux capture-pane -p -J -t "${SESSION}:0.0" 2>/dev/null || true
}

wait_for_pane() {
  local needle=$1
  local attempts=${2:-160}
  for ((i=0; i<attempts; i++)); do
    if capture_pane | grep -F -- "${needle}" >/dev/null; then return 0; fi
    sleep 0.05
  done
  echo "wifi-inline e2e: timed out waiting for pane text: ${needle}" >&2
  capture_pane >&2
  return 1
}

wait_for_log() {
  local needle=$1
  local attempts=${2:-160}
  for ((i=0; i<attempts; i++)); do
    if [[ -f "${CALL_LOG}" ]] && grep -F -- "${needle}" "${CALL_LOG}" >/dev/null; then return 0; fi
    sleep 0.05
  done
  echo "wifi-inline e2e: timed out waiting for nmcli call: ${needle}" >&2
  [[ -f "${CALL_LOG}" ]] && cat "${CALL_LOG}" >&2
  return 1
}

printf '==> starting inline terminal application under tmux\n'
tmux new-session -d -x 100 -y 30 -s "${SESSION}" -c "${ROOT_DIR}" "${RUNNER}"
wait_for_log $'device\twifi\tlist'
wait_for_pane 'OfficeNet'
capture_pane >"${INITIAL_CAPTURE}"
grep -F 'INLINE-SENTINEL' "${INITIAL_CAPTURE}" >/dev/null
grep -F 'Wi-Fi / NetworkManager' "${INITIAL_CAPTURE}" >/dev/null
sentinel_line="$(grep -n -m1 'INLINE-SENTINEL' "${INITIAL_CAPTURE}" | cut -d: -f1)"
menu_line="$(grep -n -m1 'Wi-Fi / NetworkManager' "${INITIAL_CAPTURE}" | cut -d: -f1)"
if (( menu_line <= sentinel_line )); then
  echo 'wifi-inline e2e: menu did not render below the pre-existing cursor content' >&2
  cat "${INITIAL_CAPTURE}" >&2
  exit 1
fi

printf '==> selecting escaped SSID and opening confirmation\n'
tmux send-keys -t "${SESSION}:0.0" j Enter
wait_for_pane 'Connect to "Cafe:Lab"?'
if [[ -f "${CALL_LOG}" ]] && grep -F $'device\twifi\tconnect' "${CALL_LOG}" >/dev/null; then
  echo 'wifi-inline e2e: connect was invoked before explicit confirmation' >&2
  cat "${CALL_LOG}" >&2
  exit 1
fi

printf '==> confirming connection and observing async completion\n'
tmux send-keys -t "${SESSION}:0.0" Enter
wait_for_log $'device\twifi\tconnect\tCafe:Lab'
wait_for_log $'CONNECTED\tCafe:Lab'
wait_for_pane 'Connected to Cafe:Lab.'
capture_pane >"${CONNECTED_CAPTURE}"

printf '==> quitting and verifying inline cleanup / zero exit\n'
tmux send-keys -t "${SESSION}:0.0" q
wait_for_pane 'INLINE-RC=0'
capture_pane >"${FINAL_CAPTURE}"
grep -F 'INLINE-SENTINEL' "${FINAL_CAPTURE}" >/dev/null
grep -F 'INLINE-RC=0' "${FINAL_CAPTURE}" >/dev/null

printf 'wifi-inline e2e: ok (inline render, async scan, confirmation-gated connect, clean exit)\n'
