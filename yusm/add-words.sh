#!/usr/bin/env bash

set -euo pipefail
shopt -s failglob

doit() {
    repo="$1"
    dir="$2"

    d=yusm_sc.words_$repo-$VER
    mkdir -p "$d"
    s="$ROOT/$repo/src/$dir"
    [ -d "$s"  ] || s="$ROOT/$repo/$dir"

    for f in $s/*.dict.yaml; do
        f2=$(basename "$f" .dict.yaml)
        f2=${f2#snow_pinyin.}
        echo ./add-words.pl --name="yusm_sc.words_$f2" "$f" \> "$d/yusm_sc.words_$f2.dict.yaml"
        time ./add-words.pl --name="yusm_sc.words_$f2" "$f" > "$d/yusm_sc.words_$f2.dict.yaml"
        echo
    done
}

ROOT="${1:-}"
[ -d "$ROOT" ] || { echo "Usage: $0 path-to-top-directory"; exit 1; }

VER=`date +%Y%m%d`

doit rime-ice cn_dicts
doit rime-snow-pinyin .
doit rime-frost cn_dicts
doit rime-frost cn_dicts_cell
doit rime-LMDG dicts

rm -f yusm_sc.words_*/*8105.dict.yaml
rm -f yusm_sc.words_*/*41448.dict.yaml
rm -f yusm_sc.words_*/yusm_sc.words_chars.dict.yaml     # rime-LMDG
rm -f yusm_sc.words_*/yusm_sc.words_snow_pinyin.dict.yaml
