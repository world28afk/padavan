<!DOCTYPE html>
<html>
<head>
<title><#Web_Title#> - 插件管理</title>
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

function initial(){
	show_banner(1);
	show_menu(5,11,1);
	show_footer();
}

function pluginAction(cmd, name){
	if (cmd == 'rm' && !confirm('确定删除插件 ' + name + ' 吗？'))
		return;
	var f = document.getElementById('pluginForm');
	f.elements['plugin_cmd'].value = cmd;
	f.elements['plugin_name'].value = name;
	f.elements['plugin_code'].value = '';
	f.submit();
}

function pluginAdd(){
	var f = document.getElementById('pluginForm');
	var n = f.elements['plugin_name'].value;
	if (!/^[A-Za-z0-9_-]{1,32}$/.test(n)) {
		alert('插件名只能使用字母、数字、下划线和减号（最多 32 个字符）');
		return;
	}
	if (!f.elements['plugin_code'].value.replace(/\s/g, '')) {
		alert('请先填写插件脚本内容');
		return;
	}
	f.elements['plugin_cmd'].value = 'add';
	f.elements['plugin_autostart'].value = document.getElementById('plugin_auto').checked ? '1' : '0';
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
                            <h2 class="box_head round_top">插件管理</h2>
                            <div class="round_bottom">
                                <div class="row-fluid">
                                    <div id="tabMenu" class="submenuBlock"></div>
                                    <div class="alert alert-info" style="margin: 10px;">
                                        运行时插件：安装后无需重新编译固件。插件保存在
                                        <code>/etc/storage/plugins/&lt;名称&gt;/</code>，
                                        入口脚本支持 <code>start</code> / <code>stop</code> 参数，
                                        设置“开机自动启动”后由 rc 在开机时拉起。日志见 <code>/tmp/plugin/&lt;名称&gt;.log</code>。
                                    </div>

                                    <% plugin_list(); %>

                                    <hr>

                                    <form id="pluginForm" method="post" action="/apply.cgi" target="hidden_frame">
                                        <input type="hidden" name="action_mode" value=" PluginCmd ">
                                        <input type="hidden" name="plugin_cmd" value="add">
                                        <input type="hidden" name="plugin_autostart" value="0">
                                        <table width="100%" cellpadding="4" cellspacing="0" class="table">
                                            <tr>
                                                <th width="50%" style="border-top: 0 none;">插件名称</th>
                                                <td style="border-top: 0 none;">
                                                    <input type="text" class="input" name="plugin_name" maxlength="32" placeholder="my-plugin" />
                                                    <label class="checkbox inline"><input type="checkbox" id="plugin_auto" /> 开机自动启动</label>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th>插件脚本（main.sh）</th>
                                                <td>
                                                    <textarea name="plugin_code" rows="12" class="span12" spellcheck="false" style="font-family:'Courier New'; font-size:12px;" placeholder="#!/bin/sh&#10;case &quot;$1&quot; in&#10;start)&#10;    echo hello > /tmp/hello.log&#10;    ;;&#10;stop)&#10;    rm -f /tmp/hello.log&#10;    ;;&#10;esac"></textarea>
                                                </td>
                                            </tr>
                                            <tr>
                                                <td colspan="2" style="border-top: 0 none;">
                                                    <center>
                                                        <button type="button" class="btn btn-primary" style="width: 219px" onclick="pluginAdd();">添加插件</button>
                                                        <button type="button" class="btn" onclick="location.href='/Advanced_Plugin_Content.asp';">刷新列表</button>
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
