#!/bin/sh
#
# sbctl.sh - sing-box runtime manager for Padavan (K2P / mipsel)
#
# The core does not fit into the 16MB firmware flash, so it is fetched into
# /tmp (tmpfs) on demand, while the configuration lives in /etc/storage/singbox.
#
# usage: sbctl.sh start|stop|restart|status|update-core|apply
#
# Copyright (C) 2026 world28
# GPL-2.0

DIR=/etc/storage/singbox
RUN=/tmp/singbox
BIN=$RUN/sing-box
CFG=$DIR/config.json
LOG=$RUN/singbox.log
PIDF=$RUN/singbox.pid
REDIR_PORT=7893
TPROXY_PORT=7894
DNS_PORT=1053

CORE_URL=$(nvram get sb_core_url)
[ -n "$CORE_URL" ] || CORE_URL="https://github.com/yandexru45/sing-box-extended-lite/releases/latest/download/sing-box-extended-lite-linux-mipsle-softfloat.tar.gz"
CORE_URL2="https://ghfast.top/https://github.com/yandexru45/sing-box-extended-lite/releases/latest/download/sing-box-extended-lite-linux-mipsle-softfloat.tar.gz"

log() {
	logger -t singbox "$@" 2>/dev/null
	echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG" 2>/dev/null
}

is_running() {
	[ -f "$PIDF" ] || return 1
	pid=$(cat "$PIDF" 2>/dev/null)
	[ -n "$pid" ] || return 1
	kill -0 "$pid" 2>/dev/null
}

ensure_tmp() {
	mkdir -p "$RUN"
	# extended-lite mipsle binary is ~15MB (stock builds are ~40MB), default /tmp is 24MB
	mount -o remount,size=48M /tmp 2>/dev/null
}

# Padavan's busybox wget is often built without TLS, curl is the safe choice.
fetch_url() {
	url="$1"
	out="$2"

	if command -v curl >/dev/null 2>&1; then
		if curl -fL --connect-timeout 20 --retry 2 --retry-delay 2 \
			-o "$out" "$url" >> "$LOG" 2>&1; then
			return 0
		fi
		log "curl failed: $url"
	fi

	if command -v wget >/dev/null 2>&1; then
		if wget -q --no-check-certificate -O "$out" "$url" >> "$LOG" 2>&1; then
			return 0
		fi
		log "wget failed: $url"
	fi

	return 1
}

fetch_core() {
	[ -x "$BIN" ] && return 0
	ensure_tmp
	rm -f /tmp/sb.tar.gz

	for u in "$CORE_URL" "$CORE_URL2"; do
		log "downloading core: $u"
		if fetch_url "$u" /tmp/sb.tar.gz && [ -s /tmp/sb.tar.gz ]; then
			break
		fi
		rm -f /tmp/sb.tar.gz
	done

	[ -s /tmp/sb.tar.gz ] || { log "core download failed (check DNS / https reachability)"; return 1; }

	rm -rf /tmp/sb_extract && mkdir -p /tmp/sb_extract
	tar -xzf /tmp/sb.tar.gz -C /tmp/sb_extract 2>>"$LOG" || { log "extract failed (tar/gzip?)"; return 1; }
	bin=$(find /tmp/sb_extract -type f -name 'sing-box' | head -n 1)
	[ -n "$bin" ] || { log "binary not found in archive"; return 1; }
	cp -f "$bin" "$BIN"
	chmod 755 "$BIN"
	rm -rf /tmp/sb_extract /tmp/sb.tar.gz
	log "core ready: $(ls -l "$BIN" | awk '{print $5}') bytes, $("$BIN" version 2>/dev/null | head -n1)"
	return 0
}

write_default_config() {
	[ -f "$CFG" ] && return 0
	mkdir -p "$DIR"
	cat > "$CFG" <<-EOF
	{
	  "log": { "level": "info", "timestamp": true },
	  "dns": {
	    "servers": [
	      { "tag": "local", "address": "223.5.5.5", "detour": "direct" },
	      { "tag": "remote", "address": "https://1.1.1.1/dns-query", "detour": "PROXY" }
	    ],
	    "rules": [ { "outbound": "any", "server": "local" } ],
	    "final": "local",
	    "independent_cache": true
	  },
	  "inbounds": [
	    { "type": "redirect", "tag": "redir-in", "listen": "0.0.0.0", "listen_port": $REDIR_PORT },
	    { "type": "tproxy", "tag": "tproxy-in", "listen": "0.0.0.0", "listen_port": $TPROXY_PORT },
	    { "type": "mixed", "tag": "mixed-in", "listen": "0.0.0.0", "listen_port": 7890 }
	  ],
	  "outbounds": [
	    { "type": "selector", "tag": "PROXY", "outbounds": [ "direct" ] },
	    { "type": "direct", "tag": "direct" }
	  ],
	  "route": {
	    "rules": [
	      { "ip_is_private": true, "outbound": "direct" },
	      { "ip_cidr": [ "127.0.0.0/8", "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16" ], "outbound": "direct" }
	    ],
	    "final": "PROXY",
	    "auto_detect_interface": true
	  }
	}
	EOF
	log "default config written"
}

apply_rules() {
	iptables -t nat -N SINGBOX 2>/dev/null
	iptables -t nat -F SINGBOX 2>/dev/null
	for n in 0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 \
	         172.16.0.0/12 192.168.0.0/16 224.0.0.0/4 240.0.0.0/4; do
		iptables -t nat -A SINGBOX -d $n -j RETURN
	done
	iptables -t nat -A SINGBOX -p tcp -j REDIRECT --to-ports $REDIR_PORT
	iptables -t nat -D PREROUTING -i br0 -j SINGBOX 2>/dev/null
	iptables -t nat -A PREROUTING -i br0 -j SINGBOX
	iptables -t nat -D OUTPUT -p tcp -j SINGBOX 2>/dev/null
	iptables -t nat -A OUTPUT -p tcp -j SINGBOX

	modprobe xt_TPROXY 2>/dev/null
	if [ -e /sys/module/xt_TPROXY ] || lsmod 2>/dev/null | grep -q xt_TPROXY; then
		ip rule add fwmark 1 table 100 2>/dev/null
		ip route add local default dev lo table 100 2>/dev/null
		iptables -t mangle -N SINGBOX 2>/dev/null
		iptables -t mangle -F SINGBOX 2>/dev/null
		for n in 0.0.0.0/8 10.0.0.0/8 127.0.0.0/8 169.254.0.0/16 \
		         172.16.0.0/12 192.168.0.0/16 224.0.0.0/4 240.0.0.0/4; do
			iptables -t mangle -A SINGBOX -d $n -j RETURN
		done
		iptables -t mangle -A SINGBOX -p tcp -j TPROXY --on-port $TPROXY_PORT --tproxy-mark 1
		iptables -t mangle -A SINGBOX -p udp -j TPROXY --on-port $TPROXY_PORT --tproxy-mark 1
		iptables -t mangle -D PREROUTING -i br0 -j SINGBOX 2>/dev/null
		iptables -t mangle -A PREROUTING -i br0 -j SINGBOX
		log "tproxy enabled (TCP+UDP)"
	else
		log "xt_TPROXY missing, TCP only"
	fi
}

clear_rules() {
	iptables -t nat -D PREROUTING -i br0 -j SINGBOX 2>/dev/null
	iptables -t nat -D OUTPUT -p tcp -j SINGBOX 2>/dev/null
	iptables -t nat -F SINGBOX 2>/dev/null
	iptables -t nat -X SINGBOX 2>/dev/null
	iptables -t mangle -D PREROUTING -i br0 -j SINGBOX 2>/dev/null
	iptables -t mangle -F SINGBOX 2>/dev/null
	iptables -t mangle -X SINGBOX 2>/dev/null
	ip rule del fwmark 1 table 100 2>/dev/null
	ip route flush table 100 2>/dev/null
}

do_start() {
	write_default_config
	fetch_core || return 1
	if is_running; then
		log "already running"
		return 0
	fi
	ensure_tmp
	"$BIN" check -c "$CFG" >> "$LOG" 2>&1 || { log "config check failed"; return 1; }
	"$BIN" run -c "$CFG" >> "$LOG" 2>&1 &
	echo $! > "$PIDF"
	sleep 3
	is_running || { log "start failed, see $LOG"; return 1; }
	apply_rules
	mkdir -p /etc/storage/dnsmasq
	grep -q "127.0.0.1#$DNS_PORT" /etc/storage/dnsmasq/dnsmasq.conf 2>/dev/null || \
		echo "server=127.0.0.1#$DNS_PORT" >> /etc/storage/dnsmasq/dnsmasq.conf
	restart_dnsmasq 2>/dev/null
	log "started (pid $(cat "$PIDF"))"
	return 0
}

do_stop() {
	clear_rules
	if is_running; then
		kill "$(cat "$PIDF")" 2>/dev/null
		sleep 1
		kill -9 "$(cat "$PIDF")" 2>/dev/null
	fi
	rm -f "$PIDF"
	restart_dnsmasq 2>/dev/null
	log "stopped"
	return 0
}

case "$1" in
	start)       do_start ;;
	stop)        do_stop ;;
	restart)     do_stop; do_start ;;
	apply)       write_default_config; do_stop; do_start ;;
	update-core) rm -f "$BIN"; fetch_core ;;
	status)
		if is_running; then echo "running $(cat "$PIDF")"; else echo "stopped"; fi
		;;
	*)
		echo "usage: $0 start|stop|restart|apply|update-core|status"
		exit 1
		;;
esac
