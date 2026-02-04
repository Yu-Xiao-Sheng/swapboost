# swapboost
[中文](README.zh.md) | [English](README.md)

💻 Linuxer 桌面用户看过来：在低内存的 Ubuntu 系发行版上，打开几个浏览器和 IDE 就卡到怀疑人生？swapboost 用一条命令调优动态 swapspace（可选 zswap），加上预设和自定义开关，让桌面顺滑不再"卡成 PPT"。

⭐ 如果觉得有用，请点个 Star 支持一下，让更多人受益！

## 功能
- ✅ 安装并配置 `swapspace`（若缺失），在 `/etc/swapspace.conf` 写入 swapboost 配置块进行动态交换管理。
- 🔌 注释默认 `/swapfile`，如在用则 `swapoff /swapfile`。
- 🎛️ 提供 apply/status/rollback，以及 `set`/`preset` 命令，无需手动改文件即可调整。
- 🔧 **可选**通过 `--enable-zswap` 参数启用 zswap（使用合理默认值：`zswap.enabled=1`、`lz4`、`max_pool_percent=20`、`z3fold`）。

## 为什么默认不启用 zswap

zswap 在交换到磁盘之前压缩内存页面，这在内存极小的系统上有帮助。但实测表明，在内存足够的系统上，zswap 会：
- 因持续的压缩/解压操作增加 CPU 负担
- 在运行多个应用时导致明显的性能下降

因此，zswap **默认不启用**。仅在内存非常有限且了解权衡利弊后才使用 `--enable-zswap`。

## 命令
- 🚀 `swapboost apply` — 应用默认调优（min 512M, max 16G, lower 20, upper 80）**不启用 zswap**。
- 🚀 `swapboost apply --enable-zswap` — 应用调优**并启用 zswap**。
- 🔍 `swapboost status` — 查看 zswap 参数、当前 swap 设备、swapspace.conf 中的 swapboost 配置块。
- ♻️ `swapboost rollback` — 移除 zswap 参数、删除 swapboost 配置块、重启 swapspace，并尝试重新启用 `/swapfile`（若存在）。
- 🎚️ `swapboost set --min 1G --max 24G --lower 15 --upper 70` — 自定义阈值（尺寸用 M/G，百分比 1–100）。
- 🧭 `swapboost preset balanced|aggressive|conservative` — 预设配置：
  - balanced：512M / 16G / 20 / 80（默认）
  - aggressive：1G / 24G / 15 / 70
  - conservative：256M / 8G / 25 / 85

## 快速使用（脚本）
```bash
cd packages/swapboost
sudo ./swapboost.sh apply
./swapboost.sh status
```

启用 zswap：
```bash
sudo ./swapboost.sh apply --enable-zswap
```

调优或切换预设：
```bash
sudo ./swapboost.sh set --min 1G --max 24G --lower 15 --upper 70
# 或
sudo ./swapboost.sh preset balanced
```

回滚：
```bash
sudo ./swapboost.sh rollback
```

## 构建 .deb 进行一键安装
```bash
cd packages/swapboost
./build.sh 0.1.0          # 版本可选，默认 0.1.0
sudo apt install ./dist/swapboost_0.1.0_all.deb
```

安装后会自动执行 `swapboost apply`（不启用 zswap）。要启用 zswap，请在安装后运行 `sudo swapboost apply --enable-zswap` 并重启。

## Releases
- 当前版本：1.0 — 亮点见 [RELEASES.md](RELEASES.md)。

## 注意事项
- 目标：Ubuntu 及衍生发行版（依赖 `grub-common`、`systemd`、`swapspace`）。
- 可反复执行，安全更新 swapboost 配置块和 GRUB 行。
- 如果要卸载，请先运行 `swapboost rollback` 以恢复之前的 GRUB/swap 设置。
- 开源协议：MIT（见 LICENSE）。
