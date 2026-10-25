#!/usr/bin/env bash
# sync-local.sh — seat Jurai Fastfetch in the local RyoStore catalogue
# tree and reinstall it, for the development loop.
#
#   repo (this folder's parent tree, as fastfetch/jurai-fastfetch)
#     -> ~/Documents/GitHub/ryostore-local (the stable local catalogue)
#     -> ryostore install fastfetch jurai-fastfetch
#
# The local tree is the durable seat: the file:// override in
# ~/.config/ryoku/ryostore-base points there, and the tree is never
# branch-switched, so a store refresh cannot unseat the preset.
set -eu

REPO="$(cd "$(dirname "$0")/.." && pwd)"
STAGE="$HOME/Documents/GitHub/ryostore-local"
PRODUCT="$STAGE/fastfetch/jurai-fastfetch"

if [ ! -f "$HOME/.config/ryoku/ryostore-base" ]; then
    echo "sync-local: no ryostore-base override — the store is serving the published catalogue; refusing" >&2
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
    if row["id"] == "jurai-fastfetch":
        row["manifestSha256"] = digest
json.dump(doc, open(path, "w"), indent=2, ensure_ascii=False)
open(path, "a").write("\n")
print("registry digest:", digest)
PY

git -C "$STAGE" add -A
git -C "$STAGE" -c user.email=local@jurai -c user.name=jurai-local \
    commit -qm "jurai-fastfetch: sync from repo" || true

"$HOME/.local/bin/jurai-storecheck" fastfetch jurai-fastfetch

ryostore remove fastfetch jurai-fastfetch >/dev/null 2>&1 || true
rm -rf "$HOME/.local/share/ryoku/fastfetch/jurai-fastfetch"
ryostore install fastfetch jurai-fastfetch
echo "sync-local: jurai-fastfetch seated from $REPO"
