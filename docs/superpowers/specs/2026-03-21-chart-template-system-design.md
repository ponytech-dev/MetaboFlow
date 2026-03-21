# 图表模板系统设计

> 确认日期：2026-03-21
> 状态：已确认

## 概述

50 种图表模板（20 基础 + 30 高级），R 端渲染，达到 Nature/Science 发表级质量。每种图表附中英文解读说明。排除雷达图。

## 调研范围

- 来源：Nature/Science 正刊 + 子刊，2020-2026 年代谢组学 / 非靶向分析论文
- 20 种基础模板：高频出现，说明是该领域必须做的分析和数据解读
- 30 种高级模板：多变量复合图，从多角度分析一套数据

## 模板分类

### 20 种基础模板（高频必做分析）

按代谢组学分析流程分为 5 类：

| 类别 | 典型图表 | 数据来源 |
|------|---------|---------|
| QC & 数据概览 | TIC 叠加图、BPC 对比、缺失值热图、CV 分布图 | MetaboData 原始层 |
| 降维与分组 | PCA score plot、PCA loading、PLS-DA、OPLS-DA S-plot | MetaboData 统计层 |
| 差异分析 | 火山图、MA plot、差异代谢物柱状图、Fold change 分布 | limma/stats 输出 |
| 聚类与模式 | 层次聚类热图、相关性热图、趋势聚类（mfuzz） | MetaboData 矩阵 |
| 注释与通路 | 通路气泡图、KEGG 通路着色图、注释级别饼图、化学类别分布 | annotation + pathway |

### 30 种高级模板（多变量复合图）

| 类型 | 示例 | 复合维度 |
|------|------|---------|
| 多面板拼合 | 火山图 + 热图 + 通路气泡图三联 | 统计 + 表达 + 功能 |
| 嵌套图 | PCA score plot 内嵌 loading 箭头 + 置信椭圆 + 组别着色 | 降维 + 统计 + 分组 |
| 多组对比矩阵 | 两两比较火山图矩阵（3+ 组） | 多组统计 |
| 网络+热图联合 | 代谢物相关性网络 + 子模块热图 | 网络拓扑 + 表达 |
| 临床关联 | ROC 曲线 + 生物标志物组合 + 决策树 | 统计 + 机器学习 |

具体模板清单由调研 Agent 确定后更新此文档。

## 数据源分类（A/B/C/D）

每个模板按数据来源分类：

| 类别 | 含义 |
|------|------|
| A | MetaboData HDF5 中已有数据，直接可用 |
| B | 需要 pipeline（xcms-worker/stats-worker）新增输出 |
| C | 需要从原始 mzML 提取谱图（EIC/MS2/TIC） |
| D | 需要外部 API/库（KEGG、Reactome、RDKit 等） |

每个模板还需标注：是否响应 feature 筛选（筛选敏感性）。具体标注由数据需求分析 Agent 完成。

## 渲染引擎

- R 端渲染：ggplot2 + ComplexHeatmap + EnhancedVolcano + patchwork
- 前端预览：直接显示 R 生成的 SVG
- 导出格式：SVG（矢量）+ PDF（发表级）+ PNG（300 dpi，报告嵌入）

## 技术架构

```
chart-templates/
  ├── _theme/                    # 统一配色系统
  │   ├── metaboflow_theme.R     # ggplot2 主题
  │   └── color_palettes.R       # 配色方案集
  ├── basic/                     # 20 种基础模板
  │   ├── volcano_plot.R
  │   ├── pca_score.R
  │   └── ...
  ├── advanced/                  # 30 种高级模板
  │   ├── volcano_heatmap_pathway_trio.R
  │   └── ...
  ├── interpretations/           # 中英文解读
  │   ├── volcano_plot_zh.md
  │   ├── volcano_plot_en.md
  │   └── ...
  └── registry.json              # 模板注册表
```

### 模板标准接口

- 输入：MetaboData HDF5 路径 + 参数 JSON
- 输出：SVG + PDF + PNG
- 所有模板共享 `metaboflow_theme.R`，保证配色一致

### registry.json

前端读取此文件获知：
- 可用图表列表
- 每种图表需要的数据字段
- 数据源分类（A/B/C/D）
- 筛选敏感性标记
- 中英文解读文件路径

## 配色系统

- 主色板：scienceplots `nature` 风格为基础
- 分组色：6-8 色离散色板（色盲友好）
- 连续色：蓝-白-红渐变（热图）、viridis（通路）
- 所有模板强制使用统一色板，禁止单个模板自定义颜色
- 例外：含固定语义颜色的图表（如 ROC 曲线灵敏度/特异度、上调/下调红绿色）允许在统一色板基础上增加语义色，但须在 registry.json 中标注 `semantic_colors: true`

## 多 Agent 调研分工

| Agent | 职责 |
|-------|------|
| 调研 Agent | 从 Nature/Science 2020-2026 论文筛选 50 种图表 |
| 数据需求分析 Agent | 逐模板 A/B/C/D 分类 + pipeline 缺口清单 + 筛选敏感性标注 |
| PonylabASMS 参考 Agent | 对齐现有模板，适配代谢组学场景 |
| 配色系统 Agent | 设计统一 Nature 风格配色 + 主题 |

## 参考

- PonylabASMS 图表模板（应用场景不同，需适配）
- 排除雷达图
