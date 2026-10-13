// One meter: name, progress bar, percentage, and the reset countdown under the
// name. It receives every value from the parent and only turns the share into
// pixels, through the shared helper in js/usage.js.
import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

import "../js/usage.js" as Usage

ColumnLayout {
    id: meterRow

    required property string label
    required property real usedFraction    // drives the colour ramp
    required property real displayFraction // drives the bar width
    required property string percentText
    required property string resetText
    required property color barColor
    required property int smallPointSize

    Layout.fillWidth: true
    spacing: Kirigami.Units.smallSpacing

    // Fixed widths so a long label or a wide percentage cannot eat the bar.
    readonly property real labelWidth: Kirigami.Units.gridUnit * 7
    readonly property real percentWidth: Kirigami.Units.gridUnit * 3

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.largeSpacing

        PlasmaComponents3.Label {
            Layout.preferredWidth: meterRow.labelWidth
            Layout.maximumWidth: meterRow.labelWidth
            text: meterRow.label
            elide: Text.ElideRight
        }

        // Track with the filled share drawn on top of it.
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
                // A zero share leaves the track empty; a small non-zero one is
                // floored to the radius so it reads as a sliver rather than a
                // slider knob.
                width: Usage.fillWidth(meterRow.displayFraction, parent.width, parent.radius)
                color: meterRow.barColor
            }
        }

        PlasmaComponents3.Label {
            Layout.preferredWidth: meterRow.percentWidth
            Layout.maximumWidth: meterRow.percentWidth
            text: meterRow.percentText
            horizontalAlignment: Text.AlignRight
        }
    }

    PlasmaComponents3.Label {
        Layout.fillWidth: true
        // Line the reset text up under the label, not under the bar, which is
        // what made it float before.
        Layout.leftMargin: meterRow.labelWidth + Kirigami.Units.largeSpacing
        text: meterRow.resetText
        font.pointSize: meterRow.smallPointSize
        opacity: 0.6
        elide: Text.ElideRight
    }
}
