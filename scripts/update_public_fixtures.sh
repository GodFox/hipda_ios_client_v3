#!/bin/sh
# 重新抓取公开页面作为解析测试 fixture（不需要论坛登录）。
# 用法：./scripts/update_public_fixtures.sh
set -eu
cd "$(dirname "$0")/.."

UA='Mozilla/5.0 (iPhone; CPU iPhone OS 7_0_3 like Mac OS X) AppleWebKit/537.51.1 (KHTML, like Gecko) Version/7.0 Mobile/11B508 Safari/9537.53'
BASE='https://www.4d4y.com/forum'
OUT='HiPDATests/Fixtures'
mkdir -p "$OUT"

fetch() {
    url="$1"
    dest="$2"
    tmp="$(mktemp)"
    curl -sS -L --max-time 30 -A "$UA" "$url" -o "$tmp"
    iconv -f GB18030 -t UTF-8 "$tmp" > "$dest"
    rm -f "$tmp"
    printf '%s -> %s (%s bytes)\n' "$url" "$dest" "$(wc -c < "$dest" | tr -d ' ')"
}

fetch "$BASE/forumdisplay.php?fid=7" "$OUT/forumdisplay.html"
fetch "$BASE/viewthread.php?action=printable&tid=448060" "$OUT/printable.html"
fetch "$BASE/viewthread.php?tid=448060&page=1" "$OUT/viewthread.html"
