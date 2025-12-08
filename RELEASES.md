# swapboost releases

## 0.1.0
- First public drop with apply/status/rollback commands.
- Added `set` for custom swapspace tuning and `preset` (balanced/aggressive/conservative).
- zswap defaults: enabled, lz4, max_pool_percent=20, z3fold.
- swapspace defaults: min 512M, max 16G, lower 20, upper 80.
