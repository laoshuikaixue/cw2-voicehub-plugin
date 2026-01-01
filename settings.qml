
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import RinUI
import ClassWidgets.Plugins

FluentPage {
    // 属性
    property var pluginId: "com.laoshui.voicehub"
    property var settings: Configs.data.plugins.configs[pluginId]

    title: qsTr("VoiceHub 插件设置")

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        SettingCard {
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            icon.name: "ic_fluent_globe_20_regular"
            title: qsTr("API 地址")
            description: qsTr("设置 VoiceHub API 的公开接口地址")

            ColumnLayout {
                spacing: 8
                
                TextField {
                    id: apiUrlField
                    Layout.preferredWidth: 400
                    Layout.fillWidth: true
                    text: (settings && settings.api_url) ? settings.api_url : "https://voicehub.lao-shui.top/api/songs/public"
                    placeholderText: "https://example.com/api/songs/public"
                    
                    onEditingFinished: {
                        if (text !== settings.api_url) {
                            Configs.setPlugin(pluginId, "api_url", text)
                        }
                    }
                }

                Text {
                    text: qsTr("默认: https://voicehub.lao-shui.top/api/songs/public")
                    font: Typography.caption
                    color: Theme.currentTheme.colors.textSecondaryColor
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            spacing: 12

            Button {
                text: qsTr("测试连接")
                icon.name: "ic_fluent_plug_connected_20_regular"
                onClicked: testConnection(apiUrlField.text)
            }

            Button {
                text: qsTr("重置为默认")
                icon.name: "ic_fluent_arrow_reset_20_regular"
                onClicked: {
                    apiUrlField.text = "https://voicehub.lao-shui.top/api/songs/public"
                    Configs.setPlugin(pluginId, "api_url", apiUrlField.text)
                    
                    floatLayer.createInfoBar({
                        title: qsTr("重置成功"),
                        text: qsTr("API 地址已重置为默认值"),
                        severity: Severity.Success
                    })
                }
            }
        }

        InfoBar {
            Layout.fillWidth: true
            title: qsTr("说明")
            severity: Severity.Info
            closable: false
            text: "• " + qsTr("请确保API地址返回的数据格式与默认API兼容") + "<br>" +
                  "• " + qsTr("修改设置后将在下次刷新时生效") + "<br>" +
                  "• " + qsTr("如果连接失败，请检查网络连接和API地址是否正确")
        }
    }

    function testConnection(url) {
        floatLayer.createInfoBar({
            title: qsTr("正在测试"),
            text: qsTr("正在尝试连接到 API..."),
            severity: Severity.Info,
            duration: 1000
        })
        
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var json = JSON.parse(xhr.responseText)
                        if (Array.isArray(json)) {
                            floatLayer.createInfoBar({
                                title: qsTr("连接成功"),
                                text: qsTr("成功连接到 API 且数据格式正确"),
                                severity: Severity.Success
                            })
                        } else {
                            floatLayer.createInfoBar({
                                title: qsTr("格式错误"),
                                text: qsTr("连接成功，但返回数据格式不正确（应为数组）"),
                                severity: Severity.Warning
                            })
                        }
                    } catch (e) {
                         floatLayer.createInfoBar({
                            title: qsTr("解析失败"),
                            text: qsTr("连接成功，但返回了无效的 JSON 数据"),
                            severity: Severity.Warning
                        })
                    }
                } else {
                    floatLayer.createInfoBar({
                        title: qsTr("连接失败"),
                        text: qsTr("无法连接到服务器: ") + xhr.status + " " + xhr.statusText,
                        severity: Severity.Error
                    })
                }
            }
        }
        xhr.open("GET", url)
        xhr.send()
    }
}
