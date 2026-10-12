#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
package_id="org.tenax.opencodego"
package_type="Plasma/Applet"
helper="$script_dir/contents/scripts/opencode-go-usage"
icon_theme_dir="$HOME/.local/share/icons/hicolor/scalable/apps"
icon_files=(opencode-go.svg opencode-go-symbolic.svg)
qml_files=(
    contents/ui/main.qml
    contents/ui/MeterRow.qml
    contents/ui/UsageBody.qml
    contents/ui/configGeneral.qml
    contents/config/config.qml
)
js_files=(contents/js/usage.js)
test_dir="contents/tests"

usage() {
    cat <<'USAGE'
Usage: ./dev.sh <command>

Commands:
  doctor       Check local dependencies, credentials and one live API probe.
  usage        Print the normalized usage JSON the plasmoid consumes.
  install      Install the plasmoid for the current user and reload Plasma Shell.
  upgrade      Upgrade the installed plasmoid and reload Plasma Shell.
  reinstall    Remove, install, and reload Plasma Shell.
  remove       Remove the plasmoid package for the current user.
  reload       Restart Plasma Shell without logging out.
  preview      Open the plasmoid in plasmoidviewer (needs plasma-sdk).
  status       Show the installed package info.
  validate     Run syntax, lint, unit-test and package checks.
  test         Run the QML unit tests for the pure helpers.

Typical loop while editing:
  ./dev.sh upgrade
  ./dev.sh preview

After adding the widget to the System Tray once, ./dev.sh upgrade applies
QML/metadata changes without logging out.
USAGE
}

have() {
    command -v "$1" >/dev/null 2>&1
}

require_command() {
    if ! have "$1"; then
        printf 'Missing required command: %s\n' "$1" >&2
        exit 127
    fi
}

is_installed() {
    kpackagetool6 --type "$package_type" --show "$package_id" >/dev/null 2>&1
}

reload_plasma() {
    if systemctl --user list-unit-files plasma-plasmashell.service >/dev/null 2>&1; then
        systemctl --user restart plasma-plasmashell.service
        return
    fi

    if have kquitapp6 && have kstart; then
        kquitapp6 plasmashell || true
        kstart plasmashell >/dev/null 2>&1 &
        return
    fi

    printf 'Could not reload Plasma Shell automatically. Log out and back in.\n' >&2
}

install_package() {
    require_command kpackagetool6
    kpackagetool6 --type "$package_type" --install "$script_dir"
    install_icons
}

install_icons() {
    mkdir -p "$icon_theme_dir"
    for icon in "${icon_files[@]}"; do
        install -m 0644 "$script_dir/contents/icons/$icon" "$icon_theme_dir/$icon"
    done
    # Make the names resolvable for the panel/tray icon lookup.
    if have kbuildsycoca6; then
        kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
    fi
}

remove_icons() {
    for icon in "${icon_files[@]}"; do
        rm -f "$icon_theme_dir/$icon"
    done
}

upgrade_package() {
    require_command kpackagetool6
    kpackagetool6 --type "$package_type" --upgrade "$script_dir"
    install_icons
}

remove_package() {
    require_command kpackagetool6
    kpackagetool6 --type "$package_type" --remove "$package_id"
    remove_icons
}

doctor() {
    bash -n "$helper"
    "$helper" doctor
}

# Resolve qmllint, which is frequently not on PATH on Arch.
qmllint_bin() {
    if have qmllint; then
        command -v qmllint
    elif [ -x /usr/lib/qt6/bin/qmllint ]; then
        printf '%s\n' /usr/lib/qt6/bin/qmllint
    else
        return 1
    fi
}

# Resolve qmltestrunner the same way.
qmltest_bin() {
    if have qmltestrunner; then
        command -v qmltestrunner
    elif [ -x /usr/lib/qt6/bin/qmltestrunner ]; then
        printf '%s\n' /usr/lib/qt6/bin/qmltestrunner
    else
        return 1
    fi
}

# Where Qt keeps its own QML modules. This only helps qmllint resolve the
# org.kde.* imports; on most installs it finds them without a hint.
qml_import_path() {
    if have qtpaths6; then
        qtpaths6 --query QT_INSTALL_QML
    elif have qmake6; then
        qmake6 -query QT_INSTALL_QML
    elif [ -d /usr/lib/qt6/qml ]; then
        printf '%s\n' /usr/lib/qt6/qml
    fi
}

check_qml() {
    local lint
    lint=$(qmllint_bin) || true
    if [ -z "$lint" ]; then
        printf 'skip: qmllint not found, QML not linted\n'
        return 0
    fi

    local import_path
    import_path=$(qml_import_path) || true

    local -a lint_targets=("${qml_files[@]}" "${js_files[@]}")
    local -a lint_args=()
    if [ -n "$import_path" ]; then
        lint_args=(-I "$import_path")
    fi
    lint_args+=("${lint_targets[@]}")

    # The plasmoid host injects i18n() at runtime, so qmllint reports every call
    # as an unqualified access. Drop only the warnings whose own source line is
    # an i18n call — a genuinely unqualified name still fails the check. The
    # `|| true` keeps `set -e` out of it when qmllint exits non-zero on errors:
    # the failure is reported through the pipeline's output, not its status.
    local output
    output=$("$lint" "${lint_args[@]}" 2>&1 | awk '
        /^(Warning|Error):/ {
            warning = $0
            getline source
            if (warning ~ /Unqualified access \[unqualified\]$/ && source ~ /i18n[cndp]*\(/) {
                next
            }
            print warning
        }' || true)

    if [ -n "$output" ]; then
        printf '%s\n' "$output"
        return 1
    fi
    printf 'ok: qmllint clean (%s files)\n' "${#lint_targets[@]}"
}

# Unit tests for the pure helpers in js/usage.js. Headless by design.
run_tests() {
    local runner
    runner=$(qmltest_bin) || true
    if [ -z "$runner" ]; then
        printf 'skip: qmltestrunner not found (usually in qt6-declarative)\n'
        return 0
    fi
    QT_QPA_PLATFORM=offscreen "$runner" -input "$script_dir/$test_dir"
}

validate() {
    local failed=0

    printf '== syntax ==\n'
    if bash -n "$helper"; then
        printf 'ok: helper parses\n'
    else
        printf 'fail: helper syntax\n'
        failed=1
    fi
    if have jq && jq -e . "$script_dir/metadata.json" >/dev/null 2>&1; then
        printf 'ok: metadata.json parses\n'
    else
        printf 'fail: metadata.json\n'
        failed=1
    fi
    if ! have xmllint; then
        printf 'skip: xmllint not installed, config/main.xml unchecked\n'
    elif xmllint --noout "$script_dir/contents/config/main.xml"; then
        printf 'ok: config/main.xml parses\n'
    else
        printf 'fail: config/main.xml does not parse\n'
        failed=1
    fi
    check_qml || failed=1

    printf '== tests ==\n'
    run_tests || failed=1

    printf '== files ==\n'
    for file in \
        metadata.json \
        contents/config/main.xml \
        contents/scripts/opencode-go-usage \
        contents/icons/opencode-go-symbolic.svg \
        contents/icons/opencode-go.svg \
        "$test_dir/tst_usage.qml" \
        "${qml_files[@]}" \
        "${js_files[@]}"; do
        if [ -e "$script_dir/$file" ]; then
            printf 'ok: %s\n' "$file"
        else
            printf 'fail: missing %s\n' "$file"
            failed=1
        fi
    done

    if [ ! -x "$helper" ]; then
        printf 'fail: helper is not executable\n'
        failed=1
    fi

    printf '== kpackage ==\n'
    if have kpackagetool6; then
        local packageroot
        packageroot=$(mktemp -d)
        if kpackagetool6 --type "$package_type" --packageroot "$packageroot" --install "$script_dir" >/dev/null; then
            printf 'ok: package structure accepted\n'
        else
            printf 'fail: kpackagetool6 rejected the package\n'
            failed=1
        fi
        rm -rf "$packageroot"
    fi

    [ "$failed" -eq 0 ] && printf 'result: ok\n' || printf 'result: problems found\n'
    return "$failed"
}

case "${1:-}" in
    doctor) doctor ;;
    usage) "$helper" json ;;
    install)
        install_package
        reload_plasma
        printf 'installed %s\n' "$package_id"
        ;;
    upgrade)
        if is_installed; then
            upgrade_package
        else
            install_package
        fi
        reload_plasma
        printf 'installed %s\n' "$package_id"
        ;;
    reinstall)
        is_installed && remove_package || true
        install_package
        reload_plasma
        printf 'installed %s\n' "$package_id"
        ;;
    remove)
        remove_package
        reload_plasma
        printf 'removed %s\n' "$package_id"
        ;;
    reload) reload_plasma ;;
    preview)
        if ! have plasmoidviewer; then
            printf 'plasmoidviewer not found. Install plasma-sdk, or add the widget to the System Tray and use ./dev.sh upgrade.\n' >&2
            exit 127
        fi
        plasmoidviewer -a "$package_id"
        ;;
    status)
        require_command kpackagetool6
        kpackagetool6 --type "$package_type" --show "$package_id"
        ;;
    validate) validate ;;
    test) run_tests ;;
    -h|--help|help) usage ;;
    *) usage >&2; exit 64 ;;
esac
