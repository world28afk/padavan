#!/bin/sh
#
# mihomo runtime manager for Padavan (K2P / mipsel)
#
# The mihomo core is ~33MB uncompressed and does not fit into the 16MB flash
# of a plain K2P, so it is fetched on demand into /tmp (tmpfs) and executed
# from there.  Configuration lives in /etc/storage/mihomo (persistent).
#
# usage: mihomo.sh start|stop|restart|status|update-core
#
# Copyright (C) 2026 world28
# GPL-2.0

DIR=/etc/storage/mihomo
RUN_DIR=/tmp/mihomo
BIN=$RUN_DIR/mihomo
LOG=$RUN_DIR/mihomo.log
PIDF=$RUN_DIR/mihomo.pid
CFG=$DIR/config.yaml
CORE_URL=$(nvram get mihomo_core_url)
[ -n "$CORE_URL" ] || CORE_URL="https://github.com/MetaCubeX/mihomo/releases/download/v1.19.30/mihomo-linux-mipsle-softfloat-v1.19.30.gz"
REDIR_PORT=7893
TPROXY_PORT=7894
MIXED_PORT=7890
DNS_PORT=1053
MARK=255

log() {
	logger -t mihomo "$@" 2>/dev/null
	echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG" 2>/dev/null
}

is_running() {
	[ -f "$PIDF" ] || return 1
	pid=$(cat "$PIDF" 2>/dev/null)
	[ -n "$pid" ] || return 1
	kill -0 "$pid" 2>/dev/null
}

ensure_tmp() {
	# mihomo needs ~35MB, default /tmp is 24MB
	mkdir -p "$RUN_DIR"
	mount -o remount,size=64M /tmp 2>/dev/null
}

fetch_core() {
	[ -x "$BIN" ] && return 0
	ensure_tmp
	log "downloading core: $CORE_URL"
	rm -f /tmp/mihomo.gz
	if ! wget -q -O /tmp/mihomo.gz "$CORE_URL"; then
		log "core download failed"
		return 1
	fi
	gzip -dc /tmp/mihomo.gz > "$BIN" || { log "gunzip failed"; rm -f /tmp/mihomo.gz; return 1; }
	chmod 755 "$BIN"
	rm -f /tmp/mihomo.gz
	log "core ready: $(ls -l "$BIN" | awk '{print $5}') bytes"
	return 0
}

apply_rules() {
	# TCP transparent proxy (REDIRECT)
	iptables -t nat -N MIHOMO 2>/dev/null
	iptables -t nat -F MIHOMO 2>/dev/null
	for n in 0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 \
	         172.16.0.0/12 192.168.0.0/16 224.0.0.0/4 240.0.0.0/4; do
		iptables -t nat -A MIHOMO -d $n -j RETURN
	done
	iptables -t nat -A MIHOMO -p tcp -m mark --mark 0x$MARK -j RETURN
	iptables -t nat -A MIHOMO -p tcp -j REDIRECT --to-ports $REDIR_PORT
	iptables -t nat -D PREROUTING -i br0 -j MIHOMO 2>/dev/null
	iptables -t nat -A PREROUTING -i br0 -j MIHOMO
	iptables -t nat -D OUTPUT -p tcp -j MIHOMO 2>/dev/null
	iptables -t nat -A OUTPUT -p tcp -j MIHOMO

	# UDP + TCP via TPROXY if the module is available
	modprobe xt_TPROXY 2>/dev/null
	if lsmod 2>/dev/null | grep -q xt_TPROXY || [ -e /sys/module/xt_TPROXY ]; then
		ip rule add fwmark 1 table 100 2>/dev/null
		ip route add local default dev lo table 100 2>/dev/null
		iptables -t mangle -N MIHOMO 2>/dev/null
		iptables -t mangle -F MIHOMO 2>/dev/null
		for n in 0.0.0.0/8 10.0.0.0/8 127.0.0.0/8 169.254.0.0/16 \
		         172.16.0.0/12 192.168.0.0/16 224.0.0.0/4 240.0.0.0/4; do
			iptables -t mangle -A MIHOMO -d $n -j RETURN
		done
		iptables -t mangle -A MIHOMO -p tcp -j TPROXY --on-port $TPROXY_PORT --tproxy-mark 1
		iptables -t mangle -A MIHOMO -p udp -j TPROXY --on-port $TPROXY_PORT --tproxy-mark 1
		iptables -t mangle -D PREROUTING -i br0 -j MIHOMO 2>/dev/null
		iptables -t mangle -A PREROUTING -i br0 -j MIHOMO
		log "tproxy enabled"
	else
		log "xt_TPROXY not available, TCP only"
	fi
}

clear_rules() {
	iptables -t nat -D PREROUTING -i br0 -j MIHOMO 2>/dev/null
	iptables -t nat -D OUTPUT -p tcp -j MIHOMO 2>/dev/null
	iptables -t nat -F MIHOMO 2>/dev/null
	iptables -t nat -X MIHOMO 2>/dev/null
	iptables -t mangle -D PREROUTING -i br0 -j MIHOMO 2>/dev/null
	iptables -t mangle -F MIHOMO 2>/dev/null
	iptables -t mangle -X MIHOMO 2>/dev/null
	ip rule del fwmark 1 table 100 2>/dev/null
	ip route flush table 100 2>/dev/null
}

do_start() {
	[ -f "$CFG" ] || { log "no config at $CFG"; return 1; }
	fetch_core || return 1
	if is_running; then
		log "already running"
		return 0
	fi
	ensure_tmp
	GOMEMLIMIT=48MiB GOGC=50 "$BIN" -d "$DIR" -f "$CFG" \
		-ext-ctl 0.0.0.0:9090 >> "$LOG" 2>&1 &
	echo $! > "$PIDF"
	sleep 3
	if ! is_running; then
		log "start failed, see $LOG"
		return 1
	fi
	apply_rules
	# dnsmasq -> mihomo dns (fake-ip)
	if ! grep -q "127.0.0.1#$DNS_PORT" /etc/storage/dnsmasq/dnsmasq.conf 2>/dev/null; then
		mkdir -p /etc/storage/dnsmasq
		echo "server=127.0.0.1#$DNS_PORT" >> /etc/storage/dnsmasq/dnsmasq.conf
	fi
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
	start)   do_start ;;
	stop)    do_stop ;;
	restart) do_stop; do_start ;;
	status)
		if is_running; then echo "running $(cat "$PIDF")"; else echo "stopped"; fi
		;;
	update-core)
		rm -f "$BIN"; fetch_core
		;;
	*)
		echo "usage: $0 start|stop|restart|status|update-core"
		exit 1
		;;
esac
