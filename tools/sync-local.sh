#!/usr/bin/env bash
# sync-local.sh: seat Insei-fastfetch in the local RyoStore catalogue
# tree and reinstall it, for the development loop.
# The local tree is never branch-switched, so a store refresh cannot
# unseat the preset.
set -eu

REPO="$(cd "$(dirname "$0")/.." && pwd)"
STAGE="$HOME/Documents/GitHub/ryostore-local"
PRODUCT="$STAGE/fastfetch/insei-fastfetch"

if [ ! -f "$HOME/.config/ryoku/ryostore-base" ]; then
    echo "sync-local: no ryostore-base override: the store is serving the published catalogue; refusing" >&2
    exit 1
fi

mkdir -p "$PRODUCT"
cp "$REPO/config.jsonc" "$REPO/emblem.png" "$PRODUCT/"
cp "$REPO/assets/preview.webp" "$PRODUCT/preview.webp"
cp "$REPO/LICENSE" "$REPO/PROVENANCE.txt" "$PRODUCT/"

DIGEST="$(python3 "$REPO/tools/build-manifest.py" "$PRODUCT")"
python3 - "$STAGE/fastfetch/registry.json" "$DIGEST" <<'PY'
import json, sys
path, digest = sys.argv[1], sys.argv[2]
doc = json.load(open(path))
key = next(k for k, v in doc.items() if isinstance(v, list))
for row in doc[key]:
    if row["id"] == "insei-fastfetch":
        row["manifestSha256"] = digest
json.dump(doc, open(path, "w"), indent=2, ensure_ascii=False)
open(path, "a").write("\n")
print("registry digest:", digest)
PY

git -C "$STAGE" add -A
git -C "$STAGE" -c user.email=local@jurai -c user.name=jurai-local \
    commit -qm "insei-fastfetch: sync from repo" || true

"$HOME/.local/bin/jurai-storecheck" fastfetch insei-fastfetch

ryostore remove fastfetch insei-fastfetch >/dev/null 2>&1 || true
rm -rf "$HOME/.local/share/ryoku/fastfetch/insei-fastfetch"
ryostore install fastfetch insei-fastfetch
echo "sync-local: insei-fastfetch seated from $REPO"
