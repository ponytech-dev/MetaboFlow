# 前端多页架构设计

> 确认日期：2026-03-21
> 状态：已确认

## 概述

多页设计，为多引擎混搭和多 pipeline 并行预留完整架构空间。Phase 1 每个环节只有 1 个引擎可选，但 UI 结构完整，Phase 2 新引擎直接出现在 dropdown 中。

## 页面结构

```
/projects                    → 项目列表（用户所有分析）
/projects/:id                → 项目概览（样本、状态）
/projects/:id/upload         → 数据上传
/projects/:id/pipeline       → Pipeline 设计器（核心页）
/projects/:id/monitor        → 实时运行监控
/projects/:id/results        → 结果展示（图表画廊+表格+下载）
/projects/:id/report         → 报告生成与导出
```

## Pipeline 设计器（核心页）

每个分析环节：
- Dropdown 选择引擎（Phase 1 各环节仅 1 个选项，Phase 2+ 扩展）
- 每个引擎独立参数面板
- 可创建多条 pipeline 组合（Pipeline A, B, C...）
- "Run All" 同时启动所有 pipeline

```
┌─ Pipeline A ──────────────────────────────────┐
│ ①峰检测: [XCMS ▼]  ②去冗余: [CAMERA ▼]       │
│   ├─ method: centWave     ├─ ppm: 10          │
│   ├─ ppm: 15              └─ ...              │
│   └─ snthresh: 10                             │
│ ③统计: [limma ▼]   ④注释: [matchms ▼]         │
│ ⑤通路: [ReactomePA ▼]                         │
└───────────────────────────────────────────────┘
          [+ Add Pipeline B]   [Run All]
```

## 实时运行监控

- 多条 pipeline 并列显示进度
- SSE 推送实时状态
- 每个环节独立进度条 + 耗时

## 结果展示页

6 个 Tab：

| Tab | 内容 | 数据来源 |
|-----|------|---------|
| Overview | 分析摘要卡片（样本数、feature 数、compound 数、引擎版本、耗时）+ 参数快照 | MetaboData.uns |
| Charts | 图表画廊——网格展示 SVG 缩略图，点击放大，支持下载 SVG/PDF/PNG | chart-service |
| Features | 可排序/可搜索 feature 表（m/z, RT, FC, p-value, adj. p-value） | MetaboData 统计层 |
| Annotation | 注释结果表（compound name, SMILES, match score, MSI level, 来源库） | annot-worker |
| Pathway | 通路富集结果 + 气泡图 | pathway_ora.R |
报告功能全部在独立的 `/projects/:id/report` 页面，不在 Results Tab 中重复。

## Features 筛选联动（B 方案）

Features Tab 的 p-value / fold change 筛选影响一组"筛选敏感"图表，自动用筛选后的子集重新渲染。具体哪些模板标为"筛选敏感"由模板调研 Agent 完成后确定。

全局图（QC / 降维 / 概览类）不受筛选影响。

## Charts Tab 交互

- "一键出图"：用户勾选图表类型 → Generate → 后端调 R 模板批量渲染 → SSE 推送进度 → 完成后刷新画廊
- 单张下载（SVG/PDF/PNG）或打包下载（ZIP）

## 多 Pipeline 结果展示

Phase 1 实际只有单 pipeline（每环节 1 个引擎），结果展示基于单 pipeline 的 5 Tab 结构。Phase 2 引入多引擎后，增加 pipeline 切换器和 Venn 对比视图，具体设计在 Phase 2 规划中定义。

## 架构预留（多引擎）

- 所有引擎调用通过 EngineAdapter 接口
- Pipeline 设计器的引擎 dropdown 数据源来自后端 `/engines` API
- Phase 1 该 API 返回每个环节 1 个引擎，Phase 2 返回多个
- 多引擎对比结果在 Phase 2 通过 Venn 图 + 共识特征提取展示
