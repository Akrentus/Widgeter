import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs as QtDialogs
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.iconthemes as KIconThemes

KCM.SimpleKCM {
    id: configRoot

    property string cfg_panelIcon: Plasmoid.configuration ? Plasmoid.configuration.panelIcon : "view-grid"
    property string cfg_cardsJson: Plasmoid.configuration ? Plasmoid.configuration.cardsJson : ""
    property alias cfg_gridColumns: gridColumnsCombo.value

    readonly property color separatorColor: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)

    ListModel {
        id: cardsListModel
    }

    onCfg_cardsJsonChanged: {
        try {
            if (cfg_cardsJson && cfg_cardsJson !== serializeCardsModel()) {
                loadCardsFromConfig();
            }
        } catch (e) {}
    }

    function serializeCardsModel() {
        let arr = [];
        for (let i = 0; i < cardsListModel.count; i++) {
            let item = cardsListModel.get(i);
            arr.push({
                title: item.title,
                icon: item.icon,
                command: item.command
            });
        }
        return JSON.stringify(arr);
    }

    function loadCardsFromConfig() {
        try {
            var raw = cfg_cardsJson || (Plasmoid.configuration ? Plasmoid.configuration.cardsJson : "");
            if (!raw || raw.trim() === "") {
                raw = '[{"title":"WIDGET","icon":"utilities-terminal","command":"konsole"},{"title":"WIDGET","icon":"system-file-manager","command":"dolphin"},{"title":"WIDGET","icon":"org.kde.plasma.systemmonitor","command":"plasma-systemmonitor"},{"title":"WIDGET","icon":"preferences-system","command":"systemsettings"}]';
            }
            var parsed = JSON.parse(raw);
            if (!Array.isArray(parsed)) {
                parsed = [];
            }
            cardsListModel.clear();
            for (let i = 0; i < parsed.length; i++) {
                let entry = parsed[i] || {};
                cardsListModel.append({
                    title: entry.title !== undefined && entry.title !== null ? String(entry.title) : "",
                    icon: entry.icon !== undefined && entry.icon !== null ? String(entry.icon) : "",
                    command: entry.command !== undefined && entry.command !== null ? String(entry.command) : ""
                });
            }
        } catch (err) {
            console.error("Widgeter Config: error parsing JSON:", err);
            cardsListModel.clear();
        }
    }

    function syncCardsToConfig() {
        cfg_cardsJson = serializeCardsModel();
    }

    function addCard() {
        cardsListModel.append({
            title: "WIDGET",
            icon: "application-x-executable",
            command: ""
        });
        syncCardsToConfig();
    }

    function removeCard(idx) {
        if (idx >= 0 && idx < cardsListModel.count) {
            cardsListModel.remove(idx, 1);
            syncCardsToConfig();
        }
    }

    function moveUp(idx) {
        if (idx > 0 && idx < cardsListModel.count) {
            cardsListModel.move(idx, idx - 1, 1);
            syncCardsToConfig();
        }
    }

    function moveDown(idx) {
        if (idx >= 0 && idx < cardsListModel.count - 1) {
            cardsListModel.move(idx, idx + 1, 1);
            syncCardsToConfig();
        }
    }

    function updateCardField(idx, field, value) {
        if (idx >= 0 && idx < cardsListModel.count) {
            cardsListModel.setProperty(idx, field, value);
            syncCardsToConfig();
        }
    }

    Component.onCompleted: {
        loadCardsFromConfig();
    }

    // Dialogs for picking icons and image files
    KIconThemes.IconDialog {
        id: configIconDialog
        property var onChosen: null
        onIconNameChanged: {
            if (iconName && onChosen) {
                onChosen(iconName);
            }
        }
    }

    QtDialogs.FileDialog {
        id: configFileDialog
        title: i18n("Choose Icon Image")
        fileMode: QtDialogs.FileDialog.OpenFile
        nameFilters: ["Image files (*.png *.svg *.jpg *.jpeg *.webp)", "All files (*)"]
        property var onChosen: null
        onAccepted: {
            if (selectedFile && onChosen) {
                let path = selectedFile.toString();
                if (path.indexOf("file://") === 0) {
                    path = decodeURIComponent(path.substring(7));
                }
                onChosen(path);
            }
        }
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing
        Layout.fillWidth: true

        // ==========================================
        // SECTION 1: General & Layout Configuration
        // ==========================================
        Kirigami.FormLayout {
            Layout.fillWidth: true

            Item {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("General")
            }

            RowLayout {
                Kirigami.FormData.label: i18n("Icon:")
                spacing: Kirigami.Units.smallSpacing

                Rectangle {
                    width: 36
                    height: 36
                    radius: 6
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)
                    border.width: 1
                    border.color: configRoot.separatorColor

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        source: configRoot.cfg_panelIcon || "view-grid"
                    }
                }

                QQC2.TextField {
                    id: panelIconField
                    text: configRoot.cfg_panelIcon
                    Layout.fillWidth: true
                    placeholderText: "view-grid"
                    onTextChanged: {
                        configRoot.cfg_panelIcon = text;
                    }
                }

                QQC2.Button {
                    icon.name: "preferences-desktop-icons"
                    text: i18n("System Icon…")
                    onClicked: {
                        configIconDialog.onChosen = function(name) {
                            configRoot.cfg_panelIcon = name;
                        };
                        configIconDialog.open();
                    }
                }

                QQC2.Button {
                    icon.name: "document-open"
                    text: i18n("Choose File…")
                    onClicked: {
                        configFileDialog.onChosen = function(path) {
                            configRoot.cfg_panelIcon = path;
                        };
                        configFileDialog.open();
                    }
                }

                QQC2.Button {
                    icon.name: "edit-clear"
                    text: i18n("Reset")
                    onClicked: {
                        configRoot.cfg_panelIcon = "view-grid";
                    }
                }
            }

            QQC2.ComboBox {
                id: gridColumnsCombo
                Kirigami.FormData.label: i18n("Grid layout:")
                Layout.fillWidth: true
                property int value: (Plasmoid.configuration && Plasmoid.configuration.gridColumns) ? Plasmoid.configuration.gridColumns : 1

                model: [
                    i18n("1 column (wide cards)"),
                    i18n("2 columns (two per row)")
                ]

                onValueChanged: {
                    let target = (value === 2 ? 1 : 0);
                    if (currentIndex !== target) {
                        currentIndex = target;
                    }
                }

                Component.onCompleted: {
                    let target = (value === 2 ? 1 : 0);
                    if (currentIndex !== target) {
                        currentIndex = target;
                    }
                }

                onActivated: index => {
                    value = (index === 1 ? 2 : 1);
                }

                onCurrentIndexChanged: {
                    let expected = (currentIndex === 1 ? 2 : 1);
                    if (value !== expected) {
                        value = expected;
                    }
                }
            }
        }

        // ==========================================
        // SECTION 2: Cards Management
        // ==========================================
        Kirigami.FormLayout {
            Layout.fillWidth: true

            Item {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Cards Configuration")
            }

            RowLayout {
                Kirigami.FormData.label: i18n("Actions:")

                QQC2.Button {
                    icon.name: "list-add"
                    text: i18n("Add Card")
                    highlighted: true
                    onClicked: configRoot.addCard()
                }

                QQC2.Label {
                    text: i18np("%1 card configured", "%1 cards configured", cardsListModel.count)
                    opacity: 0.7
                }
            }
        }

        // List of Cards
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing * 2

            Repeater {
                model: cardsListModel

                delegate: Rectangle {
                    id: cardConfigItem
                    required property int index
                    required property string title
                    required property string icon
                    required property string command

                    Layout.fillWidth: true
                    implicitHeight: cardInnerLayout.implicitHeight + Kirigami.Units.smallSpacing * 4

                    radius: 8
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.04)
                    border.width: 1
                    border.color: configRoot.separatorColor

                    ColumnLayout {
                        id: cardInnerLayout
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.smallSpacing * 2
                        spacing: Kirigami.Units.smallSpacing

                        // Card item header (Index + Reorder/Delete buttons)
                        RowLayout {
                            Layout.fillWidth: true

                            Kirigami.Heading {
                                level: 4
                                text: i18n("Card #%1", cardConfigItem.index + 1)
                                Layout.fillWidth: true
                            }

                            QQC2.Button {
                                icon.name: "go-up"
                                display: QQC2.AbstractButton.IconOnly
                                enabled: cardConfigItem.index > 0
                                QQC2.ToolTip.visible: hovered
                                QQC2.ToolTip.text: i18n("Move Up")
                                onClicked: configRoot.moveUp(cardConfigItem.index)
                            }

                            QQC2.Button {
                                icon.name: "go-down"
                                display: QQC2.AbstractButton.IconOnly
                                enabled: cardConfigItem.index < cardsListModel.count - 1
                                QQC2.ToolTip.visible: hovered
                                QQC2.ToolTip.text: i18n("Move Down")
                                onClicked: configRoot.moveDown(cardConfigItem.index)
                            }

                            QQC2.Button {
                                icon.name: "edit-delete"
                                display: QQC2.AbstractButton.IconOnly
                                QQC2.ToolTip.visible: hovered
                                QQC2.ToolTip.text: i18n("Delete Card")
                                onClicked: configRoot.removeCard(cardConfigItem.index)
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)
                        }

                        // Label input
                        RowLayout {
                            Layout.fillWidth: true

                            QQC2.Label {
                                text: i18n("Label:")
                                Layout.minimumWidth: Kirigami.Units.gridUnit * 5
                            }

                            QQC2.TextField {
                                text: cardConfigItem.title
                                placeholderText: "WIDGET"
                                Layout.fillWidth: true
                                onTextChanged: {
                                    if (cardConfigItem.title !== text) {
                                        configRoot.updateCardField(cardConfigItem.index, "title", text);
                                    }
                                }
                            }
                        }

                        // Icon selection
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                            QQC2.Label {
                                text: i18n("Icon:")
                                Layout.minimumWidth: Kirigami.Units.gridUnit * 5
                            }

                            Rectangle {
                                width: 32
                                height: 32
                                radius: 4
                                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)
                                border.width: 1
                                border.color: configRoot.separatorColor

                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    width: 22
                                    height: 22
                                    source: cardConfigItem.icon || "application-x-executable"
                                }
                            }

                            QQC2.TextField {
                                id: cardIconInput
                                text: cardConfigItem.icon
                                placeholderText: "application-x-executable"
                                Layout.fillWidth: true
                                onTextChanged: {
                                    if (cardConfigItem.icon !== text) {
                                        configRoot.updateCardField(cardConfigItem.index, "icon", text);
                                    }
                                }
                            }

                            QQC2.Button {
                                icon.name: "preferences-desktop-icons"
                                text: i18n("System…")
                                onClicked: {
                                    configIconDialog.onChosen = function(name) {
                                        configRoot.updateCardField(cardConfigItem.index, "icon", name);
                                    };
                                    configIconDialog.open();
                                }
                            }

                            QQC2.Button {
                                icon.name: "document-open"
                                text: i18n("File…")
                                onClicked: {
                                    configFileDialog.onChosen = function(path) {
                                        configRoot.updateCardField(cardConfigItem.index, "icon", path);
                                    };
                                    configFileDialog.open();
                                }
                            }
                        }

                        // Bash Command input
                        RowLayout {
                            Layout.fillWidth: true

                            QQC2.Label {
                                text: i18n("Command:")
                                Layout.minimumWidth: Kirigami.Units.gridUnit * 5
                            }

                            QQC2.TextField {
                                text: cardConfigItem.command
                                placeholderText: i18n("Bash command (e.g. konsole)")
                                Layout.fillWidth: true
                                onTextChanged: {
                                    if (cardConfigItem.command !== text) {
                                        configRoot.updateCardField(cardConfigItem.index, "command", text);
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
