mod discord 'apps/warbandeer-discord/justfile'
mod desktop 'apps/warbandeer-desktop/justfile'

# Run tests
check:
    busted .
    luacheck .