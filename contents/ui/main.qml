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

    // Populated from the helper JSON.
    property var meters: []
    property string renewsAt: ""
    property bool hasData: false
    property string errorCode: ""
    property string errorText: ""
    property bool loading: false

    // Ticked every poll so the "Resets in" countdown stays fresh.
    property double nowMs: Date.now()

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'";
    }

    function refresh() {
        root.loading = true;
        root.nowMs = Date.now();
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

    function fraction(meter) {
        if (!meter || !meter.limit || meter.limit <= 0) {
            return 0;
        }
        return Math.max(0, Math.min(1, meter.used / meter.limit));
    }

    function percentText(meter) {
        return Math.round(root.fraction(meter) * 100) + "% used";
    }

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

    Plasmoid.icon: "opencode-go-symbolic"
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

        Layout.minimumWidth: Kirigami.Units.gridUnit * 20
        Layout.minimumHeight: Kirigami.Units.gridUnit * 10
        Layout.preferredWidth: Kirigami.Units.gridUnit * 21
        collapseMarginsHint: true

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Label {
                    text: i18n("Go")
                    font.bold: true
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
                }

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: root.renewsText(root.renewsAt)
                    opacity: 0.6
                    elide: Text.ElideRight
                }

                PlasmaComponents3.Button {
                    text: i18n("Manage")
                    onClicked: Qt.openUrlExternally(root.consoleUrl)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing
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

                            ColumnLayout {
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                                spacing: 0

                                PlasmaComponents3.Label {
                                    text: meterRow.modelData.label
                                }

                                PlasmaComponents3.Label {
                                    Layout.fillWidth: true
                                    text: root.resetText(meterRow.modelData.resetsAt)
                                    font: Kirigami.Theme.smallFont
                                    opacity: 0.6
                                    elide: Text.ElideRight
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: Math.round(Kirigami.Units.gridUnit * 0.6)
                                radius: height / 2
                                color: Qt.rgba(Kirigami.Theme.textColor.r,
                                               Kirigami.Theme.textColor.g,
                                               Kirigami.Theme.textColor.b,
                                               0.15)

                                Rectangle {
                                    height: parent.height
                                    radius: parent.radius
                                    width: Math.max(parent.height,
                                                    parent.width * root.fraction(meterRow.modelData))
                                    color: "#4ec26a"
                                }
                            }

                            PlasmaComponents3.Label {
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                                text: root.percentText(meterRow.modelData)
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }
            }

            PlasmaExtras.PlaceholderMessage {
                Layout.fillWidth: true
                visible: !root.hasData
                iconName: "opencode-go-symbolic"
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
                font: Kirigami.Theme.smallFont
                wrapMode: Text.WordWrap
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                visible: root.hasData
                text: i18n("Updated %1", Qt.formatTime(new Date(root.nowMs), "HH:mm"))
                font: Kirigami.Theme.smallFont
                opacity: 0.6
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
        interval: 60000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
