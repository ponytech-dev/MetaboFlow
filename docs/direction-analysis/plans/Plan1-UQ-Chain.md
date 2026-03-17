# Plan 1: UQ传播完整链条 — 完整执行方案

**生成日期**: 2026-03-16
**压力测试状态**: 通过（核心假设全部验证，2项需月5/月3门控确认）
**覆盖方向**: MNAR-VAE化学先验填补 (AC 7.5) + 组合A端到端UQ传播 (NatMethods 8.7-9.0)

---

## 0. 执行摘要

两个方向均有明确的可执行路径。方向A（MNAR-VAE）的直接竞争来自多篇VAE-metabolomics论文，但无一利用化学结构先验——差异化窗口真实存在，但较窄，需精确叙事。方向B（端到端UQ传播）的竞争格局更复杂：arXiv 2026-03-10的论文专注注释层不确定性，MassID（bioRxiv 2026-02-11）做了概率注释+FDR过滤，BAUM（Briefings in Bioinformatics 2024）做了贝叶斯通路分析。但没有一篇论文覆盖完整的三阶段链条：**CP校准注释UQ → 注释感知加权差异分析 → 通路贝叶斯传播的端到端整合**，尤其是差异分析UQ传播这个环节依然是真实空白。

---

## 1. 战略定位

### 1.1 在整体研究计划中的位置

这是研究计划的"旗舰组合"。方向A是AC 7.5分级别的快速产出（6-8个月），用于：
1. 在高影响力期刊建立存在感
2. 解决方向B所需的数据质量问题（缺失值填补是所有下游分析的前提）
3. 验证化学先验驱动的方法论路线

方向B是NatMethods级别的核心旗舰（12-18个月），完整的端到端UQ传播框架将成为领域方法论基础设施。

### 1.2 为什么优先级最高

- **时机窗口收窄中**：arXiv 2026-03-10和MassID 2026-02-11说明这个方向有多方在同步探索，但完整链条仍无人覆盖
- **方法论杠杆效应高**：一旦建立，所有代谢组学研究都可以"插进来"使用
- **暗代谢组叙事天然支持**：Giera-Siuzdak 2024-2025 Nature Metabolism辩论为"注释不确定性很重要"提供了完美的动机叙事
- **CCS先验是独有资产**：如果用IsoDistinguish的实验CCS数据，这是竞争者很难快速复现的数据护城河

---

## 2. 方向A: MNAR-VAE化学先验填补

### 2.1 科学问题定义

**核心问题**：质谱代谢组学中，离子强度低于检测限导致的MNAR缺失（约占总缺失值的60-80%）是系统性的、非随机的。现有最优方法（QRILC、GSimp、MissForest）将代谢物视为独立特征，忽略了一个基本事实：**一个代谢物是否被检测到，受其物理化学属性决定**——极性高的代谢物更容易因离子化效率低而缺失，分子量大的分子更难挥发，logP低的化合物在反相色谱中保留时间短而容易丢失。

这个先验知识是免费的（来自HMDB/PubChem等公开数据库），但没有任何现有填补方法利用它。

**精确陈述**：在MNAR条件下，设计一个利用化学属性先验信息（MW, logP, 极性面积/TPSA, 电荷状态）的structure-informed VAE，使缺失机制建模更准确，填补误差在真实MNAR场景下比现有最优方法降低≥20%。

### 2.2 方法设计

**整体架构：Chemical-Prior MNAR-VAE（CP-MNAR-VAE）**

```
输入层
├── 已观测强度矩阵 X_obs [N样本 × M特征，含缺失]
└── 化学属性矩阵 C [M特征 × K属性]
    (MW, logP, TPSA, 电荷, 极性类别)

模块1: MNAR缺失机制建模
├── 缺失指示矩阵 R [N×M]，R_ij=1 表示缺失
├── 缺失概率网络: p(R|X, C) = σ(f_θ(X_obs, C))
│   — 将化学属性C作为结构先验注入缺失概率估计
└── 可识别性条件: 参考GINA框架的充分条件

模块2: 条件VAE编码器
├── 输入: [X_obs (mask填0), 缺失mask M, 化学属性C]
├── 编码器 q(z|X_obs, M, C): 2层MLP → μ, logσ²
└── 重参数化: z ~ N(μ, σ²)

模块3: 条件VAE解码器
├── p(X_complete|z, C): 化学属性C通过cross-attention注入
└── 输出: 完整强度矩阵 X̂

损失函数
L = E[log p(X_obs|z,C)] - KL(q(z|X_obs,M,C) || p(z))
  + λ · MNAR惩罚项 (防止模型无视缺失机制)
  + γ · 化学一致性正则化 (相近化学属性的代谢物应有相似填补模式)
```

**关键技术选择说明**：
- 化学属性通过cross-attention而非简单concatenation注入：允许模型选择性地关注对当前缺失模式最相关的化学维度
- MNAR惩罚项参考 MMISVAE (Sci Reports 2025) 的多重重要性采样思路
- 可识别性参考 GINA (PMC 2023) 的框架

### 2.3 数据需求与来源

| 数据集 | 类型 | 样本量 | 特征数 | 获取方式 | 化学属性来源 |
|--------|------|--------|--------|----------|------------|
| MTBLS1 (MetaboLights) | 人血清LC-MS | 132样本 | ~1000特征 | 公开下载 | HMDB/PubChem API |
| ST000001 (Metabolomics Workbench) | 尿液LC-MS | 60样本 | ~500特征 | 公开下载 | 同上 |
| MTBLS2 (MetaboLights) | 植物LC-MS | 140样本 | ~800特征 | 公开下载 | 同上 |
| Dunn et al. 2012 CAMCAP | 血浆 | 299样本 | 2098特征 | 公开 | 同上 |
| ImpLiMet benchmark数据集 | 多类型 | 已标准化 | 多规模 | GitHub/文章补充 | 同上 |

**化学属性获取**：PubChemPy API（MW, logP, TPSA, 极性）+ RDKit计算。未注释特征用LC保留时间作为logP代理（RT~logP在反相色谱中显著相关）。

### 2.4 预期贡献

**基线对比**：QRILC、GSimp、MissForest、kNN、MMISVAE

**量化目标**：
- NRMSE（已知MNAR场景）：比QRILC降低≥20%，比MissForest降低≥15%
- 下游差异分析：假阳性率比QRILC降低≥10%
- 化学解释性：对"为什么缺失"的概率预测AUC≥0.75

### 2.5 论文结构大纲

**Title候选**：
- "Chemical structure-informed imputation of missing not at random values in untargeted metabolomics"
- "CP-MNAR-VAE: A structure-aware variational autoencoder for MNAR missing value imputation in LC-MS metabolomics"

**主要Figures（5-6张）**：
- Fig 1: 方法架构图（化学先验注入机制的概念图）
- Fig 2: 模拟MNAR基准测试（NRMSE对比，多数据集）
- Fig 3: 化学属性与缺失概率的关系分析（logP最强预测因子验证）
- Fig 4: 真实数据集下游影响（差异分析和通路分析的下游比较）
- Fig 5: 消融研究（去掉化学先验后的性能下降量化）

**目标期刊**：Analytical Chemistry。备选：Bioinformatics、Briefings in Bioinformatics

### 2.6 执行时间线

| 阶段 | 时间 | 里程碑 | 门控点 |
|------|------|--------|--------|
| 数据准备与基础设施 | 月1-2 | 下载数据、建立化学属性查询pipeline | 注释覆盖率<25%则切换RT代理方案 |
| 模型实现 | 月3-4 | PyTorch实现、5个基线统一接口 | 基础VAE≥kNN性能 |
| 实验与消融 | 月5-6 | 完整benchmark、消融研究 | **关键门控：NRMSE改进≥10%** |
| 下游验证与写作 | 月7-8 | Python包、论文初稿、投稿AC | — |

**预期投稿时间**：Month 8。bioRxiv占位：Month 6。

### 2.7 风险矩阵

| 风险 | 概率 | 影响 | 缓解策略 |
|------|------|------|---------|
| 化学属性覆盖率不足（未注释特征多） | 高 | 中 | RT作为logP代理；聚焦已注释特征子集 |
| VAE在MNAR条件下不可识别 | 中 | 高 | GINA框架充分条件；否则转向实用性论证 |
| NRMSE改进不显著（<10%） | 中 | 高 | 聚焦特定化学类别的选择性改进 |
| 竞争者抢先 | 低-中 | 中 | Month 6上bioRxiv占位 |
| "To Impute or Not To Impute"反叙事 | 低 | 低 | 正面回应：MNAR场景下imputation有效，关键是用对方法 |

---

## 3. 方向B: 组合A — 端到端UQ传播

### 3.1 科学问题定义

**核心问题**：未靶向代谢组学中，从原始谱图到通路解读，每一步都有不确定性，但现有工作流将这些不确定性隔离处理或完全忽略。**一个注释置信度0.3的特征和置信度0.95的特征被同等对待**，进入同一个差异分析，最终影响通路结论。

**精确陈述**：设计并验证一个三阶段UQ传播框架，使注释不确定性显式地传播到差异分析（通过注释感知加权）和通路分析（通过贝叶斯不确定性传播），并在真实数据集上证明：相比标准工作流，端到端UQ传播能减少假阳性通路发现≥30%、提高通路可重复性≥50%。

### 3.2 方法设计（三阶段详细架构）

#### Phase 1: 保形预测（CP）注释UQ框架

```
输入: LC-MS特征 f_i = (m/z, RT, MS2谱图, [CCS可选])

Step 1: 候选生成
├── 谱图相似性: cosine similarity vs GNPS/HMDB/MassBank
└── 候选列表: {(c_j, s_ij)} j=1,...,K

Step 2: CP校准
├── Conformity score: A_ij = f(s_ij, Δm/z, ΔRT, [ΔCCS])
├── 校准集: 有已知标准品的特征集
└── 预测集 C_i = {c_j : A_ij ≤ q̂}

Step 3: 不确定性量化输出
├── 集合大小 |C_i|: 越大=越不确定
├── 置信得分 p_i ∈ [0,1]
└── 同分异构体标记
```

**CCS可选先验**：仅当有实验CCS+同分异构体候选+差异>1.5%时启用。贝叶斯更新：P(c_j|data) ∝ P(data|c_j) × P(c_j|CCS)。

**与arXiv 2026-03-10的差异**：他们聚焦"是否该abstain"，不传播到下游。我们的CP校准置信集显式传播到差异分析和通路。

#### Phase 2: 注释感知加权差异分析（★核心空白）

```
注释感知加权差异分析:
Step 1: 权重函数 w_i = p_i^β，β∈(0,1]
Step 2: 加权limma — w_i作为precision weights注入lmFit
Step 3: IHW (Independent Hypothesis Weighting) FDR校正
Step 4: 同分异构体专项 — 模糊节点，差异信号按概率分配

输出: 带双重不确定性（统计+注释）的差异分析结果表
```

**与现有方法的关键区别**：
- BAUM：贝叶斯非参数，计算量大，不适合大规模untargeted
- MassID：概率注释+FDR过滤，但差异分析仍等权重
- MetaboAnalystR 4.0：通路层加权，差异分析层未加权
- **我们：差异分析层的注释感知加权 + 同分异构体模糊分配 → 真实空白**

#### Phase 3: 通路感知贝叶斯传播

```
Step 1: 概率通路映射 — 特征→候选集→通路的概率权重
Step 2: 贝叶斯通路显著性 — Beta先验 × 加权差异结果似然 → 后验
Step 3: 不确定性感知排序 — 通路得分 = 后验概率 × (1 - 注释不确定性)
Step 4: Monte Carlo sensitivity — 注释扰动×1000次 → 鲁棒/脆弱发现分类
```

### 3.3 数据需求与来源

| 用途 | 数据集 | 来源 | 规模 |
|------|--------|------|------|
| CP校准 | NIST标准品 | NIST MS database | ~1000已知化合物 |
| 主验证集1 | ST001050 (2型糖尿病) | Metabolomics Workbench | 189样本 |
| 主验证集2 | MTBLS214 (结直肠癌) | MetaboLights | 100样本 |
| 可重复性 | Dunn CAMCAP cohort | 公开 | 299样本 |
| 同分异构体 | ashwagandha extract 2025 | AC 2025文章 | 多批次 |

**数据可行性**：高。前4个数据集完全公开。

### 3.4 预期贡献

**量化目标**：
- 通路假阳性率：比标准工作流降低≥30%
- 跨队列通路可重复性：前10条通路Jaccard重叠率≥0.6（vs标准≤0.4）
- 同分异构体：≥3个真实案例展示模糊性影响通路结论

### 3.5 论文结构大纲

**Title候选**：
- "End-to-end uncertainty propagation from metabolite annotation to pathway analysis in untargeted metabolomics"

**主要Figures（6-7张）**：
- Fig 1: 端到端框架概念图（三阶段不确定性流动）
- Fig 2: CP校准验证（coverage vs confidence曲线）
- Fig 3: 注释感知加权差异分析（vs等权重方法ROC/PR对比）
- Fig 4: 同分异构体案例研究（3个真实案例）
- Fig 5: 端到端通路结果（可重复性+假阳性率）
- Fig 6: Sensitivity analysis（鲁棒vs脆弱发现泡泡图）

**目标期刊**：Nature Methods。备选：Molecular & Cellular Proteomics、Analytical Chemistry

### 3.6 执行时间线

| 阶段 | 时间 | 里程碑 | 门控点 |
|------|------|--------|--------|
| Phase 1: CP框架 | 月1-3 | conformity score设计+校准 | empirical coverage ≥ nominal (±5%) |
| Phase 2: 加权差异分析 | 月4-6 | IHW框架+同分异构体处理 | 加权precision ≥ 等权重方法 |
| Phase 3: 贝叶斯通路 | 月7-9 | 概率通路映射+Monte Carlo | Jaccard重叠率 ≥ 0.5 |
| 整合+写作 | 月10-12 | R/Python包、bioRxiv(月11)、投稿NatMethods(月12) | — |
| 审稿响应 | 月13-18 | 预留NatMethods大修 | — |

### 3.7 风险矩阵

| 风险 | 概率 | 影响 | 缓解策略 |
|------|------|------|---------|
| arXiv 2026-03-10扩展到差异分析层 | 中 | 高 | 监控Ghent大学Waegeman组；bioRxiv时间点前置(月11)；差异化叙事(他们无同分异构体处理) |
| MassID扩展到差异分析加权 | 中 | 高 | 商业产品发论文慢；学术vs商业差异化 |
| CP覆盖率保证在真实数据失败 | 中 | 高 | 退回经验置信估计；重定位为"实用框架" |
| NatMethods拒稿 | 中 | 中 | 备选：MCP、AC、Bioinformatics |
| MassID市场化加速论文输出 | 中 | 中 | 6-12月内完成方向B，不拖到18月 |

---

## 4. 组合协同与依赖关系

### 4.1 MNAR-VAE如何为组合A铺路

1. **数据质量依赖**：差异分析功效直接受缺失值填补质量影响
2. **化学属性基础设施共享**：MW/logP/TPSA查询系统两方向复用
3. **数据集重用**：MTBLS1、ST001050、Dunn数据集双向使用
4. **叙事协同**：化学先验路线的独立验证

### 4.2 共享基础设施

| 组件 | 方向A | 方向B | 建设时间 |
|------|-------|-------|---------|
| 化学属性查询系统 | 核心 | CCS先验补充 | 月1-2 |
| MetaboLights数据预处理脚本 | 核心 | 核心 | 月1-2 |
| HMDB/GNPS注释pipeline | 特征注释 | 候选生成 | 月1-2 |

### 4.3 时间线耦合

```
Month 1-2: 共享基础设施
Month 3-8: 方向A独立推进 → Month 6 bioRxiv → Month 8 投AC
Month 1+:  方向B Phase 1可并行启动（不强依赖A）
Month 7+:  方向B利用A的化学属性基础设施
Month 11:  方向B bioRxiv → Month 12 投NatMethods
```

---

## 5. 竞争格局总结

### 5.1 方向A竞争者

| 论文 | 重叠度 | 关键差异 |
|------|--------|---------|
| MetImputBERT (BriefBioinf 2025) | 中 | NMR数据，BERT架构，无化学先验 |
| MMISVAE (Sci Reports 2025) | 中-高 | VAE相似，但无化学结构先验 |
| Multi-scale VAE (CBM 2024) | 中 | 利用基因组信息非化学属性 |
| ImpLiMet (BioinfAdv 2025) | 低 | 传统方法比较，无DL |

**结论**：无致命竞争，差异化需精确叙事——"化学结构先验"是核心区别点。

### 5.2 方向B竞争者

| 论文 | 重叠度 | 关键差异 |
|------|--------|---------|
| arXiv 2026-03-10 | 高（注释层） | 仅Phase 1，不传播到下游 |
| MassID (bioRxiv 2026-02) | 高（注释+FDR） | 差异分析等权重；商业产品 |
| BAUM (BriefBioinf 2024) | 中（通路层） | 计算量大，无差异分析层加权 |
| MetaboAnalystR 4.0 (NC 2024) | 中（通路层） | 差异分析层无注释加权 |
| IDP (AC 2025) | 中（注释层） | 不传播到下游 |

**结论**：差异分析层加权（Phase 2）是真实空白。完整三阶段无直接竞争。

### 5.3 抢先占位策略

| 时间 | 行动 | 目的 |
|------|------|------|
| Month 6 | 方向A bioRxiv | 占位"化学先验imputation" |
| Month 8 | 方向A投AC | 快速发表 |
| Month 11 | 方向B bioRxiv | 占位完整三阶段框架 |
| Month 12 | 方向B投NatMethods | 旗舰论文 |

---

## 6. 压力测试结果

### 6.1 验证通过的假设

| 假设 | 结论 |
|------|------|
| 化学属性与MNAR缺失概率相关 | ✅ 极性/logP/TPSA与检测效率有充分文献支持 |
| 现有方法不利用化学先验 | ✅ 系统检索确认无一方法使用 |
| RT可作为logP代理 | ✅ 反相色谱标准假设 |
| 差异分析层注释加权是真实空白 | ✅ MassID/BAUM/MetaboAnalystR均不覆盖 |
| CP在代谢物注释上可行 | ✅ 酶功能注释NC 2024+内分泌干扰物ABC 2025有先例 |
| 注释不确定性传播改变通路结论 | ✅ BAUM文献明确引用4%误识别率导致假阳性通路 |
| 完整三阶段无直接竞争 | ✅ 截至2026-03-16无覆盖完整链条的论文 |

### 6.2 压力测试发现的新风险

1. **MassID市场化风险**：Panome Bio 2026-02-25发布商业产品，有动机快速扩展。需6-12月完成方向B
2. **arXiv 2026-03-10作者**：Ghent大学Waegeman组是CP领域知名组，需持续监控
3. **"To Impute or Not To Impute" (JASMS 2025)**：反imputation元分析，需正面回应

---

## 7. Go/No-Go门控标准

### 方向A（月5门控）

| 条件 | 决策 |
|------|------|
| NRMSE降低≥10%（已注释子集） | Go |
| NRMSE降低<5%且消融显示化学先验无效 | Pivot：缩小为"缺失机制分类" |
| NRMSE降低<5%且未注释>70% | Pivot：聚焦脂质组学MNAR |
| 发现直接对应论文 | Stop：资源转方向B |

### 方向B（月3门控）

| 条件 | 决策 |
|------|------|
| CP empirical coverage ≥ nominal (±5%) | Go Phase 2 |
| CP失败但经验估计有效 | Pivot：去掉理论保证叙事 |
| arXiv组在月6前发表差异分析加权 | Pivot：聚焦同分异构体+CCS+Phase 3 |
| MassID在月9前发表差异分析加权 | 评估重叠度后决定 |

---

## 8. 可选扩展：B8 ISF-MNAR联合建模（吸收为实验章节）

> 从独立方向降级为MNAR-VAE论文的可选实验节（v1.1更新，2026-03-16）

### 8.1 背景

ISF假阳性峰会污染MNAR填补模型的训练数据——ISF产生的"虚假特征"被当作真实缺失值建模，导致填补系统性偏差。影响量估计3-7%，作为独立论文不足以发AC，但作为MNAR-VAE的实验章节有增量价值。

### 8.2 在MNAR-VAE论文中的位置

在Fig 5（消融研究）之后加一个实验：
- **Fig 6（可选）**：ISF-aware vs ISF-unaware填补对比
- 方法：用Plan 4 ISF检测器标记ISF候选峰，CP-MNAR-VAE的先验网络加入ISF标志位
- 预期结果：在3-7%的ISF相关特征上，ISF-aware填补NRMSE显著低于ISF-unaware

### 8.3 前置依赖

- Plan 4 ISF-GNN检测器至少完成M6（有可用的ISF标记输出）
- 如果Plan 4延迟，此章节可跳过不影响MNAR-VAE核心论文

### 8.4 工作量估计

额外1-2周实验 + 0.5周写作，不影响主时间线。

---

## 参考资料

**直接竞争（需持续跟踪）**：
- arXiv 2026-03-10 "When should we trust the annotation?" — Phase 1最直接竞争
- MassID bioRxiv 2026-02-11 — 注释层+FDR竞争
- BAUM Briefings in Bioinformatics 2024 — Phase 3相关
- MetaboAnalystR 4.0 Nature Communications 2024 — 通路层加权

**方向A基础文献**：
- MMISVAE Sci Reports 2025 — VAE架构参考
- ImpLiMet Bioinformatics Advances 2025 — 基线工具
- GINA PMC 2023 — 可识别性框架
- To Impute or Not To Impute JASMS 2025 — 需回应的反叙事

**方向B基础文献**：
- IDP Analytical Chemistry 2025 — 注释概率量化
- CP for enzyme function Nature Communications 2024 — CP先例
- Dark metabolome Nature Metabolism 2024-2025 — 动机叙事
