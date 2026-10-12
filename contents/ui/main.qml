pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    readonly property string helperPath: decodeURIComponent(String(Qt.resolvedUrl("../scripts/opencode-go-usage")).replace(/^file:\/\//, ""))

    readonly property string consoleUrl: "https://opencode.ai/console"

    readonly property int pollIntervalMs: 60000

    // Populated from the helper JSON.
    property var meters: []
    property string renewsAt: ""
    property bool hasData: false
    property string errorCode: ""
    property string errorText: ""
    property bool loading: false

    // Ticked every second so the "Resets in" and "Refreshing in" countdowns
    // stay live between polls.
    property double nowMs: Date.now()
    property double nextPollMs: 0

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'";
    }

    function refresh() {
        root.loading = true;
        root.nowMs = Date.now();
        root.nextPollMs = root.nowMs + root.pollIntervalMs;
        // The trailing comment is a cheap cache-buster: the executable engine
        // treats every distinct source string as a new request.
        executableEngine.connectSource(shellQuote(helperPath) + " json # " + Date.now());
    }

    function refreshCountdownText() {
        const seconds = Math.max(0, Math.ceil((root.nextPollMs - root.nowMs) / 1000));
        return i18n("Refreshing in %1s", seconds);
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

    function fraction(meter) {
        if (!meter || !meter.limit || meter.limit <= 0) {
            return 0;
        }
        return Math.max(0, Math.min(1, meter.used / meter.limit));
    }

    function percentText(meter) {
        return Math.round(root.fraction(meter) * 100) + "%";
    }

    // Green/amber/red ramp driven by the theme, so the bar follows the user's
    // colour scheme instead of a hardcoded green.
    function barColor(value) {
        if (value >= 0.9) {
            return Kirigami.Theme.negativeTextColor;
        }
        if (value >= 0.7) {
            return Kirigami.Theme.neutralTextColor;
        }
        return Kirigami.Theme.highlightColor;
    }

    // Point size for the secondary lines. Kirigami.Theme.smallFont is the same
    // size as the default font on several themes, which leaves the sub-lines
    // without any visual hierarchy.
    readonly property int smallPointSize: Math.max(6, Kirigami.Theme.defaultFont.pointSize - 1)

    function renewsText(iso) {
        if (!iso) {
            return "";
        }
        const date = new Date(iso);
        if (isNaN(date.getTime())) {
            return "";
        }
        return i18n("Renews %1", Qt.formatDate(date, "MMM d"));
    }

    function resetText(iso) {
        if (!iso) {
            return "";
        }
        const ms = new Date(iso).getTime() - root.nowMs;
        if (!isFinite(ms)) {
            return "";
        }
        if (ms <= 0) {
            return i18n("Resets now");
        }
        const totalMinutes = Math.floor(ms / 60000);
        const days = Math.floor(totalMinutes / 1440);
        const hours = Math.floor((totalMinutes % 1440) / 60);
        const minutes = totalMinutes % 60;
        if (days > 0) {
            return i18n("Resets in %1d %2h", days, hours);
        }
        if (hours > 0) {
            return i18n("Resets in %1h %2m", hours, minutes);
        }
        return i18n("Resets in %1m", minutes);
    }

    function summaryText() {
        if (root.meters.length === 0) {
            return root.hasData ? "" : i18n("No data");
        }
        let best = root.meters[0];
        for (const meter of root.meters) {
            if (root.fraction(meter) > root.fraction(best)) {
                best = meter;
            }
        }
        return best.label + " " + Math.round(root.fraction(best) * 100) + "%";
    }

    Plasmoid.icon: "opencode-go"
    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    Plasmoid.title: i18n("OpenCode Go Usage")

    toolTipMainText: Plasmoid.title
    toolTipSubText: {
        if (root.errorText) {
            return root.errorText;
        }
        return root.hasData
            ? i18n("Go · %1", root.summaryText())
            : i18n("Loading…");
    }

    compactRepresentation: MouseArea {
        id: compactMouseArea

        anchors.fill: parent
        hoverEnabled: true

        QQC2.ToolTip.visible: containsMouse
        QQC2.ToolTip.text: root.toolTipSubText
        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay

        // Open the popup on click only.
        onClicked: root.expanded = !root.expanded

        Kirigami.Icon {
            anchors.fill: parent
            source: Plasmoid.icon
            active: compactMouseArea.containsMouse
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        id: popup

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

        contentItem: ColumnLayout {
            id: body

            spacing: Kirigami.Units.largeSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Label {
                    text: i18n("Go")
                    font.bold: true
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
                    Layout.alignment: Qt.AlignBaseline
                }

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignBaseline
                    text: root.renewsText(root.renewsAt)
                    opacity: 0.6
                    elide: Text.ElideRight
                }

                PlasmaComponents3.Button {
                    text: i18n("Manage")
                    // A flat button keeps the header from being dominated by a
                    // boxed control twice as tall as the text next to it.
                    flat: true
                    onClicked: Qt.openUrlExternally(root.consoleUrl)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                // Wider than the gap inside one meter (smallSpacing), so the
                // three meters read as groups instead of six unbroken lines.
                spacing: Math.round(Kirigami.Units.gridUnit * 0.75)
                visible: root.hasData

                Repeater {
                    model: root.meters

                    delegate: ColumnLayout {
                        id: meterRow

                        required property var modelData

                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.largeSpacing

                            PlasmaComponents3.Label {
                                // Fixed width so the label and the reset line
                                // below it cannot eat the bar's space.
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 7
                                Layout.maximumWidth: Kirigami.Units.gridUnit * 7
                                text: meterRow.modelData.label
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.minimumWidth: Kirigami.Units.gridUnit * 4
                                implicitHeight: Math.round(Kirigami.Units.gridUnit * 0.45)
                                radius: height / 2
                                color: Qt.rgba(Kirigami.Theme.textColor.r,
                                               Kirigami.Theme.textColor.g,
                                               Kirigami.Theme.textColor.b,
                                               0.2)

                                Rectangle {
                                    height: parent.height
                                    radius: parent.radius
                                    // Floor to the radius rather than the full
                                    // height, so a low value reads as a sliver
                                    // and not as a slider knob.
                                    width: Math.max(parent.radius,
                                                    parent.width * root.fraction(meterRow.modelData))
                                    color: root.barColor(root.fraction(meterRow.modelData))
                                }
                            }

                            PlasmaComponents3.Label {
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                                Layout.maximumWidth: Kirigami.Units.gridUnit * 3
                                text: root.percentText(meterRow.modelData)
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            // Line the reset text up under the label, not under
                            // the bar, which is what made it float before.
                            Layout.leftMargin: Kirigami.Units.gridUnit * 7 + Kirigami.Units.largeSpacing
                            text: root.resetText(meterRow.modelData.resetsAt)
                            font.pointSize: root.smallPointSize
                            opacity: 0.6
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            PlasmaExtras.PlaceholderMessage {
                Layout.fillWidth: true
                visible: !root.hasData
                iconName: "opencode-go"
                text: root.errorText || i18n("Loading…")
                explanation: root.errorText && root.renewsAt
                    ? i18n("Showing the last values received.")
                    : i18n("Reads usage from the OpenCode console API every minute.")
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                visible: root.hasData && root.errorText.length > 0
                text: root.errorText
                color: Kirigami.Theme.negativeTextColor
                font.pointSize: root.smallPointSize
                wrapMode: Text.WordWrap
            }

            Kirigami.Separator {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                visible: root.hasData
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                visible: root.hasData
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Label {
                    text: i18n("Updated %1", Qt.formatTime(new Date(root.nowMs), "HH:mm"))
                    font.pointSize: root.smallPointSize
                    opacity: 0.6
                }

                Item {
                    Layout.fillWidth: true
                }

                PlasmaComponents3.Label {
                    text: root.refreshCountdownText()
                    font.pointSize: root.smallPointSize
                    opacity: 0.6
                }
            }
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
            root.loading = false;

            const stdout = String(data.stdout || "").trim();
            let payload = null;
            try {
                payload = JSON.parse(stdout);
            } catch (error) {
                payload = null;
            }

            if (!payload || typeof payload !== "object") {
                root.errorCode = "bad-output";
                root.errorText = root.errorMessageFor("bad-output");
                return;
            }

            if (payload.ok) {
                root.meters = payload.meters || [];
                root.renewsAt = payload.renewsAt || "";
                root.hasData = root.meters.length > 0;
                root.errorCode = "";
                root.errorText = "";
                return;
            }

            root.errorCode = payload.error || "unknown";
            root.errorText = root.errorMessageFor(root.errorCode);
            // Keep the last good values in root.meters on purpose.
        }
    }

    Timer {
        id: pollTimer
        interval: root.pollIntervalMs
        repeat: true
        running: true
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

    Component.onCompleted: root.refresh()
}
