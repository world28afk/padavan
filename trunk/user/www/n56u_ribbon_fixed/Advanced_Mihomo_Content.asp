<!DOCTYPE html>
<html>
<head>
<title><#Web_Title#> - Mihomo</title>
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
<script>

<% login_state_hook(); %>

var mihomo_state = "<% mihomo_status(); %>";

function initial(){
	show_banner(1);
	show_menu(5,8,5);
	show_footer();

	var parts = mihomo_state.split("|");
	var st = parts[0], cfg = parts[1];
	var el = document.getElementById("mh_status");
	if (st == "running") {
		el.className = "label label-success";
		el.innerHTML = "运行中";
	} else {
		el.className = "label label-warning";
		el.innerHTML = "已停止";
	}
	document.getElementById("mh_cfg").innerHTML = (cfg == "ok") ? "已保存" : "未保存";
}

function mhSubmit(cmd){
	if (cmd == "stop" && !confirm("确定停止 mihomo 并清理 iptables 规则？"))
		return;
	showLoading();
	var f = document.getElementById("mhForm");
	f.elements["mihomo_cmd"].value = cmd;
	f.submit();
}

function mhLoadFile(input){
	if (!input.files || !input.files[0])
		return;
	var file = input.files[0];
	if (file.size > 512 * 1024) {
		alert("配置文件过大（上限 512KB）");
		return;
	}
	var reader = new FileReader();
	reader.onload = function(e) {
		document.getElementById("mhForm").elements["mihomo_cfg"].value = e.target.result;
		alert("已载入 " + file.name + "，点击“保存配置”写入路由器");
	};
	reader.readAsText(file);
}

function mhSub(){
	var u = document.getElementById("mh_url").value;
	if (!/^https?:\/\//.test(u)) {
		alert("请填写 http/https 订阅地址");
		return;
	}
	var f = document.getElementById("mhForm");
	f.elements["mihomo_url"].value = u;
	f.elements["mihomo_cmd"].value = "sub";
	f.submit();
}

</script>
</head>

<body onload="initial();" onUnLoad="return unload_body();">

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

    <iframe name="hidden_frame" id="hidden_frame" src="" width="0" height="0" frameborder="0"></iframe>

    <div class="container-fluid">
        <div class="row-fluid">
            <div class="span3">
                <!--Sidebar content-->
                <!--=====Beginning of Main Menu=====-->
                <div class="well sidebar-nav side_nav" style="padding: 0px;">
                    <ul id="mainMenu" class="clearfix"></ul>
                    <ul class="clearfix">
                        <li>
                            <div id="subMenu" class="accordion"></div>
                        </li>
                    </ul>
                </div>
            </div>

            <div class="span9">
                <!--Body content-->
                <div class="row-fluid">
                    <div class="span12">
                        <div class="box well grad_colour_dark_blue">
                            <h2 class="box_head round_top">Mihomo（Clash.Meta）</h2>
                            <div class="round_bottom">
                                <div class="row-fluid">
                                    <div id="tabMenu" class="submenuBlock"></div>

                                    <div class="alert alert-info" style="margin: 10px;">
                                        内核不写进 flash（约 33MB），首次启动时自动下载到 <code>/tmp</code> 并运行；
                                        配置保存在 <code>/etc/storage/mihomo/config.yaml</code>。<br />
                                        支持 Clash/mihomo YAML；普通 base64 订阅请先用 subconverter（<code>target=clash</code>）转换。
                                    </div>

                                    <table width="100%" cellpadding="4" cellspacing="0" class="table">
                                        <tr>
                                            <th width="50%" style="border-top: 0 none;">运行状态</th>
                                            <td style="border-top: 0 none;">
                                                <span id="mh_status" class="label">未知</span>
                                                &nbsp;配置：<span id="mh_cfg">-</span>
                                            </td>
                                        </tr>
                                    </table>

                                    <form id="mhForm" method="post" action="/apply.cgi">
                                        <input type="hidden" name="action_mode" value=" MihomoCmd ">
                                        <input type="hidden" name="mihomo_cmd" value="">
                                        <input type="hidden" name="mihomo_url" value="">

                                        <table width="100%" cellpadding="4" cellspacing="0" class="table">
                                            <tr>
                                                <th width="50%">本地配置文件</th>
                                                <td>
                                                    <input type="file" id="mh_file" accept=".yaml,.yml,.conf,.txt" onchange="mhLoadFile(this);" />
                                                    <span class="help-block" style="margin-bottom:0;">选择 Flower_SS.yaml 之类的文件，内容会填入下方编辑框</span>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th>订阅地址（Clash YAML）</th>
                                                <td>
                                                    <input type="text" class="input span10" id="mh_url" placeholder="https://sub.example.com/...&flag=clash" />
                                                    <button type="button" class="btn" onclick="mhSub();">下载订阅</button>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th>配置内容</th>
                                                <td>
                                                    <textarea name="mihomo_cfg" rows="18" class="span12" spellcheck="false" style="font-family:'Courier New'; font-size:12px;"><% mihomo_conf(); %></textarea>
                                                </td>
                                            </tr>
                                            <tr>
                                                <td colspan="2" style="border-top: 0 none;">
                                                    <center>
                                                        <button type="button" class="btn" onclick="mhSubmit('save');">保存配置</button>
                                                        <button type="button" class="btn btn-primary" onclick="mhSubmit('save_start');">保存并启动</button>
                                                        <button type="button" class="btn" onclick="mhSubmit('stop');">停止</button>
                                                        <button type="button" class="btn" onclick="mhSubmit('update-core');">更新内核</button>
                                                        <button type="button" class="btn" onclick="location.href='/Advanced_Mihomo_Content.asp';">刷新</button>
                                                    </center>
                                                </td>
                                            </tr>
                                        </table>
                                    </form>

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
