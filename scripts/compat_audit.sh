#!/bin/sh
# 兼容性静态扫描：找出论坛改版 / iOS 新 SDK 下最容易出问题的代码。
# 用法：./scripts/compat_audit.sh
set -eu
cd "$(dirname "$0")/.."

section() {
    printf '\n== %s ==\n' "$1"
}

section "已废弃 / UIScene 下不可用的 UI API"
grep -rnE '\[\[UIAlertView alloc\]|\[UIAlertView alloc\]|\[UIAlertView show|\[\[UIActionSheet alloc\]|UIActionSheet \*|UIWebView' HiPDA --include='*.m' --include='*.h' || true

section "已废弃的屏幕/状态栏几何 API"
grep -rnE 'applicationFrame|statusBarHeightForOrientation|statusBarStyle' HiPDA --include='*.m' --include='*.h' || true

section "可能把 NSNotFound 传给 substring 的位置"
grep -rnE 'substringFromIndex:|substringToIndex:' HiPDA --include='*.m' || true

section "写死的旧域名 / 非 HTTPS 论坛地址"
grep -rnE 'hi-pda|http://www\.4d4y\.com' HiPDA README.md --include='*.m' --include='*.h' --include='*.html' --include='*.md' || true

section "解析器入口（改版时优先回归这些方法）"
grep -rnE '^\+ \(NSArray \*\)extract|^\+ \(void\)load|^\+ \(NSArray \*\).*Parser' HiPDA/Model --include='*.m' | head -80 || true
