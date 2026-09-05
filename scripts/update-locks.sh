#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/lock-utils.sh"

github_latest_tag() {
    local repo="$1"
    curl -fsSL -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${repo}/releases/latest" \
        | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])'
}

sha256_from_sums() {
    local sums_url="$1"
    local artifact="$2"
    curl -fsSL "$sums_url" | awk -v name="$artifact" '
        $2 == name || $2 == "./" name { gsub(/^\.\//, "", $2); print $1; found=1; exit }
        END { if (!found) exit 1 }
    '
}

echo "==> Updating bootstrap pins"
mise_tag="$(github_latest_tag jdx/mise)"
font_tag="$(github_latest_tag ryanoasis/nerd-fonts)"
font_asset="JetBrainsMono.tar.xz"

mise_sha_linux_x64="$(sha256_from_sums "https://github.com/jdx/mise/releases/download/${mise_tag}/SHASUMS256.txt" "mise-${mise_tag}-linux-x64.tar.gz")"
mise_sha_linux_arm64="$(sha256_from_sums "https://github.com/jdx/mise/releases/download/${mise_tag}/SHASUMS256.txt" "mise-${mise_tag}-linux-arm64.tar.gz")"
mise_sha_macos_x64="$(sha256_from_sums "https://github.com/jdx/mise/releases/download/${mise_tag}/SHASUMS256.txt" "mise-${mise_tag}-macos-x64.tar.gz")"
mise_sha_macos_arm64="$(sha256_from_sums "https://github.com/jdx/mise/releases/download/${mise_tag}/SHASUMS256.txt" "mise-${mise_tag}-macos-arm64.tar.gz")"
font_sha="$(sha256_from_sums "https://github.com/ryanoasis/nerd-fonts/releases/download/${font_tag}/SHA-256.txt" "$font_asset")"

cat >"$ROOT/locks/bootstrap.lock" <<EOF
# key=value — bump with: make update

mise_version=${mise_tag}
mise_sha256_linux_x64=${mise_sha_linux_x64}
mise_sha256_linux_arm64=${mise_sha_linux_arm64}
mise_sha256_macos_x64=${mise_sha_macos_x64}
mise_sha256_macos_arm64=${mise_sha_macos_arm64}

font_tag=${font_tag}
font_asset=${font_asset}
font_sha256=${font_sha}
EOF
echo "    Mise CLI ${mise_tag}"
echo "    Nerd Font ${font_tag} / ${font_asset}"

echo "==> Updating plugin SHAs"
plugin_lock="$ROOT/locks/zsh-plugins.lock"
plugin_tmp="$(mktemp)"
{
    echo "# name url commit branch — bump with: make update"
    while read -r name url sha branch; do
        [[ -z "${name:-}" || "$name" == \#* ]] && continue
        new_sha="$(git ls-remote "$url" "refs/heads/${branch}" | awk '{print $1}')"
        if [[ -z "$new_sha" ]]; then
            echo "error: could not resolve HEAD for $name at $url $branch" >&2
            exit 1
        fi
        echo "$name $url $new_sha $branch"
        echo "    $name ${new_sha:0:12}" >&2
    done <"$plugin_lock"
} >"$plugin_tmp"
mv "$plugin_tmp" "$plugin_lock"

PLUGIN_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"
if command -v git >/dev/null 2>&1 && [[ -d "$PLUGIN_DIR" ]]; then
    echo "==> Checking out pinned plugins locally"
    while read -r name url sha branch; do
        [[ -z "${name:-}" || "$name" == \#* ]] && continue
        if [[ -d "$PLUGIN_DIR/$name/.git" ]]; then
            git -C "$PLUGIN_DIR/$name" fetch --depth 1 origin "$sha"
            git -C "$PLUGIN_DIR/$name" checkout --detach "$sha" --quiet
            echo "    Updated $name"
        fi
    done <"$plugin_lock"
fi

echo "==> Updating Mise pins"
if command -v mise >/dev/null 2>&1; then
    mise trust "$ROOT/mise/config.toml" >/dev/null
    # upgrade --bump rewrites pins in config.toml; lock refreshes checksums.
    (cd "$ROOT" && mise upgrade --bump && mise lock -p linux-x64,linux-arm64,macos-x64,macos-arm64)
    echo "==> Installing locked Mise tools"
    MISE_LOCKED=1 mise install --locked || echo "warning: mise install --locked failed"
else
    echo "Mise was not found; skipped the lockfile update."
fi

echo "==> Done. Review and commit locks/, mise/config.toml, and mise/mise.lock."
