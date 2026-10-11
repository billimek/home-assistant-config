#!/bin/sh
# Copies the tracked .storage/lovelace* files from the running pod into this clone.
set -eu
cd "$(git rev-parse --show-toplevel)"
for f in $(git ls-files '.storage/lovelace*'); do
  tmp=$(mktemp)
  kubectl -n default exec deploy/home-assistant -c code-server -- cat "/config/$f" > "$tmp"
  if [ ! -s "$tmp" ]; then
    echo "empty: $f" >&2
    rm -f "$tmp"
    exit 1
  fi
  mv "$tmp" "$f"
done
git status --short .storage
