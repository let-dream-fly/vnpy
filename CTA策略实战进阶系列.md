# VeighNa CTA 策略实战进阶系列

> 基于 VeighNa 4.3.0 源码 · Python 3.13 · 适用平台：vnpy_ctastrategy + vnpy_ctabacktester

---

## 目录

- [第一章 基础操作](#第一章-基础操作)
- [第二章 K线逻辑](#第二章-k线逻辑)
- [第三章 回测原理](#第三章-回测原理)
- [第四章 止盈止损](#第四章-止盈止损)
- [第五章 结果分析](#第五章-结果分析)
- [第六章 委托管理](#第六章-委托管理)
- [第七章 参数优化](#第七章-参数优化)
- [第八章 自动交易](#第八章-自动交易)
- [第九章 策略进阶](#第九章-策略进阶)

---

# 第一章 基础操作

## 1.1 开发环境准备

### 环境要求

| 组件 | 版本要求 |
|------|---------|
| Python | 3.10+（推荐 3.13） |
| vnpy | 4.3.0 |
| vnpy_ctastrategy | 最新版 |
| vnpy_ctabacktester | 最新版 |
| vnpy_sqlite | 最新版（默认数据库）|

### 项目目录结构

```
~/.vntrader/              ← 运行时数据根目录
├── vt_setting.json       ← 全局配置文件
├── database.db           ← SQLite 历史数据库
├── log/
│   └── vt_YYYYMMDD.log   ← 每日滚动日志
└── temp/
    └── CtaStrategy/
        └── <策略名>.json  ← 策略变量持久化（重启恢复）
```

### 全局配置 `vt_setting.json`

```json
{
    "font.family": "Arial",
    "font.size": 12,
    "log.active": true,
    "log.level": 20,
    "log.console": true,
    "log.file": true,
    "database.timezone": "Asia/Shanghai",
    "database.name": "sqlite",
    "database.database": "database.db",
    "datafeed.name": "tushare",
    "datafeed.username": "your_username",
    "datafeed.password": "your_tushare_token"
}
```

### 快速验证安装

```python
from vnpy.event import EventEngine
from vnpy.trader.engine import MainEngine
from vnpy_ctastrategy import CtaStrategyApp

ee = EventEngine()
me = MainEngine(ee)
me.add_app(CtaStrategyApp)
print("环境准备完毕")
me.close()
```

---

## 1.2 认识策略模板

CTA 策略必须继承 `CtaTemplate`，所有策略能力由模板提供，开发者只需关注信号逻辑。

### 策略模板核心结构

```python
from vnpy_ctastrategy import CtaTemplate, StopOrder
from vnpy.trader.object import TickData, BarData, TradeData, OrderData
from vnpy.trader.constant import Interval


class CtaTemplate:
    # ---- 类级属性（必须声明）----
    author: str = ""         # 策略作者
    parameters: list = []    # 参数名列表（支持 UI 编辑和参数优化）
    variables: list = []     # 变量名列表（持久化到磁盘）

    # ---- 生命周期回调（按需重写）----
    def on_init(self) -> None: ...      # 初始化：加载历史数据预热指标
    def on_start(self) -> None: ...     # 启动：策略就绪，开始接收实时行情
    def on_stop(self) -> None: ...      # 停止：清理状态

    # ---- 行情回调（二选一）----
    def on_tick(self, tick: TickData) -> None: ...  # Tick 级别策略
    def on_bar(self, bar: BarData) -> None: ...     # Bar 级别策略（常用）

    # ---- 委托回调 ----
    def on_order(self, order: OrderData) -> None: ...
    def on_trade(self, trade: TradeData) -> None: ...
    def on_stop_order(self, stop_order: StopOrder) -> None: ...

    # ---- 交易指令（四个核心方法）----
    def buy(self, price, volume, stop=False, lock=False, net=False): ...   # 买入开多
    def sell(self, price, volume, stop=False, lock=False, net=False): ...  # 卖出平多
    def short(self, price, volume, stop=False, lock=False, net=False): ... # 卖出开空
    def cover(self, price, volume, stop=False, lock=False, net=False): ... # 买入平空

    # ---- 辅助方法 ----
    def cancel_all(self) -> None: ...             # 撤销所有活动委托
    def write_log(self, msg: str) -> None: ...    # 写入策略日志
    def load_bar(self, days: int, ...) -> None:   # 加载历史 Bar 预热
    def load_tick(self, days: int) -> None: ...   # 加载历史 Tick 预热
    def put_event(self) -> None: ...              # 推送策略状态更新到 UI
    def sync_data(self) -> None: ...              # 立即持久化策略变量
```

### 参数与变量声明规范

```python
class MyStrategy(CtaTemplate):
    author = "量化实战"

    # parameters：策略参数，在 UI 中可视化编辑，支持参数优化遍历
    fast_window = 10        # 默认值
    slow_window = 30
    parameters = ["fast_window", "slow_window"]

    # variables：策略运行状态变量，随策略持久化存储，重启后自动恢复
    fast_ma = 0.0
    slow_ma = 0.0
    pos = 0                 # 核心持仓字段（由模板自动维护）
    variables = ["fast_ma", "slow_ma"]
```

> **关键区别**：`parameters` 是配置输入，重启不变；`variables` 是运行状态输出，实盘中随成交实时更新并持久化，`pos` 是最重要的状态变量，表示当前净持仓。

---

## 1.3 开发第一个策略

双均线策略（DoubleMa）是最经典的趋势跟踪入门策略，以此演示完整开发流程。

```python
from vnpy_ctastrategy import CtaTemplate
from vnpy.trader.object import BarData
from vnpy.trader.utility import BarGenerator, ArrayManager


class DoubleMaStrategy(CtaTemplate):
    """双均线金叉死叉策略"""
    author = "量化实战"

    fast_window = 10   # 快线周期
    slow_window = 30   # 慢线周期
    parameters = ["fast_window", "slow_window"]

    fast_ma = 0.0
    slow_ma = 0.0
    variables = ["fast_ma", "slow_ma"]

    def on_init(self) -> None:
        """初始化：加载足够的历史数据预热指标"""
        self.am = ArrayManager(size=max(self.fast_window, self.slow_window) + 10)
        # 加载 10 天历史 1 分钟 Bar，驱动 on_bar 预热 ArrayManager
        self.load_bar(10)

    def on_start(self) -> None:
        self.write_log("策略启动")

    def on_stop(self) -> None:
        self.write_log("策略停止")

    def on_bar(self, bar: BarData) -> None:
        """每根 Bar 结束时触发"""
        self.cancel_all()          # 先撤销上轮未成交委托

        am = self.am
        am.update_bar(bar)
        if not am.inited:          # 数据不够，指标不可靠
            return

        # 计算双均线
        self.fast_ma = am.sma(self.fast_window)
        self.slow_ma = am.sma(self.slow_window)

        # 判断交叉方向
        cross_over = self.fast_ma > self.slow_ma    # 金叉
        cross_below = self.fast_ma < self.slow_ma   # 死叉

        # 开仓逻辑
        if cross_over and self.pos <= 0:
            if self.pos < 0:
                self.cover(bar.close_price, abs(self.pos))  # 先平空
            self.buy(bar.close_price, 1)                    # 再开多

        elif cross_below and self.pos >= 0:
            if self.pos > 0:
                self.sell(bar.close_price, abs(self.pos))   # 先平多
            self.short(bar.close_price, 1)                  # 再开空

        self.put_event()           # 刷新 UI 策略面板

    def on_order(self, order) -> None:
        pass

    def on_trade(self, trade) -> None:
        self.put_event()
```

---

## 1.4 历史数据回测

### 准备历史数据

回测需要本地数据库中存有历史 Bar 数据，有两种获取方式：

**方式一：通过数据管理模块下载**

在 VeighNa Trader 中点击【应用 → 数据管理】，选择合约、周期、时间范围后点击【下载数据】，数据服务（TuShare）会将数据存入本地 SQLite。

**方式二：CSV 导入**

```python
# 手动导入 CSV 格式历史数据
# 在数据管理界面点击【导入数据】，配置字段映射即可
# CSV 格式要求：datetime, open, high, low, close, volume
```

### 代码方式回测

```python
from vnpy_ctabacktester.engine import BacktestingEngine
from vnpy.trader.constant import Interval
from datetime import datetime

engine = BacktestingEngine()
engine.set_parameters(
    vt_symbol="rb2401.SHFE",      # 合约代码
    interval=Interval.MINUTE,      # K线周期（1分钟）
    start=datetime(2023, 1, 1),   # 回测开始时间
    end=datetime(2023, 12, 31),   # 回测结束时间
    rate=0.0001,                   # 手续费率（万一）
    slippage=1,                    # 滑点（价格跳动数）
    size=10,                       # 合约乘数（螺纹钢 10）
    pricetick=1,                   # 最小价格变动
    capital=1_000_000,             # 初始资金
)

engine.add_strategy(DoubleMaStrategy, {
    "fast_window": 10,
    "slow_window": 30,
})

engine.load_data()         # 从数据库加载历史数据
engine.run_backtesting()   # 逐 Bar 推送，内部撮合
df = engine.calculate_result()           # 生成逐日盈亏表
stats = engine.calculate_statistics(df)  # 计算绩效指标
engine.show_chart(df)      # 显示交互式资金曲线图
```

---

## 1.5 策略参数优化

详见第七章参数优化，此处给出快速入口：

```python
from vnpy.trader.optimize import OptimizationSetting

setting = OptimizationSetting()
setting.add_parameter("fast_window", 5, 25, 5)   # start, end, step
setting.add_parameter("slow_window", 20, 60, 10)
setting.set_target("sharpe_ratio")               # 优化目标

# 穷举法（进程并行）
result = engine.run_bf_optimization(setting, max_workers=8)

# 遗传算法（大参数空间）
result = engine.run_ga_optimization(setting, max_workers=8)
```

---

## 1.6 实盘自动交易

### GUI 方式（推荐新手）

1. 启动 VeighNa Trader → 连接交易接口（CTP/仿真）
2. 点击【应用 → CTA策略】→ 【添加策略】
3. 选择策略类、配置合约和参数
4. 点击【初始化】→ 等待预热完成 → 点击【启动】

### 代码无头模式（生产服务器）

```python
from vnpy.event import EventEngine
from vnpy.trader.engine import MainEngine
from vnpy.trader.setting import SETTINGS
from vnpy_ctp import CtpGateway
from vnpy_ctastrategy import CtaStrategyApp

SETTINGS["log.file"] = True
SETTINGS["log.level"] = 20

ee = EventEngine()
me = MainEngine(ee)
me.add_gateway(CtpGateway)
cta_engine = me.add_app(CtaStrategyApp)

me.connect({
    "用户名": "your_account",
    "密码": "your_password",
    "经纪商代码": "9999",
    "交易服务器": "tcp://180.168.146.187:10201",
    "行情服务器": "tcp://180.168.146.187:10211",
    "产品名称": "simnow_client_test",
    "授权编码": "0000000000000000",
}, "CTP")

from time import sleep
sleep(10)                          # 等待连接

cta_engine.init_engine()
cta_engine.init_all_strategies()
sleep(60)                          # 等待策略预热

cta_engine.start_all_strategies()
```

---

# 第二章 K线逻辑

## 2.1 K线合成原理

VeighNa 中的 K 线（`BarData`）包含以下核心字段：

```python
@dataclass
class BarData(BaseData):
    symbol: str
    exchange: Exchange
    datetime: datetime       # 该 Bar 的起始时间（整分钟对齐）
    interval: Interval       # 时间周期
    open_price: float
    high_price: float
    low_price: float
    close_price: float
    volume: float            # 成交量（增量，非累计）
    turnover: float          # 成交额（增量）
    open_interest: float     # 持仓量（期货专用）
```

**Tick 合成 1 分钟 Bar 的关键规则**（来自 `BarGenerator.update_tick`）：

| 字段 | 来源 | 说明 |
|------|------|------|
| `open_price` | 第一个 Tick 的 `last_price` | 分钟内第一笔成交价 |
| `high_price` | `max(last_price, tick.high_price)` | 取行情字段 high，防止遗漏盘中极值 |
| `low_price` | `min(last_price, tick.low_price)` | 取行情字段 low |
| `close_price` | 最后一个 Tick 的 `last_price` | |
| `volume` | `当前tick.volume - 上一tick.volume` | **增量**，防止重复计数 |

---

## 2.2 自定义K线合成

`BarGenerator` 支持三种聚合模式：

### 多分钟 K 线（N 分钟，N 必须能整除 60）

```python
from vnpy.trader.utility import BarGenerator

# 15 分钟 K 线
self.bg15 = BarGenerator(
    on_bar=self.on_bar,          # 1分钟Bar回调（内部使用）
    window=15,                   # 聚合窗口
    on_window_bar=self.on_15min_bar,  # 15分钟Bar完成时的回调
)

def on_bar(self, bar: BarData) -> None:
    self.bg15.update_bar(bar)    # 喂入 1 分钟 Bar

def on_15min_bar(self, bar: BarData) -> None:
    # 此处处理 15 分钟 K 线逻辑
    pass
```

**合成完成判断**（源码）：

```python
# window_bar 完成条件：(分钟数+1) % window == 0
if not (bar.datetime.minute + 1) % self.window:
    self.on_window_bar(self.window_bar)
    self.window_bar = None
```

### 小时 K 线

```python
from vnpy.trader.constant import Interval

self.bg1h = BarGenerator(
    on_bar=self.on_bar,
    window=1,
    on_window_bar=self.on_1h_bar,
    interval=Interval.HOUR       # 指定为小时级别
)
```

### 日 K 线（需指定收盘时间）

```python
from datetime import time

self.bgd = BarGenerator(
    on_bar=self.on_bar,
    window=1,
    on_window_bar=self.on_daily_bar,
    interval=Interval.DAILY,
    daily_end=time(15, 0)        # 必须指定收盘时间，否则抛 RuntimeError
)
```

---

## 2.3 时间序列容器

`ArrayManager` 是一个固定大小的**环形缓冲区**，每次 `update_bar` 后最新 Bar 在末尾（`-1` 下标），最老 Bar 在头部。

```python
class ArrayManager:
    def __init__(self, size: int = 100) -> None:
        # 7 个 numpy 数组，统一长度 size
        self.open_array   = np.zeros(size)
        self.high_array   = np.zeros(size)
        self.low_array    = np.zeros(size)
        self.close_array  = np.zeros(size)
        self.volume_array = np.zeros(size)
        self.turnover_array      = np.zeros(size)
        self.open_interest_array = np.zeros(size)

    def update_bar(self, bar: BarData) -> None:
        # 整体左移一位（丢弃最老数据），新数据填入末尾
        self.close_array[:-1] = self.close_array[1:]
        self.close_array[-1]  = bar.close_price
        # ... 其余字段同理

        self.count += 1
        if not self.inited and self.count >= self.size:
            self.inited = True  # 数据充满，指标可靠
```

**使用规范**：

```python
am = ArrayManager(size=100)
am.update_bar(bar)

if not am.inited:
    return       # 数据不够，跳过本轮计算

# 获取最新值（标量）
close_now  = am.close[-1]      # 最新收盘价
close_prev = am.close[-2]      # 前一根收盘价

# 获取完整序列（用于自定义计算）
close_series = am.close        # ndarray，长度 = size
```

---

## 2.4 DoubleMa策略（完整版）

结合 `BarGenerator` + `ArrayManager` 的完整实现：

```python
from vnpy_ctastrategy import CtaTemplate
from vnpy.trader.object import BarData, TickData
from vnpy.trader.utility import BarGenerator, ArrayManager


class DoubleMaStrategy(CtaTemplate):
    """双均线趋势策略（完整版）"""
    author = "量化实战"

    fast_window = 10
    slow_window = 30
    parameters = ["fast_window", "slow_window"]

    fast_ma0 = 0.0   # 当前 fast MA
    fast_ma1 = 0.0   # 前一根 fast MA
    slow_ma0 = 0.0
    slow_ma1 = 0.0
    variables = ["fast_ma0", "fast_ma1", "slow_ma0", "slow_ma1"]

    def on_init(self) -> None:
        self.bg = BarGenerator(self.on_bar)
        self.am = ArrayManager(size=max(self.fast_window, self.slow_window) + 10)
        self.load_bar(10)

    def on_start(self) -> None:
        self.write_log("策略启动")

    def on_stop(self) -> None:
        self.write_log("策略停止")

    def on_tick(self, tick: TickData) -> None:
        self.bg.update_tick(tick)   # Tick 合成 1 分钟 Bar

    def on_bar(self, bar: BarData) -> None:
        self.cancel_all()
        am = self.am
        am.update_bar(bar)
        if not am.inited:
            return

        fast_ma = am.sma(self.fast_window, array=True)
        slow_ma = am.sma(self.slow_window, array=True)

        self.fast_ma0 = fast_ma[-1]
        self.fast_ma1 = fast_ma[-2]
        self.slow_ma0 = slow_ma[-1]
        self.slow_ma1 = slow_ma[-2]

        # 金叉：fast 上穿 slow
        cross_over = (self.fast_ma0 > self.slow_ma0
                      and self.fast_ma1 < self.slow_ma1)
        # 死叉：fast 下穿 slow
        cross_below = (self.fast_ma0 < self.slow_ma0
                       and self.fast_ma1 > self.slow_ma1)

        if cross_over:
            if self.pos < 0:
                self.cover(bar.close_price, abs(self.pos))
            if self.pos == 0:
                self.buy(bar.close_price, 1)

        elif cross_below:
            if self.pos > 0:
                self.sell(bar.close_price, abs(self.pos))
            if self.pos == 0:
                self.short(bar.close_price, 1)

        self.put_event()

    def on_order(self, order) -> None:
        pass

    def on_trade(self, trade) -> None:
        self.put_event()
```

---

## 2.5 扩展技术指标

`ArrayManager` 封装了 TA-Lib 的完整指标集，调用规范统一：

```python
am = ArrayManager(size=100)

# 趋势类
sma  = am.sma(20)             # 简单移动平均（最新值 float）
ema  = am.ema(20)             # 指数移动平均
wma  = am.wma(20)             # 加权移动平均

# 震荡类
rsi  = am.rsi(14)             # RSI 相对强弱指数
cci  = am.cci(20)             # 商品通道指数
adx  = am.adx(14)             # 平均趋向指数
adxr = am.adxr(14)            # 平滑 ADX

# 波动类
atr  = am.atr(14)             # 真实波动幅度均值
natr = am.natr(14)            # 标准化 ATR（百分比）

# 布林带
upper, mid, lower = am.boll(20, 2.0)   # (上轨, 中轨, 下轨)

# KDJ
k, d = am.kd(9, 3)           # K 和 D 值（无 J 值）

# MACD
macd, signal, hist = am.macd(12, 26, 9)

# 抛物线 SAR
sar = am.sar(0.02, 0.2)

# TRIX
trix, matrix = am.trix(12)

# 自定义计算（使用原始 numpy 数组）
import numpy as np
mom = am.close[-1] - am.close[-10]  # 10 根 Bar 价格动量
```

**获取完整序列用于自定义指标**：

```python
# 传入 array=True 返回 ndarray 而非最新值
close_arr = am.close                   # 直接访问 property
sma_arr   = am.sma(20, array=True)    # ndarray，长度 = am.size
```

---

## 2.6 条件逻辑写法

实盘策略中条件判断的常见规范：

```python
def on_bar(self, bar: BarData) -> None:
    am = self.am
    am.update_bar(bar)
    if not am.inited:
        return

    # ---- 推荐：用前后两根 Bar 判断交叉（避免当 Bar 反复触发）----
    fast_arr = am.sma(self.fast_window, array=True)
    cross_over  = fast_arr[-1] > am.sma(self.slow_window) and \
                  fast_arr[-2] < am.sma(self.slow_window, array=True)[-2]

    # ---- 推荐：持仓状态前置判断，避免重复开仓 ----
    if cross_over and self.pos == 0:
        self.buy(bar.close_price, 1)

    # ---- 推荐：每根 Bar 开头先撤单，再重新评估 ----
    self.cancel_all()   # 放在判断逻辑之前

    # ---- 注意：close_price 是当前 Bar 收盘价，实际成交通常在下一 Bar 开盘 ----
    # 回测中默认用下一 Bar 的价格撮合，不存在未来函数
```

---

## 2.7 完整策略构成

一个生产级别的 CTA 策略应包含以下完整要素：

```python
class ProductionStrategy(CtaTemplate):
    author = "量化实战"

    # 1. 参数声明（外部可配置）
    bar_window = 15           # K 线周期（分钟）
    fast_window = 10
    slow_window = 30
    atr_window = 14
    stop_multiplier = 2.0     # ATR 止损倍数
    fixed_size = 1            # 每次开仓手数
    parameters = ["bar_window", "fast_window", "slow_window",
                  "atr_window", "stop_multiplier", "fixed_size"]

    # 2. 变量声明（运行状态，自动持久化）
    long_stop = 0.0
    short_stop = 0.0
    variables = ["long_stop", "short_stop"]

    def on_init(self) -> None:
        # 3. 初始化行情工具
        self.bg = BarGenerator(
            self.on_bar, self.bar_window, self.on_window_bar
        )
        self.am = ArrayManager(size=max(self.slow_window, self.atr_window) + 10)
        self.load_bar(10)

    def on_tick(self, tick: TickData) -> None:
        self.bg.update_tick(tick)

    def on_bar(self, bar: BarData) -> None:
        self.bg.update_bar(bar)

    def on_window_bar(self, bar: BarData) -> None:
        # 4. 信号逻辑
        self.cancel_all()
        am = self.am
        am.update_bar(bar)
        if not am.inited:
            return

        fast_ma = am.sma(self.fast_window)
        slow_ma = am.sma(self.slow_window)
        atr = am.atr(self.atr_window)

        # 5. 止损计划（每根 Bar 更新）
        if self.pos > 0:
            self.long_stop = bar.close_price - self.stop_multiplier * atr
        elif self.pos < 0:
            self.short_stop = bar.close_price + self.stop_multiplier * atr

        # 6. 开仓信号
        if fast_ma > slow_ma and self.pos == 0:
            self.buy(bar.close_price, self.fixed_size)
            self.long_stop = bar.close_price - self.stop_multiplier * atr

        elif fast_ma < slow_ma and self.pos == 0:
            self.short(bar.close_price, self.fixed_size)
            self.short_stop = bar.close_price + self.stop_multiplier * atr

        # 7. 止损平仓
        if self.pos > 0 and bar.close_price < self.long_stop:
            self.sell(bar.close_price, abs(self.pos))

        if self.pos < 0 and bar.close_price > self.short_stop:
            self.cover(bar.close_price, abs(self.pos))

        self.put_event()

    def on_trade(self, trade) -> None:
        self.put_event()

    def on_order(self, order) -> None:
        pass
```

---

# 第三章 回测原理

## 3.1 回测工作流程

```
BacktestingEngine.load_data()
    ↓  从 SQLite 或 datafeed 加载 BarData 列表

BacktestingEngine.run_backtesting()
    ↓  逐 Bar 推送（不走 EventEngine，直接调用策略方法）
    │
    ├── strategy.on_bar(bar)       ← 策略信号逻辑
    │       ↓  buy/sell/short/cover
    │   engine.send_order()        ← 记录委托（不发网络）
    │
    ├── engine._cross_limit_order()  ← 限价单撮合
    │   engine._cross_stop_order()   ← 停止单触发
    │       ↓  生成 TradeData
    │   strategy.on_trade(trade)   ← 策略更新 pos
    │
    └── 下一根 Bar...

BacktestingEngine.calculate_result()
    ↓  生成逐日盈亏 DataFrame

BacktestingEngine.calculate_statistics()
    ↓  计算 Sharpe、MaxDrawdown、Calmar、RGR 等
```

---

## 3.2 限价单撮合

回测引擎默认对限价单采用**下一根 Bar 的 open/high/low 价格撮合**，核心逻辑：

```python
def _cross_limit_order(self, bar: BarData) -> None:
    """
    限价单撮合规则（每根新 Bar 到来时检查）：
    - 买入限价单：bar.low_price <= order.price → 以 min(order.price, bar.open) 成交
    - 卖出限价单：bar.high_price >= order.price → 以 max(order.price, bar.open) 成交
    """
    for order in list(self.active_limit_orders.values()):
        if order.direction == Direction.LONG:
            if bar.low_price <= order.price:
                trade_price = min(order.price, bar.open_price)
                # 生成成交记录
                self._generate_trade(order, trade_price, bar.datetime)

        elif order.direction == Direction.SHORT:
            if bar.high_price >= order.price:
                trade_price = max(order.price, bar.open_price)
                self._generate_trade(order, trade_price, bar.datetime)
```

**关键结论**：
- 回测中不存在"当根 Bar 以收盘价下单、当根 Bar 成交"的情况
- 委托在 `on_bar` 中生成，在**下一根 Bar** 检查是否触发
- 成交价格不高于买入限价、不低于卖出限价

---

## 3.3 停止单撮合

停止单（Stop Order）是 VeighNa 内部的虚拟委托类型，**不发往交易所**，由回测引擎在价格突破时自动转化为市价单。

```python
# 在策略中使用停止单
self.buy(bar.close_price + 10, 1, stop=True)   # 价格上破时买入

# 回测引擎撮合逻辑
def _cross_stop_order(self, bar: BarData) -> None:
    for stop_order in list(self.active_stop_orders.values()):
        if stop_order.direction == Direction.LONG:
            if bar.high_price >= stop_order.price:
                # 以 max(stop_price, bar.open) 成交（不使用 slippage）
                trade_price = max(stop_order.price, bar.open_price)
                self._generate_trade(stop_order, trade_price, bar.datetime)

        elif stop_order.direction == Direction.SHORT:
            if bar.low_price <= stop_order.price:
                trade_price = min(stop_order.price, bar.open_price)
                self._generate_trade(stop_order, trade_price, bar.datetime)
```

**实盘中停止单的处理**：自动转化为对应方向的限价单，并经过 `OffsetConverter` 处理开平仓后发往交易所。

---

## 3.4 什么是未来函数

**未来函数（Look-ahead Bias）**：在回测中不应存在的情况——策略在某根 Bar 的计算中用到了该 Bar **收盘后才能知道的数据**，导致回测绩效虚高。

### 常见未来函数错误示例

```python
def on_bar(self, bar: BarData) -> None:
    # ❌ 错误：用当根 Bar 的 close 下单，同时在当根 Bar 成交
    # 真实情况：close 价格是该分钟的最后成交价，下单时收盘已过
    self.buy(bar.close_price, 1)    # 回测引擎在当根 Bar 检查撮合 → 未来函数

    # ✅ 正确：下一根 Bar 才会检查撮合，close_price 作为限价已知
    self.buy(bar.close_price, 1)    # 配合回测引擎"次Bar撮合"机制使用
```

```python
def on_bar(self, bar: BarData) -> None:
    am = self.am
    am.update_bar(bar)    # ← 先更新当前 Bar

    # ❌ 错误：sma 计算包含了当根 Bar 的 close，用于当根 Bar 下单
    # 这在实盘中也成立（收盘后下单），但以下模式是错误的：
    high_series = am.high   # 包含当根 Bar 的 high

    # ✅ 正确：使用 high[-2] 等前一根 Bar 数据判断信号
    if am.high[-2] > some_level:    # 前一根突破，当根开盘追入
        self.buy(bar.open_price, 1)
```

### 时间顺序一致性原则

```
Bar N-1 结束（close 确定）
    ↓
on_bar(bar_N-1) 触发 → 信号计算 → 下委托
    ↓
Bar N 开始（第一个 Tick）
    ↓
限价单/停止单检查撮合 → 以 Bar N 的 open 等价格成交
    ↓
on_trade 触发 → 更新 pos
```

**原则**：信号在 Bar N-1 **结束后**生成，成交在 Bar N **开始时**发生，两者严格时间顺序。

---

## 3.5 DualThrust 策略

DualThrust 是经典的通道突破策略，以此演示回测原理的综合应用：

```python
from vnpy_ctastrategy import CtaTemplate
from vnpy.trader.object import BarData
from vnpy.trader.utility import BarGenerator, ArrayManager


class DualThrustStrategy(CtaTemplate):
    """DualThrust 日内突破策略"""
    author = "量化实战"

    k1 = 0.4           # 上轨系数
    k2 = 0.4           # 下轨系数
    lookback = 4       # 回看天数
    fixed_size = 1

    parameters = ["k1", "k2", "lookback", "fixed_size"]

    upper_bound = 0.0
    lower_bound = 0.0
    variables = ["upper_bound", "lower_bound"]

    def on_init(self) -> None:
        self.bg = BarGenerator(self.on_bar, 1, self.on_daily_bar,
                               interval=Interval.DAILY,
                               daily_end=time(15, 0))
        self.am = ArrayManager(size=self.lookback + 5)
        self.load_bar(self.lookback + 2)

    def on_bar(self, bar: BarData) -> None:
        self.bg.update_bar(bar)

        # 日内以停止单方式追价（突破上轨买入，突破下轨做空）
        if self.upper_bound and self.lower_bound:
            if self.pos == 0:
                self.buy(self.upper_bound, self.fixed_size, stop=True)
                self.short(self.lower_bound, self.fixed_size, stop=True)

            elif self.pos > 0:
                self.sell(self.lower_bound, abs(self.pos), stop=True)
                self.short(self.lower_bound, self.fixed_size, stop=True)

            elif self.pos < 0:
                self.cover(self.upper_bound, abs(self.pos), stop=True)
                self.buy(self.upper_bound, self.fixed_size, stop=True)

    def on_daily_bar(self, bar: BarData) -> None:
        """每日 K 线完成，更新次日突破区间"""
        self.cancel_all()
        am = self.am
        am.update_bar(bar)
        if not am.inited:
            return

        # DualThrust 公式：Range = max(HH-LC, HC-LL)
        hh = am.high[-self.lookback:].max()  # N日最高价的最高
        lc = am.close[-self.lookback:].min() # N日收盘价的最低
        hc = am.close[-self.lookback:].max() # N日收盘价的最高
        ll = am.low[-self.lookback:].min()   # N日最低价的最低

        rng = max(hh - lc, hc - ll)
        self.upper_bound = bar.close_price + self.k1 * rng
        self.lower_bound = bar.close_price - self.k2 * rng

        self.put_event()
```

---

# 第四章 止盈止损

## 4.1 通道突破逻辑

布林通道突破是趋势策略的常见入场逻辑：

```python
def on_bar(self, bar: BarData) -> None:
    self.cancel_all()
    am = self.am
    am.update_bar(bar)
    if not am.inited:
        return

    # 布林通道
    upper, mid, lower = am.boll(self.boll_window, self.boll_dev)

    # 上轨突破 → 开多（停止单，突破即触发）
    if self.pos == 0:
        self.buy(upper, self.fixed_size, stop=True)
        self.short(lower, self.fixed_size, stop=True)

    # 回归中轨 → 平仓（中轨以停止单方式平仓）
    elif self.pos > 0:
        self.sell(mid, abs(self.pos), stop=True)
    elif self.pos < 0:
        self.cover(mid, abs(self.pos), stop=True)

    self.put_event()
```

---

## 4.2 固定止损止盈

最简单直接的风险控制方式：

```python
class FixedStopStrategy(CtaTemplate):
    stop_loss_pct = 0.02    # 2% 止损
    take_profit_pct = 0.04  # 4% 止盈
    parameters = ["stop_loss_pct", "take_profit_pct"]

    entry_price = 0.0
    variables = ["entry_price"]

    def on_bar(self, bar: BarData) -> None:
        self.cancel_all()
        am = self.am
        am.update_bar(bar)
        if not am.inited:
            return

        if self.pos > 0:
            # 固定止损：入场价 × (1 - 止损比例)
            stop_price   = self.entry_price * (1 - self.stop_loss_pct)
            profit_price = self.entry_price * (1 + self.take_profit_pct)

            self.sell(stop_price,   abs(self.pos), stop=True)  # 止损停止单
            self.sell(profit_price, abs(self.pos))             # 止盈限价单

        elif self.pos == 0:
            # 入场信号（此处简化为均线判断）
            if am.sma(20) > am.sma(60):
                self.entry_price = bar.close_price
                self.buy(bar.close_price, 1)

    def on_trade(self, trade) -> None:
        if self.pos != 0:
            self.entry_price = trade.price   # 记录成交入场价
        else:
            self.entry_price = 0.0
        self.put_event()
```

---

## 4.3 移动止损原理

移动止损（Trailing Stop）随价格有利方向移动，锁住浮盈：

```python
class TrailingStopStrategy(CtaTemplate):
    trailing_pct = 0.02   # 移动止损比例（跟踪幅度）
    parameters = ["trailing_pct"]

    long_stop  = 0.0      # 多头移动止损价
    short_stop = 0.0      # 空头移动止损价
    intra_trade_high = 0.0  # 持仓期间最高价
    intra_trade_low  = 0.0  # 持仓期间最低价
    variables = ["long_stop", "short_stop",
                 "intra_trade_high", "intra_trade_low"]

    def on_bar(self, bar: BarData) -> None:
        self.cancel_all()
        am = self.am
        am.update_bar(bar)
        if not am.inited:
            return

        if self.pos == 0:
            self.intra_trade_high = bar.high_price
            self.intra_trade_low  = bar.low_price

            # 简化入场：金叉开多，死叉开空
            if am.sma(10) > am.sma(30):
                self.buy(bar.close_price, 1)
            elif am.sma(10) < am.sma(30):
                self.short(bar.close_price, 1)

        elif self.pos > 0:
            # 更新持仓期间最高价
            self.intra_trade_high = max(self.intra_trade_high, bar.high_price)
            # 移动止损 = 最高价 × (1 - trailing_pct)
            self.long_stop = self.intra_trade_high * (1 - self.trailing_pct)
            self.sell(self.long_stop, abs(self.pos), stop=True)

        elif self.pos < 0:
            self.intra_trade_low  = min(self.intra_trade_low, bar.low_price)
            self.short_stop = self.intra_trade_low * (1 + self.trailing_pct)
            self.cover(self.short_stop, abs(self.pos), stop=True)

        self.put_event()
```

---

## 4.4 进阶移动止损（ATR 自适应）

用 ATR 替代固定比例，自适应市场波动：

```python
class AtrTrailingStopStrategy(CtaTemplate):
    atr_window    = 14
    atr_multiple  = 3.0      # ATR 倍数
    parameters    = ["atr_window", "atr_multiple"]

    long_stop  = 0.0
    short_stop = 0.0
    variables  = ["long_stop", "short_stop"]

    def on_bar(self, bar: BarData) -> None:
        self.cancel_all()
        am = self.am
        am.update_bar(bar)
        if not am.inited:
            return

        atr = am.atr(self.atr_window)

        if self.pos > 0:
            # ATR 移动止损：每根 Bar 用最新 ATR 更新止损位
            new_stop = bar.close_price - self.atr_multiple * atr
            # 只允许止损价上移（锁住浮盈）
            self.long_stop = max(self.long_stop, new_stop)
            self.sell(self.long_stop, abs(self.pos), stop=True)

        elif self.pos < 0:
            new_stop = bar.close_price + self.atr_multiple * atr
            self.short_stop = min(self.short_stop, new_stop)
            self.cover(self.short_stop, abs(self.pos), stop=True)

        else:
            # 入场后初始化止损
            if am.sma(10) > am.sma(30):
                self.buy(bar.close_price, 1)
                self.long_stop = bar.close_price - self.atr_multiple * atr
            elif am.sma(10) < am.sma(30):
                self.short(bar.close_price, 1)
                self.short_stop = bar.close_price + self.atr_multiple * atr

        self.put_event()
```

---

## 4.5 AtrRsi 策略

结合 ATR 止损和 RSI 入场过滤：

```python
class AtrRsiStrategy(CtaTemplate):
    """ATR + RSI 趋势跟踪策略"""
    author = "量化实战"

    atr_window   = 14
    atr_multiple = 3.0
    rsi_window   = 14
    rsi_level    = 50      # RSI 多空分界
    fixed_size   = 1
    parameters   = ["atr_window", "atr_multiple", "rsi_window",
                     "rsi_level", "fixed_size"]

    long_stop  = 0.0
    short_stop = 0.0
    variables  = ["long_stop", "short_stop"]

    def on_init(self) -> None:
        self.bg = BarGenerator(self.on_bar)
        self.am = ArrayManager(size=max(self.atr_window, self.rsi_window) + 10)
        self.load_bar(10)

    def on_bar(self, bar: BarData) -> None:
        self.cancel_all()
        am = self.am
        am.update_bar(bar)
        if not am.inited:
            return

        atr = am.atr(self.atr_window)
        rsi = am.rsi(self.rsi_window)

        if self.pos == 0:
            # RSI > 50 做多，RSI < 50 做空
            if rsi > self.rsi_level:
                self.buy(bar.close_price, self.fixed_size)
                self.long_stop = bar.close_price - self.atr_multiple * atr
            elif rsi < self.rsi_level:
                self.short(bar.close_price, self.fixed_size)
                self.short_stop = bar.close_price + self.atr_multiple * atr

        elif self.pos > 0:
            self.long_stop = max(self.long_stop,
                                  bar.close_price - self.atr_multiple * atr)
            self.sell(self.long_stop, abs(self.pos), stop=True)

        elif self.pos < 0:
            self.short_stop = min(self.short_stop,
                                   bar.close_price + self.atr_multiple * atr)
            self.cover(self.short_stop, abs(self.pos), stop=True)

        self.put_event()
```

---

## 4.6 BollChannel 策略

布林通道 + ATR 止损的经典组合：

```python
class BollChannelStrategy(CtaTemplate):
    """布林通道趋势策略"""
    author = "量化实战"

    boll_window  = 18
    boll_dev     = 3.4
    cci_window   = 10
    atr_window   = 30
    sl_multiplier = 5.2
    fixed_size   = 1
    parameters   = ["boll_window", "boll_dev", "cci_window",
                     "atr_window", "sl_multiplier", "fixed_size"]

    boll_up   = 0.0
    boll_down = 0.0
    long_stop  = 0.0
    short_stop = 0.0
    variables  = ["boll_up", "boll_down", "long_stop", "short_stop"]

    def on_init(self) -> None:
        self.bg = BarGenerator(self.on_bar)
        self.am = ArrayManager(size=max(self.boll_window, self.atr_window) + 10)
        self.load_bar(10)

    def on_bar(self, bar: BarData) -> None:
        self.cancel_all()
        am = self.am
        am.update_bar(bar)
        if not am.inited:
            return

        self.boll_up, _, self.boll_down = am.boll(self.boll_window, self.boll_dev)
        cci = am.cci(self.cci_window)
        atr = am.atr(self.atr_window)

        if self.pos == 0:
            # 布林上轨突破 + CCI > 0 做多
            if cci > 0:
                self.buy(self.boll_up, self.fixed_size, stop=True)
                self.short(self.boll_down, self.fixed_size, stop=True)

        elif self.pos > 0:
            self.long_stop = max(self.long_stop,
                                  bar.close_price - self.sl_multiplier * atr)
            self.sell(self.long_stop, abs(self.pos), stop=True)

        elif self.pos < 0:
            self.short_stop = min(self.short_stop,
                                   bar.close_price + self.sl_multiplier * atr)
            self.cover(self.short_stop, abs(self.pos), stop=True)

        self.put_event()

    def on_trade(self, trade) -> None:
        atr = self.am.atr(self.atr_window)
        if self.pos > 0:
            self.long_stop = trade.price - self.sl_multiplier * atr
        elif self.pos < 0:
            self.short_stop = trade.price + self.sl_multiplier * atr
        self.put_event()
```

---

# 第五章 结果分析

## 5.1 回测成交记录

```python
engine.run_backtesting()
df = engine.calculate_result()

# df 是 pandas DataFrame，包含每日数据：
# date, close_price, pre_close, trade_count,
# start_pos, end_pos, turnover, commission, slippage,
# trading_pnl, holding_pnl, total_pnl, net_pnl

# 查看前几行
print(df.head(10))

# 查看所有成交记录
for trade in engine.trades.values():
    print(f"{trade.datetime}  {trade.direction.value} {trade.offset.value}"
          f"  price={trade.price}  volume={trade.volume}")
```

---

## 5.2 逐日盯市盈亏

`calculate_result()` 返回的 DataFrame 区分两类盈亏：

| 字段 | 含义 |
|------|------|
| `trading_pnl` | 当日交易产生的盈亏（已平仓部分）|
| `holding_pnl` | 当日持仓浮盈浮亏（按昨收盘价计算）|
| `total_pnl` | `trading_pnl + holding_pnl` |
| `net_pnl` | `total_pnl - commission - slippage` |

**逐日盯市（Mark-to-Market）**是期货行业标准，每日按收盘价结算持仓盈亏，与实盘保证金变动一致。

---

## 5.3 统计指标计算

```python
stats = engine.calculate_statistics(df)

# 关键指标说明：
print(f"总收益率:       {stats['total_return']:.1%}")
print(f"年化收益率:     {stats['annual_return']:.1%}")
print(f"Sharpe 比率:    {stats['sharpe_ratio']:.2f}")
print(f"最大回撤:       {stats['max_drawdown']:.1%}")
print(f"最大回撤持续:   {stats['max_dduration']} 天")
print(f"Calmar 比率:    {stats['calmar_ratio']:.2f}")
print(f"RGR 指标:       {stats['rgr']:.2f}")        # 4.3.0 新增
print(f"总交易次数:     {stats['total_trade_count']}")
print(f"胜率:           {stats['winning_rate']:.1%}")
print(f"盈亏比:         {stats['profit_loss_ratio']:.2f}")
```

**RGR（Risk-adjusted Growth Rate，4.3.0新增）**：年化收益 / 最大回撤，综合衡量风险调整后的增长质量，数值越大越好。

---

## 5.4 资金曲线绘制

```python
# 方式一：使用内置 plotly 交互图表
engine.show_chart(df)

# 方式二：手动绘制资金曲线
import matplotlib.pyplot as plt

balance = df["net_pnl"].cumsum() + engine.capital
balance.plot(title="资金曲线", figsize=(12, 6))
plt.xlabel("日期")
plt.ylabel("账户资金")
plt.grid(True)
plt.show()

# 方式三：绘制回撤曲线
rolling_max = balance.cummax()
drawdown = (balance - rolling_max) / rolling_max
drawdown.plot(title="回撤曲线", kind="area", figsize=(12, 4), color="red", alpha=0.3)
plt.show()
```

---

# 第六章 委托管理

## 6.1 交易回调函数

策略中有三个委托相关回调，理解执行时序是关键：

```python
def on_order(self, order: OrderData) -> None:
    """
    委托状态变化时触发，可能触发多次：
    SUBMITTING → NOTTRADED → PARTTRADED → ALLTRADED / CANCELLED
    注意：回测中 on_order 可能不触发（直接产生 on_trade）
    """
    pass

def on_trade(self, trade: TradeData) -> None:
    """
    发生实际成交时触发。
    trade.direction + trade.offset 是判断开平方向的依据。
    成交后 self.pos 已由模板自动更新。
    """
    self.put_event()   # 刷新 UI 策略状态

def on_stop_order(self, stop_order: StopOrder) -> None:
    """
    停止单状态变化时触发。
    StopOrder 是 VeighNa 内部虚拟类型，不发往交易所。
    """
    pass
```

**`on_trade` 中常见操作**：

```python
def on_trade(self, trade: TradeData) -> None:
    if trade.direction == Direction.LONG:
        if trade.offset == Offset.OPEN:
            # 买入开多成交 → 记录入场价
            self.entry_price = trade.price
            self.long_stop = trade.price - self.atr_multiple * self.last_atr

    elif trade.direction == Direction.SHORT:
        if trade.offset == Offset.OPEN:
            self.entry_price = trade.price
            self.short_stop = trade.price + self.atr_multiple * self.last_atr

    self.put_event()
```

---

## 6.2 委托控制逻辑

### 防止重复下单

```python
def on_bar(self, bar: BarData) -> None:
    # 每根 Bar 开头撤销所有上轮委托，然后重新评估
    self.cancel_all()

    # ... 信号计算 ...

    # 通过 pos 判断当前持仓状态，避免重复开仓
    if signal_long and self.pos == 0:
        self.buy(price, volume)
    elif signal_short and self.pos == 0:
        self.short(price, volume)
```

### 控制活动委托数量

```python
def on_bar(self, bar: BarData) -> None:
    # 检查当前活动委托数量
    if len(self.active_orderids) > 0:
        return   # 已有委托挂单，本轮跳过
```

### 部分成交处理

```python
def on_order(self, order: OrderData) -> None:
    if order.status == Status.PARTTRADED:
        # 部分成交，可选择撤销剩余部分或继续等待
        self.cancel_order(order.vt_orderid)
```

---

## 6.3 开平自动转换

VeighNa 通过 `OffsetConverter` 自动处理**中国期货市场的开平仓规则**，策略层无需关心。

**调用方式**（策略内的 `buy/sell/short/cover` 参数）：

```python
# 普通开平（OffsetConverter 自动决定开/平/平今/平昨）
self.buy(price, volume)

# 锁仓模式（今仓有持仓则开反向单锁仓，而非平今）
self.buy(price, volume, lock=True)

# 净持仓模式（直接透传，跳过转换，适合净持仓合约）
self.buy(price, volume, net=True)
```

---

## 6.4 上期所规则

上期所（SHFE）和上期能源所（INE）的合约区分**今仓和昨仓**，平今手续费通常更高。`OffsetConverter` 的 SHFE 模式处理逻辑：

```python
# OffsetConverter 内部逻辑（converter.py）
# 对于 SHFE/INE 合约平空单：
#   1. 先平今（short_td > 0 时使用 CLOSETODAY）
#   2. 今仓不够则继续平昨（short_yd > 0 时使用 CLOSEYESTERDAY）
#   3. 可能拆分为两笔委托

# 实盘中 OffsetConverter 维护的持仓状态：
holding = offset_converter.get_position_holding(vt_symbol)
print(f"多头今仓: {holding.long_td}")
print(f"多头昨仓: {holding.long_yd}")
print(f"空头今仓: {holding.short_td}")
print(f"空头昨仓: {holding.short_yd}")
```

---

## 6.5 自动锁仓规则

当策略需要**持有双向持仓**（多空同时持有）时，使用锁仓模式：

```python
# 场景：今日有多头持仓，且已产生浮亏
# 想在不平仓的情况下对冲风险

# 锁仓 = 开反向单而不平现有仓位
self.short(price, volume, lock=True)
# OffsetConverter 检测到今仓有多头 → 生成"开空"委托
# 结果：账户同时持有多头和空头（双向持仓）
```

> **注意**：锁仓会占用双倍保证金，且平仓操作更复杂，一般不推荐新手使用。优先考虑通过 ATR 止损控制风险，而非锁仓。

---

# 第七章 参数优化

## 7.1 为什么要优化

参数优化的核心目的是在**给定的参数空间**内找到使策略在历史数据上表现最优的参数组合，但需要警惕过拟合。

**优化的正确使用方式**：
- 优化目标优先选择 **Sharpe 比率**（而非总收益率），防止以高风险换高收益
- 必须做**样本内外分割**：在样本内优化，在样本外验证
- 参数步长不宜过细，避免过拟合历史数据

---

## 7.2 暴力穷举算法

```python
from vnpy.trader.optimize import OptimizationSetting
from concurrent.futures import ProcessPoolExecutor

# 配置优化参数
setting = OptimizationSetting()
setting.add_parameter("fast_window", 5, 30, 5)    # 5,10,15,20,25,30
setting.add_parameter("slow_window", 20, 80, 10)  # 20,30,40,50,60,70,80
setting.set_target("sharpe_ratio")                 # 优化目标

# 启动穷举优化（多进程并行）
result = engine.run_bf_optimization(
    setting,
    output=print,
    max_workers=8      # 并行进程数，建议 = CPU核心数
)

# result 是 (params_dict, stats_dict) 元组列表，按目标降序排列
for params, stats in result[:5]:
    print(f"参数: {params}")
    print(f"  Sharpe: {stats['sharpe_ratio']:.2f}")
    print(f"  最大回撤: {stats['max_drawdown']:.1%}")
```

**原理**：使用 `ProcessPoolExecutor(mp_context='spawn')` 并行回测所有参数组合（笛卡尔积），`spawn` 避免 macOS/Windows 的 `fork` 问题。

---

## 7.3 遗传迭代算法

当参数空间极大时（组合数 > 1000），穷举法耗时过长，改用遗传算法：

```python
result = engine.run_ga_optimization(
    setting,
    output=print,
    max_workers=8,
    population_size=100,   # 种群大小
    ngen_size=30,          # 迭代代数
    mu=200,                # 每代选择个体数
    lambda_=200,           # 每代产生后代数
    cxpb=0.95,             # 交叉概率
    mutpb=0.01,            # 变异概率
)
```

**遗传算法原理**（基于 DEAP 库）：
1. 从参数网格随机初始化种群（每个个体 = 一组参数）
2. 对每个个体运行回测，计算适应度（目标指标）
3. 使用 NSGA-2 选择算子保留优秀个体
4. 交叉和变异产生下一代
5. 迭代 `ngen_size` 代后返回最优结果

---

## 7.4 样本内外区分

```python
# 样本内（In-Sample）：用于参数优化
engine_is = BacktestingEngine()
engine_is.set_parameters(
    start=datetime(2020, 1, 1),
    end=datetime(2022, 12, 31),   # 前3年做优化
    ...
)
result = engine_is.run_bf_optimization(setting)
best_params = result[0][0]     # 取样本内最优参数

# 样本外（Out-of-Sample）：验证参数泛化能力
engine_os = BacktestingEngine()
engine_os.set_parameters(
    start=datetime(2023, 1, 1),
    end=datetime(2023, 12, 31),   # 后1年做验证
    ...
)
engine_os.add_strategy(MyStrategy, best_params)
engine_os.run_backtesting()
stats_os = engine_os.calculate_statistics()

print("样本外验证结果：")
print(f"  Sharpe: {stats_os['sharpe_ratio']:.2f}")
```

**原则**：样本外 Sharpe 应 ≥ 样本内 Sharpe 的 50%，否则过拟合风险高。

---

## 7.5 优化结果选择

```python
# 不应只看排名第一的参数，应检查参数稳健性
for params, stats in result[:10]:
    print(f"fast={params['fast_window']:3d}  slow={params['slow_window']:3d}"
          f"  Sharpe={stats['sharpe_ratio']:.2f}"
          f"  MaxDD={stats['max_drawdown']:.1%}")

# 选择标准：
# 1. 参数连续性：最优参数附近邻域的参数表现也应良好
# 2. 回撤控制：最大回撤不超过可接受上限（如 20%）
# 3. 样本外稳定：样本外 Sharpe ≥ 0.5 × 样本内 Sharpe
```

---

# 第八章 自动交易

## 8.1 停止单触发

实盘中停止单（`stop=True`）的工作方式与回测不同：

| 场景 | 回测 | 实盘 |
|------|------|------|
| 停止单本质 | 引擎内部虚拟委托 | 转化为限价单后发往交易所 |
| 触发条件 | Bar 的 high/low 穿越触发价 | 实时 Tick 价格穿越触发价 |
| 成交时机 | 下一根 Bar 开盘价 | 触发后立即以市价/限价成交 |

实盘停止单转化逻辑（`CtaEngine`）：
```python
# 当 tick.last_price >= stop_order.price（买入停止单）
# → 生成 OrderRequest(price=stop_order.price, type=OrderType.LIMIT)
# → 调用 main_engine.send_order()
```

---

## 8.2 每日运维流程

生产环境的推荐日常运维流程：

```python
# 1. 开盘前（8:45 / 20:45）
#    检查日志，确认策略状态正常
#    确认持仓与前日收盘一致

# 2. 连接交易所
main_engine.connect(ctp_setting, "CTP")
time.sleep(10)   # 等待登录完成

# 3. 策略初始化（加载历史数据预热）
cta_engine.init_engine()
cta_engine.init_all_strategies()
time.sleep(60)   # 等待预热完成

# 4. 启动策略（开始接收行情，自动交易）
cta_engine.start_all_strategies()

# 5. 收盘后（15:00 / 02:30）
#    检查当日成交记录
#    核对持仓与预期一致
#    保存日志和数据

# 6. 断线重连处理
# CtpGateway 内置自动重连逻辑，连接断开后会自动尝试重连
```

---

## 8.3 交易滑点跟踪

```python
# 回测设置滑点
engine.set_parameters(
    slippage=1,    # 1个价格跳动（pricetick）
    ...
)

# 实盘追踪实际滑点
# 在 on_trade 中记录委托价 vs 成交价的差异
def on_trade(self, trade: TradeData) -> None:
    # 获取对应委托
    order = self.cta_engine.main_engine.get_order(trade.vt_orderid)
    if order:
        slippage = abs(trade.price - order.price)
        self.write_log(f"成交滑点: {slippage:.1f} 元")
    self.put_event()
```

---

## 8.4 国内期货注意点

| 注意点 | 说明 |
|--------|------|
| 开平仓规则 | 上期所/能源所区分今昨仓，平今手续费更高 |
| 涨跌停板 | 委托价格超出涨跌停范围会被交易所拒绝 |
| 集合竞价 | 8:55-9:00（日盘）、20:55-21:00（夜盘），此段时间行情特殊 |
| 最后交易日 | 主力合约换月时需要手动或自动迁仓，防止持有到期 |
| 持仓限额 | 部分合约有持仓限额，超限委托会被拒绝 |
| 程化交易监控 | 需符合交易所程序化交易报备要求（报撤比等）|

---

## 8.5 外盘市场注意点

以 Interactive Brokers（IB）为例：

| 注意点 | 说明 |
|--------|------|
| 时区处理 | 所有时间戳统一转为本地时区，`database.timezone` 须设置正确 |
| 合约代码 | IB 格式：`ES`（合约代码）+`.CME`（交易所）|
| 夏令时 | 美国市场夏令时影响行情时间，需特殊处理 |
| 融资融券 | 股票卖出需区分 `SHORT`（卖空）和 `SELL`（平多）|
| 手续费 | 通常为固定费用/股，而非比例手续费 |

---

# 第九章 策略进阶

## 9.1 跨时间周期实现

同时利用多个时间周期信号：日线确认趋势方向，小时/分钟线寻找入场点。

```python
class MultiTimeframeStrategy(CtaTemplate):
    """多周期策略：日线趋势 + 小时线入场"""
    author = "量化实战"

    daily_window = 20   # 日线均线周期
    hour_window  = 10   # 小时线均线周期
    fixed_size   = 1
    parameters   = ["daily_window", "hour_window", "fixed_size"]

    daily_trend = 0    # +1 多头趋势 / -1 空头趋势
    variables   = ["daily_trend"]

    def on_init(self) -> None:
        # 小时线 BarGenerator
        self.bg1h = BarGenerator(
            self.on_bar, 1, self.on_1h_bar, interval=Interval.HOUR
        )
        # 日线 BarGenerator
        self.bgd = BarGenerator(
            self.on_bar, 1, self.on_daily_bar,
            interval=Interval.DAILY, daily_end=time(15, 0)
        )
        # 两个独立的 ArrayManager
        self.am_daily = ArrayManager(size=self.daily_window + 5)
        self.am_1h    = ArrayManager(size=self.hour_window + 5)
        self.load_bar(20)

    def on_bar(self, bar: BarData) -> None:
        self.bg1h.update_bar(bar)
        self.bgd.update_bar(bar)

    def on_daily_bar(self, bar: BarData) -> None:
        """日线 K 线完成：更新趋势方向"""
        self.am_daily.update_bar(bar)
        if not self.am_daily.inited:
            return

        daily_ma = self.am_daily.sma(self.daily_window)
        if bar.close_price > daily_ma:
            self.daily_trend = 1     # 日线多头趋势
        elif bar.close_price < daily_ma:
            self.daily_trend = -1    # 日线空头趋势

    def on_1h_bar(self, bar: BarData) -> None:
        """小时 K 线完成：在趋势方向上寻找入场"""
        self.cancel_all()
        self.am_1h.update_bar(bar)
        if not self.am_1h.inited or self.daily_trend == 0:
            return

        hour_ma = self.am_1h.sma(self.hour_window)

        # 日线多头趋势 + 小时线金叉 → 做多
        if self.daily_trend == 1 and bar.close_price > hour_ma and self.pos <= 0:
            if self.pos < 0:
                self.cover(bar.close_price, abs(self.pos))
            self.buy(bar.close_price, self.fixed_size)

        # 日线空头趋势 + 小时线死叉 → 做空
        elif self.daily_trend == -1 and bar.close_price < hour_ma and self.pos >= 0:
            if self.pos > 0:
                self.sell(bar.close_price, abs(self.pos))
            self.short(bar.close_price, self.fixed_size)

        self.put_event()
```

---

## 9.2 进阶策略分享：股指跨周期

```python
class IndexMultiPeriodStrategy(CtaTemplate):
    """
    股指期货跨周期策略
    - 日线：判断市场整体多空格局（MA金叉/死叉）
    - 60分钟：判断中期趋势（价格相对布林带位置）
    - 5分钟：精细入场（RSI超买超卖过滤）
    """
    author = "量化实战"

    daily_ma_period  = 20
    hour_boll_period = 20
    hour_boll_dev    = 2.0
    min5_rsi_period  = 14
    min5_rsi_entry   = 30     # RSI 低于此值允许做多
    fixed_size       = 1
    parameters = ["daily_ma_period", "hour_boll_period", "hour_boll_dev",
                  "min5_rsi_period", "min5_rsi_entry", "fixed_size"]

    daily_bias  = 0    # 1: 多头偏多, -1: 空头偏空
    hour_signal = 0    # 1: 突破上轨, -1: 跌破下轨
    variables   = ["daily_bias", "hour_signal"]

    def on_init(self) -> None:
        self.bg5   = BarGenerator(self.on_bar, 5, self.on_5min_bar)
        self.bg60  = BarGenerator(self.on_bar, 60, self.on_1h_bar,
                                  interval=Interval.HOUR)
        self.bgd   = BarGenerator(self.on_bar, 1, self.on_daily_bar,
                                  interval=Interval.DAILY, daily_end=time(15, 0))
        self.am5   = ArrayManager(size=50)
        self.am60  = ArrayManager(size=50)
        self.am_d  = ArrayManager(size=50)
        self.load_bar(30)

    def on_bar(self, bar: BarData) -> None:
        self.bg5.update_bar(bar)
        self.bg60.update_bar(bar)
        self.bgd.update_bar(bar)

    def on_daily_bar(self, bar: BarData) -> None:
        self.am_d.update_bar(bar)
        if not self.am_d.inited:
            return
        ma = self.am_d.sma(self.daily_ma_period)
        self.daily_bias = 1 if bar.close_price > ma else -1

    def on_1h_bar(self, bar: BarData) -> None:
        self.am60.update_bar(bar)
        if not self.am60.inited:
            return
        up, _, down = self.am60.boll(self.hour_boll_period, self.hour_boll_dev)
        if bar.close_price > up:
            self.hour_signal = 1
        elif bar.close_price < down:
            self.hour_signal = -1

    def on_5min_bar(self, bar: BarData) -> None:
        self.cancel_all()
        self.am5.update_bar(bar)
        if not self.am5.inited:
            return

        rsi = self.am5.rsi(self.min5_rsi_period)

        # 三层过滤：日线偏多 + 小时线突破 + RSI未超买
        if (self.daily_bias == 1
                and self.hour_signal == 1
                and rsi < (100 - self.min5_rsi_entry)
                and self.pos == 0):
            self.buy(bar.close_price, self.fixed_size)

        elif (self.daily_bias == -1
                and self.hour_signal == -1
                and rsi > self.min5_rsi_entry
                and self.pos == 0):
            self.short(bar.close_price, self.fixed_size)

        self.put_event()
```

---

## 9.3 动态仓位管理

根据市场波动率和账户净值动态调整每次开仓手数：

```python
class DynamicSizeStrategy(CtaTemplate):
    """动态仓位管理：基于 ATR 和账户净值计算每次开仓手数"""
    author = "量化实战"

    atr_window    = 14
    risk_pct      = 0.02    # 每笔交易允许亏损的账户比例（2%）
    contract_size = 10      # 合约乘数
    price_tick    = 1.0     # 最小价格变动
    parameters    = ["atr_window", "risk_pct", "contract_size", "price_tick"]

    def on_bar(self, bar: BarData) -> None:
        self.cancel_all()
        am = self.am
        am.update_bar(bar)
        if not am.inited:
            return

        atr = am.atr(self.atr_window)

        # 动态手数计算：
        # risk_amount = 账户净值 × risk_pct
        # 每手风险 = ATR × contract_size（一个 ATR 的金额风险）
        # 手数 = risk_amount / 每手风险

        capital = self.cta_engine.main_engine.get_account("CTP.account_id")
        if capital:
            net_value = capital.balance
        else:
            net_value = 1_000_000   # 默认初始资金

        risk_amount = net_value * self.risk_pct
        risk_per_lot = atr * self.contract_size

        if risk_per_lot > 0:
            size = int(risk_amount / risk_per_lot)
            size = max(size, 1)    # 最少1手
        else:
            size = 1

        # 信号逻辑（此处简化）
        if am.sma(10) > am.sma(30) and self.pos == 0:
            self.buy(bar.close_price, size)

        self.put_event()
```

---

## 9.4 进阶策略分享：螺纹趋势

```python
class RbarTrendStrategy(CtaTemplate):
    """
    螺纹钢期货趋势策略
    - 基于布林通道突破 + ATR 自适应止损
    - 动态仓位管理（固定比例风险）
    - 跨日持仓，捕捉中长期趋势
    """
    author = "量化实战"

    boll_window  = 20
    boll_dev     = 2.0
    atr_window   = 14
    atr_multiple = 2.5
    risk_pct     = 0.02
    parameters   = ["boll_window", "boll_dev", "atr_window",
                     "atr_multiple", "risk_pct"]

    long_stop   = 0.0
    short_stop  = 0.0
    variables   = ["long_stop", "short_stop"]

    def on_init(self) -> None:
        self.bg = BarGenerator(self.on_bar, 60, self.on_1h_bar,
                               interval=Interval.HOUR)
        self.am = ArrayManager(size=max(self.boll_window, self.atr_window) + 10)
        self.load_bar(20)

    def on_bar(self, bar: BarData) -> None:
        self.bg.update_bar(bar)

    def on_1h_bar(self, bar: BarData) -> None:
        self.cancel_all()
        am = self.am
        am.update_bar(bar)
        if not am.inited:
            return

        boll_up, _, boll_down = am.boll(self.boll_window, self.boll_dev)
        atr = am.atr(self.atr_window)
        size = max(1, int(100000 * self.risk_pct / (atr * 10)))  # 简化动态手数

        if self.pos == 0:
            # 布林上轨突破停止单做多
            self.buy(boll_up, size, stop=True)
            # 布林下轨突破停止单做空
            self.short(boll_down, size, stop=True)

        elif self.pos > 0:
            # ATR 移动止损（只上移，不下移）
            new_stop = bar.close_price - self.atr_multiple * atr
            self.long_stop = max(self.long_stop, new_stop)
            self.sell(self.long_stop, abs(self.pos), stop=True)

        elif self.pos < 0:
            new_stop = bar.close_price + self.atr_multiple * atr
            self.short_stop = min(self.short_stop, new_stop)
            self.cover(self.short_stop, abs(self.pos), stop=True)

        self.put_event()

    def on_trade(self, trade: TradeData) -> None:
        atr = self.am.atr(self.atr_window)
        if self.pos > 0:
            self.long_stop = trade.price - self.atr_multiple * atr
        elif self.pos < 0:
            self.short_stop = trade.price + self.atr_multiple * atr
        else:
            self.long_stop = 0.0
            self.short_stop = 0.0
        self.put_event()
```

---

## 9.5 发送微信通知

通过企业微信群机器人或第三方推送服务，在关键事件时发送通知：

```python
import requests

def send_wechat_notification(content: str) -> None:
    """通过企业微信群机器人发送通知"""
    webhook_url = "https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=YOUR_KEY"
    data = {
        "msgtype": "text",
        "text": {"content": content}
    }
    try:
        requests.post(webhook_url, json=data, timeout=5)
    except Exception:
        pass   # 通知失败不影响交易


# 在策略中使用
class NotifyStrategy(CtaTemplate):

    def on_trade(self, trade: TradeData) -> None:
        msg = (f"【{self.strategy_name}】成交通知\n"
               f"合约: {trade.vt_symbol}\n"
               f"方向: {trade.direction.value} {trade.offset.value}\n"
               f"价格: {trade.price}\n"
               f"数量: {trade.volume}\n"
               f"当前持仓: {self.pos}")
        send_wechat_notification(msg)
        self.put_event()

    def on_stop(self) -> None:
        send_wechat_notification(f"【{self.strategy_name}】策略已停止")
```

---

## 9.6 回测实盘区分控制

同一份策略代码在回测和实盘中行为可能需要有所不同：

```python
class AdaptiveStrategy(CtaTemplate):

    def on_bar(self, bar: BarData) -> None:
        am = self.am
        am.update_bar(bar)
        if not am.inited:
            return

        # 判断是否处于实盘模式
        is_live = self.trading   # True = 实盘, False = 回测初始化阶段

        if is_live:
            # 实盘：使用更保守的仓位，额外增加滑点预估
            size = 1
            # 实盘中下单价格加一个 pricetick，提高成交概率
            price = bar.close_price + self.pricetick
        else:
            # 回测：使用收盘价，交给撮合引擎处理
            size = 2
            price = bar.close_price

        if am.sma(10) > am.sma(30) and self.pos == 0:
            self.buy(price, size)

    def on_init(self) -> None:
        self.am = ArrayManager()
        self.load_bar(10)
        # on_init 期间 self.trading = False
        # on_start 后 self.trading = True

    def on_start(self) -> None:
        # 此时 self.trading = True，策略正式启动
        self.write_log(f"策略启动，运行模式：{'实盘' if self.trading else '回测'}")
```

**`self.trading` 的状态变化**：

```
on_init()  →  self.trading = False  （预热阶段，不实际下单）
on_start() →  self.trading = True   （正式启动，开始下单）
on_stop()  →  self.trading = False  （停止，不再下单）
```

---

## 附录：常用代码片段速查

### ArrayManager 指标速查表

```python
am = ArrayManager(100)

# 均线族
am.sma(n)          # 简单移动平均
am.ema(n)          # 指数移动平均
am.wma(n)          # 加权移动平均
am.dema(n)         # 双指数移动平均
am.tema(n)         # 三指数移动平均
am.trix(n)         # TRIX 三重指数平滑

# 波动类
am.atr(n)          # 真实波动幅度均值
am.natr(n)         # 标准化 ATR（%）
am.boll(n, d)      # 布林带 → (upper, mid, lower)

# 震荡类
am.rsi(n)          # RSI（0-100）
am.cci(n)          # 商品通道指数
am.adx(n)          # 平均趋向指数
am.adxr(n)         # 平滑 ADX
am.kd(n, m)        # KD 随机指标 → (k, d)
am.macd(f, s, sig) # MACD → (macd, signal, hist)
am.sar(a, m)       # 抛物线 SAR

# 直接访问原始序列
am.open[-1]        # 最新开盘价
am.high[-1]        # 最新最高价
am.close[-5:]      # 最近5根收盘价数组
```

### BarGenerator 初始化速查

```python
from datetime import time
from vnpy.trader.constant import Interval

# 1分钟 Bar（从 Tick 合成）
bg = BarGenerator(on_bar)

# N分钟 Bar（N 必须能整除60）
bg = BarGenerator(on_bar, 5, on_5min_bar)      # 5分钟
bg = BarGenerator(on_bar, 15, on_15min_bar)    # 15分钟

# 小时 Bar
bg = BarGenerator(on_bar, 1, on_1h_bar, interval=Interval.HOUR)

# 日 Bar（必须指定收盘时间）
bg = BarGenerator(on_bar, 1, on_daily_bar,
                  interval=Interval.DAILY, daily_end=time(15, 0))
```

### 回测引擎参数速查

```python
engine.set_parameters(
    vt_symbol="rb2401.SHFE",    # 合约（symbol.exchange）
    interval=Interval.MINUTE,   # MINUTE / HOUR / DAILY
    start=datetime(2023, 1, 1),
    end=datetime(2023, 12, 31),
    rate=0.0001,        # 手续费率（万一 = 0.0001）
    slippage=1,         # 滑点（单位：pricetick）
    size=10,            # 合约乘数（螺纹钢=10，IF=300，沪深300=300）
    pricetick=1,        # 最小价格变动（螺纹钢=1元）
    capital=1_000_000,  # 初始资金
    mode=BacktestingMode.BAR,   # BAR 或 TICK
)
```

### 常见合约参数

| 合约 | 代码 | 合约乘数 | 最小变动 | 手续费 |
|------|------|---------|---------|-------|
| 螺纹钢 | RB.SHFE | 10 | 1 元 | 万一 |
| 铜 | CU.SHFE | 5 | 10 元 | 万零点三 |
| 沪深300期货 | IF.CFFEX | 300 | 0.2 点 | 万零点二三 |
| 中证500期货 | IC.CFFEX | 200 | 0.2 点 | 万零点二三 |
| 豆粕 | M.DCE | 10 | 1 元 | 万一点五 |
| 棕榈油 | P.DCE | 10 | 2 元 | 万二点五 |

---

*文档基于 VeighNa 4.3.0 源码编写，结合官方文档 [vnpy.com/docs](https://www.vnpy.com/docs/cn/index.html) 整理。*
