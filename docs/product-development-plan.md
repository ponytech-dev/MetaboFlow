# MetaboFlow 产品开发计划书

**版本**: v2.0
**日期**: 2026-03-15
**状态**: 已确认，待执行

---

## 目录

1. [产品概述](#1-产品概述)
2. [产品架构设计](#2-产品架构设计)
3. [引擎集成计划](#3-引擎集成计划)
4. [功能模块详细设计](#4-功能模块详细设计)
5. [用户交互设计](#5-用户交互设计)
6. [开发路线图](#6-开发路线图)
7. [学术发表路线图](#7-学术发表路线图)
8. [质量保证](#8-质量保证)
9. [风险清单与缓解措施](#9-风险清单与缓解措施)
10. [成功指标（KPI）](#10-成功指标kpi)

---

## 1. 产品概述

### 1.1 产品愿景（一句话）

**让任何科研人员不写一行代码，就能用最好的质谱引擎完成代谢组学全流程分析并生成 Nature 级图表。**

### 1.2 产品定位

MetaboFlow 是代谢组学领域的**引擎聚合平台**：

- 不自研任何核心算法引擎（峰检测、统计、注释、谱图库、图表引擎）
- 封装集成现有社区成熟引擎，统一接口，用户自由选择和切换
- 类似 OpenRouter（AI 模型聚合路由器）对 LLM 的聚合，MetaboFlow 对质谱分析引擎做同样的事情
- 提供零代码的 Web SaaS 界面 + 本地桌面应用备选
- 覆盖从原始 mzML/mzXML 数据到 Nature 论文级图表的端到端全流程
- 同时承担**引擎横向评估基准平台**的学术职能，积累多引擎对同一数据集的处理结果

**MetaboFlow 是独立项目，不与 PonyLab / PonylabASMS 混合。**

### 1.3 目标用户画像

#### Persona A：湿实验室独立研究员（核心用户）

- **身份**：博士研究生或青年 PI，主专业是生物化学、医学、生态学等
- **技术背景**：会 Excel，听说过 R 但从未成功安装过，没有 Docker 概念
- **痛点**：
  - 跑完质谱之后，后续分析完全卡住或依赖服务型合同公司
  - MetaboAnalyst 上传数据到国外服务器有顾虑；结果难以复现
  - 出的图"不好看"，需要反复和 ggplot2 熟手同事协商
  - 不知道该用哪个软件，XCMS / MS-DIAL / MZmine 都看过但不知道如何选择
- **使用场景**：一个人在办公室，把质谱文件拖进浏览器，希望下班前得到一套完整分析图表
- **核心诉求**：一键全流程 + 出版级图表 + 数据留在本地

#### Persona B：核心设施/质谱平台服务人员

- **身份**：大学或研究院质谱核心设施的技术负责人，负责给其他实验室提供代谢组学数据分析服务
- **技术背景**：熟悉 MS-DIAL / MZmine 操作，会一点 R，但无生信专业背景
- **痛点**：
  - 每次分析都要手动走一遍，无法批量处理 10 个课题组的项目
  - 不同课题组要求不同（有的要 XCMS，有的要 MS-DIAL），无法统一
  - 出图标准不一致，每次都要手动美化
- **使用场景**：批量处理 20 个项目，每个项目自动生成分析报告，发给对应课题组
- **核心诉求**：批量处理 + 引擎可选 + 自动报告生成 + 可重复性

#### Persona C：发表导向的生信研究员（方法学研究者）

- **身份**：代谢组学生物信息学方向的博士后或研究员，计划发表方法学文章
- **技术背景**：精通 R/Python，了解各引擎原理，但苦于跨引擎比较的工具链搭建成本
- **痛点**：
  - 要对比 XCMS vs MZmine 的峰检测结果，需要自己写大量胶水代码
  - 引擎版本固定和可重复性问题让 benchmark 结果难以让 Reviewer 信服
  - 想做系统性方法学研究，但没有标准化平台
- **使用场景**：用 MetaboFlow 的多引擎并行模式，对 5 个公开数据集运行 4 个引擎，生成对比报告
- **核心诉求**：多引擎并行 + 结果对比可视化 + 完整方法记录 + 可发表的 benchmark 数据

#### Persona D：制药/临床代谢组学研究员（新增）

- **身份**：制药公司 ADME/毒理部门或临床医院转化研究员
- **技术背景**：懂质谱操作，了解 FDA MIST 规范，需要合规数据包
- **痛点**：
  - 靶向代谢物追踪需要符合 FDA MIST 指南的验证文件
  - 多中心临床数据批次效应难以控制，跨实验室一致性差
  - 现有工具输出格式不符合临床报告要求
- **核心诉求**：合规报告生成 + 批次效应标准化 + 多中心数据对齐

### 1.4 核心价值主张

| 价值 | 具体体现 | 对应竞品的差距 |
|------|---------|-------------|
| **零代码全流程** | 点击+拖拽完成从 mzML 到 Nature 图表 | MetaboAnalyst 无法本地部署；商业软件强绑仪器 |
| **引擎自由选择** | 同一数据集可在 XCMS / MZmine / pyOpenMS 之间切换和对比 | 所有现有工具单引擎单路线，无跨引擎对比 |
| **出版级图表** | 自动生成符合 Nature 格式要求的完整图表集，一键 SVG/PDF 导出 | 所有工具图表质量差或需要手动 ggplot2 定制 |
| **本地数据安全** | Web SaaS + 桌面离线双模式，临床数据不必上传外部服务器 | MetaboAnalyst 仅网页版，数据必须上传 |
| **完全可重复** | 每次分析参数快照+引擎版本锁定，结果完全可重现 | 所有现有工具可重复性差（版本漂移、默认参数变化） |
| **引擎评估平台** | 积累多引擎处理同一数据集的结果，为社区提供方法选择依据 | 目前无任何平台做到这点（2022 Metabolomics 综述指出该领域空白） |
| **产业合规支持** | 自动生成 FDA MIST 合规报告、CLIA 友好的 QC 数据包 | 现有工具无合规报告生成能力 |

### 1.5 与竞品的差异化点

| 竞品 | 核心能力 | MetaboFlow 差异 |
|------|---------|----------------|
| **MetaboAnalyst 6.0** | 最接近 E2E 的免费 Web 平台 | MetaboFlow 可本地部署，图表深度可定制，支持多引擎切换 |
| **Compound Discoverer** | 与 Thermo 仪器深度集成 | MetaboFlow 仪器无关，开放格式，跨厂商 |
| **Progenesis QI** | RT 对齐精度高，界面引导 | MetaboFlow 开放接口，支持 XCMS/MZmine 多种算法，不绑定仪器 |
| **MS-DIAL / MZmine** | 专业峰检测工具，社区大 | MetaboFlow 封装这些工具，加零代码界面、统计分析和图表 |
| **Galaxy W4M** | 无需编程的云端工作流 | MetaboFlow 专注代谢组学，UI 现代化，图表出版质量，中文社区支持 |
| **tidyMass** | 面向对象可重复性框架 | MetaboFlow 有 GUI，不要求 R 编程，面向实验室而非生信开发者 |

---

## 2. 产品架构设计

### 2.1 系统架构总览

```
┌─────────────────────────────────────────────────────────────────┐
│                        用户接入层                                │
│  Web SaaS (metaboflow.com)  |  Tauri 桌面应用（本地离线）        │
│  React + Next.js + Tailwind + shadcn/ui                         │
│  主流程：Wizard 向导  |  高级模式：ReactFlow 节点编辑器           │
└──────────────────────────────┬──────────────────────────────────┘
                               │ HTTPS / SSE
┌──────────────────────────────▼──────────────────────────────────┐
│                      API 网关 & 任务调度层                        │
│  FastAPI（Python）— REST API + SSE 进度推送                      │
│  Celery + Redis — 异步任务队列                                   │
│  PostgreSQL — 任务记录、用户数据、分析历史                        │
│  MinIO — 原始文件、中间结果、图表文件对象存储                      │
└─────────┬──────────┬───────────┬────────────┬───────────────────┘
          │          │           │            │
┌─────────▼─┐ ┌──────▼──┐ ┌─────▼──────┐ ┌──▼────────────────────┐
│ 峰检测    │ │ 统计    │ │ 注释       │ │ 图表                  │
│ 引擎层    │ │ 引擎层  │ │ 引擎层     │ │ 引擎层                │
│           │ │         │ │            │ │                       │
│ xcms-     │ │ stats-  │ │ annot-     │ │ chart-r-worker        │
│ worker    │ │ worker  │ │ worker     │ │ (ggplot2+ComplexHeatmap│
│           │ │         │ │            │ │ chart-py-worker       │
│ mzmine-   │ │         │ │ sirius-    │ │ (matplotlib+seaborn)  │
│ worker    │ │         │ │ worker     │ │ chart-js-worker       │
│           │ │         │ │            │ │ (Plotly.js)           │
│ pyopenms- │ │         │ │ matchms-   │ │                       │
│ worker    │ │         │ │ worker     │ │                       │
│ msdial-   │ │         │ │ dreams-    │ │                       │
│ worker    │ │         │ │ worker     │ │                       │
└─────────┬─┘ └────┬────┘ └──────┬─────┘ └────────────┬──────────┘
          │        │             │                     │
┌─────────▼────────▼─────────────▼─────────────────────▼──────────┐
│                      MetaboData 中间格式层                        │
│  .metabodata (HDF5)  |  mzTab-M 输入/输出  |  CSV 兼容          │
└─────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────┐
│                       数据库与谱图库层                            │
│  HMDB（本地 SQLite）  |  MoNA（本地 ~2.4GB）                     │
│  MassBank（本地 clone）  |  Reactome（本地）                      │
│  KEGG（一次性下载缓存）  |  CompoundDb（Bioconductor）             │
│  LipidBlast（本地）  |  GNPS Public Library（本地镜像）           │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 技术栈选型及理由

#### 前端

| 技术 | 选型 | 调研依据 |
|------|------|---------|
| Web 框架 | **React + Next.js（App Router）** | Streamlit/Shiny 不支持拖拽工作流且并发差；Next.js 是 2025 年最成熟 React 框架 |
| 样式 | **Tailwind CSS + shadcn/ui** | shadcn/ui 基于 Radix UI，组件质量高，可定制，无运行时开销 |
| 工作流编辑器 | **ReactFlow（xyflow）** | 仅高级模式使用；代谢组学线性流程主要用 Wizard，ReactFlow 作为可选扩展 |
| 图表（Web 交互） | **Plotly.js** 为主，**ECharts** 处理超大样本量热图 | Plotly 原生支持科学图表类型（volcano plot、PCA、heatmap），有发表质量导出 |
| 状态管理 | **Zustand** | 轻量，适合中等复杂度的 SPA |
| 类型系统 | TypeScript 全链路 | 减少运行时错误，与 shadcn/ui 生态一致 |
| 桌面端 | **Tauri v2** | 安装包 ~2.5 MB vs Electron ~85 MB，内存降低 70%，Tauri 2.0 于 2024 年发布后生态成熟 |

#### 后端

| 技术 | 选型 | 调研依据 |
|------|------|---------|
| API 框架 | **FastAPI（Python）** | 原生支持 async/await 和 SSE；类型提示完整；性能优于 Flask |
| 任务队列 | **Celery + Redis** | Galaxy 已在高并发场景验证；Python 生态无缝集成；Temporal 对本项目属于过度工程 |
| 进度推送 | **SSE（Server-Sent Events）** | 任务进度是单向推送场景，SSE 比 WebSocket 实现更简单；FastAPI 原生支持 |
| 主数据库 | **PostgreSQL** | 任务记录、用户数据、分析历史；关系型结构清晰 |
| 文件存储 | **MinIO** | 自托管 S3 兼容对象存储；本地部署无需公有云；分片上传（tus.io 协议）支持大 mzML 文件 |

#### 引擎层（各引擎独立 Docker 容器）

| 引擎容器 | 基础镜像 | 封装方式 | 调研依据 |
|---------|---------|---------|---------|
| `xcms-worker` | `rocker/bioconductor:3.19` | R Plumber REST API | XCMS 年下载量 82,681 次（2025），生态最成熟 |
| `mzmine-worker` | `eclipse-temurin:17-jre` | MZmine CLI 批处理模式 | Stars 267，CLI 成熟，Nature Protocols 2024 有标准流程 |
| `pyopenms-worker` | `python:3.11-slim` | pyOpenMS Python API | Stars 575，TOPP CLI 设计最适合微服务化 |
| `msdial-worker` | `mono:latest` | MS-DIAL CLI（Wine/Mono） | Stars 350，脂质鉴定能力最强，EAD sn 位置解析 |
| `stats-worker` | `python:3.11-slim` | FastAPI 封装 scipy/scikit-learn/statsmodels | Python 统计栈集成成本极低 |
| `annot-worker` | `python:3.11-slim` | matchms Python API + SIRIUS CLI | matchms Stars 400，API 设计优雅；SIRIUS 学术账号免费 |
| `dreams-worker` | `python:3.11-slim` | DreaMS Python API | Nature Biotechnology 2025，自监督谱图 Transformer |
| `chart-r-worker` | `rocker/r-ver:4.4` | R Plumber API | ggplot2 + ComplexHeatmap（Stars 1,500）是 Nature 热图标配 |
| `chart-py-worker` | `python:3.11-slim` | FastAPI + matplotlib/Plotly Kaleido | 静态图导出 PDF/SVG/EPS |

#### 数据库层

| 数据库/库 | 部署方式 | 调研依据 |
|---------|---------|---------|
| HMDB | 下载 XML，解析为本地 SQLite | 220,945+ 代谢物，完全开放免费 |
| MoNA | 下载 JSON（2.4GB），本地索引 | 2,090,173 条谱图，可完整本地化 |
| MassBank | GitHub clone | 结构化质量最高的开放谱图库 |
| LipidBlast | 下载 MSP，本地索引 | 212,516 条 in-silico 脂质谱图，Fiehn Lab |
| GNPS Public Library | 定期镜像下载 | 700,000+ 谱图，天然产物覆盖好 |
| Reactome | 一次性下载，本地 Neo4j 或 SQLite | 完全开放，无 KEGG 授权问题；ReactomePA Stars 45，2025 年增长 134% |
| KEGG | 一次性下载缓存（sspa/KNeXT） | KEGG 禁止再分发，用户初始化时自动一次性下载；中国大陆访问不稳定须本地化 |

### 2.3 MetaboData 中间格式设计

借鉴单细胞领域 AnnData（GitHub Stars 720，scverse 生态核心）的设计哲学，定义 MetaboFlow 专用中间格式 `MetaboData`：

```python
class MetaboData:
    """
    代谢组学标准中间格式对象
    存储格式：HDF5（.metabodata），兼容 h5py/zarr
    """
    X: np.ndarray          # 特征矩阵（shape: n_samples × n_features）
    obs: pd.DataFrame      # 样本元数据（分组、批次、质控标志、采样时间等）
    var: pd.DataFrame      # 特征元数据（m/z、RT、注释名称、adduct、MSI 置信度、ISF 标志）
    obsm: dict             # 降维结果（"pca": scores, "plsda": scores）
    varm: dict             # 特征载荷（"pca_loadings", "vip_scores"）
    uns: dict              # 非结构化附加信息：
                           #   - 分析参数快照（引擎名称+版本+所有参数）
                           #   - 通路富集结果
                           #   - QC 指标（blank ratio、CV 分布）
                           #   - 处理步骤溯源链（provenance）
                           #   - FDR 控制结果（target-decoy）
                           #   - 孟德尔随机化结果
    layers: dict           # 多个强度矩阵版本：
                           #   - "raw": 原始峰面积
                           #   - "normalized": 归一化后
                           #   - "log2": log2 变换后
                           #   - "imputed": 缺失值填充后
                           #   - "batch_corrected": 批次效应校正后
```

**与现有标准的关系：**
- 可导出为 **mzTab-M 2.0** 格式（HUPO-PSI 标准，MZmine4 和 MS-DIAL 5 支持）
- 可导入 MetaboLights 提交所需的 **ISA-Tab** 格式
- 与 AnnData 可双向转换（利用 `anndata` 包），便于与单细胞工具链对接

### 2.4 引擎适配层设计

每个引擎封装遵循统一的 `EngineAdapter` 接口：

```python
class EngineAdapter(ABC):
    """所有引擎适配器的基类"""

    @property
    @abstractmethod
    def engine_name(self) -> str: ...          # "xcms", "mzmine", "pyopenms"

    @property
    @abstractmethod
    def engine_version(self) -> str: ...       # 运行时检测实际版本

    @abstractmethod
    def validate_params(self, params: dict) -> ValidationResult: ...
    # 参数校验，返回错误列表和警告

    @abstractmethod
    def run(self, input: MetaboData, params: dict) -> MetaboData: ...
    # 执行分析，输入输出均为 MetaboData 对象

    @abstractmethod
    def get_default_params(self) -> dict: ...
    # 返回该引擎的推荐默认参数

    @abstractmethod
    def get_param_schema(self) -> JSONSchema: ...
    # 参数 JSON Schema，供前端动态渲染参数表单
```

**容错与故障回退（参考 OpenRouter 的 Fallback 设计）：**
- 主引擎失败 → 自动尝试同类备用引擎（可配置）
- 超时（默认 2h）→ 返回部分结果 + 警告
- 引擎容器不可用 → 前端提示，提供其他引擎选项

---

## 3. 引擎集成计划

### 3.1 格式转换引擎

| 引擎 | 语言 | GitHub Stars | CLI/API 封装性 | 集成优先级 | 集成方式 |
|------|------|-------------|--------------|---------|---------|
| **MSConvert (ProteoWizard)** | C++ | ~500 | 5 | P0 | Docker（chambm/pwiz 镜像） |
| **ThermoRawFileParser** | C# | ~300 | 5 | P0 | Docker 直接调用 CLI |
| **OpenTIMS / TimsPy** | C++/Python | ~150 | 4 | P1 | Python API（Bruker timsTOF 必备） |
| **pyOpenMS（格式读写）** | Python | ~575 | 5 | P1 | Python API 集成 |
| **pymzML** | Python | ~200 | 5 | P2 | Python API，轻量 mzML 读写 |

### 3.2 峰检测/预处理引擎

| 引擎 | 语言 | GitHub Stars | CLI/API 封装性 | 集成优先级 | 集成方式 | 备注 |
|------|------|-------------|--------------|---------|---------|------|
| **XCMS 4.x** | R | ~500（Bioc） | 3 | P0 | Docker + R Plumber API | 82,681 次/年下载，引用最广泛 |
| **MZmine 4** | Java | ~700 | 4 | P0 | Docker + CLI 批处理 | Nature Protocols 2024，支持 IMS/PASEF |
| **pyOpenMS 3.x** | Python/C++ | ~575 | 5 | P1 | Docker + Python API | TOPP 设计最适合微服务化 |
| **MS-DIAL 5** | C# | ~350 | 4 | P1 | Docker（Mono）+ CLI | 脂质鉴定最强；GC/LC/IMS 全支持 |
| **asari 1.x** | Python | ~200 | 5 | P1 | Docker + Python API | 大规模（1000+ 样本）LC-MS 首选 |
| **MassCube** | Python | ~150 | 5 | P2 | Docker + Python API | Nature Commun. 2025；准确率 95.2%，生态新兴 |
| **Skyline（Small Mol）** | C# | 闭源 | 4 | P2 | CLI（SkylineBatch） | 靶向定量金标准，MRM/SRM 场景 |
| **El-MAVEN** | C++ | ~350 | 3 | P3 | CLI | GUI 为主，CI 集成难度高 |

### 3.3 批次效应校正引擎

| 引擎 | 语言 | GitHub Stars | CLI/API 封装性 | 集成优先级 | 集成方式 |
|------|------|-------------|--------------|---------|---------|
| **SERRF** | R | ~100 | 3 | P0 | R Plumber API（已封装） |
| **WaveICA 2.0** | R | ~80 | 3 | P0 | R Plumber API |
| **ComBat (sva)** | R | Bioc 高 | 4 | P0 | R Plumber API |
| **malbacR** | R | ~80 | 4 | P1 | R Plumber API（统一调用 11 种方法） |
| **QC-RLSC/LOESS** | R/Python | 内置多包 | 4 | P0 | stats-worker 内置 |

### 3.4 统计分析引擎

| 引擎 | 语言 | GitHub Stars/下载 | CLI/API 封装性 | 集成优先级 | 集成方式 |
|------|------|-----------------|--------------|---------|---------|
| **limma** | R | 762,034/年（Bioc） | 4 | P0 | R Plumber API |
| **mixOmics** | R | 54,438/年（Bioc） | 4 | P1 | R Plumber API |
| **ropls（OPLS-DA）** | R | Bioc 高 | 4 | P1 | R Plumber API |
| **scikit-learn** | Python | 61,100（GitHub） | 5 | P0 | stats-worker 内置 |
| **scipy/statsmodels** | Python | 13,800（GitHub） | 5 | P0 | stats-worker 内置 |
| **MetaboAnalystR 4.0** | R | ~600（GitHub） | 4 | P2 | R Plumber API（部分模块） |

### 3.5 注释/鉴定引擎

| 引擎 | 语言 | GitHub Stars | CLI/API 封装性 | 集成优先级 | 集成方式 | 许可限制 |
|------|------|-------------|--------------|---------|---------|---------|
| **matchms 0.26+** | Python | ~400 | 5 | P0 | Python API（annot-worker） | MIT 开源 |
| **ms2deepscore** | Python | ~200 | 5 | P0 | Python API（matchms 生态） | MIT 开源 |
| **SIRIUS 6** | Java | ~500 | 5 | P1 | Docker + CLI（sirius-worker） | 学术免费，商业需授权 |
| **DreaMS** | Python | ~300 | 4 | P1 | Python API（dreams-worker） | MIT 开源；Nature Biotech 2025 |
| **MS2Query** | Python | ~150 | 5 | P1 | Python API | MIT 开源 |
| **MetDNA3** | R/Web | ~200 | 3 | P2 | R Plumber API | 代谢反应网络传播注释 |
| **CFM-ID 4.0** | C++ | ~150 | 4 | P2 | Docker + CLI | 开源；正向 MS/MS 预测 |
| **BUDDY** | Python | ~200 | 4 | P2 | Python API | Nature Methods 2023；分子式 FDR 控制 |
| **GNPS2 API** | Web | — | 3 | P2 | 异步 REST API | 免费；分子网络场景 |
| **ClassyFire API** | Web | ~100 | 4 | P2 | REST API | 开放；化合物分类 |

### 3.6 通路分析引擎

| 引擎 | 语言 | Stars/下载量 | CLI/API 封装性 | 集成优先级 | 集成方式 |
|------|------|------------|--------------|---------|---------|
| **ReactomePA** | R | 112,533/年（Bioc） | 4 | P0 | R Plumber API |
| **sspa（Python）** | Python | PyPI 中等 | 4 | P0 | Python API（本地化 KEGG/Reactome） |
| **Mummichog 3** | Python | ~300 | 4 | P1 | Python API（无需先注释直接做通路分析） |
| **pathview** | R | Bioc 高 | 4 | P1 | R Plumber API（KEGG 通路可视化） |
| **KEGGREST** | R | Bioc 高 | 3 | P1 | R Plumber API（本地缓存规避速率限制） |

### 3.7 图表引擎

| 引擎 | 语言 | Stars | 集成优先级 | 出版质量 |
|------|------|-------|---------|---------|
| **ggplot2 + ggpubr + ggrepel** | R | 6,900 | P0 | 极高 |
| **ComplexHeatmap** | R | 1,500 | P0 | 极高（60-70% Nature 热图使用） |
| **EnhancedVolcano** | R | ~500 | P0 | 极高 |
| **Plotly.js** | JS | — | P0 | 中高（交互探索） |
| **ECharts** | JS | 65,900 | P1 | 中（超大样本热图） |
| **matplotlib + seaborn** | Python | 13,800 | P1 | 高 |
| **spectrum_utils** | Python | ~200 | P1 | 高（谱图 Mirror Plot） |

### 3.8 集成优先级矩阵（总览）

| 引擎 | 优先级 | 目标集成时间 |
|------|--------|------------|
| XCMS、limma、matchms、scikit-learn/scipy、MZmine 4、ComplexHeatmap、ggplot2、MSConvert、SERRF、ComBat、ReactomePA、sspa | **P0** | Phase 1 |
| pyOpenMS、MS-DIAL 5、asari、mixOmics、ropls、SIRIUS 6、DreaMS、ms2deepscore、ThermoRawFileParser、WaveICA 2.0、malbacR、Mummichog、pathview、EnhancedVolcano、MS2Query | **P1** | Phase 2 |
| MassCube、MetDNA3、CFM-ID、BUDDY、GNPS2 API、ClassyFire、Skyline、OpenTIMS、MetaboAnalystR（部分模块）、mzRAPP | **P2** | Phase 3 |
| El-MAVEN、MS2LDA、MolNetEnhancer、NPClassifier、PatRoon | **P3** | Phase 4+ |

### 3.9 引擎间结果差异处理策略

基于调研发现：**四个主流峰检测工具处理同一唾液样本，特征仅 8% 重叠**（Analytica Chimica Acta 2024）。MetaboFlow 采用三层策略：

**层次 1（Phase 1 实现）：透明展示差异**
- 并排展示各引擎的特征检测数量、注释率、QC 指标
- Venn 图可视化跨引擎特征重叠情况
- 高亮"多引擎共识特征"

**层次 2（Phase 2 实现）：共识特征提取**
- 按 m/z 容差（±5 ppm）和 RT 容差（±0.1 min）匹配跨引擎特征
- 输出"引擎共识得分"

**层次 3（Phase 4+ 实现）：数据积累与元分析**
- 收集平台上多引擎处理同一数据集的历史记录
- 训练参数推荐模型

---

## 4. 功能模块详细设计

### M1: 数据导入与格式转换

**功能描述**

接受用户上传的质谱原始数据，进行格式验证和元数据提取，转换为标准 mzML 格式供下游处理。

**用户交互流程**

1. 用户拖拽上传文件（支持批量多文件），或输入远程 URL（MassIVE/MetaboLights 公开数据）
2. 系统自动识别文件格式，展示文件列表和格式信息
3. 用户填写样本元数据表（分组名、批次号、QC 标志），支持 CSV 模板导入
4. 点击"验证并继续"，系统检查文件完整性和元数据一致性

**输入/输出**

- 输入：mzML、mzXML（直接支持）；mzMLb（HDF5 版本）；仪器厂商格式（Thermo .raw、Waters .raw、Bruker .d、Agilent .d、SCIEX .wiff）需 MSConvert 转换
- 输出：标准 mzML 文件集 + 样本元数据表（写入 MetaboData.obs）

**依赖引擎**

- MSConvert（ProteoWizard）：仪器原生格式 → mzML 转换；通过 Docker 容器调用
- ThermoRawFileParser：Thermo .raw 文件的跨平台替代方案（无需 Windows）
- 注意：MSConvert 官方仅提供 Windows 版 GUI，但有非官方 Linux Docker 镜像（chambm/pwiz-skyline-i-agree-to-the-vendor-licenses）

**UI 草图描述**

- 中央拖拽区 + 文件列表侧边栏
- 进度条显示上传和转换进度（SSE 实时推送）
- 元数据表格内联编辑（ag-grid 风格）
- 错误文件高亮红色，鼠标悬停显示具体错误信息

---

### M2: 峰检测与预处理（多引擎选择）

**功能描述**

对 mzML 文件进行峰检测（feature detection）、峰对齐（RT alignment）、特征对应（feature correspondence），生成特征矩阵。用户可选择不同引擎，也可多引擎并行运行后对比。

**用户交互流程**

1. 引擎选择卡片（展示 XCMS / MZmine 4 / pyOpenMS / MS-DIAL / asari 的特点对比）
2. 参数面板（显示所选引擎的关键参数，提供默认值和推荐范围提示）
3. 可选："多引擎对比模式"——同时勾选多个引擎，并行运行
4. 提交任务，SSE 实时显示进度（每个文件处理进度 + ETA）
5. 完成后展示：检测到的特征数量、缺失率分布、m/z 分布直方图
6. 多引擎模式下：Venn 图展示特征重叠情况

**子步骤（在单引擎内部）**

| 步骤 | 算法选项 | 默认推荐 |
|------|---------|---------|
| 峰检测 | centWave（XCMS）、ADAP（MZmine）、FeatureFinderMetabo（OpenMS） | centWave |
| RT 对齐 | OBI-Warp（XCMS）、JoinAligner（MZmine） | OBI-Warp |
| 特征对应 | density grouping（XCMS）、peak list combiner（MZmine） | 随引擎选择 |
| 归一化 | TIC、PQN（概率商）、内标、中位数 | PQN |
| 缺失值填充 | kNN（MAR）、最小值/2（MNAR）、随机森林 | kNN |

**依赖引擎**

- XCMS 4.4.x（R，P0）
- MZmine 4（Java，P0）
- pyOpenMS 3.x（Python，P1）
- MS-DIAL 5（C#，P1）
- asari（Python，P1）

---

### M3: 质量控制与批次效应校正

**功能描述**

基于 QC 样本评估系统稳定性，可视化批次效应，执行批次效应校正。

**用户交互流程**

1. 系统自动识别元数据中标记为 "QC" 的样本
2. 展示 QC 样本的 CV（变异系数）分布直方图：目标 CV < 20-30%
3. PCA 图展示批次分离情况（有/无批次效应对比）
4. 用户选择是否执行批次效应校正，以及校正方法
5. 校正后自动重新展示 PCA 和 CV 分布

**依赖引擎**

- SERRF（Python/R 实现，2025 年评估表现最佳）
- QC-RSC（LOESS 信号校正，R 实现）
- ComBat（sva 包，R）
- WaveICA 2.0（小波 ICA，R）
- malbacR（统一接口，调用 11 种方法）

---

### M4: 统计分析（PCA/PLS-DA/差异分析）

**功能描述**

执行多变量分析（PCA、PLS-DA、OPLS-DA）和单变量差异分析（t-test、ANOVA、Mann-Whitney），筛选差异代谢物。

**用户交互流程**

1. 选择分析类型：探索性（PCA）/ 判别分析（PLS-DA）/ 差异代谢物筛选
2. 设置分组对比（支持多组对比矩阵，不只限于两组 vs 对照组）
3. 设置筛选阈值（FC、p-value、VIP、FDR 校正方法）
4. 交互式结果：可点击火山图上的点查看代谢物信息，可框选感兴趣区域

**依赖引擎**

- limma（R）：差异分析主力，支持复杂实验设计
- mixOmics（R）：PLS-DA、sPLS-DA
- ropls（R）：OPLS-DA
- scikit-learn（Python）：PCA、SVM 分类
- scipy/statsmodels（Python）：t-test、ANOVA、FDR 校正

**核心统计流程**

```
归一化特征矩阵
    → PCA（探索性，异常样本检测）
    → limma lmFit() + eBayes()（差异分析）
    → FDR 校正（Benjamini-Hochberg）
    → 差异代谢物：|FC| ≥ 1.5 × adj.p ≤ 0.05（默认，可调）
    → PLS-DA（判别分析，VIP > 1 的特征）
    → 置换检验（permutation test，防止过拟合，强制 Phase 2 实现）
```

---

### M5: 代谢物注释与鉴定

**功能描述**

对检测到的特征（m/z + RT + MS2 谱图）进行代谢物鉴定，按 MSI（Metabolomics Standards Initiative）置信度分级（Level 1-4），并集成 ISF 自动注释和 IIMN 离子身份分子网络。

**用户交互流程**

1. 系统自动检索本地谱图库（MoNA + MassBank + HMDB + LipidBlast）
2. ISF 过滤：自动识别并过滤源内碎片（占数据集全部峰 >70% 的干扰信号）
3. 可选：启用 SIRIUS 6 进行 in silico 结构预测（需用户账号）
4. 可选：启用 DreaMS 谱图嵌入（自监督 Transformer，无需账号）
5. 每个特征展示匹配候选列表（化合物名、精确质量偏差 ppm、谱图相似度分数、MSI 置信度）
6. 用户可手动审查低置信度匹配，升级或拒绝
7. 镜像谱图图（Mirror Plot）可视化查询谱图 vs 参考谱图

**ISF 自动注释（In-Source Fragment Detection）**

源内碎片可能占 LC-MS 代谢组学数据集全部峰的 >70%（JACS Au 2025），若不过滤会人为放大代谢组复杂度。MetaboFlow 集成 ISFrag 等专用工具：
- 基于峰形相关性和 m/z 差值规则识别可能的 ISF 来源关系
- 将 ISF 峰标注（不删除），在 MetaboData.var 中新增 `is_isf` 和 `isf_parent_mz` 字段
- 参考 MassCube 的 ISF 检测实现（Nature Commun. 2025）

**IIMN（离子身份分子网络）**

参考 MZmine 的 IIMN 实现（Nature Communications 2021）：
- **MS1 层**：通过峰形相关性将同一化合物的不同加合物（[M+H]+、[M+Na]+、[M+NH4]+）和源内碎片归并为同一"离子身份"
- **MS2 层**：基于谱图相似性连接结构相关化合物（FBMN）
- 双层叠加使分子网络复杂度降低约 56%，特别适合天然产物研究

**Target-Decoy FDR 控制**

参考蛋白质组学的 target-decoy 策略（Nature Methods nmeth.4072）：
- 为 MS2 谱图库匹配实现 target-decoy FDR 框架
- Decoy 生成方法：次级排名法（与真实 FDR 0.05 最接近，PMC 2024）
- 在注释结果中强制标注 FDR 控制阈值，防止过度报告假阳性注释

**MSI 置信度分级展示**

| Level | 判定标准 | 在 MetaboFlow 中的实现 |
|-------|---------|------------------|
| 1（确认） | 标准品验证（m/z + RT + MS2 完全匹配） | 用户导入自建标准库 |
| 2a | MS/MS 谱图库匹配（高相似度 ≥0.8） | matchms 对比 MoNA/MassBank |
| 2b | 谱图预测匹配（SIRIUS CSI:FingerID 或 DreaMS） | SIRIUS 6 / DreaMS |
| 3 | 精确质量 + 化合物类别（CANOPUS/ClassyFire） | SIRIUS 6 CANOPUS |
| 4 | 精确质量匹配（MS1 only） | HMDB/MoNA 精确质量搜库 |

**依赖引擎**

- matchms（Python）：MS/MS 谱图相似度计算，对接 MoNA/MassBank 本地库
- ms2deepscore（Python）：深度学习谱图相似度
- DreaMS（Python）：自监督 Transformer 谱图表征
- SIRIUS 6 CLI（Java）：分子式预测 + CSI:FingerID + CANOPUS（需账号）
- HMDB REST API（本地 SQLite 镜像）：MS1 精确质量搜索
- BUDDY（Python）：分子式 FDR 控制（Nature Methods 2023）

---

### M6: 通路分析

**功能描述**

以差异代谢物列表为输入，进行过度表示分析（ORA）、代谢物集富集分析（MSEA）和无需先注释的 Mummichog 通路分析，可视化富集通路。

**用户交互流程**

1. 选择通路数据库（Reactome / KEGG / HMDB SMPDB / PathBank）
2. 选择物种（130+ 物种支持）
3. 可选：Mummichog 模式（无需注释，直接用 m/z 列表分析）
4. 设置显著性阈值（FDR < 0.05 默认）
5. 交互式气泡图：x 轴 = 富集比，y 轴 = -log10(FDR)，气泡大小 = 通路代谢物数
6. 点击通路查看详情（包含的代谢物列表、KEGG 通路图链接）

**依赖引擎**

- ReactomePA（R）：Reactome 通路分析（首选，数据开放无授权）
- sspa（Python）：KEGG/Reactome/PathBank 本地化后的 ORA/MSEA
- Mummichog 3（Python）：无需先注释的通路分析
- KEGG 本地缓存（sspa 一次性下载）：规避中国大陆访问不稳定

**MetaboFlow v1 中的四工作流传承**

MetaboFlow v1.r 已实现 SMPDB-ORA（WF1）、MSEA（WF2）、KEGG-ORA（WF3）、QEA 定量富集（WF4）四路并行。新版本在此基础上：
- 将四工作流迁移为平台后端引擎调用
- 新增 Reactome 通路（替代 WF1 的 SMPDB，数据更开放）
- 新增 Mummichog（无需注释）
- 保留 QEA（globaltest）作为高级选项
- 并行运行多数据库，展示结果一致性（解决数据库偏差问题）

---

### M7: 图表生成引擎（核心差异化模块）

**功能描述**

从分析结果自动生成完整的 Nature 级图表集，支持深度定制和矢量导出。这是 MetaboFlow 最核心的差异化模块。

**用户交互流程**

1. 分析完成后，进入"图表生成"界面
2. 展示可生成的图表类型列表（含缩略图预览）
3. 用户勾选需要的图表，选择配色方案（色盲友好方案标注）
4. 设置全局参数（字体、字号、尺寸、分辨率）
5. 一键"生成全部"或逐图生成
6. 每张图右侧展示参数面板，实时预览调整效果
7. 导出选项：SVG（矢量）/ PDF（印刷） / TIFF（300 DPI）/ PNG（屏显）

**标准图表模板库（≥12 种，Phase 1 交付）**

| 图表类型 | 引擎 | 用途 | 对应分析步骤 |
|---------|------|------|------------|
| PCA Score Plot | ggplot2 | 样本质控可视化，分离效果 | M4 |
| PLS-DA Score Plot | ggplot2 + mixOmics | 判别分析可视化 | M4 |
| 火山图（Volcano Plot） | EnhancedVolcano | 差异代谢物筛选 | M4 |
| 复杂热图（Heatmap） | ComplexHeatmap | 代谢物聚类，VIP 代谢物 | M4 |
| 通路富集气泡图 | ggplot2 | KEGG/Reactome 通路显著性 | M6 |
| 箱线图/小提琴图 | ggplot2 + ggpubr | 单代谢物各组分布 + p 值标注 | M4 |
| 相关热图 | ComplexHeatmap | 代谢物相关性矩阵 | M4 |
| VIP 条形图 | ggplot2 | PLS-DA 重要变量 | M4 |
| ROC 曲线 | ggplot2 | 生物标志物评估 | M4 |
| 代谢物网络图 | ggraph/igraph（R） | 相关网络可视化 | M5 |
| Mirror 谱图图 | spectrum_utils（Python） | MS/MS 谱图对比 | M5 |
| 引擎 Venn 图 | ggVennDiagram（R） | 多引擎特征重叠比较 | M2 |

**配色方案管理**

| 方案名 | 特点 | 适用场景 |
|-------|------|---------|
| Nature Default | 蓝灰橙，柔和 | 通用首选 |
| Color-Blind Safe | Okabe-Ito 8 色 | 色觉友好，强烈推荐 |
| High Contrast | 纯饱和色 | 黑白印刷对比 |
| Pastel Academic | 低饱和柔和 | 大量子图排版 |

**性能目标**

- 标准图集（12 张图）生成时间 < 60 秒
- 单张图参数调整预览 < 3 秒
- SVG 导出后可在 Adobe Illustrator 中直接编辑（字体嵌入，无光栅化）

---

### M8: 报告与导出

**功能描述**

生成完整的分析报告，包括参数记录、分析结果摘要、所有图表，支持多格式导出。同时生成可直接用于论文 Methods 部分的方法学文字描述。

**用户交互流程**

1. 预览报告（HTML 格式，响应式布局）
2. 选择导出格式：HTML / PDF / Word
3. 可选：下载数据包（包含所有 CSV 原始结果 + MetaboData 对象 + 所有图表文件）

**自动 Methods 段落生成**

根据分析参数快照自动填充模板：

```
"Raw data files were converted to mzML format using MSConvert (ProteoWizard 3.x.x).
Feature detection was performed using {ENGINE} version {VERSION} with the following
parameters: ppm = {PPM}, peakwidth = {PEAKWIDTH}, snthresh = {SN}. Retention time
alignment was performed using {ALIGNMENT_METHOD}. Missing values (>50% in any group
removed; remaining imputed using {IMPUTATION_METHOD}). Normalization was performed
using {NORMALIZATION}. Differential analysis was performed using limma version
{LIMMA_VERSION} with Benjamini-Hochberg FDR correction. Pathway analysis was
performed using ReactomePA version {REACTOMEPA_VERSION}. MSI annotation confidence
levels were assigned following the Metabolomics Standards Initiative guidelines."
```

---

### M9: 项目管理与可重复性

**功能描述**

管理分析项目，记录每次分析的完整参数，支持重现历史分析，支持多人协作。

**用户交互流程**

1. 项目列表页面（卡片视图，含最后修改时间、状态）
2. 每个项目内有版本历史（每次提交分析 = 一个版本快照）
3. "重现此分析"按钮：加载历史参数，一键重跑
4. 分析版本对比：两个版本结果并排展示差异
5. 分享链接（可生成只读分享链接，包含完整结果）

**可重复性保证**

- 每次分析存储完整参数快照（引擎名称 + 版本 + 所有参数）
- 引擎容器 Docker 镜像 tag 锁定（不使用 `latest`，使用精确版本号）
- MetaboData 文件包含完整 provenance 链（原始文件 checksum → 每步处理参数 → 输出文件 checksum）

---

### M10: 算法创新模块（自研差异化算法）

**功能描述**

MetaboFlow v2.0 新增自研算法模块，从数学前沿和跨领域方法中引入创新算法，作为现有引擎的补充和差异化竞争力。以下算法不替代现有引擎，而是以可选模块形式提供。

#### M10.1 最优传输谱图相似度（OT-Similarity）

**背景**：传统余弦相似度忽略峰之间的 m/z 邻近关系，对同分异构体和加合离子区分能力差。Wasserstein 距离天然感知峰的位置漂移。

**实现**：
- 基于 Sinkhorn 算法（Python `POT` 库）实现 GPU 加速的 Wasserstein 谱图相似度
- 与现有 matchms 流程并行：用户可选择 Cosine / FlashEntropy / OT-Wasserstein 三种相似度算法
- 直接先例：GromovMatcher（eLife 2024）已证明 OT 在代谢组学中可行
- 目标：对同分异构体的区分度提升量化对比（Cosine vs OT）

**发表策略**：*Analytical Chemistry* 投稿；若效果显著可冲 *Nature Methods*

#### M10.2 TDA 持久同调峰检测（TDA-PeakDetect）

**背景**：XCMS centWave 母小波固定，参数敏感。持续同调将真峰对应为持续性强的连通分量，噪声对应持续性弱的短命特征，天然具有噪声鲁棒性。

**实现**：
- 将 2D 质谱图（RT × m/z）视为拓扑空间
- 使用 `giotto-tda` / `ripser` 计算持续同调条形码（barcode）
- 真峰 = 生命周期长的连通分量；噪声峰 = 生命周期短的特征
- 直接先例：GC-IMS 2D 持续同调峰检测（Analytica Chimica Acta 2024）；MetaboFlow 扩展到 LC-MS 2D 数据
- 作为 XCMS/MZmine 峰检测的后处理质量打分器（不替代，而是补充）

**发表策略**：*Analytical Chemistry* 或 *Nature Methods*（系统性对比 XCMS/MZmine 的基准测试论文）

#### M10.3 图信号处理通路分析（GSP-Pathway）

**背景**：现有 ORA/MSEA 逐通路独立检验，忽略代谢物在网络中的邻接关系。图信号处理（GSP）将代谢物浓度作为代谢网络图上的信号，图拉普拉斯低通滤波对应通路层面的系统性变化。

**实现**：
- 从 KEGG/Reactome 构建代谢物-反应图
- 将差异代谢物浓度变化作为图信号
- 图拉普拉斯谱分解：低频特征向量对应通路级变化，高频对应局部扰动
- 使用 `PyGSP` 库实现；图节点对应代谢物（处理注释不完整问题）
- 与现有 ReactomePA 并行提供，用于高级分析模式

**发表策略**：*Nature Methods* 级别潜力；目前代谢组学中几乎无竞争

#### M10.4 保形预测不确定性量化（Conformal-Annotation）

**背景**：现有代谢物注释只给出相似度分数，缺乏统计保证。Conformal Prediction 提供无需分布假设的覆盖率保证（"真实化合物以 95% 概率在候选集中"）。

**实现**：
- 对 matchms / DreaMS 注释流程的每一步添加 Conformal Prediction 校准
- 校准集：从 MoNA/MassBank 中随机保留的验证集
- 输出：每个特征的注释候选集（Prediction Set），而非单一最优匹配
- 计算成本低（仅需校准分数排序），可直接在 annot-worker 中实现
- 直接先例：质谱预测不确定性量化综述（IJMS 2024）

**发表策略**：*Analytical Chemistry* 或 *Bioinformatics*；实现简单但缺口真实

#### M10.5 DreaMS 式预训练谱图表征（扩展）

**背景**：DreaMS（Nature Biotechnology 2025）用自监督方式在数百万条未标注 MS/MS 谱图上预训练，学到的嵌入超越传统方法。MetaboFlow 的机会在于扩展预训练到多平台（LC-MS + GC-MS 联合）。

**实现**：
- 集成 DreaMS 开源模型（已发布）作为基础注释引擎
- Phase 3+ 自研扩展：多平台对比预训练（LC-MS + GC-MS 双模态），填补 DreaMS 未覆盖的空白
- 训练数据：MoNA（2.1M 谱图）+ GNPS（700K 谱图）+ MassBank（80K 谱图）
- 使用 SimCLR/MoCo 框架，`matchms` 生态对接

**发表策略**：多平台扩展版本目标 *Nature Methods* / *Nature Biotechnology*

#### M10.6 遥感端元提取 → MSI 谱图解卷积（Endmember-MSI）

**背景**：MALDI-MSI 每个像素是多种代谢物信号的空间混合，与高光谱遥感的端元混合（endmember mixing）完全同构。遥感领域的 VCA（Vertex Component Analysis）、NMF、自编码器解混算法在代谢组学中几乎没有系统应用。

**实现**：
- 将 MS Imaging 数据矩阵（像素 × m/z）建模为线性混合模型
- 使用 VCA 或非负矩阵分解（NMF）提取端元谱图（纯代谢物谱图）和丰度图（空间分布）
- `scikit-learn` NMF 直接可用；高级版本使用 `pysptools`（遥感工具包）
- 直接先例：遥感解混综述（ScienceDirect 2025）；MSI 领域几乎未引用此类算法

**发表策略**：*Analytical Chemistry* 或 *Nature Methods*（首篇系统性遥感解混用于 MSI 的论文）

---

### M11: 产业应用模块（新增）

**功能描述**

针对制药、临床、食品等产业应用场景的专项功能模块，包括合规报告生成、多中心数据管理等。

#### M11.1 制药 ADME/MIST 模块

基于 FDA MIST 指南（2016/2023 年更新）和 IQ 联盟代谢物生物分析工作组推荐：
- **代谢物追踪**：自动追踪药物相关物质（>10% 人体血浆暴露量阈值判断）
- **种属比较**：人体 vs 动物毒理种属代谢物暴露量对比表
- **合规报告生成**：自动生成符合 FDA 申报格式的代谢物定性/定量报告
- **HRMS 代谢物鉴定**：集成 SIRIUS/CFM-ID 进行药物代谢物 in silico 结构推断

#### M11.2 临床靶向代谢组学模块

针对 CLIA/ISO 15189 认证实验室和临床研究：
- **方法验证报告**：自动生成线性范围、精密度（CV）、准确度、稳定性验证数据表
- **QC 控制图**：Levey-Jennings 控制图，批间/批内 CV 追踪
- **NIST SRM 1950 比对**：与 NIST SRM 1950 参考值自动比对，728 个代谢物定量
- **多中心数据对齐**：基于 Biocrates 靶向 panel 的跨中心数据标准化

#### M11.3 孟德尔随机化模块（参考 MetaboAnalyst 6.0）

MetaboAnalyst 6.0 已在 NAR 2024 发表孟德尔随机化模块，MetaboFlow 提供类似功能：
- 输入：差异代谢物列表 + GWAS 汇总统计数据
- 支持双样本 MR（Two-Sample MR）分析
- MR 方法：IVW、MR-Egger、加权中位数、PRESSO
- 输出：代谢物 → 表型因果关联强度（OR/Beta，95% CI）+ 敏感性分析
- 依赖：`TwoSampleMR` R 包 + MR-Base API

#### M11.4 剂量-响应分析模块（参考 MetaboAnalyst 6.0）

MetaboAnalyst 6.0 已发布剂量-响应模块：
- 支持单调剂量-响应、非单调（U 型/倒 U 型）模式检测
- 基准剂量（BMD）估算：自动拟合 Hill 方程、Michaelis-Menten 方程
- 代谢物剂量-响应热图：展示各剂量组下代谢物的变化模式
- 应用场景：毒理代谢组学、药效代谢组学
- 依赖：`drc`（dose-response curves）R 包

#### M11.5 微生物组-代谢组联合分析模块

针对微生物组代谢组学的专项场景：
- 宿主 vs 菌群来源代谢物分层（基于同位素追踪或数据库标注）
- 16S/宏基因组与代谢物相关性分析（Spearman/Pearson + FDR 校正）
- SCFA/胆汁酸等微生物组特征代谢物专属注释模板
- 输出：代谢物-微生物关联网络图

---

## 5. 用户交互设计

### 5.1 主流程：向导式分步（Wizard）

```
步骤 1            步骤 2               步骤 3              步骤 4
数据导入   →    峰检测与预处理   →    统计分析      →    代谢物注释
[完成 ✓]       [进行中 ...]           [待解锁]            [待解锁]

步骤 5            步骤 6               步骤 7
通路分析   →    图表生成         →    导出报告
[待解锁]       [待解锁]               [待解锁]
```

- 每步完成后才解锁下一步（防止流程跳步导致错误）
- 用户可随时返回修改前面步骤（修改后自动标记后续步骤为"需重新运行"）
- 右上角常驻项目状态面板（当前步骤、任务进度、预计剩余时间）

### 5.2 每步内：参数面板 + 实时预览

- 左侧：参数配置面板（分基础参数和高级参数两组，高级参数默认折叠）
- 右侧：实时预览区（低分辨率快速预览，点击"运行完整分析"后更新）
- 参数变更时：相关参数实时高亮联动
- 参数验证：实时显示参数合理性提示

### 5.3 高级模式：ReactFlow 节点编辑器

- 针对 Persona C（方法学研究者）的可选高级功能
- 流程以 DAG（有向无环图）形式展示
- 支持并行分支（多引擎并行）、结果汇聚（多引擎结果对比节点）
- 入口：向导流程页面右上角"切换到高级模式"按钮

### 5.4 图表交互

- **配色方案切换**：顶部工具栏下拉选择，所有图表实时同步更换
- **字体和尺寸**：全局设置影响所有图表（符合期刊版面要求，如 8pt/10pt 字体）
- **单图参数调整**：每张图下方有"调整此图参数"折叠区，修改后 3 秒内预览更新
- **一键导出图表集**：ZIP 包含所有图表的 SVG + PDF + TIFF 三种格式

### 5.5 进度反馈（SSE 实时推送）

- 任务提交后，页面顶部出现任务进度条
- 进度推送内容：当前步骤名称、百分比、ETA、实时日志流（折叠）
- 任务完成后：Toast 通知 + 自动展示结果
- 任务失败后：错误详情 + 建议修复步骤

---

## 6. 开发路线图

### Phase 0：基础重构（第 1-2 月）

**目标**：为后续开发建立可靠基础，不新增面向用户的功能。

| 任务 | 具体内容 | 输出物 |
|------|---------|-------|
| 代码库初始化 | 建立 monorepo 结构（`packages/frontend`、`packages/backend`、`packages/engines`、`packages/common`） | 初始化的 git 仓库 |
| MetaboFlow v1 模块化 | 将 `MetaboFlow_v1.r`（977 行）拆分为独立 R 函数文件 | 模块化 R 包结构 |
| 版本锁定 | R 依赖用 `renv` 锁定；Python 依赖用 `uv` + `pyproject.toml` | `renv.lock`、`uv.lock` |
| 基础测试框架 | R 用 `testthat`；Python 用 `pytest` | 20+ 测试用例通过 |
| MetaboData 格式定义 | 实现 `MetaboData` Python 类，HDF5 序列化/反序列化 | `packages/common/metabodata.py` |
| Docker 环境搭建 | xcms-worker、stats-worker 的 Dockerfile 和构建流程 | `docker-compose.yml` + 2 个可构建镜像 |
| CI/CD 基础 | GitHub Actions：PR 触发 lint + 测试；main 触发 Docker 镜像构建 | `.github/workflows/` 配置 |

**里程碑验收标准**：MetaboFlow v1 全部功能在模块化后通过测试，结果与原始脚本完全一致。

---

### Phase 1：MVP — 核心 E2E 流程（第 3-6 月）

**目标**：跑通从 mzML 导入到图表导出的完整流程，内测可用。

| 月份 | 任务 | 负责模块 |
|-----|------|---------|
| 第 3 月 | 前端框架搭建（Next.js + Tailwind + shadcn/ui）；7 步 Wizard 骨架；FastAPI 后端基础 API 结构 | M1、架构 |
| 第 3 月 | M1 数据导入（mzML/mzXML 直接支持）；MSConvert + ThermoRawFileParser 容器；MinIO 文件存储 | M1 |
| 第 4 月 | XCMS 引擎集成（xcms-worker + R Plumber API）；MZmine 4 引擎集成；M2 峰检测前端参数面板 | M2 |
| 第 4 月 | M3 QC 基础（CV 评估、批次 PCA）；SERRF + ComBat 批次校正集成 | M3 |
| 第 5 月 | limma + scipy 统计分析；stats-worker；PCA / 火山图交互展示 | M4 |
| 第 5 月 | matchms + ms2deepscore 注释引擎；HMDB + MoNA 本地谱图库初始化 | M5 |
| 第 6 月 | chart-r-worker（ggplot2 + ComplexHeatmap + EnhancedVolcano）；M7 基础图表模板（12 种） | M7 |
| 第 6 月 | M8 基础 HTML 报告导出；M9 项目管理基础；SSE 进度推送完整实现 | M8、M9 |

**Phase 1 交付物**

- Web SaaS 可访问（内测 URL，需邀请码）
- 支持的引擎：XCMS + MZmine 4（峰检测）、limma+scipy（统计）、matchms（注释）、ggplot2（图表）
- 支持的图表类型：12 种基础图表
- 数据格式：mzML、mzXML 直接上传；Thermo .raw 通过 ThermoRawFileParser 转换
- 内测用户目标：5-10 个实验室

**Phase 1 里程碑验收（第 6 月末）**

- 使用 MetaboFlow v1 的斑马鱼示例数据，新平台与 v1 结果对比：差异代谢物列表重叠率 ≥95%
- 完整分析流程（从 mzML 上传到图表导出）< 30 分钟（20 个样本规模）
- 无运行时崩溃，错误处理完善

---

### Phase 2：差异化 — 图表引擎 + 多引擎对比 + 高级注释（第 7-10 月）

**目标**：实现核心差异化功能，图表质量达到发表级，多引擎对比可用，算法创新模块原型。

| 月份 | 任务 | 负责模块 |
|-----|------|---------|
| 第 7 月 | 多引擎并行运行 UI；Venn 图特征重叠展示；共识特征提取（Layer 2 策略） | M2 多引擎 |
| 第 7 月 | ISF 自动注释集成（ISFrag 工具）；IIMN 离子身份分子网络 | M5 |
| 第 8 月 | SIRIUS 6 CLI 集成（sirius-worker）；DreaMS 集成（dreams-worker）；M5 MSI Level 1-4 完整实现 | M5 |
| 第 8 月 | Target-Decoy FDR 控制框架实现（M5.FDR）；BUDDY 分子式 FDR 集成 | M5 |
| 第 9 月 | ReactomePA + sspa + Mummichog 通路分析集成；M6 交互式气泡图；多数据库并行 | M6 |
| 第 9 月 | M4 扩展：OPLS-DA（ropls）；ROC 曲线；多组对比矩阵；强制置换检验 | M4 |
| 第 10 月 | pyOpenMS、MS-DIAL 5 引擎集成（P1 引擎全部上线） | M2 |
| 第 10 月 | M9 版本历史 + 重现分析；M8 PDF/Word 报告导出；自动 Methods 段落 | M8、M9 |
| 第 10 月 | M10.4 保形预测不确定性量化（实现简单，优先落地）；M10.1 OT 谱图相似度原型 | M10 |

**Phase 2 交付物**

- 多引擎对比视图（XCMS vs MZmine vs pyOpenMS vs MS-DIAL）
- 完整 MSI Level 1-4 注释流程 + Target-Decoy FDR 控制
- SIRIUS 6 + DreaMS 双注释引擎
- ISF 自动过滤 + IIMN 分子网络
- Reactome + KEGG + Mummichog 通路分析
- 保形预测不确定性量化（全球首个系统性实现于代谢组注释）

---

### Phase 3：发表准备 + 产业模块 + 生态（第 11-14 月）

**目标**：建立 benchmark 数据集，完成论文撰写，产业模块上线，Tauri 本地客户端。

| 月份 | 任务 |
|-----|------|
| 第 11-12 月 | Benchmark 数据集建立：选取 5+ 公开数据集，覆盖不同仪器厂商（Thermo/Waters/Bruker）、不同生物基质（血浆/尿液/组织），运行 4 个引擎处理，记录所有结果 |
| 第 11-12 月 | M11.1 制药 ADME/MIST 模块；M11.2 临床靶向模块；M11.3 孟德尔随机化模块 |
| 第 11-12 月 | M10.2 TDA 峰检测原型（针对 GC-MS 2D 数据首发）；M10.3 GSP 通路分析原型 |
| 第 13 月 | Nature Communications 论文撰写（MetaboFlow 跨引擎评估框架）；Supplementary benchmark 数据 |
| 第 13 月 | 外部用户验证：招募 3-5 个外部课题组；M11.4 剂量-响应模块；M11.5 微生物组联合分析 |
| 第 14 月 | Tauri v2 桌面客户端（Windows + macOS）；< 50 MB 安装包目标 |
| 第 14 月 | 社区建设：完整文档（中英双语）、教程视频（5 个场景）、示例数据集 |

**发表前置条件（第 13 月末检查）**

- [ ] 平台 GitHub 开源（MIT）
- [ ] 至少 4 个引擎完整集成
- [ ] 5+ 公开数据集 benchmark，结果公开
- [ ] 至少 2 个外部课题组使用案例
- [ ] 完整文档和可运行 Docker Compose 部署包
- [ ] 所有 benchmark 数据存入 Metabolomics Workbench（获得数据集 ID）
- [ ] Target-Decoy FDR 控制框架验证完成

---

### Phase 4：扩展（第 15 月+）

| 方向 | 具体内容 | 优先级 |
|------|---------|-------|
| 算法创新深化 | M10.5 DreaMS 多平台扩展预训练（Nature Biotechnology 目标）；M10.6 遥感解混 MSI | 高 |
| 更多引擎 | MassCube 升 P1、GNPS2 批量 API、PatRoon（环境代谢组学） | 按生态发展决定 |
| 多组学整合 | 转录组（DESeq2）+ 代谢组联合分析；DIABLO（mixOmics）；multi-MetaboData 格式 | 高 |
| 联邦学习 | 多中心代谢组学联邦批次效应校正（PySyft/Flower 框架）；隐私保护数据分析 | 中 |
| 商业版 | 私有部署企业版；SLA 支持；高级图表模板；定制化引擎 | 长期 |
| 社区 Challenge | 基于积累的公开数据集，发起年度多引擎评估 Challenge（类 CASP 模式） | 长期 |
| NAR 更新 | 每次大版本更新投一篇 NAR Web Server Issue（借鉴 MetaboAnalyst 策略） | 长期 |

---

## 7. 学术发表路线图

### 7.1 Nature Communications 首发论点

**核心论点（基于调研的最有胜算角度）**

> "MetaboFlow 是首个对主流代谢组学引擎（XCMS、MS-DIAL、MZmine、pyOpenMS）进行系统性横向基准测试的统一框架，同时提供零代码操作界面，使非生信用户能够在标准化、可重复的条件下进行跨引擎方法选择。"

**为什么选 Nature Communications 而非 Nature Methods**

| 期刊 | 接受类型 | 当前可行性 |
|------|---------|----------|
| Nature Methods | 算法突破、开创性平台 | 不可行：MetaboFlow 聚合层本身门槛不足；M10 算法模块成熟后可尝试 |
| Nature Biotechnology | 规模性平台 | 需要更大规模用户基础和多年社区积累 |
| **Nature Communications** | 全流程框架、可重复性创新 | **可行**：tidyMass（NC 2022）、asari（NC 2023）、MetaboAnalystR 4.0（NC 2024）、MS-DIAL 5（NC 2024）均发在此 |

**三层贡献结构**

1. **主贡献（方法学）**：首次建立跨引擎标准化 benchmark 体系。XCMS/MZmine/pyOpenMS 处理同一数据集特征仅 8% 重叠（Analytica Chimica Acta 2024），目前无任何平台让用户系统性认知这一差异并做出有依据的选择。
2. **次贡献（工程）**：统一零代码接口，非生信用户可在同等条件下运行和比较多个引擎。
3. **三次贡献（可重复性）**：完整的参数快照 + 版本锁定 + MetaboData 格式，解决代谢组学可重复性危机。

### 7.2 算法创新论文路线（Phase 3-4 追加）

| 模块 | 目标期刊 | 时间节点 | 核心论点 |
|------|---------|---------|---------|
| M10.1 OT 谱图相似度 | Analytical Chemistry / Nature Methods | 第 16-18 月 | Wasserstein 距离在同分异构体区分上优于余弦相似度的系统对比 |
| M10.4 保形预测 | Analytical Chemistry | 第 12-14 月 | 首个具有统计保证的代谢物注释置信集框架 |
| M10.2 TDA 峰检测 | Nature Methods / Anal. Chem. | 第 18-20 月 | 持续同调用于 LC-MS 2D 峰检测的系统性基准测试 |
| M10.3 GSP 通路 | Nature Methods | 第 20-24 月 | 图信号处理通路感知统计检验（目前代谢组学真空地带） |
| M10.5 多平台 DreaMS | Nature Biotechnology | 第 24-30 月 | LC-MS + GC-MS 双平台自监督谱图预训练 |
| M10.6 MSI 端元解混 | Nature Methods / Anal. Chem. | 第 20-24 月 | 遥感高光谱解混算法首次系统应用于 MS Imaging |

### 7.3 发表前置条件清单

| 条件 | 最低标准 | 目标标准 |
|------|---------|---------|
| 核心引擎集成数量 | ≥3 个 | ≥4 个（XCMS、MZmine、pyOpenMS、matchms） |
| Benchmark 数据集 | ≥3 个 | ≥5 个（不同仪器、不同基质） |
| 外部用户验证 | ≥2 个课题组 | ≥4 个课题组，有真实科研问题的应用案例 |
| 代码开源 | GitHub 开源（MIT） | 开源 + Zenodo DOI + 完整文档 |
| 可重复性验证 | 3 个不同环境结果一致 | Docker Compose 一键部署，3 个 OS 验证 |
| 数据公开 | Metabolomics Workbench 数据集 ID | Metabolomics Workbench + MetaboLights |

### 7.4 Reviewer 预案

| 质疑 | 预防措施 |
|------|---------|
| "只是一个 wrapper，没有方法学贡献" | 重点展示 benchmark 框架本身；用 RNA-seq benchmarking 论文类比；M10 算法创新模块是附加贡献 |
| "和 UmetaFlow/tidyMass 有何本质区别" | 直接在引言中说明：UmetaFlow 只用 OpenMS，tidyMass 只用自己算法——MetaboFlow 是跨引擎的 |
| "数据集不够多样化" | 至少覆盖 3 种仪器厂商、2 种色谱模式（RP + HILIC）、3 种生物基质 |
| "代码是否足够稳定" | 投稿前确保：有完整测试覆盖、有 CI/CD、有至少 3 个月外部用户使用记录 |
| "与 MetaboAnalyst 功能高度重叠" | 强调差异：MetaboAnalyst 单引擎（asari）、不可本地部署、图表固定；MetaboFlow 多引擎对比是核心差异 |
| "Target-Decoy FDR 控制不够严格" | 参照 Nature Methods nmeth.4072 的 MS Imaging FDR 框架，系统验证 decoy 生成方法的真实 FDR 估计 |

### 7.5 后续发表策略

```
Phase 3 末（第 14 月）：Nature Communications 首发
  → 核心论点：跨引擎标准化评估框架 + E2E 零代码平台

Phase 4（约第 18 月）：Analytical Chemistry（M10.1 OT / M10.4 保形预测）
  → 算法创新首发；积累 MetaboFlow 的方法学声誉

Phase 4（约第 20 月）：NAR Web Server Issue 更新
  → 论点：增加产业模块、新引擎支持、孟德尔随机化

Phase 5（约第 24-30 月）：Nature Methods 冲刺
  → 条件：M10 算法模块成熟，大量用户，benchmark 积累形成方法学洞见
  → 论点：M10.3 GSP 通路分析或 M10.5 多平台预训练
```

---

## 8. 质量保证

### 8.1 测试策略

#### 单元测试

| 测试对象 | 框架 | 覆盖目标 |
|---------|------|---------|
| MetaboData 对象（Python） | pytest | 序列化/反序列化、转换方法：100% |
| EngineAdapter 基类 | pytest | 接口契约验证：100% |
| R 分析函数（modular） | testthat | 关键路径：≥80% |
| FastAPI 路由 | pytest + httpx | 所有端点：≥90% |

#### 集成测试

| 测试场景 | 测试数据 | 验收标准 |
|---------|---------|---------|
| XCMS 完整峰检测流程 | MetaboFlow v1 斑马鱼示例数据 | 差异代谢物列表与 v1 重叠率 ≥95% |
| MZmine 完整峰检测流程 | 同上 | 特征数量在预期范围内，无崩溃 |
| matchms + MoNA 注释 | NIST SRM 1950 血浆标准 | Level 2a 命中率 ≥60% |
| Target-Decoy FDR 控制 | MoNA 验证集（随机保留 10%） | 估计 FDR 与真实 FDR 偏差 ≤0.01 |
| limma 差异分析 | 已知正对照数据集（3 组对比） | FDR 校正后结果与文献一致 |
| ReactomePA 通路分析 | 差异代谢物列表（含 HMDB ID） | 前 10 通路与 MetaboFlow v1 高度一致 |
| 图表生成 | 完整分析结果 | 所有 12 种图表格式正确，文件可打开 |
| E2E 完整流程 | MetaboFlow v1 示例数据 | 从 mzML 上传到报告导出 < 30 分钟，无报错 |

#### E2E 测试（Playwright）

- 模拟用户完整操作流程（上传文件 → 配置参数 → 等待结果 → 下载图表）
- 在 Chrome / Firefox / Safari 三浏览器运行
- 每次 main 分支合并后自动触发

### 8.2 CI/CD 流水线

```yaml
触发条件:
  PR → main:
    - ruff lint（Python）
    - eslint（TypeScript）
    - pytest（Python 单元测试 + 集成测试）
    - R CMD check（R 包）
    - Docker 镜像构建测试（不推送）

  合并到 main:
    - 全部 PR 检查 +
    - Docker 镜像构建并推送到 registry（tag: git SHA + 版本号）
    - Playwright E2E 测试（staging 环境）
    - 自动 staging 部署

  发布 tag（vX.Y.Z）:
    - 生产环境部署
    - Tauri 桌面应用构建（Windows + macOS）
    - 自动发布 GitHub Release（附件：安装包）
    - Zenodo DOI 更新
```

### 8.3 引擎版本锁定策略

- **原则**：所有引擎 Docker 镜像 tag 使用精确版本号，绝不使用 `latest`
- **锁定文件**：`engines/versions.json` 记录每个引擎的当前使用版本和上次验证日期
- **升级流程**：手动触发升级 PR → 完整集成测试通过 → Reviewer 审查 → 合并

```json
{
  "xcms": { "version": "4.4.0", "bioc_release": "3.19", "tested": "2026-03-15" },
  "mzmine": { "version": "4.x.y", "tested": "2026-03-15" },
  "msdial": { "version": "5.x.y", "tested": "2026-03-15" },
  "matchms": { "version": "0.26.x", "tested": "2026-03-15" },
  "sirius": { "version": "6.3.3", "tested": "2026-03-15" },
  "dreams": { "version": "1.x.y", "tested": "2026-03-15" },
  "limma": { "version": "3.67.0", "tested": "2026-03-15" }
}
```

---

## 9. 风险清单与缓解措施

### 9.1 技术风险

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| MZmine CLI 的 `-login-console` 要求阻碍无头服务化 | 中 | 高 | 提前与 MZmine 开发团队联系；备选：pyOpenMS 替代 MZmine 的 P0 地位 |
| MS-DIAL 仅 Windows，Mono 运行不稳定 | 中 | 中 | Wine Docker 方案测试；MS-DIAL 为 P1 引擎，Phase 2 验证，不影响 Phase 1 |
| SIRIUS 学术账号 token 配额限制影响多用户并发 | 中 | 中 | 实现 token 池管理；用户需自带账号；CANOPUS 无需 token |
| KEGG API 在中国大陆不稳定 | 高（中国用户） | 中 | Phase 1 即实现 sspa 本地缓存；Reactome 作为首选通路库 |
| mzML 文件 GB 级别，SaaS 上传带宽瓶颈 | 高 | 高 | tus.io 分片上传；Tauri 桌面应用作为大文件首选路径 |
| DreaMS GPU 内存需求高 | 中 | 中 | CPU 推理模式（慢但可用）；GPU 实例作为高级选项 |
| MetaboData 中间格式设计不满足扩展需求 | 低 | 高 | Phase 0 充分参考 AnnData 设计；预留 `uns` 字典作为扩展槽 |
| Target-Decoy FDR 估计偏差 | 中 | 中 | 选用 PMC 2024 验证的次级排名法；在发布前系统基准测试 |

### 9.2 市场风险

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| 研究者改变现有工具习惯阻力大 | 高 | 中 | 定位为"现有工具的聚合"而非替代；与 MetaboAnalyst 保持格式兼容 |
| MetaboAnalyst 持续迭代缩小差距 | 中 | 中 | MetaboFlow 的多引擎对比是 MetaboAnalyst 不可能做的（单引擎固定） |
| 商业软件厂商进入 E2E 市场（Bruker 收购 Biocrates 趋势） | 中 | 高 | 开源策略建立社区壁垒；价格优势（开源免费 vs 商业软件 $10k+/年） |
| 制药 CRO 市场渗透难度高 | 高 | 中 | 先建立学术信誉（NC 论文），再向 CRO 推广；M11 产业模块作为切入点 |

### 9.3 竞争风险

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| MassCube 快速成长为新标准 | 中（长期） | 低（短期） | 直接纳入为 P2 引擎，MetaboFlow 受益于其成长 |
| MetaboAnalyst 推出本地部署版本 | 低 | 高 | 加速 Tauri 本地版开发（Phase 3）；M10 算法创新模块是独特壁垒 |
| DreaMS 等 AI 注释工具直接提供 E2E 平台 | 低 | 高 | 先发优势 + 多引擎 benchmark 数据是护城河；与 DreaMS 合作而非竞争 |

### 9.4 产业/临床风险（新增）

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| FDA MIST 合规功能开发成本高于预期 | 中 | 中 | M11.1 模块定为 Phase 3，留足开发时间；先与制药公司合作用户验证需求 |
| 临床数据隐私合规（HIPAA/GDPR）要求高 | 高 | 高 | 本地部署模式（Tauri）是临床用户首选；不存储用户数据到云端（可配置） |
| 跨实验室可重复性验证成本高 | 中 | 中 | 与现有 Ring Trial 项目（如 NIST SRM 1950 研究组）合作，共享验证资源 |
| 市场教育成本高（临床用户不了解非靶向代谢组学价值） | 高 | 中 | 先专注靶向代谢组学（M11.2 临床靶向模块），需求更明确 |

### 9.5 学术发表风险

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| Reviewer 认为"只是 wrapper"而拒稿 | 中 | 高 | 论文核心论点强调 benchmark 框架；引入足够数量外部用户案例；参照 RNA-seq benchmarking 论文 |
| 同行在发表前做类似工作 | 低 | 高 | 加速 benchmark 数据集建立（Phase 3 优先任务）；提前在 bioRxiv 发布 |
| 数据集不够多样化被 Reviewer 否定 | 中 | 中 | 至少 5 个数据集，覆盖不同仪器厂商（Thermo + Waters + Bruker）、不同基质 |
| M10 算法创新模块论文被认为创新不足 | 中 | 中 | OT 谱图相似度和 TDA 峰检测已有先例文章（eLife 2024、Anal. Chimica Acta 2024），类比论证 |

---

## 10. 成功指标（KPI）

### 10.1 产品指标

| 指标 | Phase 1 末（第 6 月） | Phase 2 末（第 10 月） | Phase 3 末（第 14 月） |
|------|-------------------|-------------------|-------------------|
| 注册用户数 | ≥20（内测） | ≥200 | ≥1000 |
| 活跃用户数（月活） | ≥10 | ≥80 | ≥400 |
| 分析任务数（累计） | ≥50 | ≥500 | ≥5000 |
| 数据集规模（累计上传样本数） | ≥500 | ≥5000 | ≥50000 |
| 用户反馈 NPS | — | ≥40 | ≥60 |
| 引擎使用分布 | XCMS+MZmine 主导 | XCMS 30% / MZmine 30% / pyOpenMS 20% / MS-DIAL 20% | 更分散（5+ 引擎） |
| 产业用户占比 | 0% | ≥5%（制药/临床） | ≥15% |

### 10.2 学术指标

| 指标 | 目标 | 时间节点 |
|------|------|---------|
| Nature Communications 投稿 | 完成投稿 | Phase 3 末（第 14 月） |
| 接受发表 | 发表 | 第 18-20 月（含审稿周期） |
| 发表后 1 年引用量 | ≥50 | 第 30 月 |
| GitHub Stars | ≥200 | 第 14 月 |
| 社区 Fork 数 | ≥50 | 第 14 月 |
| 外部贡献 PR | ≥5 | 第 14 月 |
| Benchmark 数据集收录（Metabolomics Workbench） | ≥5 个数据集 ID | 第 13 月 |
| M10 算法模块论文投稿 | ≥2 篇 | 第 20 月 |
| NAR Web Server Issue 更新论文 | 投稿 | 第 24 月（约） |

### 10.3 质量指标

| 指标 | 标准 |
|------|------|
| 分析可重复性 | 相同参数、相同引擎版本，不同机器、不同日期运行，结果完全一致（MD5 校验通过） |
| 峰检测一致性（内部 benchmark） | MetaboFlow 调用 XCMS 结果与直接运行 XCMS 脚本结果：特征数量差异 ≤0.1% |
| Target-Decoy FDR 精度 | 估计 FDR 与真实 FDR（基于验证集）偏差 ≤0.01 |
| 图表导出质量 | SVG 在 Adobe Illustrator 中可编辑（字体未嵌入为曲线），PDF 字体嵌入，TIFF 分辨率 ≥300 DPI |
| 系统可用性 | SaaS 99.5% uptime（月度）；计划维护提前 24h 通知 |
| E2E 任务成功率 | ≥98%（失败任务有明确错误信息，不含用户数据问题）|
| ISF 过滤召回率 | 已知 ISF 阳性集上召回率 ≥80%（基于 JACS Au 2025 数据集验证） |

### 10.4 产业指标（新增）

| 指标 | 目标 | 时间节点 |
|------|------|---------|
| 制药公司合作用户 | ≥1 家 CRO/制药公司内测用户 | 第 14 月 |
| MIST 合规报告生成覆盖率 | 覆盖 FDA MIST 指南要求的核心数据条目 ≥90% | Phase 3 末 |
| 临床实验室用户 | ≥2 家 CLIA 认证实验室试用 | 第 18 月 |
| 数据安全审计通过 | 本地部署模式通过基本数据安全审查 | Phase 3 末 |

---

## 附录：关键参考文献

### 引擎生态

- XCMS 4.x: "xcms in Peak Form: Now Anchoring a Complete Metabolomics Data Preprocessing and Analysis Software Ecosystem" — Analytical Chemistry 2025
- MZmine 4: "Reproducible mass spectrometry data processing in MZmine 3" — Nature Protocols 2024
- MS-DIAL 5: "MS-DIAL 5 for comprehensive metabolome, lipidome, and now proteome analyses" — Nature Communications 2024
- MassCube: "MassCube improves accuracy for metabolomics data processing" — Nature Communications 2025
- asari: "Trackable and scalable LC-MS metabolomics data processing using asari" — Nature Communications 2023
- matchms: matchms GitHub (Netherlands eScience Center), v0.26, 400+ Stars
- DreaMS: "Self-supervised learning from tandem mass spectra" — Nature Biotechnology 2025
- BUDDY: "Bottom-up MS/MS interrogation" — Nature Methods 2023
- MetDNA3: "Knowledge and data-driven metabolite annotation network" — Nature Communications 2025
- IIMN: "Ion Identity Molecular Networking" — Nature Communications 2021
- QuanFormer: "Transformer-Based Peak Detection" — Analytical Chemistry 2025

### 竞品与市场

- MetaboAnalyst 6.0: "MetaboAnalyst 6.0: towards a unified platform for metabolomics data analysis" — Nucleic Acids Research 2024
- MetaboAnalystR 4.0: "MetaboAnalystR 4.0: a unified LC-MS workflow for large-scale metabolomics studies" — Nature Communications 2024
- "Modular comparison of untargeted metabolomics processing steps" — Analytica Chimica Acta 2024（**特征仅 8% 重叠数据来源**）
- "A Reproducibility Crisis for Clinical Metabolomics Studies" — PMC 2025（**244 项临床研究 meta 分析**）

### 产业/临床

- FDA MIST Guidance: "Safety Testing of Drug Metabolites" — FDA 2016/2023
- FDA BMVB Guidance: "Bioanalytical Method Validation for Biomarkers" — FDA 2025
- IFCC 全球临床代谢组学调研 — CCLM 2024
- NIST SRM 1950 综合定量分析 — Analytical Chemistry 2024
- "Ion suppression correction for non-targeted metabolomics" — Nature Communications 2025
- "The Hidden Impact of In-Source Fragmentation" — PMC/JACS Au 2025
- Bruker 收购 Biocrates — 2025 年行业报告

### 算法创新

- GromovMatcher: "Optimal transport for untargeted metabolomic data alignment" — eLife 2024
- TDA 持续同调 GC-IMS 峰检测 — Analytica Chimica Acta 2024
- Target-Decoy FDR for MS imaging — Nature Methods nmeth.4072
- FDR control methods for untargeted metabolomics — PMC 2024
- RSR-MSI 超分辨率 — Analytical Chemistry 2025
- DIA-BERT — Nature Communications 2025
- CMSSP 对比学习 — Analytical Chemistry 2024
- GNN 代谢物疾病关联（M-GNN）— IJMS 2025

### 技术架构

- AnnData: anndata GitHub (scverse), v0.12.10, Stars 720
- Galaxy 2024 Update — Nucleic Acids Research 2024
- Tauri vs Electron 2025 Comparison
- ReactomePA: 2025 年下载量 112,533，同比增长 134%（Bioconductor 统计）
- SIRIUS 6 账号与许可: boecker-lab.github.io/docs.sirius.github.io/account-and-license/

### 学术发表策略

- MZmine 3 — Nature Biotechnology 2023（多引擎聚合平台发表先例）
- FBMN/GNPS — Nature Methods 2020（工作流创新发表策略）
- "Good practices and recommendations for benchmarking computational metabolomics annotation tools" — Metabolomics 2022
- MetaboAnalyst NAR 更新系列（2009/2012/2015/2019/2021/2024）：双轨发表策略模板
