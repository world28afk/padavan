<!DOCTYPE html>
<html>
<head>
<title><#Web_Title#> - 科学上网</title>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Expires" content="-1">

<link rel="shortcut icon" href="images/favicon.ico">
<link rel="icon" href="images/favicon.png">
<link rel="stylesheet" type="text/css" href="/bootstrap/css/bootstrap.min.css">
<link rel="stylesheet" type="text/css" href="/bootstrap/css/main.css">

<style>
.sb-card{border:0;border-radius:10px;background:#fff;box-shadow:0 2px 10px rgba(0,0,0,.08);margin-bottom:14px;overflow:hidden}
.sb-card>.hd{padding:10px 16px;background:linear-gradient(90deg,#1f6feb,#3b82f6);color:#fff;font-weight:600;font-size:14px;display:flex;align-items:center;gap:8px}
.sb-card>.bd{padding:14px 16px}
.sb-status{display:flex;align-items:center;flex-wrap:wrap;gap:14px}
.sb-dot{width:10px;height:10px;border-radius:50%;display:inline-block;margin-right:6px}
.sb-dot.on{background:#22c55e;box-shadow:0 0 0 3px rgba(34,197,94,.18)}
.sb-dot.off{background:#f59e0b;box-shadow:0 0 0 3px rgba(245,158,11,.18)}
.sb-meta{color:#64748b;font-size:12px}
.sb-toolbar{margin-left:auto;display:flex;gap:8px;flex-wrap:wrap}
.sb-toolbar .btn{border-radius:8px}
.sb-editor{width:100%;min-height:300px;font-family:Consolas,'Courier New',monospace;font-size:12px;line-height:1.5;border:1px solid #e2e8f0;border-radius:8px;padding:10px;background:#0f172a;color:#e2e8f0}
.sb-log{max-height:240px;overflow:auto;background:#0f172a;color:#cbd5e1;font-family:Consolas,monospace;font-size:12px;border-radius:8px;padding:10px;white-space:pre-wrap}
.sb-row{display:flex;gap:10px;flex-wrap:wrap;align-items:center;margin-bottom:10px}
.sb-row .form-control{border-radius:8px}
.sb-hint{color:#94a3b8;font-size:12px;margin-top:6px}
.sb-badge{border-radius:999px;padding:4px 12px;font-size:12px;font-weight:600}
.sb-badge.on{background:#dcfce7;color:#166534}
.sb-badge.off{background:#fef3c7;color:#92400e}
.sb-pill{background:#f1f5f9;border-radius:999px;padding:4px 10px;font-size:12px;color:#475569}
</style>

<script type="text/javascript" src="/jquery.js"></script>
<script type="text/javascript" src="/state.js"></script>
<script type="text/javascript" src="/general.js"></script>
<script type="text/javascript" src="/popup.js"></script>
<script type="text/javascript" src="/js-yaml.min.js"></script>
<script type="text/javascript" src="/singbox-conv.js"></script>
<script>

<% login_state_hook(); %>

var sb_state = "<% proxy_status(); %>";

function initial(){
	show_banner(1);
	show_menu(5,8,5);
	show_footer();

	var p = sb_state.split("|");
	var running = (p[0] == "running");
	var size = parseInt(p[1] || "0", 10);

	var badge = document.getElementById("sb_badge");
	badge.className = "sb-badge " + (running ? "on" : "off");
	badge.innerHTML = running ? "运行中" : "已停止";

	document.getElementById("sb_dot").className = "sb-dot " + (running ? "on" : "off");
	document.getElementById("sb_size").innerHTML = size ? (size + " 字节") : "未配置";

}

function sbSubmit(cmd){
	if (cmd == "stop" && !confirm("停止后所有设备将直连，确定？"))
		return;
	if (cmd == "update-core" && !confirm("重新下载内核（约 10-20MB），确定？"))
		return;
	showLoading();
	var f = document.getElementById("sb_form");
	f.elements["proxy_cmd"].value = cmd;
	f.submit();
}

function sbMode(){ return document.getElementById("sb_mode").value; }

function sbLoadFile(input){
	if (!input.files || !input.files[0]) return;
	var file = input.files[0];
	if (file.size > 1024 * 1024) { alert("配置文件过大（上限 1MB）"); return; }

	var reader = new FileReader();
	reader.onload = function(e){
		var text = e.target.result;
		sbApplyText(text, file.name);
	};
	reader.readAsText(file);
}

function sbApplyText(text, name){
	var ta = document.getElementById("sb_cfg");
	var trimmed = text.replace(/^\s+/, "");

	if (trimmed.charAt(0) == "{") {
		ta.value = text;
		sbToast("已载入 sing-box 配置：" + (name || "粘贴内容"));
		return;
	}

	try {
		ta.value = convertClashToSingbox(text, sbMode());
		sbToast("已把 Clash 订阅转换为 sing-box 配置（" + (name || "粘贴内容") + "）");
	} catch (err) {
		alert("转换失败：" + err.message);
	}
}

function sbFetchSub(){
	var u = document.getElementById("sb_url").value;
	if (!/^https?:\/\//.test(u)) { alert("请填写 http/https 订阅地址"); return; }
	showLoading();
	var f = document.getElementById("sb_form");
	f.elements["proxy_url"].value = u;
	f.elements["proxy_cmd"].value = "sub";
	f.submit();
}

function sbSaveCore(){
	var u = document.getElementById("sb_core_url").value;
	if (!/^https?:\/\//.test(u)) { alert("请填写内核下载地址"); return; }
	showLoading();
	var f = document.getElementById("sb_form");
	f.elements["proxy_core"].value = u;
	f.elements["proxy_cmd"].value = "coreurl";
	f.submit();
}

function sbToast(msg){
	var t = document.getElementById("sb_toast");
	t.innerHTML = msg;
	t.style.display = "block";
	setTimeout(function(){ t.style.display = "none"; }, 4000);
}

</script>
</head>

<body onload="initial();" onunLoad="return unload_body();">

<div class="wrapper">
    <div class="container-fluid" style="padding-right: 0px">
        <div class="row-fluid">
            <div class="span3"><center><div id="logo"></div></center></div>
            <div class="span9" >
                <div id="TopBanner"></div>
            </div>
        </div>
    </div>

    <div id="Loading" class="popup_bg"></div>

    <div class="container-fluid">
        <div class="row-fluid">
            <div class="span3">
                <div class="well sidebar-nav side_nav" style="padding: 0px;">
                    <ul id="mainMenu" class="clearfix"></ul>
                    <ul class="clearfix">
                        <li><div id="subMenu" class="accordion"></div></li>
                    </ul>
                </div>
            </div>

            <div class="span9">
                <div class="row-fluid">
                    <div class="span12">
                        <div id="tabMenu" class="submenuBlock"></div>

                        <div id="sb_toast" class="alert alert-success" style="display:none;margin:10px 0;"></div>

                        <form id="sb_form" method="post" action="/apply.cgi">
                            <input type="hidden" name="action_mode" value=" ProxyCmd ">
                            <input type="hidden" name="proxy_cmd" value="">
                            <input type="hidden" name="proxy_url" value="">
                            <input type="hidden" name="proxy_core" value="">

                            <!-- 状态 -->
                            <div class="sb-card">
                                <div class="hd">状态</div>
                                <div class="bd">
                                    <div class="sb-status">
                                        <span id="sb_badge" class="sb-badge off">读取中…</span>
                                        <span class="sb-meta"><i id="sb_dot" class="sb-dot off"></i>sing-box 内核</span>
                                        <span class="sb-pill">配置：<span id="sb_size">-</span></span>
                                        <span class="sb-pill">代理端口 7890 / 透明 7893</span>
                                        <span class="sb-toolbar">
                                            <button type="button" class="btn btn-success btn-small" onclick="sbSubmit('start');">启动</button>
                                            <button type="button" class="btn btn-warning btn-small" onclick="sbSubmit('stop');">停止</button>
                                            <button type="button" class="btn btn-small" onclick="sbSubmit('restart');">重启</button>
                                            <button type="button" class="btn btn-small" onclick="sbSubmit('update-core');">更新内核</button>
                                        </span>
                                    </div>
                                </div>
                            </div>

                            <!-- 导入 -->
                            <div class="sb-card">
                                <div class="hd">导入节点</div>
                                <div class="bd">
                                    <div class="sb-row">
                                        <label class="btn btn-primary btn-small" style="margin:0;">
                                            选择本地文件<input type="file" id="sb_file" accept=".yaml,.yml,.json,.txt" onchange="sbLoadFile(this);" style="display:none;" />
                                        </label>
                                        <span class="sb-hint">支持 Clash/Mihomo YAML（自动转 sing-box）或 sing-box JSON</span>
                                    </div>
                                    <div class="sb-row">
                                        <select id="sb_mode" class="form-control" style="width:120px;">
                                            <option value="rule">规则模式</option>
                                            <option value="global">全局模式</option>
                                        </select>
                                        <span class="sb-hint">规则模式：内网与 .cn 直连，其余走代理</span>
                                    </div>
                                    <div class="sb-row">
                                        <input type="text" id="sb_url" class="form-control" style="flex:1;min-width:260px;" placeholder="订阅地址（.yaml，返回 Clash 配置）" />
                                        <button type="button" class="btn btn-small" onclick="sbFetchSub();">下载订阅</button>
                                    </div>
                                    <div class="sb-hint">订阅会直接保存为 sing-box 配置，因此地址必须返回 sing-box JSON；返回 Clash YAML 的订阅请先「选择本地文件」转换。</div>
                                </div>
                            </div>

                            <!-- 配置 -->
                            <div class="sb-card">
                                <div class="hd">配置 (config.json)</div>
                                <div class="bd">
                                    <textarea id="sb_cfg" name="proxy_cfg" class="sb-editor" spellcheck="false"><% proxy_conf(); %></textarea>
                                    <div class="sb-row" style="margin-top:10px;justify-content:flex-end;">
                                        <button type="button" class="btn btn-small" onclick="sbSubmit('save');">保存配置</button>
                                        <button type="button" class="btn btn-primary btn-small" onclick="sbSubmit('save_start');">保存并应用</button>
                                    </div>
                                </div>
                            </div>

                            <!-- 内核地址 -->
                            <div class="sb-card">
                                <div class="hd">内核</div>
                                <div class="bd">
                                    <div class="sb-row">
                                        <input type="text" id="sb_core_url" class="form-control" style="flex:1;min-width:260px;" value="<% nvram_get_x("","sb_core_url"); %>" placeholder="sing-box mipsle 内核下载地址" />
                                        <button type="button" class="btn btn-small" onclick="sbSaveCore();">保存地址</button>
                                    </div>
                                    <div class="sb-hint">默认 <span id="sb_core_view">https://github.com/yandexru45/sing-box-extended-lite/releases/latest/download/sing-box-extended-lite-linux-mipsle-softfloat.tar.gz</span>；内核约 15MB（extended-lite），运行时放在 /tmp（tmpfs 48MB）。</div>
                                </div>
                            </div>
                        </form>

                        <!-- 日志 -->
                        <div class="sb-card">
                            <div class="hd">运行日志 <span class="sb-hint" style="color:#dbeafe;">最近 8KB</span></div>
                            <div class="bd">
                                <div class="sb-log"><% proxy_log(); %></div>
                                <div style="text-align:right;margin-top:8px;">
                                    <button type="button" class="btn btn-small" onclick="location.href='/Advanced_Proxy_Content.asp';">刷新</button>
                                </div>
                            </div>
                        </div>

                    </div>
                </div>
            </div>
        </div>
    </div>

    <div id="footer"></div>
</div>
</body>
</html>
