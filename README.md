# Padavan for PHICOMM K2P

基于 [TurBoTse/padavan](https://github.com/TurBoTse/padavan) 维护的 Padavan 4.4 内核固件仓库，
面向 MT7621 平台的 PHICOMM K2P 系列路由器（K2P / K2P-USB / K2P-NANO），
在保留上游构建体系与板级适配的前提下，提供更精简的功能集与更完整的运行时可扩展能力。

- 上游项目：**TurBoTse** — <https://github.com/TurBoTse/padavan>
- 更上游：hanwckf/rt-n56u、原始 Padavan（rt-n56u）项目
- 许可证：**GNU GPL v2**（见 [LICENSE](LICENSE)）
- 目标平台：MT7621 + MT7615D / MT7915D，16MB flash，128MB 内存

## 功能概览

### 系统与网络

- Linux 4.4 内核，MT7621 硬件 NAT（`CONFIG_RA_NAT_HW`）与 SFE 快转
- 网关 / 纯路由 / AP 三种工作模式，IPv6、WireGuard、fullcone NAT 沿用上游能力
- 重启前自动落盘 nvram，避免配置丢失
- DHCP 地址池异常时自动按 LAN 网段修复，并在启动阶段自愈重试

### 无线

- 2.4G / 5G 双频，MT7615 DBDC，支持 2x2 MIMO、802.11ac
- 无线参数完全沿用上游实现，未做额外改写
- WebUI 提供信道、带宽、发射功率、访客网络、WDS、MAC 过滤等常用配置

### MAC 地址管理

- **外网 MAC**：`高级设置 → 外部网络` 中修改，支持从客户端列表选择
- **内网 MAC**：`高级设置 → 内部网络` 中修改，留空则使用出厂 MAC
- 两处均提供**随机生成**按钮，生成符合规范的地址（单播、本地管理位、12 位十六进制），
  保存后立即生效

### WebUI

- 顶栏展示负载、内存、运行时间、无线状态与固件版本
- 功能开关使用经典「是 / 否」单选按钮，风格与原版 Padavan 一致
- 页脚保留项目致谢与固件来源

### 运行时插件系统

固件内的功能通过编译期开关裁剪，插件则在设备运行期间安装，无需重新编译固件：

- 管理器：`/sbin/plugin-mgr`
- 存储位置：`/etc/storage/plugins/<name>/`（持久分区，重启保留）
- 入口脚本：`main.sh`，支持 `start` / `stop` 参数
- WebUI：`高级设置 → 系统管理 → 插件管理`，支持在线添加、启动、停止、删除、开机自启
- 开机时由 `rc` 调用 `plugin-mgr autostart` 拉起已启用的插件

目录结构：

```
/etc/storage/plugins/<name>/
├── main.sh        # 入口脚本（start / stop）
└── plugin.conf    # NAME / VERSION / AUTOSTART / INSTALLED
```

命令行同样可用：

```sh
plugin-mgr list
plugin-mgr add demo 1 /tmp/demo.sh     # 名称 / 是否开机自启 / 脚本路径
plugin-mgr start demo
plugin-mgr stop demo
plugin-mgr enable demo
plugin-mgr rm demo
```

### 关于代理功能

本仓库发布的是**不含任何代理内核**的基线固件：shadowsocks、Xray、Trojan、sing-box、
naiveproxy 及相关 DNS 组件均不编入，WebUI 也不提供对应入口。如此可让固件保持在
16MB flash 的可用范围内，并把运行内存留给路由与插件。

内核侧仍保留 `IP_SET`、`NETFILTER_XT_SET`、`XT_TPROXY`、`XT_REDIRECT` 等能力，
需要时可以通过插件形式在 `/etc/storage` 或外置存储上部署独立的代理组件。

## 编译

依赖（Debian / Ubuntu 22.04 及以上）：

```sh
sudo apt install unzip libtool-bin ccache curl cmake gperf gawk flex bison nano xxd \
    fakeroot kmod cpio bc zip git python3-docutils gettext automake autopoint \
    texinfo build-essential help2man pkg-config zlib1g-dev libgmp3-dev \
    libmpc-dev libmpfr-dev libncurses5-dev libltdl-dev wget libc-dev-bin liblzma-dev
```

编译指定机型：

```sh
make K2P          # 产物位于 trunk/images/*.trx
make K2P-USB
make clean        # 切换机型前清理
```

顶层 `Makefile` 会自动下载预编译工具链
（`releases/download/toolchain/mipsel-linux-musl.tar.xz`），下载失败时回退到
`toolchain/` 内的 crosstool-NG 源码构建。

持续集成：

- `.github/workflows/build.yml`：推送到任意分支后自动编译 `K2P`、`K2P-USB` 并发布 trx
- `.github/workflows/custom.yml`：手动选择机型、超频档位与插件开关
- `.github/workflows/toolchain.yml`：工具链单独构建与发布

## 目录结构

```
Makefile                 顶层构建入口（make <机型>）
toolchain/               crosstool-NG 源码
trunk/
  Makefile              固件主构建流程
  configure             生成 .config 与内核配置
  linux-4.4.x/          内核及 MTK/Ralink 驱动
  libc/ libs/           运行库与第三方库
  user/                 用户态软件包（含 pluginmgr）
  vendors/Ralink/       镜像打包规则
  configs/templates/    各机型功能模板
  configs/boards/       板级描述、内核配置、SKU 数据
  tools/                lzma、mkimage、mksquashfs、romfs 工具
.github/workflows/      CI 工作流
```

## 刷机

1. 已运行 Padavan 的设备：`高级设置 → 系统管理 → 固件升级`，选择对应机型的 `.trx` 上传即可，
   配置默认保留
2. 原厂固件首次刷入：需要先通过 Breed 或其他方式写入引导
3. 固件分区容量为 15.19MiB（`0x50000` 起 `0xF30000`），上传文件超过该容量会被拒绝

刷机存在风险，请提前备份原厂固件与 Breed。

## 支持机型

沿用上游 55 个板级配置，包括：K2P、K2P-USB、K2P-NANO、MI-R3G / R3P / 4 / 4A、NEWIFI3、
RM2100、CR660x、DIR-878 / 882、JCG 系列、MSG1500、ZTE-E8820S / V2、ZTT-RX6000、
NETGEAR R6800 / R7450 / BZV 等。各机型的适配来源见 `trunk/configs/boards/` 与上游提交记录。

## 致谢

- Padavan（rt-n56u）原始项目及其社区
- [hanwckf/rt-n56u](https://github.com/hanwckf/rt-n56u)
- [TurBoTse/padavan](https://github.com/TurBoTse/padavan) — 本仓库的直接上游
- 各机型的板级适配作者

固件按 GPL-2.0 分发，仅供个人学习与自用，请遵守当地法律法规。
