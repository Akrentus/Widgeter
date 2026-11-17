import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    readonly property color separatorColor: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
    readonly property color cardBorderColor: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)

    preferredRepresentation: compactRepresentation

    // List of card objects: [{ title: "...", icon: "...", command: "..." }]
    property var cardsList: []

    // Data source for executing bash commands
    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            disconnectSource(sourceName);
        }
    }

    // Timer for delayed command launch (150 ms) after popup closes
    Timer {
        id: delayedCommandTimer
        interval: 150
        repeat: false
        property string commandToRun: ""

        onTriggered: {
            if (commandToRun && commandToRun.trim() !== "") {
                root.runCommand(commandToRun);
                commandToRun = "";
            }
        }
    }

    function runCommand(cmd) {
        if (!cmd || cmd.trim() === "") {
            return;
        }
        executable.disconnectSource(cmd);
        executable.connectSource(cmd);
    }

    function runCommandDelayed(cmd) {
        delayedCommandTimer.commandToRun = cmd;
        delayedCommandTimer.restart();
    }

    function loadCards() {
        try {
            var raw = Plasmoid.configuration ? Plasmoid.configuration.cardsJson : "";
            if (!raw || raw.trim() === "") {
                raw = '[{"title":"WIDGET","icon":"utilities-terminal","command":"konsole"},{"title":"WIDGET","icon":"system-file-manager","command":"dolphin"},{"title":"WIDGET","icon":"org.kde.plasma.systemmonitor","command":"plasma-systemmonitor"},{"title":"WIDGET","icon":"preferences-system","command":"systemsettings"}]';
            }
            cardsList = JSON.parse(raw);
        } catch (err) {
            console.error("Widgeter: error parsing cards JSON:", err);
            cardsList = [];
        }
    }

    Connections {
        target: Plasmoid.configuration
        function onCardsJsonChanged() {
            root.loadCards();
        }
    }

    Component.onCompleted: {
        loadCards();
    }

    // ==========================================
    // Compact Representation (Panel Button)
    // ==========================================
    compactRepresentation: MouseArea {
        id: compactRoot

        Layout.minimumWidth: Kirigami.Units.iconSizes.medium
        Layout.minimumHeight: Kirigami.Units.iconSizes.medium
        Layout.preferredWidth: Layout.minimumWidth
        Layout.preferredHeight: Layout.minimumHeight

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            root.expanded = !root.expanded;
        }

        Rectangle {
            anchors.fill: parent
            radius: Kirigami.Units.cornerRadius
            color: compactRoot.containsMouse || root.expanded
                   ? Kirigami.Theme.highlightColor
                   : "transparent"
            opacity: compactRoot.containsPress ? 0.35 : (compactRoot.containsMouse || root.expanded ? 0.2 : 0)
            Behavior on opacity {
                NumberAnimation { duration: Kirigami.Units.shortDuration }
            }
        }

        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) - Kirigami.Units.smallSpacing * 2
            height: width
            source: Plasmoid.configuration.panelIcon || "view-grid"
        }
    }

    // ==========================================
    // Full Representation (Dropdown Popup Window)
    // ==========================================
    fullRepresentation: Item {
        id: fullRoot

        Layout.minimumWidth: Kirigami.Units.gridUnit * 22
        Layout.minimumHeight: Kirigami.Units.gridUnit * 18
        Layout.preferredWidth: Kirigami.Units.gridUnit * 28
        Layout.preferredHeight: Kirigami.Units.gridUnit * 22

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing * 2
            spacing: Kirigami.Units.smallSpacing * 2

            // Top Header Bar
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: Plasmoid.configuration.panelIcon || "view-grid"
                    implicitWidth: Kirigami.Units.iconSizes.smallMedium
                    implicitHeight: implicitWidth
                }

                Kirigami.Heading {
                    level: 2
                    text: i18n("Widgeter")
                    Layout.fillWidth: true
                }
            }

            // Separator
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: root.separatorColor
            }

            // Cards Grid View Area
            PlasmaComponents.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth

                // Empty state if no cards exist
                Item {
                    anchors.fill: parent
                    visible: root.cardsList.length === 0

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Kirigami.Units.largeSpacing

                        Kirigami.Icon {
                            Layout.alignment: Qt.AlignHCenter
                            source: "view-grid"
                            implicitWidth: Kirigami.Units.iconSizes.huge
                            implicitHeight: implicitWidth
                            opacity: 0.4
                        }

                        PlasmaComponents.Label {
                            Layout.alignment: Qt.AlignHCenter
                            text: i18n("No cards configured")
                            font.weight: Font.Bold
                            opacity: 0.7
                        }

                        PlasmaComponents.Label {
                            Layout.alignment: Qt.AlignHCenter
                            text: i18n("Right click widget and choose 'Configure Widgeter…' to add cards.")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.5
                        }
                    }
                }

                // Cards Grid Area (1 or 2 columns based on configuration)
                GridLayout {
                    id: cardsGrid
                    width: parent.width
                    columns: (Plasmoid.configuration && Plasmoid.configuration.gridColumns === 2) ? 2 : 1
                    columnSpacing: Kirigami.Units.smallSpacing * 2
                    rowSpacing: Kirigami.Units.smallSpacing * 2
                    visible: root.cardsList.length > 0

                    Repeater {
                        model: root.cardsList

                        delegate: Rectangle {
                            id: cardDelegate
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            Layout.preferredWidth: cardsGrid.columns === 2
                                ? (cardsGrid.width - cardsGrid.columnSpacing) / 2
                                : cardsGrid.width
                            Layout.maximumWidth: cardsGrid.columns === 2
                                ? (cardsGrid.width - cardsGrid.columnSpacing) / 2
                                : -1
                            implicitHeight: Kirigami.Units.gridUnit * 3.2

                            radius: 10
                            color: {
                                if (cardMouseArea.containsPress) {
                                    return Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.25);
                                }
                                if (cardMouseArea.containsMouse) {
                                    return Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.12);
                                }
                                return Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.06);
                            }

                            border.width: 1
                            border.color: cardMouseArea.containsMouse
                                          ? Kirigami.Theme.highlightColor
                                          : root.cardBorderColor

                            Behavior on color {
                                ColorAnimation { duration: Kirigami.Units.shortDuration }
                            }
                            Behavior on border.color {
                                ColorAnimation { duration: Kirigami.Units.shortDuration }
                            }

                            MouseArea {
                                id: cardMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    root.expanded = false;
                                    root.runCommandDelayed(cardDelegate.modelData.command);
                                }
                            }

                            // Card Content Split by Vertical Line
                            RowLayout {
                                anchors.fill: parent
                                spacing: 0

                                // Left: Custom Icon
                                Item {
                                    Layout.preferredWidth: cardDelegate.height
                                    Layout.fillHeight: true

                                    Kirigami.Icon {
                                        anchors.centerIn: parent
                                        width: Kirigami.Units.iconSizes.medium
                                        height: Kirigami.Units.iconSizes.medium
                                        source: cardDelegate.modelData.icon || "application-x-executable"
                                    }
                                }

                                // Center: Thin Vertical Line
                                Rectangle {
                                    Layout.preferredWidth: 1
                                    Layout.fillHeight: true
                                    Layout.topMargin: Kirigami.Units.smallSpacing * 1.5
                                    Layout.bottomMargin: Kirigami.Units.smallSpacing * 1.5
                                    color: root.separatorColor
                                }

                                // Right: User Label
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.leftMargin: Kirigami.Units.smallSpacing * 2
                                    Layout.rightMargin: Kirigami.Units.smallSpacing * 2

                                    PlasmaComponents.Label {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        Layout.alignment: Qt.AlignVCenter
                                        text: cardDelegate.modelData.title || "WIDGET"
                                        font.weight: Font.DemiBold
                                        font.pointSize: Kirigami.Theme.defaultFont.pointSize
                                        elide: Text.ElideRight
                                        color: Kirigami.Theme.textColor
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
