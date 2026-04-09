@ECHO OFF
CHCP 65001 >NUL
SETLOCAL ENABLEDELAYEDEXPANSION

:: ============================================================
::  VeighNa 4.3.0  Windows 一键安装 + 启动脚本
::
::  用法：
::    install_win.bat                  -- 使用默认 Python + vnpy 镜像源
::    install_win.bat python3.13       -- 指定 Python 解释器
::    install_win.bat python https://pypi.tuna.tsinghua.edu.cn/simple
::                                     -- 指定解释器 + 自定义 PyPI 镜像源
::
::  功能：
::    1. 检测 Python 版本（要求 3.10+，64 位）
::    2. 升级 pip / wheel / hatchling（构建系统依赖）
::    3. 安装 ta-lib 预编译 wheel（来自 vnpy 镜像或官方 PyPI）
::    4. 安装 vnpy 核心框架及全部依赖
::    5. 安装常用应用模块（CTP / CTA / 数据管理 / 风控等）
::    6. 生成 vt_setting.json 默认配置文件
::    7. 生成 run_trader.py 启动脚本
::    8. 启动 VeighNa Trader 图形界面
:: ============================================================

:: ---------- 参数处理 ----------
SET "_PY=%~1"
SET "_PYPI_URL=%~2"

IF "%_PY%"==""       SET "_PY=python"
IF "%_PYPI_URL%"=""  SET "_PYPI_URL=https://pypi.vnpy.com"

:: vnpy 官方预编译镜像（用于 ta-lib 等 C 扩展）
SET "_VNPY_MIRROR=https://pypi.vnpy.com"
:: 国内通用镜像（清华，作为额外索引）
SET "_TUNA=https://pypi.tuna.tsinghua.edu.cn/simple"

ECHO.
ECHO ============================================================
ECHO   VeighNa 4.3.0  Windows 一键安装脚本
ECHO   Python  : %_PY%
ECHO   镜像源  : %_PYPI_URL%
ECHO ============================================================
ECHO.

:: ============================================================
:: 步骤 1：检测 Python 是否存在并满足版本要求
:: ============================================================
ECHO [1/7] 检测 Python 环境...

%_PY% --version >NUL 2>&1
IF ERRORLEVEL 1 (
    ECHO [错误] 未找到 Python 解释器：%_PY%
    ECHO        请安装 Python 3.10+ (64位) 或通过参数指定路径
    ECHO        下载地址：https://www.python.org/downloads/
    GOTO :ERROR
)

:: 检查 Python >= 3.10
%_PY% -c "import sys; exit(0 if sys.version_info>=(3,10) else 1)" >NUL 2>&1
IF ERRORLEVEL 1 (
    FOR /F "tokens=*" %%V IN ('%_PY% --version 2^>^&1') DO SET "_PY_VER=%%V"
    ECHO [错误] Python 版本不符合要求，当前：!_PY_VER!
    ECHO        VeighNa 4.3.0 需要 Python 3.10 或更高版本
    GOTO :ERROR
)

:: 检查 64 位（ta-lib / PySide6 均无 32 位 wheel）
%_PY% -c "import struct; exit(0 if struct.calcsize('P')==8 else 1)" >NUL 2>&1
IF ERRORLEVEL 1 (
    ECHO [错误] 检测到 32 位 Python，VeighNa 需要 64 位 Python
    GOTO :ERROR
)

FOR /F "tokens=*" %%V IN ('%_PY% --version 2^>^&1') DO SET "_PY_VER=%%V"
ECHO     OK：%_PY_VER% (64-bit)

:: ============================================================
:: 步骤 2：升级 pip / wheel / 构建系统依赖
:: ============================================================
ECHO.
ECHO [2/7] 升级 pip / wheel / hatchling / babel...

%_PY% -m pip install --upgrade pip wheel ^
    --index-url %_PYPI_URL% ^
    --extra-index-url %_TUNA%
IF ERRORLEVEL 1 (
    ECHO [错误] pip 升级失败，请检查网络连接
    GOTO :ERROR
)

:: 安装 vnpy 构建系统依赖（PEP 517 隔离构建也需要）
%_PY% -m pip install --upgrade "hatchling>=1.27.0" "babel>=2.17.0" ^
    --index-url %_PYPI_URL% ^
    --extra-index-url %_TUNA%
IF ERRORLEVEL 1 (
    ECHO [错误] 构建依赖安装失败（hatchling / babel）
    GOTO :ERROR
)

ECHO     OK

:: ============================================================
:: 步骤 3：安装 ta-lib 预编译 wheel
::   优先从 vnpy 官方镜像获取预编译 wheel（无需 C 编译器）
::   如果失败，尝试从官方 PyPI 获取
:: ============================================================
ECHO.
ECHO [3/7] 安装 ta-lib（技术指标 C 扩展库）...

%_PY% -m pip install "ta_lib==0.6.4" ^
    --extra-index-url %_VNPY_MIRROR% ^
    --extra-index-url %_TUNA%
IF ERRORLEVEL 1 (
    ECHO     vnpy 镜像 ta-lib 0.6.4 不可用，尝试从官方 PyPI 安装最新版...
    %_PY% -m pip install "ta-lib>=0.6.4" ^
        --extra-index-url %_TUNA%
    IF ERRORLEVEL 1 (
        ECHO [错误] ta-lib 安装失败
        ECHO        Windows 下可手动下载预编译 wheel：
        ECHO        https://github.com/ta-lib/ta-lib-python/releases
        ECHO        或访问：https://www.lfd.uci.edu/~gohlke/pythonlibs/#ta-lib
        GOTO :ERROR
    )
)
ECHO     OK

:: ============================================================
:: 步骤 4：安装 vnpy 核心框架
:: ============================================================
ECHO.
ECHO [4/7] 安装 VeighNa 核心框架...

%_PY% -m pip install . ^
    --extra-index-url %_VNPY_MIRROR% ^
    --extra-index-url %_TUNA%
IF ERRORLEVEL 1 (
    ECHO [错误] VeighNa 核心框架安装失败
    GOTO :ERROR
)
ECHO     OK

:: ============================================================
:: 步骤 5：安装应用模块
::   - 数据库：vnpy_sqlite（默认）
::   - 交易接口：vnpy_ctp（国内期货标准接口）
::   - 策略应用：CTA策略 / CTA回测 / 数据管理 / 风控 / 算法交易
::   - 可选：价差交易 / 组合策略 / Web服务 / RPC服务
:: ============================================================
ECHO.
ECHO [5/7] 安装应用模块...

SET "_APPS=^
    vnpy_sqlite ^
    vnpy_ctp ^
    vnpy_ctastrategy ^
    vnpy_ctabacktester ^
    vnpy_datamanager ^
    vnpy_datarecorder ^
    vnpy_riskmanager ^
    vnpy_algotrading ^
    vnpy_paperaccount ^
    vnpy_spreadtrading ^
    vnpy_portfoliostrategy ^
    vnpy_portfoliomanager ^
    vnpy_chartwizard"

%_PY% -m pip install ^
    vnpy_sqlite ^
    vnpy_ctp ^
    vnpy_ctastrategy ^
    vnpy_ctabacktester ^
    vnpy_datamanager ^
    vnpy_datarecorder ^
    vnpy_riskmanager ^
    vnpy_algotrading ^
    vnpy_paperaccount ^
    vnpy_spreadtrading ^
    vnpy_portfoliostrategy ^
    vnpy_portfoliomanager ^
    vnpy_chartwizard ^
    --extra-index-url %_VNPY_MIRROR% ^
    --extra-index-url %_TUNA%
IF ERRORLEVEL 1 (
    ECHO [错误] 应用模块安装失败
    GOTO :ERROR
)
ECHO     OK

:: ============================================================
:: 步骤 6：生成默认配置文件 .vntrader\vt_setting.json
:: ============================================================
ECHO.
ECHO [6/7] 生成默认配置文件...

IF NOT EXIST "%USERPROFILE%\.vntrader" (
    MKDIR "%USERPROFILE%\.vntrader"
)

IF NOT EXIST "%USERPROFILE%\.vntrader\vt_setting.json" (
    %_PY% -c ^"
import json, os
setting = {
    'font.family': '微软雅黑',
    'font.size': 12,
    'log.active': True,
    'log.level': 20,
    'log.console': True,
    'log.file': True,
    'email.server': 'smtp.qq.com',
    'email.port': 465,
    'email.username': '',
    'email.password': '',
    'email.sender': '',
    'email.receiver': '',
    'datafeed.name': '',
    'datafeed.username': '',
    'datafeed.password': '',
    'database.timezone': 'Asia/Shanghai',
    'database.name': 'sqlite',
    'database.database': 'database.db',
    'database.host': '',
    'database.port': 0,
    'database.user': '',
    'database.password': ''
}
path = os.path.join(os.environ['USERPROFILE'], '.vntrader', 'vt_setting.json')
with open(path, 'w', encoding='utf-8') as f:
    json.dump(setting, f, ensure_ascii=False, indent=4)
print('    配置文件已生成：' + path)
^"
) ELSE (
    ECHO     配置文件已存在，跳过：%USERPROFILE%\.vntrader\vt_setting.json
)

:: ============================================================
:: 步骤 7：生成启动脚本 run_trader.py
:: ============================================================
ECHO.
ECHO [7/7] 生成 VeighNa Trader 启动脚本 run_trader.py...

IF NOT EXIST "run_trader.py" (
    %_PY% -c ^"
content = '''\"\"\"
VeighNa Trader -- Windows 启动脚本（由 install_win.bat 自动生成）
修改本文件来增减交易接口和应用模块。
\"\"\"
from vnpy.event import EventEngine
from vnpy.trader.engine import MainEngine
from vnpy.trader.ui import MainWindow, create_qapp
from vnpy.trader.setting import SETTINGS

# ---- 交易接口（按需取消注释）----
from vnpy_ctp import CtpGateway           # 国内期货（CTP，主流）
# from vnpy_mini import MiniGateway       # CTP Mini 精简版
# from vnpy_sopt import SoptGateway       # ETF 期权（上交所）
# from vnpy_uft import UftGateway         # 恒生 UFT 期货 / ETF 期权
# from vnpy_esunny import EsunnyGateway   # 易盛期货 / 黄金 TD
# from vnpy_xtp import XtpGateway         # 中泰 XTP 股票 / ETF 期权
# from vnpy_tora import ToraStockGateway  # 华鑫奇点股票 / ETF 期权
# from vnpy_ib import IbGateway           # Interactive Brokers 海外
# from vnpy_tap import TapGateway         # 易盛 9.0 外盘期货
# from vnpy_paperaccount import PaperAccountApp  # 本地仿真（无需真实账户）

# ---- 策略 / 功能应用（按需取消注释）----
from vnpy_ctastrategy import CtaStrategyApp
from vnpy_ctabacktester import CtaBacktesterApp
from vnpy_datamanager import DataManagerApp
from vnpy_datarecorder import DataRecorderApp
from vnpy_riskmanager import RiskManagerApp
from vnpy_algotrading import AlgoTradingApp
from vnpy_spreadtrading import SpreadTradingApp
from vnpy_portfoliostrategy import PortfolioStrategyApp
from vnpy_portfoliomanager import PortfolioManagerApp
from vnpy_chartwizard import ChartWizardApp
# from vnpy_rpcservice import RpcServiceApp   # 分布式 RPC 服务
# from vnpy_webtrader import WebTraderApp     # Web 浏览器交易界面
# from vnpy_optionmaster import OptionMasterApp  # 期权波动率交易


def main() -> None:
    SETTINGS[\"log.active\"] = True
    SETTINGS[\"log.level\"] = 20    # INFO
    SETTINGS[\"log.console\"] = True
    SETTINGS[\"log.file\"] = True

    qapp = create_qapp()
    event_engine = EventEngine()
    main_engine = MainEngine(event_engine)

    # ---- 注册交易接口 ----
    main_engine.add_gateway(CtpGateway)
    # main_engine.add_gateway(PaperAccountApp)  # 仅使用本地仿真时替换上行

    # ---- 注册应用模块 ----
    main_engine.add_app(CtaStrategyApp)
    main_engine.add_app(CtaBacktesterApp)
    main_engine.add_app(DataManagerApp)
    main_engine.add_app(DataRecorderApp)
    main_engine.add_app(RiskManagerApp)
    main_engine.add_app(AlgoTradingApp)
    main_engine.add_app(SpreadTradingApp)
    main_engine.add_app(PortfolioStrategyApp)
    main_engine.add_app(PortfolioManagerApp)
    main_engine.add_app(ChartWizardApp)

    main_window = MainWindow(main_engine, event_engine)
    main_window.showMaximized()
    qapp.exec()


if __name__ == \"__main__\":
    main()
'''
with open('run_trader.py', 'w', encoding='utf-8') as f:
    f.write(content)
print('    run_trader.py 已生成')
^"
) ELSE (
    ECHO     run_trader.py 已存在，跳过生成
)

:: ============================================================
:: 安装完成，询问是否立即启动
:: ============================================================
ECHO.
ECHO ============================================================
ECHO   安装完成！
ECHO.
ECHO   配置文件: %USERPROFILE%\.vntrader\vt_setting.json
ECHO   启动脚本: run_trader.py
ECHO   日志目录: %USERPROFILE%\.vntrader\log\
ECHO.
ECHO   下次启动直接运行：
ECHO     %_PY% run_trader.py
ECHO.
ECHO   新手建议：
ECHO     1. 在 SimNow 注册仿真账号：https://www.simnow.com.cn/
ECHO     2. 启动后点击【系统 -> 连接CTP】填入账号信息
ECHO     3. 连接成功后点击【应用 -> CTA回测】体验策略回测
ECHO ============================================================
ECHO.

SET /P "_LAUNCH=是否立即启动 VeighNa Trader？[Y/n] "
IF /I "!_LAUNCH!"=="n" GOTO :EOF
IF /I "!_LAUNCH!"=="N" GOTO :EOF

ECHO.
ECHO 正在启动 VeighNa Trader...
%_PY% run_trader.py
GOTO :EOF

:: ============================================================
:ERROR
ECHO.
ECHO ============================================================
ECHO   安装失败，请根据上方错误信息排查问题。
ECHO   常见解决方案：
ECHO     - 确保 Python 3.10+ 64位 已安装并在 PATH 中
ECHO     - 检查网络连接（部分大包需访问境外 PyPI）
ECHO     - 以管理员身份运行此脚本（右键 -> 以管理员身份运行）
ECHO     - 查阅文档：https://www.vnpy.com/docs/cn/index.html
ECHO     - 社区求助：https://www.vnpy.com/forum/
ECHO ============================================================
PAUSE
EXIT /B 1
