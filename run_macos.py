"""
VeighNa Trader — macOS 启动脚本
不依赖 CTP（仅支持 Windows/Linux），使用 PaperAccount 本地仿真接口
"""
from vnpy.event import EventEngine
from vnpy.trader.engine import MainEngine
from vnpy.trader.ui import MainWindow, create_qapp
from vnpy.trader.setting import SETTINGS

from vnpy_paperaccount import PaperAccountApp
from vnpy_ctastrategy import CtaStrategyApp
from vnpy_ctabacktester import CtaBacktesterApp
from vnpy_datamanager import DataManagerApp
from vnpy_datarecorder import DataRecorderApp


def main() -> None:
    SETTINGS["log.active"] = True
    SETTINGS["log.console"] = True
    SETTINGS["log.file"] = True

    qapp = create_qapp()

    event_engine = EventEngine()
    main_engine = MainEngine(event_engine)

    # 本地仿真接口（macOS 无 CTP，用 PaperAccount 代替）
    main_engine.add_app(PaperAccountApp)

    # 策略应用
    main_engine.add_app(CtaStrategyApp)
    main_engine.add_app(CtaBacktesterApp)

    # 数据管理
    main_engine.add_app(DataManagerApp)
    main_engine.add_app(DataRecorderApp)

    main_window = MainWindow(main_engine, event_engine)
    main_window.showMaximized()

    qapp.exec()


if __name__ == "__main__":
    main()
