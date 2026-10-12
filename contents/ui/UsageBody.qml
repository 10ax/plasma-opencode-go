pragma ComponentBehavior: Bound

// The popup's body: header, meter list, error/empty states and footer. It owns
// the presentation and the i18n text; the polling state it shows is passed in
// by main.qml.
import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras

import "../js/usage.js" as Usage

ColumnLayout {
    id: body

    required property var meters         // visible meters, already filtered
    required property string percentMode // "used" (default) or "remaining"
    required property bool hasData
    required property string renewsAt
    required property string errorText
    required property bool showFooter
    required property double nowMs
    required property int smallPointSize // point size for the secondary lines
    required property string refreshText // e.g. "Refreshing in 12s"
    required property url consoleUrl

    property string iconName: "opencode-go"

    spacing: Kirigami.Units.largeSpacing

    readonly property bool hasVisibleMeters: body.meters.length > 0
    readonly property bool footerVisible: body.hasData && body.showFooter

    // Green/amber/red ramp driven by the theme, so the bar follows the user's
    // colour scheme instead of a hardcoded green. Always keyed on the share
    // used, so red keeps meaning "nearly out" in either percentage mode.
    function barColor(usedFraction) {
        if (usedFraction >= 0.9) {
            return Kirigami.Theme.negativeTextColor;
        }
        if (usedFraction >= 0.7) {
            return Kirigami.Theme.neutralTextColor;
        }
        return Kirigami.Theme.highlightColor;
    }

    function resetText(iso) {
        const date = Usage.parseIso(iso);
        const parts = date ? Usage.durationParts(date.getTime() - body.nowMs) : null;
        if (!parts) {
            return "";
        }
        if (parts.expired) {
            return i18n("Resets now");
        }
        if (parts.days > 0) {
            return i18n("Resets in %1d %2h", parts.days, parts.hours);
        }
        if (parts.hours > 0) {
            return i18n("Resets in %1h %2m", parts.hours, parts.minutes);
        }
        return i18n("Resets in %1m", parts.minutes);
    }

    function renewsText() {
        const date = Usage.parseIso(body.renewsAt);
        return date ? i18n("Renews %1", Qt.formatDate(date, "MMM d")) : "";
    }

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
            text: body.renewsText()
            opacity: 0.6
            elide: Text.ElideRight
        }

        PlasmaComponents3.Button {
            text: i18n("Manage")
            // A flat button keeps the header from being dominated by a boxed
            // control twice as tall as the text next to it.
            flat: true
            onClicked: Qt.openUrlExternally(body.consoleUrl)
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        // Wider than the gap inside one meter (smallSpacing), so the meters
        // read as groups instead of unbroken lines.
        spacing: Math.round(Kirigami.Units.gridUnit * 0.75)
        visible: body.hasVisibleMeters

        Repeater {
            model: body.meters

            delegate: MeterRow {
                required property var modelData

                smallPointSize: body.smallPointSize
                label: modelData.label
                usedFraction: Usage.usedFraction(modelData)
                displayFraction: Usage.displayFraction(modelData, body.percentMode)
                percentText: Usage.percent(modelData, body.percentMode) + "%"
                resetText: body.resetText(modelData.resetsAt)
                barColor: body.barColor(Usage.usedFraction(modelData))
            }
        }
    }

    PlasmaExtras.PlaceholderMessage {
        Layout.fillWidth: true
        visible: body.hasData && !body.hasVisibleMeters
        iconName: body.iconName
        text: i18n("All meters are hidden")
        explanation: i18n("Turn at least one meter back on in the widget settings.")
    }

    PlasmaExtras.PlaceholderMessage {
        Layout.fillWidth: true
        visible: !body.hasData
        iconName: body.iconName
        text: body.errorText || i18n("Loading…")
        explanation: body.errorText && body.renewsAt
            ? i18n("Showing the last values received.")
            : i18n("Reads usage from the OpenCode console API every minute.")
    }

    PlasmaComponents3.Label {
        Layout.fillWidth: true
        visible: body.hasData && body.errorText.length > 0
        text: body.errorText
        color: Kirigami.Theme.negativeTextColor
        font.pointSize: body.smallPointSize
        wrapMode: Text.WordWrap
    }

    Kirigami.Separator {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        visible: body.footerVisible
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        visible: body.footerVisible
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents3.Label {
            text: i18n("Updated %1", Qt.formatTime(new Date(body.nowMs), "HH:mm"))
            font.pointSize: body.smallPointSize
            opacity: 0.6
        }

        Item {
            Layout.fillWidth: true
        }

        PlasmaComponents3.Label {
            text: body.refreshText
            font.pointSize: body.smallPointSize
            opacity: 0.6
        }
    }
}
