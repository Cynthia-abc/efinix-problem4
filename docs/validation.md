# 版本与验证范围

## 发布基线

仓库以 `analysis_build_20261027` 的2026-10-29模式4矩形修复版为基线，保留五模式功能、模式3全画面多候选分析与上位机框数控制。代码整理只清理用户RTL中的普通说明注释，保留必要工具指令、版权和许可声明；厂商IP及其加密内容原样保留。

`reports/build_20261029/release.json` 是原构建时的版本摘要，其中路径属于原构建目录；仓库中的下载文件位于 `bitstreams/`。`reports/submission_manifest.json` 描述本次整理后的文件和哈希。

## 已有构建证据

- Efinity 2026.1完成综合、接口生成、布局布线及bit导出。
- LUT4为12,839，FF为10,736，RAM10为238，DSP48/DSP24为4/1。
- 像素域setup/hold裕量分别为+1.562/+0.026 ns；全报告最小值为+0.298/+0.019 ns。
- 原发布bit哈希已与仓库下载文件逐字节核对。

视频主链已开展实板演示。原2026-10-29发布摘要将该次矩形修复bit的实板复验状态记录为 `PENDING`；本次仓库整理不改变这项历史记录，也不将仿真视为实板测试。

## 当前整理后的回归

在仓库根目录执行 `python scripts/run_submission_checks.py`，检查当前打包源码：

1. `sim/verify_multi_reference.py`：用独立Python八连通flood-fill和Moore外边界遍历，对照RTL的边缘数、包围盒、比值、轮廓步数与状态；59组图、131条记录。
2. `sim/check_shape_rectfix.py`：11组细边缘用例，覆盖矩形行位置变化、正方形、断边、轻微倾斜、圆形及空图。
3. `sim/check_shape_rectfix.py --fullhd`：4组1920×1080生产参数用例，覆盖矩形、倾斜矩形、圆形及ROI外干扰。
4. `tb_erosion_bounds`：忙时输入隔离、遍历上限、标签溢出及后续恢复。
5. `tb_erosion_overlay`：数值转换、消隐提交和候选清除。

这些用例核对相关模块的功能与打包完整性，整机的摄像头、DDR和HDMI仍以Efinity构建及实板运行为验证手段。`sim`和`simulation`还保留部分早期方案测试，未纳入当前入口的历史测试不代表本版本的验证结论。
