"""
VoiceHub 广播站排期
展示广播站当日排期歌曲，按播放顺序显示歌曲信息
"""

import time
import requests
from datetime import datetime, timedelta, timezone
from pathlib import Path
from PySide6.QtCore import Qt, QTimer, Signal, QThread, Slot
from loguru import logger
from ClassWidgets.SDK import CW2Plugin, PluginAPI

WIDGET_ID = 'widget_voicehub'
WIDGET_NAME = 'VoiceHub 广播站排期'
API_URL = "https://voicehub.lao-shui.top/api/songs/public"

HEADERS = {
    'User-Agent': (
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/91.0.4472.124 Safari/537.36 Edge/91.0.864.64'
    )
}


class FetchThread(QThread):
    """网络请求线程"""
    # songs(list), display_date(str), status(str: success/no_schedule)
    fetch_finished = Signal(list, str, str)
    fetch_failed = Signal()

    def __init__(self):
        super().__init__()
        self.max_retries = 3

    def run(self):
        retry_count = 0
        while retry_count < self.max_retries:
            try:
                response = requests.get(API_URL, headers=HEADERS, proxies={'http': None, 'https': None})
                response.raise_for_status()
                data = response.json()

                if isinstance(data, list) and data:
                    # 获取今天的日期 (北京时间 UTC+8)
                    tz_cn = timezone(timedelta(hours=8))
                    today = datetime.now(tz_cn).date()

                    # 1. 尝试获取今天的歌曲
                    today_songs = []
                    for item in data:
                        # playDate 格式如 "2023-10-01T00:00:00.000Z"
                        # 简单处理：截取前10位日期
                        play_date_str = item.get('playDate', '')[:10]
                        try:
                            play_date = datetime.strptime(play_date_str, '%Y-%m-%d').date()
                        except ValueError:
                            continue
                            
                        if play_date == today:
                            today_songs.append(item)

                    today_songs.sort(key=lambda x: x.get('sequence', 0))

                    if today_songs:
                        self.fetch_finished.emit(today_songs, today.strftime('%Y/%m/%d'), "success")
                        return

                    # 2. 如果今天没有，查找未来最近的排期
                    logger.warning("今天没有找到歌曲排期，尝试查找往后最近的排期")
                    future_dates = {}
                    for item in data:
                        play_date_str = item.get('playDate', '')[:10]
                        try:
                            play_date = datetime.strptime(play_date_str, '%Y-%m-%d').date()
                        except ValueError:
                            continue

                        if play_date > today:
                            if play_date not in future_dates:
                                future_dates[play_date] = []
                            future_dates[play_date].append(item)

                    if future_dates:
                        nearest_date = min(future_dates.keys())
                        nearest_songs = future_dates[nearest_date]
                        nearest_songs.sort(key=lambda x: x.get('sequence', 0))

                        logger.info(f"找到往后最近的排期日期: {nearest_date}")
                        self.fetch_finished.emit(nearest_songs, nearest_date.strftime('%Y/%m/%d'), "success")
                        return
                    else:
                        logger.warning("未找到任何往后的排期")
                        self.fetch_finished.emit([], "", "no_schedule")
                        return
                else:
                    logger.error("API返回空数据或格式错误")
                    
            except Exception as e:
                logger.error(f"请求失败: {e}")

            retry_count += 1
            time.sleep(2)

        self.fetch_failed.emit()


class Plugin(CW2Plugin):
    # songs(list), display_date(str), status(str)
    contentUpdated = Signal(list, str, str)
    
    def __init__(self, api: PluginAPI):
        super().__init__(api)
        self.api = api
        
        # 缓存数据
        self.songs = []
        self.display_date = ""
        self.status = "loading"  # loading, success, error, no_schedule
        
        # 注册小组件
        widget_qml_path = Path(__file__).parent / "widget_voicehub.qml"
        self.api.widgets.register(
            widget_id=WIDGET_ID,
            name=WIDGET_NAME,
            qml_path=widget_qml_path,
            backend_obj=self
        )

        # 重试定时器
        self.retry_timer = QTimer()
        self.retry_timer.timeout.connect(self.update_songs)

        # 定期更新定时器 (1小时)
        self.update_timer = QTimer()
        self.update_timer.timeout.connect(self.update_songs)
        self.update_timer.start(60 * 60 * 1000)

    def update_songs(self):
        """启动更新"""
        self.status = "loading"
        self.contentUpdated.emit([], "", "loading")
        self.retry_timer.stop()

        self.worker_thread = FetchThread()
        self.worker_thread.fetch_finished.connect(self.handle_success)
        self.worker_thread.fetch_failed.connect(self.handle_failure)
        self.worker_thread.start()

    @Slot()
    def init_content(self):
        """QML初始化时调用"""
        logger.info("QML requested content initialization")
        self.contentUpdated.emit(self.songs, self.display_date, self.status)

    def handle_success(self, songs, display_date, status):
        """处理成功响应 (包括 no_schedule)"""
        self.songs = songs
        self.display_date = display_date
        self.status = status
        
        self.contentUpdated.emit(songs, display_date, status)
        
        if status == "success":
            logger.info(f"VoiceHub排期更新成功: {display_date}, 共{len(songs)}首")
        else:
            logger.info("暂无排期")

    def handle_failure(self):
        """处理失败情况"""
        logger.warning("更新失败，10分钟后自动重试")
        self.status = "error"
        self.contentUpdated.emit([], "", "error")
        self.retry_timer.start(10 * 60 * 1000)

    def on_load(self):
        super().on_load()
        logger.info("VoiceHub插件加载成功！")
        # 延迟更新
        QTimer.singleShot(100, self.update_songs)

    def on_unload(self):
        logger.info("VoiceHub插件卸载成功！")
        self.retry_timer.stop()
        self.update_timer.stop()
