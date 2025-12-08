# swapboost
[中文](README.zh.md) | [English](README.md)

💻 Hey linuxer! Tired of your low-memory Ubuntu desktop freezing the moment you open a few browsers and IDEs? swapboost keeps things smooth by turning on zswap, tuning dynamic swapspace, and giving you friendly presets plus custom knobs—all in one command.

⭐ If swapboost helps, please consider dropping a Star to support the project!

## What it does
- ✅ Enables zswap with sane defaults (`zswap.enabled=1`, `lz4`, `max_pool_percent=20`, `z3fold`) via GRUB and runs `update-grub`.
- 🔌 Disables the default `/swapfile` entry and `swapoff /swapfile` when present.
- 🧩 Installs `swapspace` (if missing) and writes a swapboost block to `/etc/swapspace.conf`.
- 🎛️ Provides apply/status/rollback plus `set` and `preset` to retune without editing files.

## Commands
- 🚀 `swapboost apply` — Apply default tuning (min 512M, max 16G, lower 20, upper 80).
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

The post-install script runs `swapboost apply` automatically. Reboot afterward to activate zswap kernel parameters.

## Releases
- Current: 0.1.0 — see [RELEASES.md](RELEASES.md) for highlights.

## Notes
- Target: Ubuntu and derivatives (requires `grub-common`, `systemd`, `swapspace`).
- Safe to re-run; it only updates the swapboost block and GRUB line.
- Before removing the package, run `swapboost rollback` if you want the previous GRUB/swap settings back.
- License: MIT (see LICENSE).
