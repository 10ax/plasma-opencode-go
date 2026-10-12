pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.plasmoid

import "../js/usage.js" as Usage

PlasmoidItem {
    id: root

    readonly property string helperPath: decodeURIComponent(String(Qt.resolvedUrl("../scripts/opencode-go-usage")).replace(/^file:\/\//, ""))

    readonly property string consoleUrl: "https://opencode.ai/console"

    readonly property int pollIntervalMs: Math.max(15, Math.min(1800,
        Number(Plasmoid.configuration.pollIntervalSeconds) || 60)) * 1000

    // Populated from the helper JSON. On a failed request the last good values
    // stay put on purpose and errorText explains what went wrong.
    property var meters: []
    property string renewsAt: ""
    property bool hasData: false
    property string errorText: ""

    // Ticked every second so the "Resets in" and "Refreshing in" countdowns
    // stay live between polls.
    property double nowMs: Date.now()
    property double nextPollMs: 0

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'";
    }

    function refresh() {
        root.nowMs = Date.now();
        root.nextPollMs = root.nowMs + root.pollIntervalMs;
        // The trailing comment is a cheap cache-buster: the executable engine
        // treats every distinct source string as a new request.
        executableEngine.connectSource(shellQuote(helperPath) + " json # " + Date.now());
    }

    function errorMessageFor(code) {
        switch (code) {
        case "notoken":
            return i18n("No OpenCode credentials found. Run: opencode auth login");
        case "unauthorized":
            return i18n("Session expired. Run: opencode auth login");
        case "payment-required":
            return i18n("No active Go subscription on this account.");
        case "network":
            return i18n("Cannot reach opencode.ai.");
        case "missing-curl":
        case "missing-jq":
            return i18n("Missing dependency: %1", code.replace("missing-", ""));
        case "":
            return "";
        default:
            return i18n("Request failed (%1).", code);
        }
    }

    // Maps a meter's stable key to its visibility setting, so a reworded label
    // in the API response cannot silently unhide a meter. Unknown keys stay
    // visible: better to show a meter the settings do not know about than to
    // hide data.
    function meterEnabled(meter) {
        switch (meter && meter.key) {
        case "fiveHour":
            return Plasmoid.configuration.showRolling;
        case "week":
            return Plasmoid.configuration.showWeekly;
        case "month":
            return Plasmoid.configuration.showMonthly;
        default:
            return true;
        }
    }

    readonly property var visibleMeters: meters.filter(meterEnabled)

    // The worst visible meter, as "Monthly 43%": what the tooltip and the
    // optional tray text summarize.
    readonly property string summaryText: {
        const worst = Usage.worstMeter(root.visibleMeters);
        return worst ? worst.label + " " + Usage.percent(worst, Plasmoid.configuration.percentMode) + "%" : "";
    }

    readonly property string refreshCountdownText: i18n("Refreshing in %1s",
        Math.max(0, Math.ceil((root.nextPollMs - root.nowMs) / 1000)))

    // Point size for the secondary lines. Kirigami.Theme.smallFont is the same
    // size as the default font on several themes, which leaves the sub-lines
    // without any visual hierarchy.
    readonly property int smallPointSize: Math.max(6, Kirigami.Theme.defaultFont.pointSize - 1)

    Plasmoid.icon: "opencode-go"
    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    Plasmoid.title: i18n("OpenCode Go Usage")

    toolTipMainText: Plasmoid.title
    toolTipSubText: {
        if (root.errorText) {
            return root.errorText;
        }
        if (!root.hasData) {
            return i18n("Loading…");
        }
        return root.summaryText ? i18n("Go · %1", root.summaryText) : i18n("Go · no meters enabled");
    }

    compactRepresentation: MouseArea {
        id: compactMouseArea

        // Only one tooltip here: the native applet one built from
        // toolTipMainText / toolTipSubText above. A QQC2.ToolTip on this
        // MouseArea would open a second, clipped bubble on top of it.

        // The tray hands us the panel's icon size as our height. With the
        // percentage text off we ask for no width of our own, so the tray keeps
        // giving us that square slot; with it on we widen to fit the text.
        anchors.fill: parent
        implicitWidth: Plasmoid.configuration.showTrayText ? compactRow.implicitWidth : 0
        hoverEnabled: true

        onClicked: root.expanded = !root.expanded

        RowLayout {
            id: compactRow

            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: Plasmoid.icon
                active: compactMouseArea.containsMouse
                // Square, and as large as the slot allows.
                implicitWidth: compactMouseArea.height > 0
                    ? compactMouseArea.height
                    : Kirigami.Units.iconSizes.medium
                implicitHeight: implicitWidth
            }

            PlasmaComponents3.Label {
                visible: Plasmoid.configuration.showTrayText
                text: root.summaryText
                font.pointSize: root.smallPointSize
            }
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 18
        Layout.preferredWidth: Kirigami.Units.gridUnit * 21
        // The popup sizes itself from the content, so the explicit padding has
        // to be added back here or the last row gets clipped.
        Layout.minimumHeight: body.implicitHeight + topPadding + bottomPadding
        collapseMarginsHint: true

        // Guarantee an even inset on every edge instead of relying on the
        // theme's dialog-background metrics.
        leftPadding: Kirigami.Units.largeSpacing
        rightPadding: Kirigami.Units.largeSpacing
        topPadding: Kirigami.Units.largeSpacing
        bottomPadding: Kirigami.Units.largeSpacing

        contentItem: UsageBody {
            id: body

            meters: root.visibleMeters
            percentMode: Plasmoid.configuration.percentMode
            hasData: root.hasData
            renewsAt: root.renewsAt
            errorText: root.errorText
            showFooter: Plasmoid.configuration.showFooter
            nowMs: root.nowMs
            smallPointSize: root.smallPointSize
            refreshText: root.refreshCountdownText
            consoleUrl: root.consoleUrl
        }
    }

    PlasmaCore.Action {
        id: refreshAction
        text: i18n("Refresh Now")
        icon.name: "view-refresh-symbolic"
        onTriggered: root.refresh()
    }

    PlasmaCore.Action {
        id: openConsoleAction
        text: i18n("Open OpenCode Console")
        icon.name: "internet-services-symbolic"
        onTriggered: Qt.openUrlExternally(root.consoleUrl)
    }

    Plasmoid.contextualActions: [refreshAction, openConsoleAction]

    P5Support.DataSource {
        id: executableEngine
        engine: "executable"
        connectedSources: []

        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);

            const stdout = String(data.stdout || "").trim();
            let payload = null;
            try {
                payload = JSON.parse(stdout);
            } catch (error) {
                payload = null;
            }

            if (!payload || typeof payload !== "object") {
                root.errorText = root.errorMessageFor("bad-output");
                return;
            }

            if (payload.ok) {
                root.meters = payload.meters || [];
                root.renewsAt = payload.renewsAt || "";
                root.hasData = root.meters.length > 0;
                root.errorText = "";
                return;
            }

            // Keep the last good values in root.meters on purpose.
            root.errorText = root.errorMessageFor(payload.error || "unknown");
        }
    }

    Timer {
        id: pollTimer
        interval: root.pollIntervalMs
        repeat: true
        running: true
        // triggeredOnStart does the first fetch at startup, so there is no
        // Component.onCompleted that would fetch a second time.
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // Drives the live countdowns once per second, independent of the poll.
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.nowMs = Date.now()
    }
}
