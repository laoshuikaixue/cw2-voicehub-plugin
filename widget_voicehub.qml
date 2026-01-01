import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import RinUI
import Widgets

Widget {
    id: root
    text: "VoiceHub广播站排期 | LaoShui"
    width: 380 // 设置足够宽度以显示歌曲信息

    property var songs: []
    property string displayDate: ""
    property string status: "loading" // loading, success, error, no_schedule

    onBackendChanged: {
        if (backend) {
            backend.init_content()
        }
    }

    // 连接后端信号
    Connections {
        target: backend

        function onContentUpdated(newSongs, newDate, newStatus) {
            songs = newSongs;
            displayDate = newDate;
            status = newStatus;

            if (newDate) {
                root.text = "VoiceHub广播站排期 | " + newDate;
            } else {
                root.text = "VoiceHub广播站排期 | LaoShui";
            }
        }
    }

    Flickable {
        id: flickable
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentLayout.height
        clip: true
        interactive: true

        ColumnLayout {
            id: contentLayout
            width: parent.width
            spacing: 2 // 减小歌曲之间的间距

            // 状态提示文本 (加载/错误/无排期)
            Text {
                visible: status !== "success"
                text: {
                    if (status === "loading") return "正在加载排期...";
                    if (status === "error") return "网络连接异常\n10分钟后自动重试";
                    if (status === "no_schedule") return "暂无排期\n1小时后自动刷新";
                    return "";
                }
                font.pointSize: 14
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 20

                color: root.miniMode ? "#555" : (Theme.isDark() ? "#ccc" : "#555")
            }

            // 歌曲列表
            Repeater {
                model: status === "success" ? songs : 0
                delegate: Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: songText.implicitHeight + 8 // 增加一点间距

                    Text {
                        id: songText
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter

                        text: {
                            var s = modelData.song;
                            var seq = modelData.sequence || (index + 1);
                            var artist = s.artist || "未知艺术家";
                            var title = s.title || "未知歌曲";
                            var req = s.requester || "未知";
                            return seq + ". " + artist + " - " + title + " - " + req;
                        }

                        font.pointSize: 12
                        font.bold: true
                        wrapMode: Text.Wrap

                        color: root.miniMode ? "#000" : (Theme.isDark() ? "#fff" : "#000")

                        onImplicitHeightChanged: restartAnimTimer.restart()
                    }
                }
            }

            // 版权信息
            Text {
                visible: status === "success" && songs.length > 0
                text: "Supported by VoiceHub | LaoShui @ 2026"
                font.pointSize: 10
                horizontalAlignment: Text.AlignHCenter
                opacity: 0.7

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 10
                Layout.bottomMargin: 10

                color: root.miniMode ? "#555" : (Theme.isDark() ? "#ccc" : "#555")
            }
        }
    }

    // 延迟启动动画的 Timer
    Timer {
        id: restartAnimTimer
        interval: 500
        onTriggered: checkAndStartScroll()
    }

    // 自动滚动动画
    SequentialAnimation {
        id: autoScrollAnim
        loops: Animation.Infinite

        // 1. 向下滚动
        NumberAnimation {
            id: scrollDown
            target: flickable
            "contentY"
            duration: 0
            easing.type: Easing.Linear
        }

        // 2. 立即平滑回滚顶部
        NumberAnimation {
            target: flickable
            "contentY"
            to: 0
            duration: 1000
            easing.type: Easing.InOutQuad
        }
    }

    function checkAndStartScroll() {
        autoScrollAnim.stop()
        flickable.contentY = 0

        // 非成功状态不滚动
        if (status !== "success") return;

        if (contentLayout.height > flickable.height) {
            var distance = contentLayout.height - flickable.height
            scrollDown.to = distance
            // 速度：每像素 50ms
            scrollDown.duration = Math.max(1000, distance * 50)
            autoScrollAnim.start()
        }
    }

    // 监听高度变化
    onHeightChanged: restartAnimTimer.restart()
}
