#!/usr/bin/env bash
# Format or check Lua sources under src/ with EmmyLuaCodeStyle (CodeFormat).
#
# The tool is invoked once per file so that the nearest .editorconfig is
# detected reliably. Only git-tracked files are visited, which automatically
# skips vendored/untracked trees such as src/lua/conf. Additional exclusions
# are read from src/.codeformatignore.
#
# CodeFormat does not always reach a fixed point in a single pass, so the
# --write mode keeps formatting until the tree stops changing (a few passes
# are normally enough).
#
# Usage:
#   tools/format-lua.sh            # check, non-zero exit if something differs
#   tools/format-lua.sh --write    # format files in place
#
# The CodeFormat binary is looked up in $CODEFORMAT, then in ~/bin/CodeFormat.

set -euo pipefail

usage() {
    sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
}

case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
    ""|check)
        mode=check
        ;;
    --write|format|write)
        mode=format
        ;;
    *)
        echo "error: unknown argument '$1'" >&2
        usage >&2
        exit 2
        ;;
esac

root=$(git rev-parse --show-toplevel)
cd "$root"

codeformat=${CODEFORMAT:-$HOME/bin/CodeFormat}
if [[ ! -x $codeformat ]]; then
    echo "error: CodeFormat not found at '$codeformat'" >&2
    echo "Install the binary or point \$CODEFORMAT at it." >&2
    exit 2
fi

ignore_file=src/.codeformatignore
patterns=()
if [[ -f $ignore_file ]]; then
    while IFS= read -r line; do
        line=${line%%#*}
        line=${line#"${line%%[![:space:]]*}"}
        line=${line%"${line##*[![:space:]]}"}
        [[ -n $line ]] && patterns+=("$line")
    done < "$ignore_file"
fi

is_ignored() {
    local file=$1 pattern
    for pattern in "${patterns[@]}"; do
        # shellcheck disable=SC2254
        case $file in
            $pattern) return 0 ;;
        esac
    done
    return 1
}

mapfile -t files < <(git ls-files -- src | grep -E '\.lua$' || true)
selected=()
for file in "${files[@]}"; do
    is_ignored "$file" || selected+=("$file")
done

# Cheap fingerprint of the tracked Lua files, used to detect convergence.
fingerprint() {
    printf '%s\n' "${selected[@]}" | xargs -d '\n' sha1sum 2>/dev/null | sha1sum
}

if [[ $mode == check ]]; then
    failed=0
    for file in "${selected[@]}"; do
        if ! out=$("$codeformat" check -f "$root/$file" -d -w "$root" \
                --diagnosis-as-error 2>&1); then
            echo "needs formatting: $file"
            printf '%s\n' "$out" | grep -vE "\.\.\. ok$" || true
            failed=$((failed + 1))
        fi
    done
    if ((failed > 0)); then
        echo "check failed: $failed of ${#selected[@]} file(s) need formatting" >&2
        exit 1
    fi
    echo "check passed: ${#selected[@]} file(s)"
    exit 0
fi

max_passes=${MAX_PASSES:-5}
pass=0
while :; do
    pass=$((pass + 1))
    before=$(fingerprint)
    for file in "${selected[@]}"; do
        if ! out=$("$codeformat" format -f "$root/$file" -d -w "$root" \
                --overwrite 2>&1); then
            echo "failed: $file"
            printf '%s\n' "$out"
            exit 1
        fi
    done
    after=$(fingerprint)
    if [[ $before == "$after" ]]; then
        break
    fi
    if ((pass >= max_passes)); then
        echo "warning: formatting did not converge in $max_passes passes" >&2
        break
    fi
done
echo "formatted: ${#selected[@]} file(s) in $pass pass(es)"
