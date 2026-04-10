# VeighNa - By Traders, For Traders, AI-Powered.

mac启动
cd /Users/shangyong.chen/Github/vnpy
.venv/bin/python run_macos.py

<p align="center">
  <img src ="https://vnpy.oss-cn-shanghai.aliyuncs.com/veighna-logo.png"/>
</p>

💬 Want to read this in **english** ? Go [**here**](README_ENG.md)

<p align="center">
    <img src ="https://img.shields.io/badge/version-4.3.0-blueviolet.svg"/>
    <img src ="https://img.shields.io/badge/platform-windows|linux|macos-yellow.svg"/>
    <img src ="https://img.shields.io/badge/python-3.10|3.11|3.12|3.13-blue.svg" />
    <img src ="https://img.shields.io/github/actions/workflow/status/vnpy/vnpy/pythonapp.yml?branch=master"/>
    <img src ="https://img.shields.io/github/license/vnpy/vnpy.svg?color=orange"/>
</p>

VeighNa是一套基于Python的开源量化交易系统开发框架，在开源社区持续不断的贡献下一步步成长为多功能量化交易平台，自发布以来已经积累了众多来自金融机构或相关领域的用户，包括私募基金、证券公司、期货公司等。

在使用VeighNa进行二次开发（策略、模块等）的过程中有任何疑问，请查看[**VeighNa项目文档**](https://www.vnpy.com/docs/cn/index.html)，如果无法解决请前往[**官方社区论坛**](https://www.vnpy.com/forum/)的【提问求助】板块寻求帮助，也欢迎在【经验分享】板块分享你的使用心得！

**想要获取更多关于VeighNa的资讯信息？** 请扫描下方二维码添加小助手加入【VeighNa社区交流微信群】：

  <img src ="https://vnpy.oss-cn-shanghai.aliyuncs.com/github_wx.png"/, width=250>

## AI-Powered


VeighNa发布十周年之际正式推出4.0版本，重磅新增面向AI量化策略的[vnpy.alpha](./vnpy/alpha)模块，为专业量化交易员提供**一站式多因子机器学习（ML）策略开发、投研和实盘交易解决方案**：

  <img src ="https://vnpy.oss-cn-shanghai.aliyuncs.com/alpha_demo.jpg"/, width=500>

* :bar_chart: **[dataset](./vnpy/alpha/dataset)**：因子特征工程

    * 专为ML算法训练优化设计，支持高效批量特征计算与处理
    * 内置丰富的因子特征表达式计算引擎，实现快速一键生成训练数据
    * [Alpha 158](./vnpy/alpha/dataset/datasets/alpha_158.py)：源于微软Qlib项目的股票市场特征集合，涵盖K线形态、价格趋势、时序波动等多维度量化因子
    * [Alpha 101](./vnpy/alpha/dataset/datasets/alpha_101.py)：源于WorldQuant的101个截面因子，侧重跨标的相对强弱与价量关系（4.3.0新增）

* :bulb: **[model](./vnpy/alpha/model)**：预测模型训练

    * 提供标准化的ML模型开发模板，大幅简化模型构建与训练流程
    * 统一API接口设计，支持无缝切换不同算法进行性能对比测试
    * 集成多种主流机器学习算法：
        * [Lasso](./vnpy/alpha/model/models/lasso_model.py)：经典Lasso回归模型，通过L1正则化实现特征选择
        * [LightGBM](./vnpy/alpha/model/models/lgb_model.py)：高效梯度提升决策树，针对大规模数据集优化的训练引擎
        * [MLP](./vnpy/alpha/model/models/mlp_model.py)：多层感知机神经网络，适用于复杂非线性关系建模

* :robot: **[strategy](./vnpy/alpha/strategy)**：策略投研开发

    * 基于ML信号预测模型快速构建量化交易策略
    * 支持截面多标的和时序单标的两种策略类型

* :microscope: **[lab](./vnpy/alpha/lab.py)**：投研流程管理

    * 集成数据管理、模型训练、信号生成和策略回测等完整工作流程
    * 简洁API设计，内置可视化分析工具，直观评估策略表现和模型效果

* :book: **[notebook](./examples/alpha_research)**：量化投研Demo

    * [download_data_rq](./examples/alpha_research/download_data_rq.ipynb)：基于RQData下载A股指数成分股数据，包含指数成分变化跟踪及历史行情获取
    * [download_data_xt](./examples/alpha_research/download_data_xt.ipynb)：基于迅投研数据服务，下载获取A股指数成分历史变化和股票K线数据
    * [research_workflow_lasso](./examples/alpha_research/research_workflow_lasso.ipynb)：基于Lasso回归模型的量化投研工作流，展示线性模型特征选择与预测能力
    * [research_workflow_lgb](./examples/alpha_research/research_workflow_lgb.ipynb)：基于LightGBM梯度提升树的量化投研工作流，利用高效集成学习方法进行预测
    * [research_workflow_mlp](./examples/alpha_research/research_workflow_mlp.ipynb)：基于多层感知机神经网络的量化投研工作流，展示深度学习在量化交易中的应用

vnpy.alpha模块的设计理念受到[Qlib](https://github.com/microsoft/qlib)项目的启发，在保持易用性的同时提供强大的AI量化能力，特此向Qlib开发团队致以诚挚感谢！


## 功能特点

带有 :arrow_up: 的模块代表已经完成4.0版本的升级适配测试，同时4.0核心框架采用了优先保证兼容性的升级方式，因此大多数模块也都可以直接使用（涉及到C++ API封装的接口必须升级后才能使用）。 

1. :arrow_up: 多功能量化交易平台（trader），整合了多种交易接口，并针对具体策略算法和功能开发提供了简洁易用的API，用于快速构建交易员所需的量化交易应用。

2. 覆盖国内外所拥有的下述交易品种的交易接口（gateway）：

    * 国内市场

        * :arrow_up: CTP（[ctp](https://www.github.com/vnpy/vnpy_ctp)）：国内期货、期权

        * :arrow_up: CTP Mini（[mini](https://www.github.com/vnpy/vnpy_mini)）：国内期货、期权

        * :arrow_up: CTP证券（[sopt](https://www.github.com/vnpy/vnpy_sopt)）：ETF期权

        * :arrow_up: 飞马（[femas](https://www.github.com/vnpy/vnpy_femas)）：国内期货

        * :arrow_up: 恒生UFT（[uft](https://www.github.com/vnpy/vnpy_uft)）：国内期货、ETF期权

        * :arrow_up: 易盛（[esunny](https://www.github.com/vnpy/vnpy_esunny)）：国内期货、黄金TD

        * :arrow_up: 顶点HTS（[hts](https://www.github.com/vnpy/vnpy_hts)）：ETF期权

        * :arrow_up: 顶点飞创（[sec](https://www.github.com/vnpy/vnpy_sec)）：ETF期权

        * :arrow_up: 中泰XTP（[xtp](https://www.github.com/vnpy/vnpy_xtp)）：国内证券（A股）、ETF期权

        * :arrow_up: 华鑫奇点（[tora](https://www.github.com/vnpy/vnpy_tora)）：国内证券（A股）、ETF期权

        * 东证OST（[ost](https://www.github.com/vnpy/vnpy_ost)）：国内证券（A股）

        * 东方财富EMT（[emt](https://www.github.com/vnpy/vnpy_emt)）：国内证券（A股）

        * 飞鼠（[sgit](https://www.github.com/vnpy/vnpy_sgit)）：黄金TD、国内期货

        * :arrow_up: 金仕达黄金（[ksgold](https://www.github.com/vnpy/vnpy_ksgold)）：黄金TD

        * :arrow_up: 利星资管（[lstar](https://www.github.com/vnpy/vnpy_lstar)）：期货资管

        * :arrow_up: 融航（[rohon](https://www.github.com/vnpy/vnpy_rohon)）：期货资管

        * :arrow_up: 杰宜斯（[jees](https://www.github.com/vnpy/vnpy_jees)）：期货资管

        * 中汇亿达（[comstar](https://www.github.com/vnpy/vnpy_comstar)）：银行间市场

        * :arrow_up: TTS（[tts](https://www.github.com/vnpy/vnpy_tts)）：国内期货（仿真）

    * 海外市场

        * :arrow_up: Interactive Brokers（[ib](https://www.github.com/vnpy/vnpy_ib)）：海外证券、期货、期权、贵金属等

        * :arrow_up: 易盛9.0外盘（[tap](https://www.github.com/vnpy/vnpy_tap)）：海外期货

        * :arrow_up: 直达期货（[da](https://www.github.com/vnpy/vnpy_da)）：海外期货

    * 特殊应用

        * :arrow_up: RQData行情（[rqdata](https://www.github.com/vnpy/vnpy_rqdata)）：跨市场（股票、指数、ETF、期货）实时行情

        * :arrow_up: 迅投研行情（[xt](https://www.github.com/vnpy/vnpy_xt)）：跨市场（股票、指数、可转债、ETF、期货、期权）实时行情

        * :arrow_up: RPC服务（[rpc](https://www.github.com/vnpy/vnpy_rpcservice)）：跨进程通讯接口，用于分布式架构

3. 覆盖下述各类量化策略的交易应用（app）：

    * :arrow_up: [cta_strategy](https://www.github.com/vnpy/vnpy_ctastrategy)：CTA策略引擎模块，在保持易用性的同时，允许用户针对CTA类策略运行过程中委托的报撤行为进行细粒度控制（降低交易滑点、实现高频策略）

    * :arrow_up: [cta_backtester](https://www.github.com/vnpy/vnpy_ctabacktester)：CTA策略回测模块，无需使用Jupyter Notebook，直接使用图形界面进行策略回测分析、参数优化等相关工作

    * :arrow_up: [spread_trading](https://www.github.com/vnpy/vnpy_spreadtrading)：价差交易模块，支持自定义价差，实时计算价差行情和持仓，支持价差算法交易以及自动价差策略两种模式

    * :arrow_up: [option_master](https://www.github.com/vnpy/vnpy_optionmaster)：期权交易模块，针对国内期权市场设计，支持多种期权定价模型、隐含波动率曲面计算、希腊值风险跟踪等功能

    * :arrow_up: [portfolio_strategy](https://www.github.com/vnpy/vnpy_portfoliostrategy)：组合策略模块，面向同时交易多合约的量化策略（Alpha、期权套利等），提供历史数据回测和实盘自动交易功能

    * :arrow_up: [algo_trading](https://www.github.com/vnpy/vnpy_algotrading)：算法交易模块，提供多种常用的智能交易算法：TWAP、Sniper、Iceberg、BestLimit等

    * :arrow_up: [script_trader](https://www.github.com/vnpy/vnpy_scripttrader)：脚本策略模块，面向多标的类量化策略和计算任务设计，同时也可以在命令行中实现REPL指令形式的交易，不支持回测功能

    * :arrow_up: [paper_account](https://www.github.com/vnpy/vnpy_paperaccount)：本地仿真模块，纯本地化实现的仿真模拟交易功能，基于交易接口获取的实时行情进行委托撮合，提供委托成交推送以及持仓记录

    * :arrow_up: [chart_wizard](https://www.github.com/vnpy/vnpy_chartwizard)：K线图表模块，基于RQData数据服务（期货）或者交易接口获取历史数据，并结合Tick推送显示实时行情变化

    * :arrow_up: [portfolio_manager](https://www.github.com/vnpy/vnpy_portfoliomanager)：交易组合管理模块，以独立的策略交易组合（子账户）为基础，提供委托成交记录管理、交易仓位自动跟踪以及每日盈亏实时统计功能

    * :arrow_up: [rpc_service](https://www.github.com/vnpy/vnpy_rpcservice)：RPC服务模块，允许将某一进程启动为服务端，作为统一的行情和交易路由通道，允许多客户端同时连接，实现多进程分布式系统

    * :arrow_up: [data_manager](https://www.github.com/vnpy/vnpy_datamanager)：历史数据管理模块，通过树形目录查看数据库中已有的数据概况，选择任意时间段数据查看字段细节，支持CSV文件的数据导入和导出

    * :arrow_up: [data_recorder](https://www.github.com/vnpy/vnpy_datarecorder)：行情记录模块，基于图形界面进行配置，根据需求实时录制Tick或者K线行情到数据库中，用于策略回测或者实盘初始化

    * :arrow_up: [excel_rtd](https://www.github.com/vnpy/vnpy_excelrtd)：Excel RTD（Real Time Data）实时数据服务，基于pyxll模块实现在Excel中获取各类数据（行情、合约、持仓等）的实时推送更新

    * :arrow_up: [risk_manager](https://www.github.com/vnpy/vnpy_riskmanager)：风险管理模块，提供包括交易流控、下单数量、活动委托、撤单总数等规则的统计和限制，有效实现前端风控功能

    * :arrow_up: [web_trader](https://www.github.com/vnpy/vnpy_webtrader)：Web服务模块，针对B-S架构需求设计，实现了提供主动函数调用（REST）和被动数据推送（Websocket）的Web服务器

4. Python交易API接口封装（api），提供上述交易接口的底层对接实现。

    * :arrow_up: REST Client（[rest](https://www.github.com/vnpy/vnpy_rest)）：基于协程异步IO的高性能REST API客户端，采用事件消息循环的编程模型，支持高并发实时交易请求发送

    * :arrow_up: Websocket Client（[websocket](https://www.github.com/vnpy/vnpy_websocket)）：基于协程异步IO的高性能Websocket API客户端，支持和REST Client共用事件循环并发运行

5. :arrow_up: 简洁易用的事件驱动引擎（event），作为事件驱动型交易程序的核心。

6. 对接各类数据库的适配器接口（database）：

    * SQL类

        * :arrow_up: SQLite（[sqlite](https://www.github.com/vnpy/vnpy_sqlite)）：轻量级单文件数据库，无需安装和配置数据服务程序，VeighNa的默认选项，适合入门新手用户

        * :arrow_up: MySQL（[mysql](https://www.github.com/vnpy/vnpy_mysql)）：主流的开源关系型数据库，文档资料极为丰富，且可替换其他NewSQL兼容实现（如TiDB）

        * :arrow_up: PostgreSQL（[postgresql](https://www.github.com/vnpy/vnpy_postgresql)）：特性更为丰富的开源关系型数据库，支持通过扩展插件来新增功能，只推荐熟手使用

    * NoSQL类

        * DolphinDB（[dolphindb](https://www.github.com/vnpy/vnpy_dolphindb)）：一款高性能分布式时序数据库，适用于对速度要求极高的低延时或实时性任务

        * :arrow_up: TDengine（[taos](https://www.github.com/vnpy/vnpy_taos)）：分布式、高性能、支持SQL的时序数据库，带有内建的缓存、流式计算、数据订阅等系统功能，能大幅减少研发和运维的复杂度

        * :arrow_up: MongoDB（[mongodb](https://www.github.com/vnpy/vnpy_mongodb)）：基于分布式文件储存（bson格式）的文档式数据库，内置的热数据内存缓存提供更快读写速度

7. 对接下述各类数据服务的适配器接口（datafeed）：

    * :arrow_up: 迅投研（[xt](https://www.github.com/vnpy/vnpy_xt)）：股票、期货、期权、基金、债券

    * :arrow_up: 米筐RQData（[rqdata](https://www.github.com/vnpy/vnpy_rqdata)）：股票、期货、期权、基金、债券、黄金TD

    * :arrow_up: MultiCharts（[mcdata](https://www.github.com/vnpy/vnpy_mcdata)）：期货、期货期权

    * :arrow_up: TuShare（[tushare](https://www.github.com/vnpy/vnpy_tushare)）：股票、期货、期权、基金

    * :arrow_up: 万得Wind（[wind](https://www.github.com/vnpy/vnpy_wind)）：股票、期货、基金、债券

    * :arrow_up: 同花顺iFinD（[ifind](https://www.github.com/vnpy/vnpy_ifind)）：股票、期货、基金、债券

    * :arrow_up: 天勤TQSDK（[tqsdk](https://www.github.com/vnpy/vnpy_tqsdk)）：期货

    * :arrow_up: 掘金（[gm](https://www.github.com/vnpy/vnpy_gm)）：股票

    * :arrow_up: polygon（[polygon](https://www.github.com/vnpy/vnpy_polygon)）：股票、期货、期权

8. :arrow_up: 跨进程通讯标准组件（rpc），用于实现分布式部署的复杂交易系统。

9. :arrow_up: Python高性能K线图表（chart），支持大数据量图表显示以及实时数据更新功能。

10. [社区论坛](http://www.vnpy.com/forum)和[知乎专栏](http://zhuanlan.zhihu.com/vn-py)，内容包括VeighNa项目的开发教程和Python在量化交易领域的应用研究等内容。

11. 官方交流群262656087（QQ），管理严格（定期清除长期潜水的成员），入群费将捐赠给VeighNa社区基金。

注：以上关于功能特点的说明为根据说明文档发布时情况罗列，后续可能存在更新或调整。若功能描述同实际存在出入，欢迎通过Issue联系进行调整。

---

## 新手入门指南

本节面向初次接触 VeighNa 的用户，从零开始完整演示如何搭建环境、连接仿真账户并运行第一个自动交易策略。

### 第一步：选择安装方式

**方式一（推荐）：VeighNa Studio 一键安装**

下载专为量化交易打造的 Python 发行版，内置 VeighNa 框架及 VeighNa Station 管理平台，无需手动配置：

[下载 VeighNa Studio-4.3.0（Windows）](https://download.vnpy.com/veighna_studio-4.3.0.exe)

**方式二：源码安装（适合开发者）**

```bash
# 1. 克隆仓库
git clone https://github.com/vnpy/vnpy.git
cd vnpy

# 2. 安装核心框架
pip install .

# 3. 安装常用应用模块
pip install vnpy_ctp vnpy_ctastrategy vnpy_ctabacktester vnpy_sqlite
```

**方式三：Docker 容器（适合服务器/Linux环境）**

```bash
# 拉取官方镜像（约851MB，含完整Python 3.13环境）
docker pull veighna/veighna:4.3.0

# 启动（带图形界面）
docker run -it \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v $(pwd)/vntrader:/root/.vntrader \
  veighna/veighna:4.3.0 python3 -m veighna_station
```

### 第二步：注册 SimNow 仿真账户（期货新手必备）

SimNow 是上期技术提供的**免费期货仿真交易平台**，无需真实资金即可测试策略：

1. 访问 [SimNow 官网](https://www.simnow.com.cn/) 注册账号
2. 登录后进入【产品与服务】页面，记录以下信息：
   - **投资者代码**（即用户名，在个人中心查看）
   - **经纪商代码（BrokerID）**：通常为 `9999`
   - **交易服务器地址（Trade Front）**：如 `tcp://180.168.146.187:10201`
   - **行情服务器地址（Market Front）**：如 `tcp://180.168.146.187:10211`
3. 在 VeighNa Trader 界面点击【系统 → 连接CTP】，填入上述信息即可登录

> SimNow 仿真账户与实盘账户完全隔离，推荐新手在此平台充分测试策略后再考虑实盘。

### 第三步：启动 VeighNa Trader

**通过 VeighNa Station（GUI方式）**

1. 启动 VeighNa Station（安装后桌面自动创建快捷方式）
2. 使用 VeighNa 社区论坛账号登录（[注册地址](https://www.vnpy.com/forum/)）
3. 点击底部的 **VeighNa Trader** 按钮启动交易终端

> 注意：VeighNa Trader 运行期间请勿关闭 VeighNa Station。

**通过脚本启动（代码方式）**

在任意目录创建 `run.py` 文件：

```python
from vnpy.event import EventEngine
from vnpy.trader.engine import MainEngine
from vnpy.trader.ui import MainWindow, create_qapp

from vnpy_ctp import CtpGateway
from vnpy_ctastrategy import CtaStrategyApp
from vnpy_ctabacktester import CtaBacktesterApp


def main():
    """启动 VeighNa Trader"""
    qapp = create_qapp()

    event_engine = EventEngine()
    main_engine = MainEngine(event_engine)

    # 注册交易接口
    main_engine.add_gateway(CtpGateway)

    # 注册策略应用
    main_engine.add_app(CtaStrategyApp)
    main_engine.add_app(CtaBacktesterApp)

    main_window = MainWindow(main_engine, event_engine)
    main_window.showMaximized()

    qapp.exec()


if __name__ == "__main__":
    main()
```

在该目录打开命令行后运行：

```bash
python run.py
```

### 第四步：基础配置

**配置文件位置**

所有用户配置保存在以下位置（优先读取当前目录，否则读取用户主目录）：

```
Windows:  C:\Users\<用户名>\.vntrader\vt_setting.json
Linux/Mac: ~/.vntrader/vt_setting.json
```

**vt_setting.json 常用配置项说明**

```json
{
    "font.family": "Arial",
    "font.size": 12,

    "log.active": true,
    "log.level": 50,
    "log.console": true,
    "log.file": true,

    "email.server": "smtp.qq.com",
    "email.port": 465,
    "email.username": "your_email@qq.com",
    "email.password": "your_smtp_password",
    "email.sender": "your_email@qq.com",
    "email.receiver": "your_email@qq.com",

    "database.timezone": "Asia/Shanghai",
    "database.name": "sqlite",
    "database.database": "database.db",

    "datafeed.name": "",
    "datafeed.username": "",
    "datafeed.password": ""
}
```

**日志级别说明**

| 数值 | 级别 | 说明 |
|------|------|------|
| 10 | DEBUG | 调试信息（开发时使用） |
| 20 | INFO | 一般运行信息 |
| 30 | WARNING | 警告信息 |
| 40 | ERROR | 错误信息 |
| 50 | CRITICAL | 严重错误（默认） |

日志文件保存在 `~/.vntrader/log/vt_YYYYMMDD.log`，按天滚动。

**切换数据库（可选）**

```json
{
    "database.name": "mysql",
    "database.host": "localhost",
    "database.port": 3306,
    "database.database": "vnpy",
    "database.username": "root",
    "database.password": "password"
}
```

需要先安装对应驱动包：`pip install vnpy_mysql`

### 第五步：运行第一个策略（CTA 回测）

1. 在 VeighNa Trader 界面点击顶部菜单【应用 → CTA回测】
2. 在策略下拉列表中选择内置示例策略（如 `AtrRsiStrategy`）
3. 配置回测参数：
   - **合约代码**：`rb2401.SHFE`（螺纹钢期货，示例）
   - **时间周期**：`1m`（1分钟线）
   - **起止日期**：选择有数据的时间范围
4. 点击【开始回测】按钮
5. 回测完成后点击【显示图表】查看净值曲线、回撤统计等绩效指标

> 首次回测需要先有历史数据。可通过【应用 → 数据管理】导入 CSV 格式历史数据，或配置数据服务（如 RQData/迅投研）自动下载。

### 第六步：策略实盘运行

完成策略回测验证后，切换到实盘运行：

1. 确认已连接交易接口（【系统 → 连接CTP】）
2. 点击【应用 → CTA策略】打开策略管理界面
3. 点击【添加策略】，选择策略类和目标合约
4. 配置策略参数后点击【初始化】
5. 初始化完成后点击【启动】，策略开始自动运行

---

## 环境准备

* 推荐使用VeighNa团队为量化交易专门打造的Python发行版[VeighNa Studio-4.3.0](https://download.vnpy.com/veighna_studio-4.3.0.exe)，集成内置了VeighNa框架以及VeighNa Station量化管理平台，无需手动安装
* 支持的系统版本：Windows 11以上 / Windows Server 2022以上 / Ubuntu 22.04 LTS以上
* 支持的Python版本：Python 3.10以上（64位），**推荐使用Python 3.13**

## 安装步骤

在[这里](https://github.com/vnpy/vnpy/releases)下载Release发布版本，解压后运行以下命令安装：

**Windows**

```
install.bat
```

**Ubuntu**

```bash
# 方式一：安装脚本
bash install.sh

# 方式二：手动安装（推荐，更可控）
# 安装系统依赖
sudo apt-get install build-essential

# 安装 TA-Lib C 库
wget http://prdownloads.sourceforge.net/ta-lib/ta-lib-0.4.0-src.tar.gz
tar -zxvf ta-lib-0.4.0-src.tar.gz
cd ta-lib/ && ./configure --prefix=/usr && make && sudo make install
cd ..

# 安装 Python 依赖
pip install .
pip install vnpy_ctp vnpy_ctastrategy vnpy_ctabacktester vnpy_sqlite
```

**Macos**

```
bash install_osx.sh
```

## 使用指南

1. 在[SimNow](http://www.simnow.com.cn/)注册CTP仿真账号，并在[该页面](http://www.simnow.com.cn/product.action)获取经纪商代码以及交易行情服务器地址。

2. 在[VeighNa社区论坛](https://www.vnpy.com/forum/)注册获得VeighNa Station账号密码（论坛账号密码即是）

3. 启动VeighNa Station（安装VeighNa Studio后会在桌面自动创建快捷方式），输入上一步的账号密码登录

4. 点击底部的**VeighNa Trader**按钮，开始你的交易！！！

注意：

* 在VeighNa Trader的运行过程中请勿关闭VeighNa Station（会自动退出）

## 脚本运行

除了基于VeighNa Station的图形化启动方式外，也可以在任意目录下创建run.py，写入以下示例代码：

```Python
from vnpy.event import EventEngine
from vnpy.trader.engine import MainEngine
from vnpy.trader.ui import MainWindow, create_qapp

from vnpy_ctp import CtpGateway
from vnpy_ctastrategy import CtaStrategyApp
from vnpy_ctabacktester import CtaBacktesterApp


def main():
    """Start VeighNa Trader"""
    qapp = create_qapp()

    event_engine = EventEngine()
    main_engine = MainEngine(event_engine)
    
    main_engine.add_gateway(CtpGateway)
    main_engine.add_app(CtaStrategyApp)
    main_engine.add_app(CtaBacktesterApp)

    main_window = MainWindow(main_engine, event_engine)
    main_window.showMaximized()

    qapp.exec()


if __name__ == "__main__":
    main()
```

在该目录下打开CMD（按住Shift->点击鼠标右键->在此处打开命令窗口/PowerShell）后运行下列命令启动VeighNa Trader：

```
python run.py
```

## 无 UI 服务器部署（生产实盘）

适合在无图形界面的 Linux 服务器上运行，采用守护进程模式自动管理交易时段：

```python
# run_server.py — 生产环境守护进程示例
import multiprocessing
import sys
from time import sleep
from datetime import datetime, time

from vnpy.event import EventEngine
from vnpy.trader.setting import SETTINGS
from vnpy.trader.engine import MainEngine
from vnpy.trader.logger import INFO

from vnpy_ctp import CtpGateway
from vnpy_ctastrategy import CtaStrategyApp

SETTINGS["log.active"] = True
SETTINGS["log.level"] = INFO
SETTINGS["log.console"] = True
SETTINGS["log.file"] = True

# 填写真实账户信息
CTP_SETTING = {
    "用户名": "your_account",
    "密码": "your_password",
    "经纪商代码": "9999",
    "交易服务器": "tcp://180.168.146.187:10201",
    "行情服务器": "tcp://180.168.146.187:10211",
    "产品名称": "simnow_client_test",
    "授权编码": "0000000000000000",
}

DAY_START = time(8, 45)
DAY_END = time(15, 0)
NIGHT_START = time(20, 45)
NIGHT_END = time(2, 45)


def check_trading_period() -> bool:
    current_time = datetime.now().time()
    return (
        (current_time >= DAY_START and current_time <= DAY_END)
        or (current_time >= NIGHT_START)
        or (current_time <= NIGHT_END)
    )


def run_child():
    """交易子进程"""
    event_engine = EventEngine()
    main_engine = MainEngine(event_engine)
    main_engine.add_gateway(CtpGateway)
    cta_engine = main_engine.add_app(CtaStrategyApp)

    main_engine.connect(CTP_SETTING, "CTP")
    sleep(10)

    cta_engine.init_engine()
    cta_engine.init_all_strategies()
    sleep(60)
    cta_engine.start_all_strategies()

    while True:
        sleep(10)
        if not check_trading_period():
            main_engine.close()
            sys.exit(0)


def run_parent():
    """守护父进程"""
    child_process = None
    while True:
        trading = check_trading_period()
        if trading and child_process is None:
            child_process = multiprocessing.Process(target=run_child)
            child_process.start()
        if not trading and child_process is not None:
            if not child_process.is_alive():
                child_process = None
        sleep(5)


if __name__ == "__main__":
    run_parent()
```

运行命令：

```bash
# 后台运行（nohup 方式）
nohup python run_server.py > output.log 2>&1 &

# 或使用 systemd 服务管理（推荐生产环境）
# 创建 /etc/systemd/system/vnpy.service 后执行
systemctl start vnpy
```

## 常见问题

**Q：安装 ta-lib 报错怎么办？**

Windows 用户可直接安装预编译版本：

```bash
pip install TA-Lib
```

如果失败，访问 [Unofficial Windows Binaries](https://www.lfd.uci.edu/~gohlke/pythonlibs/#ta-lib) 下载对应版本的 `.whl` 文件后手动安装：

```bash
pip install TA_Lib-0.4.x-cpXX-cpXX-win_amd64.whl
```

**Q：启动时提示找不到模块 `vnpy_ctastrategy`？**

需要单独安装应用模块包：

```bash
pip install vnpy_ctastrategy vnpy_ctabacktester vnpy_ctp vnpy_sqlite
```

**Q：如何查看策略运行日志？**

日志文件位于：
- Windows: `C:\Users\<用户名>\.vntrader\log\vt_YYYYMMDD.log`
- Linux/Mac: `~/.vntrader/log/vt_YYYYMMDD.log`

也可在 VeighNa Trader 界面底部的【日志】面板实时查看。

**Q：Ubuntu 下无 GUI 界面如何使用？**

参见上方【无 UI 服务器部署】章节，使用无头模式脚本。如需在 WSL 中使用图形界面，可安装 [X410](https://x410.dev/)（Windows 10）或使用 WSLg（Windows 11）。

**Q：如何切换策略参数？**

在 VeighNa Trader 的 CTA 策略界面，停止策略后双击策略名称，在弹出的参数编辑界面修改参数值，保存后重新初始化和启动。

---

## 贡献代码

VeighNa使用Github托管其源代码，如果希望贡献代码请使用github的PR（Pull Request）的流程:

1. [创建 Issue](https://github.com/vnpy/vnpy/issues/new) - 对于较大的改动（如新功能，大型重构等）建议先开issue讨论一下，较小的improvement（如文档改进，bugfix等）直接发PR即可

2. Fork [VeighNa](https://github.com/vnpy/vnpy) - 点击右上角**Fork**按钮

3. Clone你自己的fork: ```git clone https://github.com/$userid/vnpy.git```
	* 如果你的fork已经过时，需要手动sync：[同步方法](https://help.github.com/articles/syncing-a-fork/)

4. 从**dev**创建你自己的feature branch: ```git checkout -b $my_feature_branch dev```

5. 在$my_feature_branch上修改并将修改push到你的fork上

6. 创建从你的fork的$my_feature_branch分支到主项目的**dev**分支的[Pull Request] -  [在此](https://github.com/vnpy/vnpy/compare?expand=1)点击**compare across forks**，选择需要的fork和branch创建PR

7. 等待review, 需要继续改进，或者被Merge!

在提交代码的时候，请遵守以下规则，以提高代码质量：

  * 使用[ruff](https://github.com/astral-sh/ruff)检查你的代码样式，确保没有error和warning。在项目根目录下运行```ruff check .```即可。
  * 使用[mypy](https://github.com/python/mypy)进行静态类型检查，确保类型注解正确。在项目根目录下运行```mypy vnpy```即可。

## 其他内容

* [获取帮助](https://github.com/vnpy/vnpy/blob/dev/.github/SUPPORT.md)
* [社区行为准则](https://github.com/vnpy/vnpy/blob/dev/.github/CODE_OF_CONDUCT.md)
* [Issue模板](https://github.com/vnpy/vnpy/blob/dev/.github/ISSUE_TEMPLATE.md)
* [PR模板](https://github.com/vnpy/vnpy/blob/dev/.github/PULL_REQUEST_TEMPLATE.md)
* [技术方案文档](./技术方案文档.md)：深入了解 VeighNa 的架构设计与量化交易技术原理

## 版权说明

MIT
