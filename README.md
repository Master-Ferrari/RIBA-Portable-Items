## RIBA Portable Items

Sources for the Barotrauma mod. The game does **not** load this folder — it has to
be compiled into `<Barotrauma>/LocalMods/RIBA Portable Items` first.

### Build

```
build.cmd            # build into the game's LocalMods folder
build.cmd -Clean     # wipe the output and staging, then build
build.cmd -Restart   # build, then close and relaunch the game
build.cmd -Launch    # build, then start the game (no-op if already running)
```

In VS Code the same thing is bound to Ctrl+Shift+B.

The game install is located automatically (Steam registry → `libraryfolders.vdf`)
and remembered in `build.config.json`. Override it with `-GameDir "X:\...\Barotrauma"`
or the `BAROTRAUMA_DIR` environment variable.

The repository no longer has to live inside `Barotrauma\LocalMods\` — `build.ps1`
mirrors the working tree into a staging folder there for you.

### Publish to the Steam Workshop

```
build.cmd -Publish -Changelog "what changed"        # dry run: checks everything, uploads nothing
build.cmd -Publish -Changelog "what changed" -Yes   # actually uploads
```

The workshop page itself — title, per-language descriptions, tags, visibility and
cover image — lives in [`workshop.json`](workshop.json) at the repo root. To seed it
from whatever is currently published:

```
Tools\RibaPublish\bin\Release\net9.0\RibaPublish.exe --init-config --id 2382545579 --yes
```

Uploading needs a running Steam client logged in as the mod's owner. It goes through
Facepunch.Steamworks — the same library and the same `Ugc.Editor` call the game itself
uses for its in-game Publish button.

Workshop link: https://steamcommunity.com/sharedfiles/filedetails/?id=2382545579
