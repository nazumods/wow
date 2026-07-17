mod discord 'apps/warbandeer-discord/justfile'

# Run tests
check:
    busted .
    luacheck .