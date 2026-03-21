# MetaboFlow Phase 1 MVP 完整设计

> 确认日期：2026-03-21
> 状态：已确认（4 段设计全部通过用户审批）

## 1. 背景与目标

### 当前状态
- Phase 0 + 0.5 已完成（100%）
- 全栈 10 服务 E2E 验证通过：2 样本，42,216 features → 1,187 compounds → annotation completed（594.7s）
- limma 返回 0 significant features（每组 n=1，统计学必然结果）
- 已有 4 样本测试数据（MTBLS733：SA1/SA2 vs SB1/SB2）

### Phase 1 目标
- 内测可用，面向 5-10 个外部实验室
- 完整分析流程：上传 → 配置 → 运行 → 结果展示 → 报告导出
- 50 种发表级图表模板，一键出图
- 架构为多引擎混搭预留完整扩展口

### 前置验证
- 用 4 样本（每组 n=2）跑完整 E2E，验证 limma 返回 significant features
- 这是后续图表和报告的数据基础，必须先完成

---

## 2. 图表模板系统

> 详细设计：`2026-03-21-chart-template-system-design.md`

### 规模与来源
- 50 种模板：20 基础（高频必做）+ 30 高级（多变量复合）
- 调研来源：Nature/Science 正刊+子刊 2020-2026 代谢组学/非靶向分析论文
- 20 基础：出现频率高，是该领域必须做的分析和数据解读
- 30 高级：同一图中整合多种变量，从多角度分析一套数据
- 排除雷达图

### 渲染引擎
- R 端渲染：ggplot2 + ComplexHeatmap + EnhancedVolcano + patchwork
- 输出格式：SVG（前端预览）+ PDF（发表级）+ PNG（300 dpi 报告嵌入）
- 统一配色：scienceplots Nature 风格，色盲友好，禁止单模板自定义颜色

### 数据源分类
每个模板标注数据源类别：

| 类别 | 含义 |
|------|------|
| A | MetaboData HDF5 中已有数据，直接可用 |
| B | 需要 pipeline 新增输出 |
| C | 需要从原始 mzML 提取谱图 |
| D | 需要外部 API/库 |

每个模板还需标注：是否响应 feature 筛选（筛选敏感性），具体由模板调研完成后确定。

### 技术架构
```
chart-templates/
  ├── _theme/                    # 统一配色系统
  │   ├── metaboflow_theme.R
  │   └── color_palettes.R
  ├── basic/                     # 20 种基础模板
  ├── advanced/                  # 30 种高级模板
  ├── interpretations/           # 中英文解读（每种图 2 个 .md）
  └── registry.json              # 模板注册表
```

### 模板标准接口
- 输入：MetaboData HDF5 路径 + 参数 JSON
- 输出：SVG + PDF + PNG
- 共享 `metaboflow_theme.R`

### 多 Agent 调研分工

| Agent | 职责 |
|-------|------|
| 调研 Agent | 从 Nature/Science 2020-2026 论文筛选 50 种图表 |
| 数据需求分析 Agent | 逐模板 A/B/C/D 分类 + pipeline 缺口清单 + 筛选敏感性标注 |
| PonylabASMS 参考 Agent | 对齐现有模板，适配代谢组学场景 |
| 配色系统 Agent | 设计统一 Nature 风格配色 + 主题 |

---

## 3. 前端多页架构

> 详细设计：`2026-03-21-frontend-multipage-architecture-design.md`

### 页面结构
```
/login                       → 登录
/register                    → 注册（需邀请码）
/projects                    → 项目列表
/projects/:id                → 项目概览
/projects/:id/upload         → 数据上传
/projects/:id/pipeline       → Pipeline 设计器（核心页）
/projects/:id/monitor        → 实时运行监控
/projects/:id/results        → 结果展示
/projects/:id/report         → 报告生成与导出
```

### Pipeline 设计器
- 每个分析环节 dropdown 选择引擎
- 每个引擎独立参数面板
- 可创建多条 pipeline 组合，"Run All" 同时启动
- Phase 1 每环节仅 1 个引擎选项，Phase 2 扩展

### 结果展示页（6 Tab）

| Tab | 内容 |
|-----|------|
| Overview | 分析摘要卡片 + 参数快照 |
| Charts | 图表画廊（SVG 缩略图，点击放大，下载 SVG/PDF/PNG，打包 ZIP） |
| Features | 可排序/搜索 feature 表，筛选联动"筛选敏感"图表 |
| Annotation | 注释结果表 |
| Pathway | 通路富集结果 + 气泡图 |


报告功能在独立 `/projects/:id/report` 页面，不在 Results Tab 中重复。Phase 1 单 pipeline，多 pipeline 结果切换在 Phase 2 设计。

### 架构预留
- 引擎列表来自后端 `/engines` API
- EngineAdapter 统一接口
- Phase 2 新引擎加入后自动出现在 dropdown

---

## 4. 报告导出系统

> 详细设计：`2026-03-21-report-export-system-design.md`

### 双格式
- PDF：Quarto 渲染，正式报告
- Word：officer R 包，可编辑，方便复制 Methods 段落

### 报告结构
1. Analysis Summary
2. Quality Control
3. Feature Detection
4. Statistical Analysis
5. Annotation
6. Pathway Enrichment
7. Methods（自动生成）
8. Appendix（参数表 + 版本表）

### 自动 Methods 段落
- 根据引擎选择和参数自动拼装
- YAML 模板配置，参数值填入占位符
- 输出可直接复制到论文

### 图表嵌入
- 复用图表模板系统输出（300 dpi PNG），不重新渲染
- 用户可选择哪些图表放入报告

---

## 5. 用户认证系统

> 详细设计：`2026-03-21-user-auth-system-design.md`

### 方案
- 邮箱 + 密码注册，需邀请码
- JWT（access 30min + refresh 7d）
- bcrypt 密码 hash
- FastAPI + python-jose + passlib

### 数据隔离
- analysis 记录 `user_id` 外键
- API 查询自动加 `WHERE user_id = current_user`
- 文件路径：`/data/{uploads|results}/{user_id}/{analysis_id}/`

### 邀请码
- 管理员 API/CLI 生成，单次使用
- Phase 1 不做自助注册

---

## 6. 执行计划概览

### 四条并行线

| 线 | 内容 | 依赖 |
|----|------|------|
| 线 0 | 4 样本 E2E 验证（limma significant features） | 无，最先做 |
| 线 1 | 图表模板调研+实现（50 种，4 Agent 并行） | 调研阶段无依赖可并行，模板调试需线 0 真实数据 |
| 线 2 | 前端多页架构 + 结果展示 + 报告导出 | 线 0 + 线 1 |
| 线 3 | 用户认证 | 无，独立并行 |

### 设计文档索引

| 文件 | 内容 |
|------|------|
| `2026-03-21-chart-template-system-design.md` | 图表模板系统 |
| `2026-03-21-frontend-multipage-architecture-design.md` | 前端多页架构 |
| `2026-03-21-report-export-system-design.md` | 报告导出系统 |
| `2026-03-21-user-auth-system-design.md` | 用户认证系统 |
| `2026-03-21-phase1-mvp-complete-design.md` | 本文档（总览） |
