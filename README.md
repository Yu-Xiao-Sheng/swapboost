# swapboost
[中文](README.zh.md) | [English](README.md)

💻 Hey linuxer! Tired of your low-memory Ubuntu desktop freezing the moment you open a few browsers and IDEs? swapboost keeps things smooth by tuning dynamic swapspace, with optional zswap support, and giving you friendly presets plus custom knobs—all in one command.

⭐ If swapboost helps, please consider dropping a Star to support the project!

## What it does
- ✅ Installs and configures `swapspace` (if missing) with a swapboost block in `/etc/swapspace.conf` for dynamic swap management.
- 🔌 Disables the default `/swapfile` entry and `swapoff /swapfile` when present.
- 🎛️ Provides apply/status/rollback plus `set` and `preset` to retune without editing files.
- 🔧 **Optionally** enables zswap with sane defaults (`zswap.enabled=1`, `lz4`, `max_pool_percent=20`, `z3fold`) via `--enable-zswap` flag.

## Why zswap is optional by default

zswap compresses memory pages before swapping to disk, which can help on very low-memory systems. However, testing shows that on systems with sufficient memory, zswap can:
- Increase CPU usage due to continuous compression/decompression
- Cause noticeable slowdown when running many applications simultaneously

Therefore, zswap is **not enabled by default**. Use `--enable-zswap` only if you have very limited RAM and understand the trade-offs.

## Commands
- 🚀 `swapboost apply` — Apply default tuning (min 512M, max 16G, lower 20, upper 80) **without zswap**.
- 🚀 `swapboost apply --enable-zswap` — Apply tuning **with zswap enabled**.
- 🔍 `swapboost status` — Show zswap params, active swaps, and the swapboost block in swapspace.conf.
- ♻️ `swapboost rollback` — Remove zswap flags, drop the swapspace block, restart swapspace, and try to re-enable `/swapfile` if it exists.
- 🎚️ `swapboost set --min 1G --max 24G --lower 15 --upper 70` — Custom thresholds (sizes in M/G; percents 1–100).
- 🧭 `swapboost preset balanced|aggressive|conservative` — Built-in tuning sets:
  - balanced: 512M / 16G / 20 / 80 (default)
  - aggressive: 1G / 24G / 15 / 70
  - conservative: 256M / 8G / 25 / 85

## Quick use (script)
```bash
cd packages/swapboost
sudo ./swapboost.sh apply
./swapboost.sh status
```

With zswap enabled:
```bash
sudo ./swapboost.sh apply --enable-zswap
```

Tune or switch preset:
```bash
sudo ./swapboost.sh set --min 1G --max 24G --lower 15 --upper 70
# or
sudo ./swapboost.sh preset balanced
```

Rollback:
```bash
sudo ./swapboost.sh rollback
```

## Build a .deb for one-command installs
```bash
cd packages/swapboost
./build.sh 0.1.0          # version optional; defaults to 0.1.0
sudo apt install ./dist/swapboost_0.1.0_all.deb
```

The post-install script runs `swapboost apply` automatically (without zswap). To enable zswap, run `sudo swapboost apply --enable-zswap` after installation and reboot.

## Releases
- Current: 0.1.0 — see [RELEASES.md](RELEASES.md) for highlights.

## Notes
- Target: Ubuntu and derivatives (requires `grub-common`, `systemd`, `swapspace`).
- Safe to re-run; it only updates the swapboost block and GRUB line.
- Before removing the package, run `swapboost rollback` if you want the previous GRUB/swap settings back.
- License: MIT (see LICENSE).
