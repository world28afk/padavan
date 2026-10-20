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
	badge.className = "label " + (running ? "label-success" : "label-warning");
	badge.innerHTML = running ? "运行中" : "已停止";

	document.getElementById("sb_size").innerHTML = size ? (size + " 字节") : "未配置";
}

function sbSubmit(cmd){
	if (cmd == "stop" && !confirm("停止后所有设备将直连，确定？"))
		return;
	if (cmd == "update-core" && !confirm("重新下载内核（约 15MB），确定？"))
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
	reader.onload = function(e){ sbApplyText(e.target.result, file.name); };
	reader.readAsText(file);
}

function sbApplyText(text, name){
	var ta = document.getElementById("sb_cfg");
	if (text.replace(/^\s+/, "").charAt(0) == "{") {
		ta.value = text;
		alert("已载入 sing-box 配置：" + (name || "粘贴内容"));
		return;
	}
	try {
		ta.value = convertClashToSingbox(text, sbMode());
		alert("已把 Clash 订阅转换为 sing-box 配置（" + (name || "粘贴内容") + "），确认后点「保存并应用」");
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
                <!--Sidebar content-->
                <div class="well sidebar-nav side_nav" style="padding: 0px;">
                    <ul id="mainMenu" class="clearfix"></ul>
                    <ul class="clearfix">
                        <li><div id="subMenu" class="accordion"></div></li>
                    </ul>
                </div>
            </div>

            <div class="span9">
                <!--Body content-->
                <div class="row-fluid">
                    <div class="span12">
                        <div class="box well grad_colour_dark_blue">
                            <h2 class="box_head round_top"><#menu5_10#> - 科学上网</h2>
                            <div class="round_bottom">
                                <div class="row-fluid">
                                    <div id="tabMenu" class="submenuBlock"></div>

                                    <form id="sb_form" method="post" action="/apply.cgi">
                                    <input type="hidden" name="action_mode" value=" ProxyCmd ">
                                    <input type="hidden" name="proxy_cmd" value="">
                                    <input type="hidden" name="proxy_url" value="">
                                    <input type="hidden" name="proxy_core" value="">

                                    <table width="100%" cellpadding="4" cellspacing="0" class="table">
                                        <tr><th colspan="2" style="background-color: #E3E3E3;">运行状态</th></tr>
                                        <tr>
                                            <th width="50%" style="border-top: 0 none;">sing-box</th>
                                            <td style="border-top: 0 none;">
                                                <span id="sb_badge" class="label">读取中…</span>
                                                &nbsp;&nbsp;配置：<span id="sb_size">-</span>
                                                <div class="form-inline" style="margin-top: 8px;">
                                                    <button type="button" class="btn btn-small btn-primary" onclick="sbSubmit('start');">启动</button>
                                                    <button type="button" class="btn btn-small" onclick="sbSubmit('stop');">停止</button>
                                                    <button type="button" class="btn btn-small" onclick="sbSubmit('restart');">重启</button>
                                                    <button type="button" class="btn btn-small" onclick="sbSubmit('update-core');">更新内核</button>
                                                    <button type="button" class="btn btn-small" onclick="location.href='/Advanced_Proxy_Content.asp';">刷新</button>
                                                </div>
                                            </td>
                                        </tr>
                                        <tr>
                                            <th>代理端口</th>
                                            <td>HTTP/SOCKS 混合 7890　透明 TCP 7893　透明 TCP+UDP 7894</td>
                                        </tr>
                                    </table>

                                    <table width="100%" cellpadding="4" cellspacing="0" class="table">
                                        <tr><th colspan="2" style="background-color: #E3E3E3;">导入节点</th></tr>
                                        <tr>
                                            <th width="50%" style="border-top: 0 none;">本地文件</th>
                                            <td style="border-top: 0 none;">
                                                <input type="file" id="sb_file" accept=".yaml,.yml,.json,.txt" onchange="sbLoadFile(this);" />
                                                <div class="help-block" style="margin-bottom: 0;">支持 Clash / Mihomo YAML（浏览器内自动转 sing-box）或 sing-box JSON</div>
                                            </td>
                                        </tr>
                                        <tr>
                                            <th>规则模式</th>
                                            <td>
                                                <select id="sb_mode" class="input">
                                                    <option value="rule">规则模式（内网 / .cn 直连）</option>
                                                    <option value="global">全局模式（全部走代理）</option>
                                                </select>
                                            </td>
                                        </tr>
                                        <tr>
                                            <th>订阅地址</th>
                                            <td>
                                                <input type="text" id="sb_url" class="input span8" placeholder="https://…/singbox.json" />
                                                <button type="button" class="btn btn-small" onclick="sbFetchSub();">下载订阅</button>
                                                <div class="help-block" style="margin-bottom: 0;">地址需返回 sing-box JSON；返回 Clash YAML 的订阅请用上面的「本地文件」导入转换</div>
                                            </td>
                                        </tr>
                                    </table>

                                    <table width="100%" cellpadding="4" cellspacing="0" class="table">
                                        <tr><th colspan="2" style="background-color: #E3E3E3;">配置 (config.json)</th></tr>
                                        <tr>
                                            <td colspan="2">
                                                <textarea id="sb_cfg" name="proxy_cfg" rows="18" class="span12" spellcheck="false" style="font-family:'Courier New'; font-size:12px;"><% proxy_conf(); %></textarea>
                                                <center>
                                                    <button type="button" class="btn btn-small" onclick="sbSubmit('save');">保存配置</button>
                                                    <button type="button" class="btn btn-small btn-primary" onclick="sbSubmit('save_start');">保存并应用</button>
                                                </center>
                                            </td>
                                        </tr>
                                    </table>

                                    <table width="100%" cellpadding="4" cellspacing="0" class="table">
                                        <tr><th colspan="2" style="background-color: #E3E3E3;">内核</th></tr>
                                        <tr>
                                            <td colspan="2">
                                                <input type="text" id="sb_core_url" class="input span8" value="<% nvram_get_x("","sb_core_url"); %>" placeholder="https://github.com/yandexru45/sing-box-extended-lite/releases/latest/download/sing-box-extended-lite-linux-mipsle-softfloat.tar.gz" />
                                                <button type="button" class="btn btn-small" onclick="sbSaveCore();">保存地址</button>
                                                <div class="help-block" style="margin-bottom: 0;">
                                                    留空使用默认 extended-lite（约 15MB，下载到 /tmp 运行）；网络不通可换成 ghfast.top / gh-proxy 前缀的镜像地址
                                                </div>
                                            </td>
                                        </tr>
                                    </table>

                                    </form>

                                    <table width="100%" cellpadding="4" cellspacing="0" class="table">
                                        <tr><th style="background-color: #E3E3E3;">运行日志（最近 8KB）</th></tr>
                                        <tr>
                                            <td>
                                                <pre style="max-height: 240px; overflow: auto; background: #f7f7f9; border: 1px solid #e1e1e8; border-radius: 4px; padding: 8px; font-size: 12px;"><% proxy_log(); %></pre>
                                            </td>
                                        </tr>
                                    </table>

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
