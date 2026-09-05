#!/usr/bin/env bash
# Pick a backend before reading stdin; `a || b` would drain stdin on the first failure.
set -euo pipefail

if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v wl-copy >/dev/null 2>&1; then
    exec wl-copy
fi

if [[ -n "${DISPLAY:-}" ]] && command -v xclip >/dev/null 2>&1; then
    exec xclip -in -selection clipboard
fi

if [[ -n "${DISPLAY:-}" ]] && command -v xsel >/dev/null 2>&1; then
    exec xsel --clipboard --input
fi

if command -v pbcopy >/dev/null 2>&1; then
    exec pbcopy
fi

cat >/dev/null
exit 1
