#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/lock-utils.sh"

# Keep in sync with minimum_release_age in mise/config.toml. A quarantine that
# the pins themselves bypass protects nothing.
MIN_AGE_DAYS=7
CUTOFF_EPOCH="$(($(date +%s) - MIN_AGE_DAYS * 86400))"

# The release list runs to megabytes, so it lands in a file: a reader that
# stops at the first match would leave curl writing into a closed pipe.
github_aged_release_tag() {
    local repo="$1" body tag=""
    body="$(mktemp)"
    if curl -fsSL -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${repo}/releases?per_page=50" -o "$body"; then
        tag="$(CUTOFF="$CUTOFF_EPOCH" RELEASES="$body" python3 -c '
import calendar, json, os, sys, time

cutoff = int(os.environ["CUTOFF"])
with open(os.environ["RELEASES"], encoding="utf-8") as handle:
    releases = json.load(handle)

for release in releases:
    if release.get("draft") or release.get("prerelease"):
        continue
    published = release.get("published_at")
    if not published:
        continue
    if calendar.timegm(time.strptime(published, "%Y-%m-%dT%H:%M:%SZ")) <= cutoff:
        print(release["tag_name"])
        break
else:
    sys.exit(1)
')"
    fi
    rm -f "$body"
    [[ -n "$tag" ]] || return 1
    printf '%s' "$tag"
}

# Newest commit on the branch that already cleared the quarantine.
aged_branch_commit() {
    local url="$1" branch="$2" dir sha=""
    dir="$(mktemp -d)"
    if git -C "$dir" init --quiet \
        && git -C "$dir" remote add origin "$url" \
        && git -C "$dir" fetch --quiet --depth 50 origin "$branch"; then
        sha="$(git -C "$dir" log FETCH_HEAD --format='%H %ct' \
            | awk -v cutoff="$CUTOFF_EPOCH" '$2 <= cutoff { print $1; exit }')"
    fi
    rm -rf "$dir"
    [[ -n "$sha" ]] || return 1
    printf '%s' "$sha"
}

echo "==> Updating bootstrap pins (nothing younger than ${MIN_AGE_DAYS} days)"
mise_tag="$(github_aged_release_tag jdx/mise)" || {
    echo "error: no jdx/mise release is at least ${MIN_AGE_DAYS} days old" >&2
    exit 1
}
font_tag="$(github_aged_release_tag ryanoasis/nerd-fonts)" || {
    echo "error: no ryanoasis/nerd-fonts release is at least ${MIN_AGE_DAYS} days old" >&2
    exit 1
}
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

echo "==> Updating plugin SHAs (nothing younger than ${MIN_AGE_DAYS} days)"
plugin_lock="$ROOT/locks/zsh-plugins.lock"
plugin_tmp="$(mktemp)"
{
    echo "# name url commit branch — bump with: make update"
    while read -r name url sha branch; do
        [[ -z "${name:-}" || "$name" == \#* ]] && continue
        if ! new_sha="$(aged_branch_commit "$url" "$branch")"; then
            echo "error: no commit on $branch of $name is at least ${MIN_AGE_DAYS} days old" >&2
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

echo "==> Mise tools are not touched by this script"
echo "    Languages are pinned to a major series in mise/config.toml; CLI tools roll."
echo "    Run 'mise outdated' to review, 'mise upgrade' to move inside a pin,"
echo "    and 'mise upgrade --bump' to cross one and rewrite the selector."

echo "==> Done. Review and commit locks/."
