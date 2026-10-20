# Padavan for PHICOMM K2P (TurBoTse fork)

K2P 可用的 Padavan 4.4 内核固件维护仓库：在原作者 [TurBoTse](https://github.com/TurBoTse) 的
[TurBoTse/padavan](https://github.com/TurBoTse/padavan) 基础上修复已知问题、增强 WebUI、并新增
**运行时插件系统**（装好固件后仍然可以在后台加插件，无需重新编译）。

- 原作者 / 上游仓库：**TurBoTse** — <https://github.com/TurBoTse/padavan>
- 更上游：hanwckf/rt-n56u、原始 Padavan (rt-n56u) 项目
- 许可证：**GNU GPL v2**（见 [LICENSE](LICENSE)，与上游 Padavan 项目一致）
- 目标设备：PHICOMM K2P / K2P-USB / K2P-NANO（MT7621 + MT7615D），其余 50+ 机型沿用上游板级配置

## 本仓库做了什么

### 1. 问题修复（对应上游 issue）

| Issue | 现象 | 根因 / 修复 |
| :-- | :-- | :-- |
| [#15](https://github.com/TurBoTse/padavan/issues/15) k2p 科学上网不能用 | 开启 SS/Xray/Trojan 后无法代理 | K2P 内核配置里 `CONFIG_IP_SET` 被关闭，而 `ss-rules`/`shadowsocks.sh` 全程依赖 `ipset`（`china`、`gfwlist` 集合），`ipset` 命令全部失败导致透明代理链建不起来。已在 `configs/boards/K2P{,-USB}/kernel-4.4.x.config` 打开 IP_SET 全家桶 + `NETFILTER_XT_SET` |
| [#30](https://github.com/TurBoTse/padavan/issues/30) 网络连接问题 | AP 模式仍下发本机网段；右上角重启 / 系统重置后变成交换机状态、拿到上级路由 IP | ① 重启按钮不落盘 `nvram` 就 reboot，WebUI 里刚改的模式/网络参数丢失 → `sys_reboot()` 前强制 `nvram_commit_safe()`；② DHCP 地址池为空/非法时 dnsmasq 起不来，客户端回落到上级 DHCP → 启动时按 LAN 地址自动修复 `dhcp_start/dhcp_end`，并在 `rc` 里做一次启动自愈重试；③ 按要求移除右上角“关机”按钮 |
| [#31](https://github.com/TurBoTse/padavan/issues/31) UI 优化 | 功能开关样式不习惯；右上角固件信息看不到原作者和编译时间 | ① `itoggle.js` 改回老毛子的“是 / 否”原生单选框（去掉 iOS 风格图片开关）；② 右上角固件信息新增“原作者（可点击跳转上游仓库）”和“编译时间”，由 `versions.inc` → `cflags.mk` → `common_ex.c` 注入 |

> **代理内核现状（2026-10 基线）**：按要求已整体移除原「科学上网」栈 ——
> shadowsocks-libev / shadowsocksr-libev / Xray / v2ray / Trojan / sing-box / naiveproxy /
> simple-obfs / ipt2socks / chinadns-ng / chnroute / dns2tcp / dnsproxy / redsocks / xTun / wing /
> resolveip / skipdbv2，以及对应的 WebUI 页面、菜单项和 rc 钩子（`APP_SHADOWSOCKS`）。
> 内核侧保留 `IP_SET`/`NETFILTER_XT_SET` 能力，便于后续重新实现代理模块。
### 2. 内网 / 外网 MAC 地址修改 + 随机 MAC

- 外网 MAC：原本已有（`Advanced_WAN_Content.asp` 的 `wan_hwaddr_x`），保留并新增“随机”按钮。
- 内网 MAC：新增 `lan_hwaddr_x`（`Advanced_LAN_Content.asp`），留空则使用出厂 MAC；
  写入后由 `reset_lan_vars()` 在 LAN 重建时套用，`variables.c` 中登记 `EVM_RESTART_LAN` 使保存后立即重建 LAN。
- 随机按钮由 `general.js: randomMAC()` 生成：6 字节、单播、本地管理位（`xx & 0xFC | 0x02`），
  12 位大写十六进制，符合 `validate_hwaddr()` 的校验规则。

### 3. 运行时插件系统（无需重新编译固件）

上游的插件（ss / xray / frp / smartdns …）都是编译期开关（`CONFIG_FIRMWARE_INCLUDE_*`），
换插件必须重新编译。本仓库增加了一套运行时插件框架：

- 后端：`/sbin/plugin-mgr`（`trunk/user/pluginmgr/`），插件持久化在 `/etc/storage/plugins/<name>/`
- WebUI：左侧「高级设置 → 插件管理」（与「系统管理」同级）新增插件面板，可在线添加脚本、启动/停止、删除、开关开机自启
- 开机自启：`rc` 在服务启动后执行 `plugin-mgr autostart`
- 插件目录结构：

```
/etc/storage/plugins/<name>/
├── main.sh        # 入口脚本，支持 start / stop（必填，添加插件时由页面写入）
└── plugin.conf    # NAME= / VERSION= / AUTOSTART=0|1 / INSTALLED=
```

`main.sh` 会收到环境变量 `PLUGIN_NAME`、`PLUGIN_DIR`、`PLUGIN_RUN_DIR`，运行日志在
`/tmp/plugin/<name>.log`，PID 在 `/tmp/plugin/<name>.pid`。

最小示例：

```sh
#!/bin/sh
case "$1" in
start)
    echo hello > /tmp/hello.log
    ;;
stop)
    rm -f /tmp/hello.log
    ;;
esac
```

也支持命令行管理：

```sh
plugin-mgr list
plugin-mgr add demo 1 /tmp/demo.sh     # 名称 / 是否开机自启 / 脚本路径
plugin-mgr start demo
plugin-mgr stop demo
plugin-mgr enable demo
plugin-mgr rm demo
```

> 注意：插件保存在 `/etc/storage`（NVRAM 之外的持久分区），大文件请放到 U 盘 / `/opt`，不要在
> `/etc/storage` 里塞几十 MB 的东西。

### 4. 5GHz 跑不满（80MHz 被降成 40MHz）

`trunk/user/rc/src/ralink.c` 在生成 `/etc/Wireless/iNIC/iNIC_ap.dat` 时，把 WebUI 的
`wl_HT_BW`（0=20M / 1=40M / 2=80M / 3=160M）写入驱动 `VHT_BW` 时做了一次错误钳位：

```c
/* 修复前：80MHz(2) 被压成 40MHz(1) */
i_val = (i_val > 1) ? 1 : 0;
fprintf(fp, "VHT_BW=%d\n", i_val);
```

K2P 是 `BOARD_MT7615_DBDC`，于是无论怎么选 80MHz，驱动拿到的都是 `VHT_BW=1`（VHT40 = 300Mbps PHY），
这正好对应“靠近路由 5G 也只有 300Mbps”；有线走 MT7621 硬件 NAT 所以能跑满 900Mbps+。

修复后按 0/1/2/3 原样下发，DBDC 芯片最高 80MHz，非 DBDC 但驱动不支持 160MHz 的平台仍回落到 80MHz。

刷机后自查：

```sh
grep -E '^(HT_BW|VHT_BW)=' /etc/Wireless/iNIC/iNIC_ap.dat   # 5G 应为 VHT_BW=2
iwpriv rai0 get HtBw ; iwpriv rai0 get VhtBw                   # 运行时确认
```

另外 5G 想跑到 400Mbps+ 还需要：频道选 149/153/157/161（80MHz）、带宽选 20/40/80、加密用 AES
（TKIP 会掉到 54Mbps）、客户端本身是 2x2 11ac。MT7621 没有 WED，无线转发仍是 CPU 转发，
2x2 80MHz 的实测上限大约 450~550Mbps。

## 编译

依赖（Debian/Ubuntu 22.04）：

```sh
sudo apt install unzip libtool-bin ccache curl cmake gperf gawk flex bison nano xxd \
    fakeroot kmod cpio bc zip git python3-docutils gettext automake autopoint \
    texinfo build-essential help2man pkg-config zlib1g-dev libgmp3-dev \
    libmpc-dev libmpfr-dev libncurses5-dev libltdl-dev wget libc-dev-bin liblzma-dev
```

编译：

```sh
make K2P          # 产物在 trunk/images/*.trx
make K2P-USB
make clean        # 换机型前清理
```

顶层 `Makefile` 会自动下载预编译工具链（`releases/download/toolchain/mipsel-linux-musl.tar.xz`），
失败时回退到 `toolchain/` 里的 crosstool-NG 源码构建。

GitHub Actions（`.github/workflows/build.yml`）在推送后自动编译 `K2P`、`K2P-USB` 并发布 trx。
`custom.yml` 支持手动选机型 / 超频 / 插件 JSON。

## 支持的设备

沿用上游 55 个板级配置：K2P、K2P-USB、K2P-NANO、MI-R3G / R3P / 4 / 4A、NEWIFI3、RM2100、CR660x、
DIR-878/882、JCG 系列、MSG1500、ZTE-E8820S/V2、ZTT-RX6000、NETGEAR R6800/R7450/BZV 等。

## 致谢

- Padavan / rt-n56u 原始项目及其社区
- [hanwckf/rt-n56u](https://github.com/hanwckf/rt-n56u)
- **TurBoTse** — 本仓库的上游：[TurBoTse/padavan](https://github.com/TurBoTse/padavan)
- 各机型适配作者（见 README 历史与 `trunk/configs/boards/`）

刷机有风险，请先备份 breed / 原厂固件，风险自负。
