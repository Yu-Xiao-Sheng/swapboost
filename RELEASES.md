# swapboost releases

## 1.0
- **Breaking change**: zswap is now optional (disabled by default)
- Add `--enable-zswap` flag to `apply` command for opt-in zswap support
- Updated documentation with explanation of why zswap is disabled by default
- Testing showed zswap can increase CPU usage and cause slowdowns on systems with sufficient memory
- Recommended for low-memory systems only

## 0.1.0
- First public drop with apply/status/rollback commands.
- Added `set` for custom swapspace tuning and `preset` (balanced/aggressive/conservative).
- zswap defaults: enabled, lz4, max_pool_percent=20, z3fold.
- swapspace defaults: min 512M, max 16G, lower 20, upper 80.
