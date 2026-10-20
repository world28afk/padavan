/*
 * Clash / Mihomo YAML -> sing-box JSON, runs entirely in the browser.
 * Covers the protocols people actually get from airports:
 *   ss, vmess, vless(+reality), trojan, hysteria2, tuic
 *
 * usage: convertClashToSingbox(yamlText, mode)  mode: "rule" | "global"
 * returns: JSON string (pretty printed)
 */
function sbTag(name, i) {
	var t = String(name || ("node-" + i)).replace(/[\r\n\t]/g, " ").trim();
	return t.length ? t : ("node-" + i);
}

function sbTls(obj, server) {
	var sni = obj.servername || obj.sni || obj.host || server;
	var tls = { enabled: true, server_name: sni };
	if (obj["skip-cert-verify"] || obj.insecure)
		tls.insecure = true;
	if (obj["client-fingerprint"])
		tls.utls = { enabled: true, fingerprint: obj["client-fingerprint"] };
	if (obj.reality && (obj.reality["public-key"] || obj["public-key"])) {
		tls.reality = {
			enabled: true,
			public_key: obj.reality ? obj.reality["public-key"] : obj["public-key"],
			short_id: (obj.reality ? obj.reality["short-id"] : obj["short-id"]) || ""
		};
	}
	return tls;
}

function sbTransport(obj) {
	var net = obj.network || "tcp";
	if (net === "ws") {
		return {
			type: "ws",
			path: (obj["ws-opts"] && obj["ws-opts"].path) || obj.path || "/",
			headers: (obj["ws-opts"] && obj["ws-opts"].headers) || (obj.host ? { Host: obj.host } : undefined)
		};
	}
	if (net === "grpc") {
		return { type: "grpc", service_name: (obj["grpc-opts"] && obj["grpc-opts"]["grpc-service-name"]) || "" };
	}
	if (net === "h2") {
		return { type: "http", path: (obj["h2-opts"] && obj["h2-opts"].path) || "/", host: (obj["h2-opts"] && obj["h2-opts"].host) || [] };
	}
	return undefined;
}

function convertClashToSingbox(text, mode) {
	if (typeof jsyaml === "undefined")
		throw new Error("js-yaml 未加载");

	var doc = jsyaml.load(text);
	if (!doc || !doc.proxies || !doc.proxies.length)
		throw new Error("没有找到 proxies 节点（请确认是 Clash/Mihomo 订阅）");

	var outbounds = [], tags = [];
	doc.proxies.forEach(function (p, i) {
		var o = null, tag = sbTag(p.name, i);
		switch (p.type) {
		case "ss":
			o = { type: "shadowsocks", tag: tag, server: p.server, server_port: p.port,
			      method: p.cipher, password: String(p.password) };
			break;
		case "vmess":
			o = { type: "vmess", tag: tag, server: p.server, server_port: p.port,
			      uuid: p.uuid, security: p.cipher || "auto", alter_id: p.alterId || 0 };
			if (p.tls) o.tls = sbTls(p, p.servername || p.sni);
			if (p.network && p.network !== "tcp") o.transport = sbTransport(p);
			break;
		case "vless":
			o = { type: "vless", tag: tag, server: p.server, server_port: p.port, uuid: p.uuid };
			if (p.flow) o.flow = p.flow;
			if (p.tls || p.reality || p["reality-opts"]) {
				if (p["reality-opts"]) p.reality = p["reality-opts"];
				o.tls = sbTls(p, p.servername || p.sni);
			}
			if (p.network && p.network !== "tcp") o.transport = sbTransport(p);
			break;
		case "trojan":
			o = { type: "trojan", tag: tag, server: p.server, server_port: p.port, password: String(p.password) };
			o.tls = sbTls(p, p.sni || p.servername);
			if (p.network && p.network !== "tcp") o.transport = sbTransport(p);
			break;
		case "hysteria2":
		case "hy2":
			o = { type: "hysteria2", tag: tag, server: p.server, server_port: p.port, password: String(p.password) };
			o.tls = sbTls(p, p.sni || p.servername);
			if (p.up) o.up_mbps = parseInt(p.up, 10) || undefined;
			if (p.down) o.down_mbps = parseInt(p.down, 10) || undefined;
			if (p.obfs) o.obfs = { type: p.obfs, password: p["obfs-password"] || "" };
			break;
		case "tuic":
			o = { type: "tuic", tag: tag, server: p.server, server_port: p.port,
			      uuid: p.uuid, password: String(p.password) };
			o.tls = sbTls(p, p.sni || p.servername);
			if (p["congestion-controller"]) o.congestion_control = p["congestion-controller"];
			if (p["udp-relay-mode"]) o.udp_relay_mode = p["udp-relay-mode"];
			break;
		default:
			return;
		}
		Object.keys(o).forEach(function (k) { if (o[k] === undefined) delete o[k]; });
		outbounds.push(o);
		tags.push(tag);
	});

	if (!outbounds.length)
		throw new Error("没有可转换的节点（支持的协议：ss / vmess / vless / trojan / hysteria2 / tuic）");

	outbounds.push({ type: "selector", tag: "PROXY", outbounds: tags.concat(["direct"]), default: tags[0] });
	outbounds.push({ type: "direct", tag: "direct" });

	var rules = [{ ip_is_private: true, outbound: "direct" }];
	if (mode !== "global")
		rules = [
			{ ip_is_private: true, outbound: "direct" },
			{ domain_suffix: [".cn"], outbound: "direct" }
		];

	var cfg = {
		log: { level: "info", timestamp: true },
		dns: {
			servers: [
				{ tag: "local", address: "223.5.5.5", detour: "direct" },
				{ tag: "remote", address: "https://1.1.1.1/dns-query", detour: "PROXY" }
			],
			rules: [{ outbound: "any", server: "local" }],
			final: "local",
			independent_cache: true
		},
		inbounds: [
			{ type: "redirect", tag: "redir-in", listen: "0.0.0.0", listen_port: 7893 },
			{ type: "tproxy", tag: "tproxy-in", listen: "0.0.0.0", listen_port: 7894 },
			{ type: "mixed", tag: "mixed-in", listen: "0.0.0.0", listen_port: 7890 }
		],
		outbounds: outbounds,
		route: { rules: rules, final: "PROXY", auto_detect_interface: true }
	};

	return JSON.stringify(cfg, null, 2);
}
