# OpenCode Go Usage

A KDE Plasma 6 system tray widget that shows your OpenCode **Go** plan usage —
rolling (5 hour), weekly and monthly meters — refreshed once a minute. Click the
tray icon to open the popup; it does not steal focus otherwise.

```
Go                      Renews Nov 1                 [ Manage ]
Rolling     [██████░░░░░░░░░░░░░░░░]                       9% used
            Resets in 0h 6m
Weekly      [█░░░░░░░░░░░░░░░░░░░░░]                       3% used
            Resets in 6d 11h
Monthly     [█████████░░░░░░░░░░░░░]                      41% used
            Resets in 19d 22h
```

## How it works

The widget shells out to `contents/scripts/opencode-go-usage`, which:

1. reads the OpenCode CLI's OAuth access token from
   `~/.local/share/opencode/opencode.db` (table `credential`,
   `integration_id='opencode'`, read-only) and falls back to
   `opencode auth export`;
2. calls `GET https://opencode.ai/console/api/go/status` with that token;
3. normalizes the response into one line of JSON for the QML front end.

The token is never printed or logged.

## Requirements

- KDE Plasma 6 (tested on 6.7.5, Wayland)
- `plasma5support` (provides the QML `executable` data source)
- `curl`, `jq`
- `sqlite3` (optional; used to read the token without spawning the CLI)
- the `opencode` CLI, logged in: `opencode auth login`

## Install

```sh
./dev.sh doctor     # dependencies, credentials, one live API probe
./dev.sh usage      # print the exact JSON the widget consumes
./dev.sh install    # install for the current user + reload Plasma Shell
```

`install` also copies the icons into `~/.local/share/icons/hicolor/scalable/apps/`
so the panel can resolve them by name; `remove` takes them away again.

Then add the widget to your system tray: right click the tray → *Configure System
Tray* → *Entries* → enable **OpenCode Go Usage**.

While editing:

```sh
./dev.sh upgrade    # apply changes and reload Plasma Shell
./dev.sh preview    # open in plasmoidviewer (needs plasma-sdk)
./dev.sh validate   # syntax + package checks
./dev.sh remove     # uninstall
```

## Behavior notes

- Polls every 60 seconds; the "Resets in" countdown is recomputed locally each
  poll so it stays fresh between requests, and the footer shows a live
  "Refreshing in Ns" countdown that updates every second.
- On a failed request the last good values stay on screen and the error is shown
  under the meters.
- The access token expires roughly monthly. The widget does **not** refresh it;
  when the console returns 401 the popup asks you to run
  `opencode auth login`.

## Icon

The tray uses `opencode-go.svg`: the OpenCode mark on its brand tile (dark
rounded square, light glyph, same as the official favicon). The monochrome
`opencode-go-symbolic.svg` is a theme-recolored fallback for placeholders. Both
are copied into `~/.local/share/icons/hicolor/scalable/apps/` on install. The
mark is derived from the official OpenCode favicon/logo (opencode is open
source, MIT). See <https://opencode.ai>.

## License

MIT.
