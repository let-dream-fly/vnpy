#!/usr/bin/env bash
# ============================================================
#  VeighNa 4.3.0  macOS 一键安装 + 启动脚本
#
#  用法：
#    bash install_osx.sh                      # 默认：自动创建 .venv，使用 vnpy 镜像
#    bash install_osx.sh python3.13           # 指定 Python 解释器
#    bash install_osx.sh python3.13 https://pypi.tuna.tsinghua.edu.cn/simple
#
#  功能：
#    1. 检测 Python 版本（要求 3.10+）
#    2. 创建 / 复用项目级虚拟环境 .venv（绕过 PEP 668 系统 Python 限制）
#    3. 升级 pip / wheel / 构建依赖（hatchling / babel）
#    4. 检测并安装 ta-lib C 库（brew）+ Python 绑定
#    5. 安装 vnpy 核心框架
#    6. 安装常用应用模块
#    7. 生成默认配置文件 ~/.vntrader/vt_setting.json
#    8. 生成启动脚本 run_trader.py
#    9. 询问是否立即启动平台
# ============================================================
set -euo pipefail

# ---------- 参数处理 ----------
_RAW_PY="${1:-}"
_PYPI_URL="${2:-https://pypi.vnpy.com}"
_VNPY_MIRROR="https://pypi.vnpy.com"
_TUNA="https://pypi.tuna.tsinghua.edu.cn/simple"

# ---------- 彩色输出辅助 ----------
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }
step()  { echo -e "\n${GREEN}$*${NC}"; }

# ---------- 错误处理 ----------
trap 'error "安装中断，请查看上方错误信息"; exit 1' ERR

echo ""
echo "============================================================"
echo "  VeighNa 4.3.0  macOS 一键安装脚本"
echo "  镜像源: $_PYPI_URL"
echo "============================================================"
echo ""

# ============================================================
# 步骤 1：检测 Python 解释器，要求 3.10+ 且非系统 Python
# ============================================================
step "[1/8] 检测 Python 环境..."

# 自动发现可用 Python（优先 3.13 → 3.12 → 3.11 → 3.10）
if [[ -z "$_RAW_PY" ]]; then
    for candidate in python3.13 python3.12 python3.11 python3.10 python3; do
        if command -v "$candidate" &>/dev/null; then
            _RAW_PY="$candidate"
            break
        fi
    done
fi

if [[ -z "$_RAW_PY" ]] || ! command -v "$_RAW_PY" &>/dev/null; then
    error "未找到 Python 解释器：${_RAW_PY:-python3}"
    error "请先安装 Python 3.10+："
    error "  brew install python@3.13"
    exit 1
fi

# 版本检查
if ! "$_RAW_PY" -c "import sys; exit(0 if sys.version_info>=(3,10) else 1)" 2>/dev/null; then
    _VER=$("$_RAW_PY" --version 2>&1)
    error "Python 版本不符合要求，当前：$_VER"
    error "VeighNa 4.3.0 需要 Python 3.10 或更高版本"
    exit 1
fi

_VER=$("$_RAW_PY" --version 2>&1)
info "检测到：$_VER（路径：$(command -v "$_RAW_PY")）"

# ============================================================
# 步骤 2：创建 / 复用虚拟环境（绕过 PEP 668 系统 Python 限制）
# ============================================================
step "[2/8] 配置虚拟环境 .venv..."

VENV_DIR="$(pwd)/.venv"

if [[ -f "$VENV_DIR/bin/python" ]]; then
    _VENV_VER=$("$VENV_DIR/bin/python" --version 2>&1)
    info "复用已有虚拟环境：$_VENV_VER"
else
    info "创建虚拟环境：$VENV_DIR"
    "$_RAW_PY" -m venv "$VENV_DIR"
    info "虚拟环境创建完成"
fi

# 后续全部使用 venv 内的 Python
PY="$VENV_DIR/bin/python"
PIP="$PY -m pip"

# ============================================================
# 步骤 3：升级 pip / wheel / 构建依赖
# ============================================================
step "[3/8] 升级 pip / wheel / 构建依赖..."

$PIP install --upgrade pip wheel \
    --index-url "$_PYPI_URL" \
    --extra-index-url "$_TUNA"

# vnpy 使用 hatchling + babel 作为构建后端（pyproject.toml build-system.requires）
$PIP install --upgrade "hatchling>=1.27.0" "babel>=2.17.0" \
    --index-url "$_PYPI_URL" \
    --extra-index-url "$_TUNA"

info "OK"

# ============================================================
# 步骤 4：检测并安装 ta-lib C 库 + Python 绑定
#   macOS 下优先用 brew 安装 C 库，再 pip 安装 Python 绑定
# ============================================================
step "[4/8] 检测 ta-lib C 库..."

_ta_lib_exists() {
    # 用 brew 检查（最可靠的 macOS 方式）
    brew list ta-lib &>/dev/null 2>&1
}

if _ta_lib_exists; then
    info "ta-lib C 库已安装（brew），跳过"
else
    info "安装 ta-lib C 库（brew install ta-lib）..."
    HOMEBREW_NO_AUTO_UPDATE=true brew install ta-lib
    info "ta-lib C 库安装完成"
fi

# 安装 Python 绑定（先 pin 0.6.4 与原脚本一致，失败则放宽版本约束）
info "安装 ta-lib Python 绑定..."
if ! $PIP install "ta_lib==0.6.4" \
        --extra-index-url "$_VNPY_MIRROR" \
        --extra-index-url "$_TUNA" 2>/dev/null; then
    warn "ta-lib 0.6.4 不可用，尝试安装最新兼容版本..."
    $PIP install "ta-lib>=0.6.4" \
        --extra-index-url "$_TUNA"
fi
info "OK"

# ============================================================
# 步骤 5：安装 vnpy 核心框架
# ============================================================
step "[5/8] 安装 VeighNa 核心框架..."

$PIP install . \
    --extra-index-url "$_VNPY_MIRROR" \
    --extra-index-url "$_TUNA"

info "OK"

# ============================================================
# 步骤 6：安装应用模块
#   macOS 不支持 CTP（C++ SDK 无 macOS 版本），使用 PaperAccount 仿真
# ============================================================
step "[6/8] 安装应用模块..."

warn "注意：CTP 接口无 macOS 版本，已替换为 PaperAccount 本地仿真接口"

$PIP install \
    vnpy_sqlite \
    vnpy_paperaccount \
    vnpy_ctastrategy \
    vnpy_ctabacktester \
    vnpy_datamanager \
    vnpy_datarecorder \
    vnpy_riskmanager \
    vnpy_algotrading \
    vnpy_spreadtrading \
    vnpy_portfoliostrategy \
    vnpy_portfoliomanager \
    vnpy_chartwizard \
    --extra-index-url "$_VNPY_MIRROR" \
    --extra-index-url "$_TUNA"

info "OK"

# ============================================================
# 步骤 7：生成默认配置文件 ~/.vntrader/vt_setting.json
# ============================================================
step "[7/8] 生成默认配置文件..."

mkdir -p "$HOME/.vntrader"
_CFG="$HOME/.vntrader/vt_setting.json"

if [[ ! -f "$_CFG" ]]; then
    $PY -c "
import json, os
setting = {
    'font.family': 'Arial',
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
path = os.path.expanduser('~/.vntrader/vt_setting.json')
with open(path, 'w', encoding='utf-8') as f:
    json.dump(setting, f, ensure_ascii=False, indent=4)
print('  配置文件已生成：' + path)
"
else
    info "配置文件已存在，跳过：$_CFG"
fi

# ============================================================
# 步骤 8：生成启动脚本 run_trader.py
# ============================================================
step "[8/8] 生成启动脚本 run_trader.py..."

if [[ ! -f "run_trader.py" ]]; then
    cat > run_trader.py << 'PYEOF'
"""
VeighNa Trader -- macOS 启动脚本（由 install_osx.sh 自动生成）
运行方式：.venv/bin/python run_trader.py
修改本文件来增减应用模块。
"""
from vnpy.event import EventEngine
from vnpy.trader.engine import MainEngine
from vnpy.trader.ui import MainWindow, create_qapp
from vnpy.trader.setting import SETTINGS

# ---- 仿真接口（macOS 无 CTP，用 PaperAccount 代替）----
from vnpy_paperaccount import PaperAccountApp

# ---- 如需连接真实交易所，请在 Windows/Linux 上使用以下接口 ----
# from vnpy_ctp import CtpGateway           # 国内期货（仅 Windows/Linux）
# from vnpy_xtp import XtpGateway           # 中泰 XTP 股票（仅 Windows/Linux）
# from vnpy_ib import IbGateway             # Interactive Brokers（全平台）

# ---- 应用模块 ----
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


def main() -> None:
    SETTINGS["log.active"] = True
    SETTINGS["log.level"] = 20    # INFO
    SETTINGS["log.console"] = True
    SETTINGS["log.file"] = True

    qapp = create_qapp()
    event_engine = EventEngine()
    main_engine = MainEngine(event_engine)

    # 本地仿真接口（macOS 环境）
    main_engine.add_app(PaperAccountApp)

    # 应用模块
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


if __name__ == "__main__":
    main()
PYEOF
    info "run_trader.py 已生成"
else
    info "run_trader.py 已存在，跳过生成"
fi

# ============================================================
# 完成
# ============================================================
echo ""
echo "============================================================"
echo "  安装完成！"
echo ""
echo "  虚拟环境: $(pwd)/.venv"
echo "  配置文件: $HOME/.vntrader/vt_setting.json"
echo "  日志目录: $HOME/.vntrader/log/"
echo ""
echo "  下次启动："
echo "    .venv/bin/python run_trader.py"
echo ""
echo "  macOS 注意事项："
echo "    - CTP 接口无 macOS 版本，已使用 PaperAccount 本地仿真"
echo "    - 如需连接真实期货账户，请在 Windows/Linux 上运行"
echo "    - 首次启动 Qt 应用可能提示安全警告，需在系统偏好设置中允许"
echo "============================================================"
echo ""

read -r -p "是否立即启动 VeighNa Trader？[Y/n] " _LAUNCH
case "${_LAUNCH:-Y}" in
    [Nn]*) echo "可随时运行 .venv/bin/python run_trader.py 启动。" ;;
    *)
        echo ""
        echo "正在启动 VeighNa Trader..."
        "$VENV_DIR/bin/python" run_trader.py
        ;;
esac
