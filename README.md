# OpenCode Go Usage

A KDE Plasma 6 system tray widget that shows your OpenCode **Go** plan usage —
rolling (5 hour), weekly and monthly meters — refreshed once a minute. Click the
tray icon to open the popup; it does not steal focus otherwise.

```
Go                      Renews Nov 1                 [ Manage ]
Rolling     [█░░░░░░░░░░░░░░░░░░░░░]                       3%
            Resets in 0h 6m                     $0.64 / $12.00
Weekly      [█░░░░░░░░░░░░░░░░░░░░░]                       7%
            Resets in 6d 11h                    $3.24 / $30.00
Monthly     [█████████░░░░░░░░░░░░░]                      43%
            Resets in 19d 22h                  $26.89 / $60.00
──────────────────────────────────────────────────────────────
Updated 16:29                              Refreshing in 5s
```

The bar sits on the label's line; the reset countdown is indented under the
label, with the allowance it is counting down to on the right. The percentage and
the bar show the share used by default and can be switched to the share remaining
in the settings.

## How it works

The widget shells out to `contents/scripts/opencode-go-usage`, which:

1. reads the OpenCode CLI's OAuth access token from
   `~/.local/share/opencode/opencode.db` (table `credential`,
   `integration_id='opencode'`, read-only) and falls back to
   `opencode auth export`;
2. calls `GET https://opencode.ai/console/api/go/status` with that token;
3. normalizes the response into one line of JSON for the QML front end.

The token is never printed or logged.

## Source layout

```
contents/
  config/main.xml             settings entries and their defaults
  config/config.qml           registers the settings page
  ui/main.qml                 applet shell: state, polling, tray icon, popup wiring
  ui/UsageBody.qml            popup body: header, meter list, empty/error states, footer
  ui/MeterRow.qml             one meter row: label, bar, percentage, reset line
  ui/configGeneral.qml        the settings page controls
  js/usage.js                 pure share/duration helpers (no i18n, no state)
  scripts/opencode-go-usage   credential + API helper; prints one line of JSON
  tests/tst_usage.qml         qmltestrunner unit tests for js/usage.js
  icons/*.svg                 tray and placeholder icons
```

`dev.sh validate` parses the helper, `metadata.json` and `config/main.xml`, runs
`qmllint` over every QML and JS file, runs the unit tests, and installs the
package into a throwaway root.

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
./dev.sh validate   # syntax + lint + unit tests + package checks
./dev.sh test       # just the unit tests for the pure helpers
./dev.sh remove     # uninstall
```

## Settings

Right click the tray icon → *Configure OpenCode Go Usage…*. The **General** page
has:

| Setting | Default | Notes |
|---|---|---|
| Refresh every | 60 s | Clamped to 15–1800 s |
| Meters: Rolling / Weekly / Monthly | all on | Hidden meters are dropped from the popup and from the tooltip |
| Show last update and next refresh | on | Hides the footer row and its separator |
| Show | Percentage used | Or *Percentage remaining* — switches both the number and the bar |
| Show the percentage next to the tray icon | off | e.g. `Monthly 43%` next to the tray icon |
| Show the used and total allowance under each meter | on | The `$0.64 / $12.00` line; the figures come from the API's `usedMicroCents`/`limitMicroCents` and are formatted with the system locale |
| Popup layout | Centred | How the popup spends height it does not need. The system tray gives its popup a fixed size, so there is always slack: *Centred* puts half above the data and half below (footer stays pinned at the bottom), *Compact* leaves it all at the bottom. In a panel/desktop slot, which sizes itself to the content, neither matters |

The settings live in `~/.config/plasma-org.kde.plasma.desktop-appletsrc`, defined
by `contents/config/main.xml` and edited through
`contents/ui/configGeneral.qml`. Turning every meter off is allowed: the popup
then says so instead of showing an empty list.

## Behavior notes

- Polls every 60 seconds by default (see **Settings**); the "Resets in" countdown
  is recomputed locally each second so it stays fresh between requests, and the
  footer shows a live "Refreshing in Ns" countdown.
- On a failed request the last good values stay on screen and the error is shown
  under the meters.
- If the plan is set to cancel at the end of the period, the header reads
  *Cancels Nov 1* instead of *Renews Nov 1* (`cancelAtPeriodEnd` from the API).
- The access token expires roughly monthly. The widget does **not** refresh it;
  when the console returns 401 the popup asks you to run
  `opencode auth login`.
- The bar is filled with the theme highlight colour and turns amber above 70%
  and red above 90% **of the share used**, whichever percentage mode is active.

## Icon

The tray uses `opencode-go.svg`: the OpenCode mark on its brand tile (dark
rounded square, light glyph, same as the official favicon). The monochrome
`opencode-go-symbolic.svg` is a theme-recolored fallback for placeholders. Both
are copied into `~/.local/share/icons/hicolor/scalable/apps/` on install. The
mark is derived from the official OpenCode favicon/logo (opencode is open
source, MIT). See <https://opencode.ai>.

## License

MIT.
