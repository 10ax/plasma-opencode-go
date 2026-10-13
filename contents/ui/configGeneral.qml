import QtQuick
import QtQuick.Controls as QQC2

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

// Config page for the "General" group in contents/config/main.xml.
//
// The root is KCM.SimpleKCM (a Kirigami.ScrollablePage), not a bare
// Kirigami.FormLayout: the dialog pushes the page with a "title" initial property
// (the category name) that the PageRow toolbar renders as the page heading, and
// only a Page has that property or the page padding. Plasma's own config pages
// do the same.
//
// The framework copies every entry onto this item as a cfg_<name> property, so
// the controls write through those rather than touching Plasmoid.configuration
// directly (that would skip Apply/Discard).
KCM.SimpleKCM {
    id: page

    property alias cfg_pollIntervalSeconds: intervalSpin.value
    property alias cfg_showRolling: rollingCheck.checked
    property alias cfg_showWeekly: weeklyCheck.checked
    property alias cfg_showMonthly: monthlyCheck.checked
    property alias cfg_showFooter: footerCheck.checked
    property alias cfg_showTrayText: trayTextCheck.checked
    property alias cfg_showAmounts: amountsCheck.checked

    // Not an alias: ComboBox maps its current index to a string value.
    property string cfg_percentMode
    property string cfg_layoutMode

    Kirigami.FormLayout {
        QQC2.SpinBox {
            id: intervalSpin

            Kirigami.FormData.label: i18n("Refresh every:")

            from: 15
            to: 1800
            stepSize: 15
            editable: true
            textFromValue: (value) => i18n("%1 s", value)
            valueFromText: (text) => Number.parseInt(text, 10) || 60
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Meters")
        }

        QQC2.CheckBox {
            id: rollingCheck
            text: i18n("Rolling (5 hour)")
        }

        QQC2.CheckBox {
            id: weeklyCheck
            text: i18n("Weekly")
        }

        QQC2.CheckBox {
            id: monthlyCheck
            text: i18n("Monthly")
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Display")
        }

        QQC2.ComboBox {
            id: percentCombo

            Kirigami.FormData.label: i18n("Show:")

            textRole: "text"
            model: [
                { value: "used", text: i18n("Percentage used") },
                { value: "remaining", text: i18n("Percentage remaining") }
            ]
            currentIndex: page.cfg_percentMode === "remaining" ? 1 : 0
            onActivated: page.cfg_percentMode = model[currentIndex].value
        }

        QQC2.CheckBox {
            id: footerCheck
            text: i18n("Show last update and next refresh")
        }

        QQC2.CheckBox {
            id: trayTextCheck
            text: i18n("Show the percentage next to the tray icon")
        }

        QQC2.ComboBox {
            id: layoutCombo

            Kirigami.FormData.label: i18n("Popup layout:")

            textRole: "text"
            model: [
                { value: "centred", text: i18n("Centred — put the spare space above and below the data") },
                { value: "compact", text: i18n("Compact — keep the rows tight, spare space at the bottom") }
            ]
            currentIndex: {
                const index = model.findIndex((entry) => entry.value === page.cfg_layoutMode);
                return index >= 0 ? index : 0;
            }
            onActivated: page.cfg_layoutMode = model[currentIndex].value
        }

        QQC2.CheckBox {
            id: amountsCheck
            text: i18n("Show the used and total allowance under each meter")
        }
    }
}
