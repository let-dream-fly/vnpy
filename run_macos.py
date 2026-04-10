"""
VeighNa Trader — macOS 启动脚本（由 install_osx.sh 生成）
运行方式：.venv/bin/python run_macos.py

macOS 注意：CTP 接口无 macOS 版本，使用 PaperAccount 本地仿真代替。
如需连接真实期货账户，请在 Windows/Linux 上运行。
"""
from vnpy.event import EventEngine
from vnpy.trader.engine import MainEngine
from vnpy.trader.ui import MainWindow, create_qapp
from vnpy.trader.setting import SETTINGS

# ---- 仿真接口（macOS 无 CTP，用 PaperAccount 代替）----
from vnpy_paperaccount import PaperAccountApp

# ---- 如需连接真实交易所，请在 Windows/Linux 上使用 ----
# from vnpy_ctp import CtpGateway           # 国内期货（仅 Windows/Linux）
# from vnpy_ib import IbGateway             # Interactive Brokers（全平台）

# ---- 策略应用 ----
from vnpy_ctastrategy import CtaStrategyApp
from vnpy_ctabacktester import CtaBacktesterApp

# ---- 数据管理 ----
from vnpy_datamanager import DataManagerApp
from vnpy_datarecorder import DataRecorderApp

# ---- 风控 / 算法 / 价差 / 组合 ----
from vnpy_riskmanager import RiskManagerApp
from vnpy_algotrading import AlgoTradingApp
from vnpy_spreadtrading import SpreadTradingApp
from vnpy_portfoliostrategy import PortfolioStrategyApp
from vnpy_portfoliomanager import PortfolioManagerApp
from vnpy_chartwizard import ChartWizardApp


def main() -> None:
    SETTINGS["log.active"] = True
    SETTINGS["log.level"] = 20    # INFO
    SETTINGS["log.console"] = True
    SETTINGS["log.file"] = True

    qapp = create_qapp()
    event_engine = EventEngine()
    main_engine = MainEngine(event_engine)

    # 本地仿真接口
    main_engine.add_app(PaperAccountApp)

    # 策略与回测
    main_engine.add_app(CtaStrategyApp)
    main_engine.add_app(CtaBacktesterApp)

    # 数据管理
    main_engine.add_app(DataManagerApp)
    main_engine.add_app(DataRecorderApp)

    # 风控 / 算法 / 价差 / 组合
    main_engine.add_app(RiskManagerApp)
    main_engine.add_app(AlgoTradingApp)
    main_engine.add_app(SpreadTradingApp)
    main_engine.add_app(PortfolioStrategyApp)
    main_engine.add_app(PortfolioManagerApp)
    main_engine.add_app(ChartWizardApp)

    main_window = MainWindow(main_engine, event_engine)
    main_window.showMaximized()
    qapp.exec()


if __name__ == "__main__":
    main()
