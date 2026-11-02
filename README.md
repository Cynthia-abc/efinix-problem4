# 地脉慧眼实时边缘分析系统

基于国产 Efinix Titanium Ti60F225 FPGA 的高清视频边缘处理与多目标几何分析系统，面向黑土地侵蚀沟图像的候选区域筛查、辅助判读和像素域形态特征记录。

本仓库由项目初期的 Sobel 工程更新而来，保留原有 Git 提交历史，现提供五模式扩展版本的 RTL、时序与管脚约束、厂商 IP、Python 上位机、仿真测试、构建报告及可下载 bit 文件。

## 处理链路

```text
SC2210 摄像头 → MIPI CSI 接收 → DDR3 帧缓存 → RGB 恢复 → 灰度
    → 高斯平滑 → Sobel 梯度 → 非极大值抑制 → 双阈值 → 有界滞后连接
        ├─ 全画面 4×4 汇聚 → 行游程八连通 CCL → Top3 候选 → 共享轮廓/几何分析
        └─ 中心 800×600 ROI → 16×16 汇聚 → 圆形/矩形轻量规则识别
    → HDMI 显示与结果叠加
```

模式3记录各 4×4 网格中的原图边缘像素数量，以行游程八连通标记提取分量，按边缘数量排序选出最多三个候选，再复用轮廓分析器输出几何特征。视频连续输出，分析器忙时跳过整帧；几何统计的更新率与 HDMI 视频刷新率分别计算。

## 平台与指标

| 项目 | 配置或报告结果 |
| --- | --- |
| FPGA | Efinix Titanium Ti60F225，C4 时序模型 |
| 开发环境 | Efinity 2026.1.132，Verilog / SystemVerilog |
| 摄像头输入 | SC2210，1920×1080，RAW8，MIPI 四通道 |
| HDMI | 1920×1080，1080p60 时序；行/帧总计数 2200×1125 |
| 像素域约束 | `clk_pixel_2x`，约 148.810 MHz |
| Canny 吞吐 | 流水线与窗口就绪后，一拍一个像素 |
| 模式3 | 480×270 分析网格，最多三个连通候选 |
| 模式4 | 中心 ROI：x=560～1359、y=240～839；BLOCK=16 |
| 串口 | 115200，8N1 |
| LUT4 / FF | 12,839 / 10,736 |
| RAM10 | 238 / 256 |
| DSP48 / DSP24 | 4 / 1 |
| 像素域 setup / hold 裕量 | +1.562 ns / +0.026 ns |
| 全报告最小 setup / hold 裕量 | +0.298 ns / +0.019 ns |

资源与时序数字对应 2026-10-29 矩形修复版，原报告见 [reports/build_20261029](reports/build_20261029)。1080p60 描述显示时序，摄像头实测采样率与几何分析更新率须分别测量。

## 五种显示模式与交互

| 模式 | 内容 | UART 命令 |
| --- | --- | --- |
| 0 | 彩色原图 | ASCII `0` |
| 1 | 左灰度、右黑底白色 Canny 边缘 | ASCII `1` |
| 2 | 彩色原图叠加红色 Canny 边缘 | ASCII `2` |
| 3 | 多候选框与几何统计 | ASCII `3` |
| 4 | 中心引导框内圆形 / 矩形 / UNKNOWN | ASCII `4` |

模式3可用上位机的“显示 1/2/3 个”按钮发送 ASCII `A/B/C`，选择显示框数量。分析器仍保存最多三个候选，编号随当前排名变化。FPGA 在视频消隐期间应用模式和框数量设置，并回传相同字符确认。

K1 / K2 短按分别增加 / 减少 Canny 高阈值，步长8，默认64，范围0～248；低阈值按高阈值的3/8联动。双键用于冻结/恢复，长按用于历史帧回看，具体行为见 [操作说明](docs/operation.md)。

### 模式3屏幕字段

| 字段 | 含义 |
| --- | --- |
| `E` | 候选分量包含的原图 Canny 边缘像素数 |
| `W` / `H` | 源图坐标中的包围盒宽、高，以4像素网格边界为精度 |
| `R` | `max(W,H)/min(W,H)`；内部为比值×1000，屏幕显示三位小数 |
| `S` | 480×270 网格上 Moore 外边界遍历的移动步数 |
| `OK` / `ISO` / `LIM` | 遍历完成 / 孤立网格点 / 达到遍历步数上限 |
| `CAND` | 连通边缘候选区域 |

这些是像素域几何特征。合成侵蚀沟样图用于演示候选提取与统计；系统当前没有侵蚀沟语义分类器、地面尺度标定或持续目标跟踪。Canny 使用适合流式处理的有界滞后连接，长弱边缘链的连接效果与整帧多轮全局算法有差异。

## 文件目录

```text
Ti60_Demo.xml           Efinity 工程入口
Ti60_Demo.peri.xml      管脚、PLL、DDR 等接口配置
Ti60_Demo.pt.sdc        时钟与时序约束
example_top.v          顶层 RTL
src/                   视频、Canny、几何分析、交互和早期实验 RTL
ip/                    Efinity 生成的 DDR、CSI、FIFO 等 IP 与配置
pri/                   MIPI 接口封装
host/                  Python UART 上位机
sim/                   当前和历史方案的仿真源文件
scripts/               构建、提交完整性检查与当前回归入口
bitstreams/            对应当前源码的矩形修复版 bit / bit.bin
reports/               已归档构建报告和本次提交检查记录
docs/                  技术文档、工程配图、操作与验证说明
samples/               合成侵蚀沟演示图片
simulation/            项目初期保留的 Sobel 单元测试
```

`src` 保留工程文件引用的早期探索模块，实际处理链以 `example_top.v` 的有效实例为准。`simulation/` 是历史测试目录，当前版本使用下述回归入口。

## 打开与构建

1. 安装 Efinity 2026.1，并准备 Ti60F225 开发板及对应摄像头、DDR3、HDMI 接线。
2. 建议将仓库克隆到不含中文和空格的路径，在 Efinity 中打开根目录 `Ti60_Demo.xml`，确认顶层为 `example_top`。
3. 在图形界面执行完整流程，或在 Windows 终端运行：

```bat
set "EFINITY_HOME=D:\Efinity\2026.1"
scripts\build.cmd
```

构建输出位于 `outflow_release/`。完整源码包括厂商加密 IP，需使用 Efinity 处理整机工程。

已有下载文件为 [Ti60_Demo_ErosionMulti4_RectFix_20261029.bit](bitstreams/Ti60_Demo_ErosionMulti4_RectFix_20261029.bit)。SHA-256：

```text
37565993ea43df1448418ff401473e4bd5107284ea484aa28c4168c73b367fcb
```

### 上位机

安装带 Tkinter 的 Python 3 后执行：

```bat
python -m pip install -r host\requirements.txt
python host\mode_panel.py
```

也可使用 `host/首次安装依赖.cmd` 安装依赖，再双击根目录 `启动上位机.cmd`。上位机负责 UART 控制，图像显示在 HDMI 屏幕上。

### 仿真与检查

将 Icarus Verilog 的 `iverilog`、`vvp` 加入 PATH，在仓库根目录运行：

```bat
python scripts\verify_submission.py
python scripts\run_submission_checks.py
```

当前回归包含模式3独立参考模型对照、模式4细边缘与1080p场景、显示统计提交及异常边界测试。验证范围和结果见 [验证说明](docs/validation.md)。

## 工程资料

- [技术文档 PDF](docs/技术文档.pdf)
- [工程六图总览](docs/figures/六图总览.png)
- [可编辑 draw.io 工程图](docs/figures/工程六图_可编辑.drawio)
- [模式4矩形修复记录](docs/mode4_rectangle_fix.md)
- [操作说明](docs/operation.md)
- [构建与验证记录](docs/validation.md)

样图为合成演示素材。厂商及第三方文件保留原版权、许可声明和工具指令；其使用条件以文件内原声明为准。
