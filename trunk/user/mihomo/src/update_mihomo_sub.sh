#!/bin/sh
#
# Fetch a subscription / remote config and store it as mihomo config.
# Converts nothing: the URL must already return a Clash/mihomo YAML
# (use subconverter with target=clash for base64 ss:// / vmess:// lists).
#
# usage: update_mihomo_sub.sh <url>
#
# Copyright (C) 2026 world28
# GPL-2.0

DIR=/etc/storage/mihomo
TMP=/tmp/mihomo-sub.$$.yaml
URL="$1"

[ -n "$URL" ] || { echo "usage: $0 <url>"; exit 1; }

mkdir -p "$DIR"

if ! wget -q -O "$TMP" "$URL"; then
	echo "download failed"
	rm -f "$TMP"
	exit 1
fi

# The URL may point to a base64 node list instead of Clash YAML: detect it and
# keep the previous config rather than writing garbage.
if ! grep -q "^[[:space:]]*proxies:" "$TMP" && ! grep -q "^[[:space:]]*mixed-port:" "$TMP"; then
	echo "not a clash/mihomo yaml"
	rm -f "$TMP"
	exit 2
fi

mv -f "$TMP" "$DIR/config.yaml"
chmod 600 "$DIR/config.yaml"
echo "ok"
