# Plan 2: 代谢组学可重复性图谱 — 完整执行方案

**生成日期**: 2026-03-16
**压力测试状态**: 通过（6/7维度验证通过，1项需月1验证）
**覆盖方向**: 组合C+ benchmark全流程 + Ensemble系列第二篇 + TDA可选引擎

---

## 1. 战略定位

### 核心主张

代谢组学已进入"数据丰裕、可重复性匮乏"的瓶颈期。2025年的文献反复暴露同一裂缝：软件选择导致特征重叠率仅约8%，临床代谢组学研究中85%的报告代谢物属于统计噪声，而批次校正、ISF处理、注释策略三个维度上各引擎的行为从未被系统比较。MassCube NC 2025做了引擎间速度和峰检测精度的比较，但它本质上是一篇**工具发布论文**，benchmark服务于自我宣传，而非服务于领域。

本方案提出的"代谢组学可重复性图谱"，是领域首个以**可重复性本身为研究对象**的系统性基准，不推销任何单一引擎，输出的是跨引擎行为知识图谱和可重复性失效模式。

### 目标发表级别判断

- 基础版（6维度）：NC 8.0-8.5，可实现
- 强化版（含B3暗代谢组显著发现）：NatMethods，需满足Go/No-Go门控

---

## 2. 方向A：组合C+——"代谢组学可重复性图谱"

### 2.1 科学问题定义：为什么现有benchmark不够

**MassCube NC 2025的实际覆盖范围（已确认）：**

| 评估维度 | MassCube NC 2025 | 我们的方案 |
|---------|-----------------|-----------|
| 引擎数量 | 4个（MS-DIAL 4.9, MZmine3, XCMS 4.0.0, MassCube） | 6+个（加入asari, MZmine4, 可选TDA引擎） |
| 峰检测精度 | 合成数据（13,500单峰+13,500双峰） | 合成+真实标准品混合物+生物样本 |
| 速度/内存 | 是 | 是（作为子指标） |
| 批次效应模块 | 无 | 有（量化过度校正） |
| ISF处理策略比较 | 部分（仅MassCube自身） | 各引擎的ISF识别策略系统对比 |
| OT注释诊断 | 无 | 有（高余弦+高OT距离=边界注释） |
| 注释不确定性量化 | 无 | 有（保形预测prediction sets） |
| 暗代谢组跨引擎一致性 | 无 | 有（B3核心模块） |
| DreaMS嵌入相似度 | 无 | 有（B7） |
| 统计功效-引擎关系 | 无 | 有（B5非单调关系） |
| Multiverse分析 | 无 | 有 |
| 数据集 | 自产（NIST SRM 1950等，非第三方独立） | 公开MTBLS数据集+新实验 |
| 结论立场 | 偏向MassCube优越性 | 中立，服务领域 |

**现有benchmark的根本缺陷：**

1. MassCube的benchmark是自我评估（自产合成数据，参数对自己有利），缺乏独立外部验证
2. 评估维度停留在峰检测层，不涉及注释、批次、统计功效等下游
3. 所有现有比较论文（2018年Analytical Chemistry综合评估等）均不包含asari（2023年NC发表）
4. 无一论文从"可重复性失效模式"角度系统分析：同一生物学信号在不同引擎中是否稳定可复现

### 2.2 方法设计

#### 引擎选择与配置

| 引擎 | 版本 | 可用性 | 运行方式 | 备注 |
|------|------|--------|---------|------|
| XCMS | 4.8.0（2025.11发布） | 公开，Bioconductor | R脚本，支持自动化 | 活跃维护，xcms in Peak Form NC级论文在投 |
| MS-DIAL | 5.5.250920 | 公开，Windows binary+源码 | CLI支持（MsdialConsoleApp），需Wine/Docker | 最新版本支持IMS |
| MZmine | 4.9 | 公开，跨平台 | CLI batch模式支持 | GUI依赖可用headless模式 |
| asari | 1.13.1 | 公开，PyPI | Python CLI，最易自动化 | 2023 NC，未被MassCube包含 |
| MassCube | 最新稳定版 | 公开，PyPI | Python CLI | 作为参照引擎 |
| TDA引擎（可选B5+） | 自研POC | 需验证 | Python | 需3个月POC，见方向C |

**参数空间（Multiverse）：**

每引擎设定3个参数配置：默认（文档推荐）、宽松（低噪声门槛）、严格（高噪声门槛）。5引擎×3配置=15套处理流水线。

#### 6维度评估框架详细设计

**维度1 — 批次效应模块（含过度校正量化）**

核心问题：引擎内置校正（如MassCube的QC-based correction）是否引入过度校正？

- 使用已知组间差异的数据集（如MTBLS87 or MTBLS264，含QC样本）
- 指标：校正前后QC的CV变化、已知差异代谢物的信号保真度、"校正前应显著但校正后消失"的特征数（过度校正指数）
- 方法：参照2025年bioRxiv"benchmarking batch correction workflow"（8月发布），将该框架应用到各引擎的内置校正模块

**维度2 — ISF影响维度（跨引擎策略比较）**

背景：Giera/Siuzdak 2024 Nature Metabolism报告ISF超过70%，2025年Yasin等反驳实为2-25%，争论核心在于数据集选择和分析方法。

- 各引擎的ISF识别策略：MassCube（coelution-based），MS-DIAL（ion mobility），XCMS（CAMERA），asari（无内置ISF过滤）
- 使用相同数据集，统计各引擎报告的ISF候选特征数和比例
- 构建ISF-非ISF分类的引擎间一致性矩阵（Jaccard相似度）
- 输出：ISF处理策略图谱，量化"引擎选择对暗代谢组规模的影响"

**维度3 — OT注释诊断（边界注释识别）**

方法来源：GromovMatcher（2024 eLife）已证明OT用于代谢组学数据对齐的可行性。

- 计算引擎-参考库之间的最优传输距离（Wasserstein距离）
- 诊断规则：余弦相似度 > 0.8 且 OT距离 > 阈值θ → "边界注释"（high-confidence spectrally but structurally uncertain）
- 在10万级特征上的OT可行性：使用entropic regularization（Sinkhorn算法），复杂度O(n²)可降至O(n log n)，在RTX 4090上处理100k特征可行（见JACS Au 2025实测）
- 产出：各引擎注释质量的"精确-边界-错误"三分类图

**维度4 — B1 CP×benchmark注释不确定性量化（★）**

方法：保形预测（Conformal Prediction）

- 使用已注释子集作为calibration set
- 为每个引擎生成注释的prediction sets（置信度1-α）
- 比较各引擎的prediction set大小分布（set越小=注释越确定）
- 直接可用工具：2026年arxiv "When should we trust the annotation?"（SGR算法，专为MS/MS注释设计）
- 产出：各引擎注释确定性曲线（精确率-coverage曲线）

**维度5（B3） — 暗代谢组跨引擎一致性（★NatMethods升级关键）**

定义"暗代谢组特征"：同时满足：(a) 未匹配任何已知数据库；(b) MS2谱图可获得；(c) DreaMS嵌入质量分数>阈值

评估方法：
- 对同一数据集各引擎分别检测暗代谢组特征
- 用DreaMS 1024维嵌入表示每个暗代谢组特征
- 计算跨引擎的特征对应关系（最近邻匹配，m/z±5ppm + RT±0.2min + embedding余弦>0.85）
- 输出：暗代谢组跨引擎一致性矩阵（"哪些暗代谢物是真实的，哪些是引擎artefact"）
- 核心发现假设：~30-50%的暗代谢组特征仅在1个引擎出现（与MassCube的ISF保守估计一致），而另一批特征在5个引擎中均稳定出现，代表真实未注释代谢物

数据集选择（需同时有MS2+已知参照+足量样本）：
- MTBLS264（人血浆，多批次，Orbitrap）：批次效应模块主数据集
- MTBLS87（人尿液，50+样本）：ISF对比主数据集
- MassIVE MSV000083388（NIST SRM1950，广泛引用参照）：峰检测基准
- 新采集（可选）：同一血浆样本在3个中心运行，作为暗代谢组跨中心验证

**维度6（B7） — DreaMS嵌入注释相似度**

- DreaMS预训练模型已公开（Zenodo+GitHub），API已验证可用（`from dreams.api import dreams_embeddings`），DreaMS Atlas包含2.01亿条MS/MS谱
- 用DreaMS嵌入距离替代字符串匹配，比较各引擎注释的"语义一致性"
- 指标：已知同系物的嵌入距离是否小于跨引擎同一特征的嵌入距离？

**B5 — 引擎-统计功效关系**

- 同一数据集（已知组间差异）×5引擎×3参数 → 每套流水线跑Mann-Whitney + FDR校正
- 记录：回收到的已知差异代谢物数量、假阳性率
- 预期发现：引擎选择与统计功效之间存在非单调关系（如asari在某类数据上丢失特征导致功效下降，而在另一类数据上噪声低导致功效更高）

### 2.3 数据需求与来源

| 数据集 | 编号 | 基质 | 仪器 | 样本量 | 用途 |
|--------|------|------|------|--------|------|
| MTBLS264 | MetaboLights | 人血浆 | Orbitrap | 500+ | 批次效应+主要基准 |
| MTBLS87 | MetaboLights | 人尿液 | QTOF | 100+ | ISF比较 |
| MSV000083388 | MassIVE | 血浆NIST SRM1950 | Orbitrap | 参照标准品 | 峰检测ground truth |
| MTBLS733/736 | MetaboLights | 标准品混合物 | Q Exactive HF | 已有ground truth | 注释基准（1100化合物） |
| 新采集（合作）| — | 血浆/尿液 | 多中心 | 3中心×30样本 | 暗代谢组跨中心验证 |

**公开数据**（可立即访问）：MTBLS264, MTBLS87, MTBLS733/736通过MetaboLights直接下载，MSV000083388通过MassIVE。DreaMS Atlas及预训练权重通过GitHub+Zenodo。

**新数据**（需合作或采集）：跨中心验证数据集，建议联系Metabolomics Society Data Challenge合作方或现有课题组合作。这是B3暗代谢组模块的可选强化，非必要条件。

**计算资源**：5引擎×15参数配置×5数据集的全流水线。单次Multiverse运行估算约200-400CPU小时。建议使用HPC集群或AWS EC2（c5.18xlarge）。OT计算GPU加速需RTX 3090/4090级显卡。

### 2.4 预期贡献（vs MassCube NC 2025的具体差异化清单）

| 维度 | MassCube NC 2025 | 本方案差异化 |
|------|-----------------|------------|
| 研究立场 | 工具发布，benchmark服务于自我 | 中立基准，benchmark服务于领域 |
| 数据集 | 自产合成数据，部分公开 | 100%独立公开数据集（MTBLS） |
| 下游覆盖 | 仅峰检测+分类 | 峰检测+批次+ISF+注释质量+统计功效 |
| 暗代谢组 | 无 | 跨引擎一致性矩阵（B3） |
| 注释不确定性 | 无 | 保形预测prediction sets（B1） |
| asari包含 | 无 | 有 |
| Multiverse | 无 | 参数空间系统扫描 |
| 结论 | "MassCube最好" | "在X场景用Y引擎，在Z场景用W引擎，可重复性失效的根源是..." |
| 社区价值 | 提供一个新工具 | 提供选择引擎的决策知识库 |

### 2.5 论文结构大纲

**Title候选（3个）：**

1. "A Metabolomics Reproducibility Atlas: Systematic Benchmarking of LC-MS Processing Engines Across Six Analytical Dimensions"
2. "Engine-Dependent Reproducibility in Untargeted Metabolomics: A Cross-Engine Benchmark Reveals Systematic Failure Modes"
3. "The Metabolomics Reproducibility Landscape: How Preprocessing Engine Choice Shapes Biological Discovery"

**Main Figures设计（7张）：**

- **Fig 1 — 概念图+研究框架**：5引擎×6维度矩阵热图（综合得分）；上方为引擎家族树（算法类型），左侧为维度分类
- **Fig 2 — 峰检测基准（独立验证）**：在MTBLS733公开标准品数据上，5引擎的precision-recall曲线；左侧单峰，右侧双峰
- **Fig 3 — Multiverse分析**：同一数据集×15参数配置的火山图"multiverse"，展示引擎选择和参数对差异代谢物列表的影响程度
- **Fig 4 — 批次×ISF双维度图谱**：批次效应校正前后各引擎的PCA轨迹；右侧ISF识别策略对比
- **Fig 5 — 注释质量图谱（OT+CP）**：各引擎注释的精确-边界-错误分布；右侧为保形预测覆盖曲线
- **Fig 6 — ★暗代谢组跨引擎一致性（B3）**：DreaMS嵌入空间中暗代谢组特征的跨引擎重叠热图；Venn图展示"5引擎共有"vs"仅1引擎独有"
- **Fig 7 — 统计功效-引擎关系（B5）**：已知差异代谢物的回收率×5引擎×3参数，揭示非单调关系；推荐决策树

### 2.6 执行时间线（14个月详细分解）

**月1-2：基础设施建立**
- 所有5引擎在标准化Linux环境下安装（Docker容器化）
- 下载并验证4个公开数据集
- 建立自动化流水线框架（Snakemake或Nextflow）
- DreaMS模型本地部署验证
- 里程碑：全流水线可对1个小数据集端到端运行

**月3-4：峰检测基准（维度1-baseline）**
- 在MTBLS733标准品数据上完成5引擎峰检测
- 建立Fig 2所需的precision-recall评估框架
- 里程碑：Fig 2初稿完成

**月5-6：批次效应+ISF模块（维度1,2）**
- MTBLS264批次效应分析：5引擎×批次校正策略
- ISF处理策略矩阵构建
- 里程碑：Fig 3, Fig 4初稿

**月7-8：注释质量+Multiverse（维度3,4）**
- OT注释诊断实现（Sinkhorn算法，GPU加速）
- 保形预测框架实现（基于arxiv 2603.10950）
- Multiverse参数扫描（15配置×5数据集，需HPC）
- 里程碑：Fig 5初稿，Multiverse数据完成

**月9-11：★B3暗代谢组模块（维度5）**
- DreaMS嵌入计算（所有引擎的未注释特征）
- 跨引擎暗代谢组一致性矩阵
- 跨中心验证（如有合作数据）
- 里程碑：Fig 6完成，确定Go/No-Go（NatMethods vs NC）

**月12：统计功效分析（B5）**
- 引擎-功效关系分析
- 决策树框架构建
- 里程碑：Fig 7完成

**月13：整合+写作**
- 所有图完成，综合结论提炼
- GitHub代码库整理
- 初稿完成

**月14：审稿+修改缓冲**
- 内审，解决分析漏洞
- 提交（NC或NatMethods，取决于B3结果）

### 2.7 风险矩阵

| 风险 | 概率 | 影响 | 缓解策略 |
|------|------|------|---------|
| MS-DIAL在Linux自动化困难（原生Windows） | 高 | 中 | 用Wine+CLI或Docker（已有社区方案），降级到MS-DIAL4.9 |
| OT计算在大规模特征上资源需求超预期 | 中 | 中 | 限定分析子集（随机抽样10k特征），Sinkhorn ε可调 |
| B3暗代谢组一致性结果无新发现（各引擎结果趋同） | 中 | 高 | 转变叙事：结果本身（引擎间高度一致）也是重要发现；降级NC路线 |
| MassCube团队发布v2并包含更多引擎 | 低 | 中 | 本方案的中立立场和全维度覆盖构成根本差异化 |
| 公开数据集缺乏多中心B3验证 | 中 | 低 | B3模块在单中心数据上仍可执行，多中心作为可选强化 |
| DreaMS嵌入质量不足以区分引擎间差异 | 低 | 中 | 备用方案：用MS2谱图余弦相似度聚类替代DreaMS嵌入 |
| 引擎更新导致结果不可重复 | 高（长期） | 中 | Docker容器锁定版本，所有结果可复现 |

---

## 3. 方向B：Ensemble/场景自适应加权（系列第二篇）

### 3.1 科学问题

方向A证明了"引擎选择影响结果"以及"不同场景下没有单一最优引擎"。方向B的问题是：能否构建一个元引擎，根据输入数据的特征（仪器类型、基质、样本量、研究目标）自适应地加权多引擎输出？

### 3.2 方法设计

**核心框架：**

1. **引擎特性知识库**（来自方向A）：每个引擎在不同场景下的性能曲线
2. **场景分类器**：输入元数据→输出场景向量
3. **加权融合层**：基于场景向量，对多引擎特征列表做加权合并
4. **不确定性传播**：B1的保形预测框架扩展为Ensemble级别的不确定性估计

**备用方案（无外部生物学验证数据时）：**

使用方向A的Multiverse数据本身作为内部验证：将15套流水线的共识特征视为ground truth。

**生物学验证路径（强化版）：**

使用已发表的代谢物GWAS结果（如MR-Base中的代谢物-表型关联）作为外部验证。

### 3.3 与方向A的依赖关系

| 方向A产出 | 方向B依赖 |
|---------|---------|
| 引擎-场景性能矩阵 | 场景分类器训练数据 |
| Multiverse共识特征集 | 内部验证ground truth |
| DreaMS嵌入空间 | Ensemble特征表示 |
| 保形预测框架 | 不确定性传播基础 |

方向B是方向A的直接延伸，代码共享率约60%。

### 3.4 执行时间线

- 月9-11（与方向A并行）：引擎特性知识库构建+场景分类器设计
- 方向A提交后月1-4：核心算法实现+内部验证
- 月5-7：生物学验证（如有合作数据）或纯内部验证
- 月8-10：写作提交

预计提交时间：方向A提交后10-12个月。

---

## 4. NatMethods升级路径

### 4.1 B3暗代谢组验证计划

**阶段一（月9，内部验证）**：在MTBLS264上完成5引擎的暗代谢组一致性分析。定量判断：跨5引擎稳定出现的暗代谢组特征数量是否>500？

**阶段二（月10，网络分析）**：对跨引擎稳定暗代谢组特征，用DreaMS Atlas分子网络确认其在2.01亿条公开谱图中的存在频率

**阶段三（月11，跨中心）**：如有合作数据，在3个独立中心验证暗代谢组特征的跨引擎跨中心稳定性

### 4.2 NC→NatMethods的叙事差异

| 层面 | NC叙事 | NatMethods叙事 |
|------|-------|--------------|
| 中心问题 | "哪个引擎更好/更准确？" | "代谢组学的可重复性失效在哪里？如何系统修复？" |
| 结论层次 | 工具推荐矩阵 | 可重复性失效的机制学说+解决路径 |
| B3定位 | 附加评估维度 | 核心生物学发现："真实暗代谢物集合"的首次系统鉴定 |
| 社区影响 | 帮助用户选引擎 | 重新定义代谢组学可重复性标准 |
| 方法创新度 | 综合benchmark框架 | CP+DreaMS+OT三位一体的注释可信度体系 |

### 4.3 Go/No-Go门控

**在月11进行强制决策点：**

| 指标 | NC路线阈值 | NatMethods路线阈值 |
|------|-----------|-----------------|
| B3跨引擎稳定暗代谢物数量 | >200 | >500 |
| 暗代谢组引擎依赖性（单引擎独有比例） | >20% | >30% |
| DreaMS Atlas中稳定暗代谢物的存在验证 | 不要求 | ≥80%在Atlas中有聚类支持 |
| 跨中心验证 | 不要求 | 至少2个独立中心 |

---

## 5. 竞争格局总结

### 直接竞争者

| 竞争者 | 发表 | 覆盖范围 | vs本方案差异 |
|--------|------|---------|------------|
| MassCube NC 2025 | Nature Communications | 4引擎，峰检测+速度 | 无asari/批次/ISF/注释UQ/暗代谢组/Multiverse |
| Modular comparison 2024 | Analytica Chimica Acta | 4引擎，8%重叠发现 | 无asari/暗代谢组/CP/DreaMS |
| XCMS 4.8.0 2025 | Analytical Chemistry | XCMS生态 | 非多引擎比较 |
| MetaboAnalystR 4.0 2024 | Nature Communications | 端到端流水线 | 非benchmark |

### 潜在竞争（需监控）

- 任何包含asari在内的新benchmark论文（搜索未发现）
- 暗代谢组领域：尚无系统性跨引擎一致性研究
- Multiverse分析应用于代谢组学：当前无直接竞争

---

## 6. 压力测试结果

### 通过的假设

| 假设 | 验证结果 | 风险级别 |
|------|---------|---------|
| MassCube差异化成立 | ✅ 5/6维度MassCube未覆盖 | 低 |
| DreaMS模型可用 | ✅ 公开Zenodo+GitHub，Python API | 低 |
| OT大规模可行 | ✅ Sinkhorn+GPU加速，GromovMatcher先例 | 低-中 |
| CP注释UQ可行 | ✅ arxiv 2603.10950 SGR算法可直接用 | 低 |
| 批次效应空白 | ✅ 2025 bioRxiv benchmark workflow可借用 | 低 |
| 暗代谢组窗口存在 | ✅ Giera/Siuzdak辩论活跃期 | 中 |

### 需注意项

- MS-DIAL Linux自动化需月1实测验证
- B3暗代谢组结果的不确定性是最大变量

---

## 7. Go/No-Go门控标准

### 月1末：基础设施门控
- 全部5引擎Docker安装完成+测试通过
- 4个公开数据集下载验证完毕
- DreaMS本地推理成功

### 月4末：峰检测基准门控
- 引擎间precision-recall呈现可区分差异
- asari有独特表现验证其包含必要性

### 月8末：Multiverse数据门控
- 15套配置全部完成
- 引擎间Jaccard相似度 < 0.5

### 月11末：NatMethods vs NC决策门控
- 见4.3节标准

---

## 参考资料

- MassCube NC 2025: PMC12216001
- DreaMS Nature Biotechnology 2025: doi:10.1038/s41587-025-02663-3
- Dark Metabolome debate: Nature Metabolism 2024-2025
- GromovMatcher eLife 2024: doi:10.7554/eLife.91597
- Conformal prediction for MS: arxiv 2603.10950
- Batch correction benchmark: bioRxiv 2025.08.01.668073
- XCMS 4.8.0: Analytical Chemistry 2025
- asari NC 2023: doi:10.1038/s41467-023-39889-1
- Modular comparison: Analytica Chimica Acta 2024
