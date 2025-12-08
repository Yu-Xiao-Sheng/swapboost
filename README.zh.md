# swapboost

面向 Linux 桌面用户（linuxer）：如果你在低内存的 Ubuntu 系发行版上动不动就卡死，swapboost 用一条命令开启 zswap、调优动态 swapspace，还提供预设和自定义开关，让桌面顺滑起来。

## 功能
- 通过 GRUB 启用 zswap，写入 `zswap.enabled=1`、`lz4`、`max_pool_percent=20`、`z3fold` 并执行 `update-grub`。
- 注释默认 `/swapfile`，如在用则 `swapoff /swapfile`。
- 安装 `swapspace`（若缺失），写入 swapboost 配置块到 `/etc/swapspace.conf`。
- 提供 apply/status/rollback，以及 `set`/`preset` 命令，无需手动改文件即可调整。

## 命令
- `swapboost apply` — 应用默认调优（min 512M, max 16G, lower 20, upper 80）。
- `swapboost status` — 查看 zswap 参数、当前 swap 设备、swapspace.conf 中的 swapboost 配置块。
- `swapboost rollback` — 移除 zswap 参数、删除 swapboost 配置块、重启 swapspace，并尝试重新启用 `/swapfile`（若存在）。
- `swapboost set --min 1G --max 24G --lower 15 --upper 70` — 自定义阈值（尺寸用 M/G，百分比 1–100）。
- `swapboost preset balanced|aggressive|conservative` — 预设配置：
  - balanced：512M / 16G / 20 / 80（默认）
  - aggressive：1G / 24G / 15 / 70
  - conservative：256M / 8G / 25 / 85

## 快速使用（脚本）
```bash
cd packages/swapboost
sudo ./swapboost.sh apply
./swapboost.sh status
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

安装后会自动执行 `swapboost apply`。重启后 zswap 内核参数生效。

## 注意事项
- 目标：Ubuntu 及衍生发行版（依赖 `grub-common`、`systemd`、`swapspace`）。
- 可反复执行，安全更新 swapboost 配置块和 GRUB 行。
- 如果要卸载，请先运行 `swapboost rollback` 以恢复之前的 GRUB/swap 设置。
