#!/usr/bin/env bash
# start-vllm-sr.sh -- one-command workshop launcher for the vLLM Semantic
# Router (baked by 54-workshop-vllm-sr.sh). Serves the stack offline, the
# dashboard auto-provisions the admin from DASHBOARD_ADMIN_* (exported
# below), then opens the dashboard. Re-runnable: stops any prior instance
# first. Log in with the email/password printed at the end.
#
# Usage: start-vllm-sr.sh [fireworks-api-key]
#   With no argument, prompts for the key (paste from
#   https://notebooks.amd.com/codes/fireworks) unless a previously
#   persisted FIREWORKS_API_KEY is in the environment. The key is wired
#   into the router config (Kimi K2 backend) before serve and persisted
#   to ~/.bashrc so start-openclaw.sh can pick it up without re-pasting.
set -euo pipefail

STATE_ROOT="${VLLM_SR_STATE_ROOT_DIR:-$HOME/Downloads/projects/router-configs}"
CONFIG="$STATE_ROOT/config_workshop_enhanced.yaml"
DASH_URL="http://localhost:8700"
ADMIN_NAME="amd"
ADMIN_EMAIL="aai26@amd.com"
ADMIN_PASSWORD="aai26"
SERVE_LOG="$HOME/vllm-sr-serve.log"
ROUTER_IMG="ghcr.io/vllm-project/semantic-router/vllm-sr:latest"
FIREWORKS_MODEL="accounts/fireworks/models/kimi-k2p6"

export PATH="$HOME/.local/bin:$PATH"
command -v vllm-sr >/dev/null || { echo "vllm-sr not on PATH" >&2; exit 1; }
[ -f "$CONFIG" ] || { echo "config not found: $CONFIG" >&2; exit 1; }

# Fireworks API key: argument wins, else any previously exported/persisted
# FIREWORKS_API_KEY, else prompt (workshop flow: fetch the key in Chrome
# at notebooks.amd.com/codes/fireworks, then run this). The [ -t 0 ] guard
# keeps non-interactive runs from hanging on the prompt. Patch it into the
# router config's Kimi K2 backend_ref before serve, and persist the export
# so later shells (start-openclaw.sh) inherit it.
FIREWORKS_API_KEY="${1:-${FIREWORKS_API_KEY:-}}"
if [ -z "$FIREWORKS_API_KEY" ] && [ -t 0 ]; then
  echo "Fireworks API key needed for the Kimi K2 cloud model."
  echo "Get it in Chrome at: https://notebooks.amd.com/codes/fireworks"
  read -r -p "Paste the key (or press Enter to skip): " FIREWORKS_API_KEY
fi
if [ -n "$FIREWORKS_API_KEY" ]; then
  export FIREWORKS_API_KEY
  command -v yq >/dev/null || { echo "yq not on PATH (needed to wire the Fireworks key)" >&2; exit 1; }
  echo "==> Wiring Fireworks API key into $CONFIG ($FIREWORKS_MODEL)..."
  # yq -i re-indents the file (4->2 space); semantically identical, verified
  # by canonical-JSON diff. yq is the mikefarah static binary (baked by
  # step 54), NOT the snap -- snaps can't run from the VNC session cgroup.
  FIREWORKS_MODEL="$FIREWORKS_MODEL" yq -i \
    '(.providers.models[] | select(.name == strenv(FIREWORKS_MODEL)) | .backend_refs[0].api_key) = strenv(FIREWORKS_API_KEY)' \
    "$CONFIG"
  if grep -q '^export FIREWORKS_API_KEY=' "$HOME/.bashrc" 2>/dev/null; then
    sed -i "s|^export FIREWORKS_API_KEY=.*|export FIREWORKS_API_KEY=\"$FIREWORKS_API_KEY\"|" "$HOME/.bashrc"
  else
    echo "export FIREWORKS_API_KEY=\"$FIREWORKS_API_KEY\"" >> "$HOME/.bashrc"
  fi
  echo "    key persisted to ~/.bashrc (FIREWORKS_API_KEY)."
else
  echo "==> No Fireworks API key (argument or FIREWORKS_API_KEY env) -- skipping key wiring."
  echo "    The $FIREWORKS_MODEL model will not work until you re-run with the key."
fi

# Auto-provision the dashboard admin. The dashboard image disables open/
# web-form bootstrap and only creates the first admin from these env vars;
# vllm-sr forwards them into the dashboard container (its passthrough
# whitelist is patched at build by 54-workshop-vllm-sr.sh). So the admin is
# created at dashboard startup -- no web form, no register call.
export DASHBOARD_ADMIN_EMAIL="$ADMIN_EMAIL"
export DASHBOARD_ADMIN_PASSWORD="$ADMIN_PASSWORD"
export DASHBOARD_ADMIN_NAME="$ADMIN_NAME"

# Wait for Docker + the pre-baked images. On a fresh boot the boot-load
# service (docker-image-load) only finishes once dockerd is up, so serving
# with --image-pull-policy never before then fails with "image not found".
# Poll `docker image inspect` on the router image (also covers "docker not
# up yet"), up to ~4 min.
printf '==> Waiting for Docker + pre-baked images '
ready=0
for _ in $(seq 1 120); do
  if docker image inspect "$ROUTER_IMG" >/dev/null 2>&1; then ready=1; echo " ready."; break; fi
  printf '.'; sleep 2
done
if [ "$ready" != 1 ]; then
  echo
  echo "Pre-baked images not loaded yet -- check:  docker images" >&2
  echo "and:  systemctl status docker-image-load.service" >&2
  echo "(re-run once they appear, or: sudo systemctl start docker-image-load.service)" >&2
  exit 1
fi

echo "==> Stopping any previous instance..."
vllm-sr stop >/dev/null 2>&1 || true

echo "==> Starting vLLM Semantic Router (offline). Logs -> $SERVE_LOG"
nohup vllm-sr serve --config "$CONFIG" --image-pull-policy never >"$SERVE_LOG" 2>&1 &

printf '==> Waiting for the dashboard at %s ' "$DASH_URL"
up=0
for _ in $(seq 1 90); do
  if curl -fsS -o /dev/null "$DASH_URL/" 2>/dev/null; then up=1; echo " up."; break; fi
  printf '.'; sleep 2
done
if [ "$up" != 1 ]; then
  echo; echo "Dashboard did not come up in time -- check $SERVE_LOG" >&2; exit 1
fi

# The dashboard auto-provisions the admin from the DASHBOARD_ADMIN_* env
# exported above (open/web-form bootstrap is disabled by the image). Just
# confirm it can log in -- retry briefly since provisioning happens as the
# dashboard container settles.
echo "==> Verifying the dashboard admin ($ADMIN_EMAIL)..."
login_code=000
for _ in $(seq 1 10); do
  login_code=$(curl -sS -o /dev/null -w '%{http_code}' \
    -X POST "$DASH_URL/api/auth/login" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}" 2>/dev/null || true)
  case "$login_code" in 2*) break ;; esac
  sleep 2
done
case "$login_code" in
  2*) echo "    login OK: $ADMIN_EMAIL / $ADMIN_PASSWORD" ;;
  *)  echo "    login check returned HTTP $login_code -- admin may still be provisioning; retry shortly." ;;
esac

echo "==> Opening the dashboard in Chrome..."
# `vllm-sr dashboard` opens the URL with Python webbrowser.open(). Point
# BROWSER at our Chrome wrapper (which injects --use-angle=swiftshader
# --enable-unsafe-swiftshader) so the dashboard's three.js/WebGL background
# renders instead of coming up BLACK under the GPU-less VNC session --
# otherwise webbrowser may launch /usr/bin/google-chrome-stable with no
# flags. Falls back to the default opener if the wrapper is missing.
[ -x /usr/local/bin/google-chrome ] && export BROWSER=/usr/local/bin/google-chrome
vllm-sr dashboard >/dev/null 2>&1 || echo "    (no browser opened -- go to $DASH_URL)"

cat <<EOF_DONE

vLLM Semantic Router is running.
  Dashboard : $DASH_URL
  Login     : $ADMIN_EMAIL  /  $ADMIN_PASSWORD   (login is by email)
  Logs      : tail -f $SERVE_LOG
  Stop      : vllm-sr stop
EOF_DONE