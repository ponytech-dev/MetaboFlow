# 代谢组学算法科研方向 — 最终研究计划书（详细版）

**版本**: v2.0 Detailed | **日期**: 2026-03-16
**前提**: 所有方向作为独立代谢组学/质谱算法科学问题评估，dry lab，公开数据，单人12-18月可完成

---

## 一、总体战略

### 1.1 研究版图

8个独立方向/组合，按3个优先级梯队推进，2年内产出6-8篇一作论文（2-3篇NC/NatMethods + 4-5篇AC）。

核心逻辑：3个战略组合（A/B/C+）各瞄准不同期刊梯队，5个独立方向提供技术基础和论文储备。方向之间有明确的数据/代码共享关系，最大化复用。

### 1.2 八个方向一览

| # | 方向 | 评分 | 目标期刊 | 投稿时间 | 优先级 |
|---|------|------|---------|---------|--------|
| 1 | 组合A: 端到端UQ传播链 | 8.7-9.0 | Nature Methods | M12 | A |
| 2 | 组合B v2: 临床功效框架 | 8.5 | AC→NC(50%) | M9(AC)/M14(NC) | A |
| 3 | 组合C+: 可重复性图谱 | 8.0-8.5 | NC→NatMethods条件 | M14 | A |
| 4 | MNAR-VAE化学先验填补 | 7.5 | Analytical Chemistry | M8 | A（最快产出） |
| 5 | ISF-aware全流程框架 | 7.5 | AC→NC条件(Phase 2) | M12 | B |
| 6 | SC代谢物→通量约束 Y1 | 7.0-7.5→POC后8.5-9.0 | AC→NM条件 | M9 | B |
| 7 | GC-MS自监督预训练 | 7.0-7.5 | AC | M15 | B |
| 8 | Ensemble场景自适应加权 | 7.0-7.5→8.0 | AC→NC条件 | M20 | C |

### 1.3 方向间依赖关系

```
MNAR-VAE (#4) ───→ 组合A (#1) 数据质量前置 + 化学属性基础设施共享
                ├── 可选扩展：B8 ISF-MNAR实验章节（依赖ISF #5）
                └── 可选扩展：Y2环境归因Discussion段落

组合C+ (#3) ───→ Ensemble (#8) 系列第二篇
            ├── ISF (#5) 提供ISF维度数据
            ├── 组合A (#1) CP模块提供注释UQ维度
            └── 可选：TDA 2D峰检测POC（1-2周）

组合B (#2) ←───→ 组合C+ (#3) 通过B5引擎-功效关系桥接

GC-MS (#7) ←───→ 组合C+ (#3) 互引 + 评估框架共享

SC通量 (#6) ──── 独立，无硬依赖
```

---

## 二、方向 #4：MNAR-VAE化学先验填补（AC 7.5，最快产出）

### 2.1 科学问题定义

**核心问题**：质谱代谢组学中，离子强度低于检测限导致的MNAR缺失（约占总缺失值的60-80%）是系统性的、非随机的。现有最优方法（QRILC、GSimp、MissForest）将代谢物视为独立特征，忽略了一个基本事实：**一个代谢物是否被检测到，受其物理化学属性决定**——极性高的代谢物更容易因离子化效率低而缺失，分子量大的分子更难挥发，logP低的化合物在反相色谱中保留时间短而容易丢失。

这个先验知识是免费的（来自HMDB/PubChem等公开数据库），但没有任何现有填补方法利用它。

**精确陈述**：在MNAR条件下，设计一个利用化学属性先验信息（MW, logP, 极性面积/TPSA, 电荷状态）的structure-informed VAE，使缺失机制建模更准确，填补误差在真实MNAR场景下比现有最优方法降低≥20%。

### 2.2 方法设计：CP-MNAR-VAE架构

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
- 化学属性通过**cross-attention**而非简单concatenation注入：允许模型选择性地关注对当前缺失模式最相关的化学维度
- MNAR惩罚项参考 MMISVAE (Sci Reports 2025) 的多重重要性采样思路
- 可识别性参考 GINA (PMC 2023) 的框架

**化学属性获取**：PubChemPy API（MW, logP, TPSA, 极性）+ RDKit计算。未注释特征用LC保留时间作为logP代理（RT~logP在反相色谱中显著相关）。

### 2.3 数据需求与来源

| 数据集 | 类型 | 样本量 | 特征数 | 获取方式 | 化学属性来源 |
|--------|------|--------|--------|----------|------------|
| MTBLS1 (MetaboLights) | 人血清LC-MS | 132样本 | ~1000特征 | 公开下载 | HMDB/PubChem API |
| ST000001 (Metabolomics Workbench) | 尿液LC-MS | 60样本 | ~500特征 | 公开下载 | 同上 |
| MTBLS2 (MetaboLights) | 植物LC-MS | 140样本 | ~800特征 | 公开下载 | 同上 |
| Dunn et al. 2012 CAMCAP | 血浆 | 299样本 | 2098特征 | 公开 | 同上 |
| ImpLiMet benchmark数据集 | 多类型 | 已标准化 | 多规模 | GitHub/文章补充 | 同上 |

### 2.4 竞争格局

| 论文 | 重叠度 | 关键差异 |
|------|--------|---------|
| MetImputBERT (BriefBioinf 2025) | 中 | NMR数据，BERT架构，无化学先验 |
| MMISVAE (Sci Reports 2025) | 中-高 | VAE相似，但无化学结构先验 |
| Multi-scale VAE (CBM 2024) | 中 | 利用基因组信息非化学属性 |
| ImpLiMet (BioinfAdv 2025) | 低 | 传统方法比较，无DL |

**结论**：无致命竞争，差异化窗口真实但窄，需精确叙事——"化学结构先验"是核心区别点。

### 2.5 量化目标

- **NRMSE**（已知MNAR场景）：比QRILC降低≥20%，比MissForest降低≥15%
- **下游差异分析**：假阳性率比QRILC降低≥10%
- **化学解释性**：对"为什么缺失"的概率预测AUC≥0.75
- **基线对比方法**：QRILC、GSimp、MissForest、kNN、MMISVAE

### 2.6 论文结构与Figure设计

**Title候选**：
- "Chemical structure-informed imputation of missing not at random values in untargeted metabolomics"
- "CP-MNAR-VAE: A structure-aware variational autoencoder for MNAR missing value imputation in LC-MS metabolomics"

**主要Figures（5-6张）**：
- **Fig 1**: 方法架构图 — 化学先验通过cross-attention注入VAE编码器/解码器的概念图，展示缺失机制建模和化学属性流
- **Fig 2**: 模拟MNAR基准测试 — 多数据集NRMSE对比（柱状图+热图），5个数据集×6个方法
- **Fig 3**: 化学属性与缺失概率的关系分析 — logP vs 缺失率散点图（logP最强预测因子验证），MW/TPSA偏依赖图
- **Fig 4**: 真实数据集下游影响 — 差异分析火山图对比（标准填补 vs CP-MNAR-VAE），通路分析结果差异
- **Fig 5**: 消融研究 — 去掉化学先验/MNAR惩罚/cross-attention各组件后的性能下降量化（条形图）
- **Fig 6（可选）**: ISF-aware vs ISF-unaware填补对比（+1-2周，依赖ISF #5 M6产出）

**目标期刊**：Analytical Chemistry。备选：Bioinformatics、Briefings in Bioinformatics

### 2.7 执行时间线

| 阶段 | 时间 | 周级分解 | 里程碑 | 门控点 |
|------|------|---------|--------|--------|
| 数据准备与基础设施 | M1-2 | W1-2:下载数据; W3-4:化学属性查询pipeline; W5-6:数据预处理+EDA; W7-8:基线方法统一接口 | 化学属性查询系统可用 | 注释覆盖率<25%则切换RT代理方案 |
| 模型实现 | M3-4 | W9-10:VAE骨架; W11-12:cross-attention化学先验注入; W13-14:MNAR惩罚项; W15-16:调参+初步对比 | PyTorch实现完成 | 基础VAE≥kNN性能 |
| 实验与消融 | M5-6 | W17-18:完整benchmark(5数据集); W19-20:消融研究; W21-22:下游差异分析验证; W23-24:化学解释性分析 | Fig 2-5数据完成 | **★M5关键门控：NRMSE改进≥10%** |
| 下游验证与写作 | M7-8 | W25-26:Python包整理; W27-28:论文初稿; W29-30:内审修改; W31-32:投稿 | 论文投AC | — |

**bioRxiv占位**：M6。**AC投稿**：M8。

### 2.8 可选扩展（不影响核心论文）

- **B8 ISF-MNAR实验章节**：ISF-aware vs unaware填补对比（+1-2周，依赖ISF #5 M6产出）
  - 方法：用Plan 4 ISF检测器标记ISF候选峰，CP-MNAR-VAE的先验网络加入ISF标志位
  - 预期：在3-7%的ISF相关特征上，ISF-aware填补NRMSE显著低于ISF-unaware
  - 前置依赖：Plan 4 ISF-GNN至少完成M6
- **Y2 Discussion段落**：外源代谢物缺失模式与内源不同的应用讨论（+0.5周）

### 2.9 风险矩阵

| 风险 | 概率 | 影响 | 缓解策略 |
|------|------|------|---------|
| 化学属性覆盖率不足（未注释特征多） | 高 | 中 | RT作为logP代理；聚焦已注释特征子集 |
| VAE在MNAR条件下不可识别 | 中 | 高 | GINA框架充分条件；否则转向实用性论证 |
| NRMSE改进不显著（<10%） | 中 | 高 | 聚焦特定化学类别的选择性改进；缩小为"缺失机制分类" |
| 竞争者抢先 | 低-中 | 中 | Month 6上bioRxiv占位 |
| "To Impute or Not To Impute"反叙事 | 低 | 低 | 正面回应：MNAR场景下imputation有效，关键是用对方法 |

### 2.10 Go/No-Go门控

| 条件 | 决策 |
|------|------|
| NRMSE降低≥10%（已注释子集） | **Go** |
| NRMSE降低<5%且消融显示化学先验无效 | **Pivot**：缩小为"缺失机制分类" |
| NRMSE降低<5%且未注释>70% | **Pivot**：聚焦脂质组学MNAR |
| 发现直接对应论文 | **Stop**：资源转组合A |

---

## 三、方向 #1：组合A — 端到端UQ传播链（NatMethods 8.7-9.0，旗舰论文）

### 3.1 科学问题定义

**核心问题**：未靶向代谢组学中，从原始谱图到通路解读，每一步都有不确定性，但现有工作流将这些不确定性隔离处理或完全忽略。**一个注释置信度0.3的特征和置信度0.95的特征被同等对待**，进入同一个差异分析，最终影响通路结论。

**精确陈述**：设计并验证一个三阶段UQ传播框架，使注释不确定性显式地传播到差异分析（通过注释感知加权）和通路分析（通过贝叶斯不确定性传播），并在真实数据集上证明：相比标准工作流，端到端UQ传播能减少假阳性通路发现≥30%、提高通路可重复性≥50%。

### 3.2 方法设计（三阶段详细架构）

#### Phase 1: 保形预测（CP）注释UQ框架（M1-4）

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

**★M3门控**：empirical coverage ≥ nominal (±5%)

**与arXiv 2026-03-10的差异**：他们聚焦"是否该abstain"，不传播到下游。我们的CP校准置信集显式传播到差异分析和通路。

#### Phase 2: 注释感知加权差异分析（M4-9，★核心空白）

```
注释感知加权差异分析:
Step 1: 权重函数 w_i = p_i^β，β∈(0,1]
Step 2: 加权limma — w_i作为precision weights注入lmFit
Step 3: IHW (Independent Hypothesis Weighting) FDR校正
Step 4: 同分异构体专项 — 模糊节点，差异信号按概率分配

输出: 带双重不确定性（统计+注释）的差异分析结果表
```

**与现有方法的关键区别**：
- **BAUM**：贝叶斯非参数，计算量大，不适合大规模untargeted
- **MassID**：概率注释+FDR过滤，但差异分析仍等权重
- **MetaboAnalystR 4.0**：通路层加权，差异分析层未加权
- **我们**：差异分析层的注释感知加权 + 同分异构体模糊分配 → **真实空白**

#### Phase 3: 通路贝叶斯传播（M9-12）

```
Step 1: 概率通路映射 — 特征→候选集→通路的概率权重
Step 2: 贝叶斯通路显著性 — Beta先验 × 加权差异结果似然 → 后验
Step 3: 不确定性感知排序 — 通路得分 = 后验概率 × (1 - 注释不确定性)
Step 4: Monte Carlo sensitivity — 注释扰动×1000次 → 鲁棒/脆弱发现分类
```

### 3.3 数据需求与来源

| 用途 | 数据集 | 来源 | 规模 | 可行性 |
|------|--------|------|------|--------|
| CP校准 | NIST标准品 | NIST MS database | ~1000已知化合物 | 高 |
| 主验证集1 | ST001050 (2型糖尿病) | Metabolomics Workbench | 189样本 | 高（公开） |
| 主验证集2 | MTBLS214 (结直肠癌) | MetaboLights | 100样本 | 高（公开） |
| 可重复性 | Dunn CAMCAP cohort | 公开 | 299样本 | 高（公开） |
| 同分异构体 | ashwagandha extract 2025 | AC 2025文章 | 多批次 | 高 |

### 3.4 竞争格局

| 论文 | 重叠度 | 关键差异 |
|------|--------|---------|
| arXiv 2026-03-10 "When should we trust" | 高（注释层） | 仅Phase 1，不传播到下游 |
| MassID (bioRxiv 2026-02) | 高（注释+FDR） | 差异分析等权重；商业产品 |
| BAUM (BriefBioinf 2024) | 中（通路层） | 计算量大，无差异分析层加权 |
| MetaboAnalystR 4.0 (NC 2024) | 中（通路层） | 差异分析层无注释加权 |
| IDP (AC 2025) | 中（注释层） | 不传播到下游 |

**结论**：差异分析层加权（Phase 2）是真实空白。完整三阶段无直接竞争。

### 3.5 量化目标

- 通路假阳性率：比标准工作流降低≥30%
- 跨队列通路可重复性：前10条通路Jaccard重叠率≥0.6（vs标准≤0.4）
- 同分异构体：≥3个真实案例展示模糊性影响通路结论

### 3.6 论文结构与Figure设计

**Title候选**：
- "End-to-end uncertainty propagation from metabolite annotation to pathway analysis in untargeted metabolomics"

**主要Figures（6-7张）**：
- **Fig 1**: 端到端框架概念图 — 三阶段不确定性流动，从注释层→差异层→通路层的信息传播示意
- **Fig 2**: CP校准验证 — coverage vs confidence曲线，不同数据集的校准质量对比
- **Fig 3**: 注释感知加权差异分析 — vs等权重方法ROC/PR对比，展示加权后的精度提升
- **Fig 4**: 同分异构体案例研究 — 3个真实案例（亮氨酸/异亮氨酸、磷脂异构体等），展示模糊分配如何改变结论
- **Fig 5**: 端到端通路结果 — 可重复性Jaccard热图+假阳性率条形图
- **Fig 6**: Sensitivity analysis — 注释扰动×1000次后鲁棒vs脆弱发现泡泡图
- **Fig 7（可选）**: CCS先验对同分异构体消歧的附加效果

**目标期刊**：Nature Methods。备选：Molecular & Cellular Proteomics、Analytical Chemistry

### 3.7 执行时间线

| 阶段 | 时间 | 周级分解 | 里程碑 | 门控点 |
|------|------|---------|--------|--------|
| Phase 1: CP框架 | M1-3 | W1-4:conformity score设计; W5-8:校准集构建+校准; W9-12:prediction set生成+CCS先验 | CP框架可输出prediction sets | ★M3: empirical coverage ≥ nominal (±5%) |
| Phase 1→2过渡 | M4 | W13-16:IHW框架搭建+权重函数设计 | 加权差异分析原型 | — |
| Phase 2: 加权差异分析 | M5-8 | W17-20:limma集成+同分异构体处理; W21-24:多数据集验证; W25-28:ROC/PR分析; W29-32:消融对比 | Fig 3-4数据完成 | 加权precision ≥ 等权重方法 |
| Phase 3: 贝叶斯通路 | M9-11 | W33-36:概率通路映射; W37-40:Beta-likelihood框架; W41-44:Monte Carlo sensitivity | Fig 5-6完成 | Jaccard重叠率 ≥ 0.5 |
| 整合+写作 | M11-12 | W45-48:R/Python包整理+论文初稿+bioRxiv(M11)+投NatMethods(M12) | 投稿 | — |
| 审稿响应 | M13-18 | 预留NatMethods大修 | 接收 | — |

### 3.8 风险矩阵

| 风险 | 概率 | 影响 | 缓解策略 |
|------|------|------|---------|
| arXiv 2026-03-10组扩展到差异分析层 | 中 | 高 | 监控Ghent大学Waegeman组；bioRxiv时间点前置(M11)；差异化叙事(他们无同分异构体处理) |
| MassID商业加速论文输出 | 中 | 高 | 学术vs商业差异化；6-12月内完成 |
| CP覆盖率保证在真实数据失败 | 中 | 高 | 退回经验置信估计；重定位为"实用框架" |
| NatMethods拒稿 | 中 | 中 | 备选：MCP、AC、Bioinformatics |

### 3.9 Go/No-Go门控

| 条件 | 决策 |
|------|------|
| CP empirical coverage ≥ nominal (±5%) | **Go Phase 2** |
| CP失败但经验估计有效 | **Pivot**：去掉理论保证叙事 |
| arXiv组在M6前发表差异分析加权 | **Pivot**：聚焦同分异构体+CCS+Phase 3 |
| MassID在M9前发表差异分析加权 | 评估重叠度后决定 |

### 3.10 与MNAR-VAE的协同

1. **数据质量依赖**：差异分析功效直接受缺失值填补质量影响
2. **化学属性基础设施共享**：MW/logP/TPSA查询系统两方向复用
3. **数据集重用**：MTBLS1、ST001050、Dunn数据集双向使用
4. **叙事协同**：化学先验路线的独立验证
5. **暗代谢组叙事天然支持**：Giera-Siuzdak 2024-2025 Nature Metabolism辩论为"注释不确定性很重要"提供完美动机

### 3.11 抢先占位策略

| 时间 | 行动 | 目的 |
|------|------|------|
| M6 | MNAR-VAE bioRxiv | 占位"化学先验imputation" |
| M8 | MNAR-VAE投AC | 快速发表 |
| M11 | 组合A bioRxiv | 占位完整三阶段框架 |
| M12 | 组合A投NatMethods | 旗舰论文 |

---

## 四、方向 #3：组合C+ — 代谢组学可重复性图谱（NC 8.0-8.5 → NatMethods条件）

### 4.1 科学问题定义

代谢组学软件选择导致特征重叠率仅~8%，85%临床报告代谢物属统计噪声。MassCube NC 2025的benchmark是自我评估（4引擎，仅峰检测层），领域缺乏以可重复性本身为研究对象的系统性基准。

**MassCube NC 2025的实际覆盖 vs 本方案**：

| 评估维度 | MassCube NC 2025 | 我们的方案 |
|---------|-----------------|-----------|
| 引擎数量 | 4个 | 5个（+asari，MassCube未包含） |
| 峰检测精度 | 合成数据 | 合成+真实标准品+生物样本 |
| 批次效应 | **无** | 有（量化过度校正） |
| ISF策略比较 | 仅MassCube自身 | 各引擎ISF识别策略系统对比 |
| OT注释诊断 | **无** | 有（高余弦+高OT距离=边界注释） |
| CP注释UQ | **无** | 有（prediction set大小分布） |
| 暗代谢组跨引擎一致性 | **无** | 有（DreaMS嵌入，★核心） |
| 统计功效-引擎关系 | **无** | 有（非单调关系） |
| Multiverse分析 | **无** | 有 |
| 数据集 | 自产（偏向自身） | 100%独立公开MTBLS数据 |
| 结论立场 | 偏向MassCube | 中立，服务领域 |

### 4.2 引擎选择与配置

| 引擎 | 版本 | 运行方式 | 备注 |
|------|------|---------|------|
| XCMS | 4.8.0 | R脚本，支持自动化 | 活跃维护，Bioconductor |
| MS-DIAL | 5.5.250920 | CLI(MsdialConsoleApp)，需Wine/Docker | 最新版支持IMS |
| MZmine | 4.9 | CLI batch模式 | headless可用 |
| asari | 1.13.1 | Python CLI，最易自动化 | 2023 NC，MassCube未包含 |
| MassCube | 最新稳定版 | Python CLI | 作为参照引擎 |

**参数空间（Multiverse）**：每引擎3配置（默认/宽松/严格）→ 5×3=15套流水线。

### 4.3 6维度评估框架详细设计

**维度1 — 批次效应模块**：
- 使用已知组间差异数据集（MTBLS264含QC样本）
- 指标：QC的CV变化、已知差异代谢物信号保真度、"校正前应显著但校正后消失"的特征数（过度校正指数）
- 参照2025 bioRxiv "benchmarking batch correction workflow"框架

**维度2 — ISF影响维度**：
- 各引擎ISF识别策略：MassCube(coelution-based)、MS-DIAL(ion mobility)、XCMS(CAMERA)、asari(无内置)
- 构建ISF-非ISF分类的引擎间一致性矩阵（Jaccard相似度）
- 输出：ISF处理策略图谱，量化"引擎选择对暗代谢组规模的影响"

**维度3 — OT注释诊断**：
- 计算引擎-参考库之间的Wasserstein距离
- 诊断：余弦>0.8 且 OT距离>阈值θ → "边界注释"
- Sinkhorn算法GPU加速，O(n log n)，RTX 4090上100k特征可行（JACS Au 2025实测）
- 产出：各引擎注释质量"精确-边界-错误"三分类图

**维度4 — B1 CP注释UQ**：
- 使用已注释子集作为calibration set
- 为每引擎生成prediction sets（置信度1-α）
- 比较各引擎prediction set大小分布（set越小=越确定）
- 可用：arXiv 2026-03-10 SGR算法

**维度5（★B3）— 暗代谢组跨引擎一致性（NatMethods升级关键）**：
- 定义"暗代谢组特征"：未匹配数据库 + 有MS2 + DreaMS嵌入质量>阈值
- 跨引擎特征对应：m/z±5ppm + RT±0.2min + DreaMS embedding余弦>0.85
- 输出：跨引擎一致性矩阵，区分"真实未知代谢物"vs"引擎artefact"
- 核心假设：~30-50%暗代谢组特征仅1个引擎出现，另一批在5个引擎均稳定
- DreaMS（Nature Biotechnology 2025）：API公开，DreaMS Atlas 2.01亿条MS/MS

**维度6（B5）— 引擎-统计功效关系**：
- 同一数据集（已知组间差异）×5引擎×3参数 → 每套跑Mann-Whitney + FDR
- 预期：引擎选择与功效非单调关系（asari某类丢特征降功效，另一类噪声低升功效）

### 4.4 数据需求

| 数据集 | 基质 | 仪器 | 样本量 | 用途 |
|--------|------|------|--------|------|
| MTBLS264 | 人血浆 | Orbitrap | 500+ | 批次效应+主基准 |
| MTBLS87 | 人尿液 | QTOF | 100+ | ISF比较 |
| MSV000083388 | 血浆NIST SRM1950 | Orbitrap | 参照标准品 | 峰检测ground truth |
| MTBLS733/736 | 标准品混合物 | Q Exactive HF | 1100化合物 | 注释基准 |

**计算资源**：15配置×5数据集≈200-400 CPU小时，建议HPC或AWS EC2。OT计算需GPU（RTX 3090/4090级）。

### 4.5 NatMethods升级路径 — B3暗代谢组验证

**阶段一（M9，内部验证）**：MTBLS264上5引擎暗代谢组一致性分析。
**阶段二（M10，网络分析）**：DreaMS Atlas分子网络确认暗代谢组在2.01亿公开谱图中的频率。
**阶段三（M11，跨中心）**：如有合作数据，3个独立中心验证。

**Go/No-Go门控（M11）**：

| 指标 | NC路线阈值 | NatMethods路线阈值 |
|------|-----------|-----------------|
| B3跨引擎稳定暗代谢物数量 | >200 | >500 |
| 单引擎独有比例 | >20% | >30% |
| DreaMS Atlas验证 | 不要求 | ≥80%有聚类支持 |
| 跨中心验证 | 不要求 | 至少2个独立中心 |

### 4.6 论文结构与Figure设计

**Title候选**：
1. "A Metabolomics Reproducibility Atlas: Systematic Benchmarking of LC-MS Processing Engines Across Six Analytical Dimensions"
2. "Engine-Dependent Reproducibility in Untargeted Metabolomics: A Cross-Engine Benchmark Reveals Systematic Failure Modes"

**Main Figures（7张）**：
- **Fig 1**: 概念图+框架 — 5引擎×6维度矩阵热图（综合得分），上方引擎家族树，左侧维度分类
- **Fig 2**: 峰检测基准 — MTBLS733标准品precision-recall曲线，5引擎×左单峰右双峰
- **Fig 3**: Multiverse分析 — 同一数据集×15参数配置火山图"multiverse"
- **Fig 4**: 批次×ISF — 批次校正前后PCA轨迹；ISF识别策略对比
- **Fig 5**: 注释质量（OT+CP）— 精确-边界-错误分布+保形预测覆盖曲线
- **Fig 6**: ★暗代谢组（B3）— DreaMS嵌入空间跨引擎重叠热图+Venn图
- **Fig 7**: 引擎-功效（B5）— 已知差异代谢物回收率×5引擎×3参数+推荐决策树

### 4.7 执行时间线（14个月）

| 阶段 | 时间 | 详细任务 | 里程碑 |
|------|------|---------|--------|
| 基础设施 | M1-2 | 5引擎Docker安装+4数据集下载验证+Snakemake/Nextflow框架+DreaMS部署 | 全流水线1个小数据集端到端 |
| 峰检测基准 | M3-4 | MTBLS733标准品5引擎峰检测+precision-recall框架 | Fig 2初稿 |
| 批次+ISF | M5-6 | MTBLS264批次分析+ISF策略矩阵 | Fig 3,4初稿 |
| OT+CP+Multiverse | M7-8 | Sinkhorn OT实现+CP框架+15配置扫描(HPC) | Fig 5初稿 |
| ★B3暗代谢组 | M9-11 | DreaMS嵌入+跨引擎一致性+Atlas验证+Go/No-Go决策 | Fig 6完成 |
| B5功效 | M12 | 引擎-功效分析+决策树 | Fig 7完成 |
| 写作 | M13 | 综合结论+GitHub代码库+初稿 | 初稿 |
| 投稿 | M14 | NC或NatMethods（取决于B3） | 投稿 |

### 4.8 风险矩阵

| 风险 | 概率 | 影响 | 缓解策略 |
|------|------|------|---------|
| MS-DIAL Linux自动化困难 | 高 | 中 | Wine+CLI或Docker，降级到MS-DIAL 4.9 |
| OT资源超预期 | 中 | 中 | 限定10k特征子集，Sinkhorn ε可调 |
| B3暗代谢组无新发现（引擎趋同） | 中 | 高 | 趋同本身也是发现；降级NC |
| MassCube发布v2含更多引擎 | 低 | 中 | 中立立场和全维度覆盖是根本差异化 |
| DreaMS嵌入质量不足 | 低 | 中 | 备用：MS2余弦聚类替代 |
| 引擎更新导致不可重复 | 高（长期） | 中 | Docker锁定版本 |

---

## 五、方向 #2：组合B v2 — 临床功效框架（AC 8.5 / NC 50%）

### 5.1 科学问题定义

大多数代谢组学研究没有做功效分析。2024年244项临床代谢组学研究meta分析：2,206个报告显著代谢物中72%只在单一研究出现，85%被估计为统计噪声。根本原因是研究设计阶段的系统性失误。

**现有工具的共同缺陷**：

| 工具 | 发表 | 方法 | 局限 |
|------|------|------|------|
| MetSizeR | 2013 | PPCA/PPCCA | 仅限2种分析；不处理MNAR |
| MetaboAnalyst/SSPA | 2015+ | pilot→效应量分布 | 强依赖pilot；SSPA原设计面向基因组 |
| MultiPower | 2020 NC | 多组学统一 | 忽略LOD-driven MNAR |
| MOPower | 2021 | 多组学模拟器 | preprint；基本等同MultiPower |

**创新空间**：整合MNAR感知 + Winner's Curse + 因果效应量 + 通路级 → 统一框架。系统性缺失，非边缘改进。

### 5.2 6个模块方法设计

#### 模块1：MNAR-aware Bootstrap功效估计

1. **缺失机制识别**：基于强度分布的left-censoring检验（KS against truncated normal），区分MNAR/MAR/MCAR
2. **截断参数估计**：MLE估计LOD阈值（μ_LOD）和截断比例（π_MNAR）
3. **MNAR-aware重采样**：bootstrap重采样保留正确MNAR结构
4. **功效计算**：每个bootstrap样本计算功效，取中位数和95% CI

**与现有方法差异**：MetSizeR/SSPA从完整数据重采样，隐含假设缺失与结果无关。我们保留"低丰度代谢物在小样本中更可能完全消失"信息。

**理论约束**：在left-censored MNAR假设下一致，其他MNAR机制可能产生偏差。需做敏感性分析。

#### 模块2：ENIT替代FDR-adjusted功效

```
ENIT(n) = Σ_i [power_i(n) × π_1_i]
```

ENIT（预期发现真阳性数）比FDR-adjusted平均功效更有临床意义："花这些钱能发现几个真实的生物标志物"。创新在于系统化为代谢组学功效分析主要输出指标，结合π_1的代谢组学先验估计。

#### 模块3：Winner's Curse校正

三层校正：
1. **检测层**：效应量分布极端值检验
2. **校正层**：Bootstrap Truncated Maximum Likelihood（BTML）或winnerscurse R包
3. **功效输入层**：校正后效应量作为功效计算输入

代谢组学适配：用代谢物相关矩阵替代LD矩阵；用ENT调整后等价阈值替代GWAS p<5e-8。

**量化影响**：GWAS 35%关联效应量高估；代谢组学小样本研究中比例预计更高。

#### 模块4：MR因果效应量输入（NC核心差异化）

1. **数据来源**：UK Biobank NMR GWAS summary statistics（251代谢物，公开）+ IEU Open GWAS ~100个靶向代谢物
2. **IV质量控制**：F>10门控；RIVW估计量处理弱IV+WC联合偏差
3. **效应量转换**：MR因果→代谢物~疾病状态差异量
4. **无mQTL代谢物**：标记"MR-ineligible"，回退WC-corrected观察效应量

**关键限制**：仅~425个靶向/NMR代谢物可做MR，不覆盖LC-MS未靶向。NC claim范围需缩小为"靶向/NMR代谢物的因果效应量框架"。

#### 模块5：通路级功效分析

```
Pathway_power(n, P) = f(
  individual_powers_i(n),    # 通路内各代谢物单变量功效
  Σ_P,                       # 通路内代谢物协方差矩阵
  coverage_rate(P),          # 当前平台覆盖该通路的比例
  annotation_uncertainty(P)  # 通路注释置信度
)
```

M_eff（有效独立测试数）用Nyholt特征值方法估计。代谢通路内代谢物高度相关（底物-产物r>0.7常见），M_eff远小于代谢物数。

#### 模块6：临床验证框架

对标2025 FDA BMV指导原则：
- Discovery → 模块1+3 → 正确功效下的样本量建议
- Replication → 模块3 → WC校正后独立验证最小样本量
- Clinical qualification → 模块6 → FDA BMV分析验证+临床验证检查清单

#### 吸收模块

- **B2注释感知功效**：`effective_power = raw_power × P(correct_annotation | MSI_level)`，作为敏感度分析章节
- **B5引擎-功效关系**：桥接组合C+，不同引擎产生不同缺失率影响MNAR-aware功效估计

### 5.3 数据需求

| 数据集 | 用途 | 可得性 |
|--------|------|--------|
| MTBLS1 / MTBLS2 | MNAR模块基准测试 | 立即可用 |
| MTBLS264 | 平台差异验证 | 立即可用 |
| UK Biobank NMR GWAS summary stats | mQTL/IV来源 | 立即可用（公开） |
| UK Biobank NMR个体数据 | MR模块验证（NC路径） | 申请需3-6月 |
| GWAS Catalog mQTL数据 | 非NMR代谢物IV | 立即可用 |

### 5.4 论文结构

**AC版 MetaPower** — Figures 5个：
1. 框架总览：MNAR-aware bootstrap + WC校正 + ENIT输出
2. MNAR对功效的影响：不同MNAR比例下传统 vs MetaPower
3. WC量化：代谢组学效应量膨胀经验分布
4. ENIT vs 平均功效：预测准确性比较
5. 通路级功效：TCA循环和脂质通路案例

**NC版增加**：
- Fig 6：MR因果效应量 vs 观察效应量的功效差异（UK Biobank 251代谢物）
- Fig 7（可选）：通路级MR功效

### 5.5 执行时间线（14个月）

**阶段0：基础设施（M1-M2）**

| 任务 | 时间 | 产出 |
|------|------|------|
| MetaboLights数据下载 | W1-2 | 基准测试数据 |
| 现有工具复现（MetSizeR, SSPA, MultiPower） | W2-4 | 基准线结果 |
| MNAR模拟框架编码 | W3-6 | 模块1原型 |
| UK Biobank GWAS summary stats下载 | W4 | mQTL数据 |
| UK Biobank研究申请提交 | M2末 | 申请编号 |
| **★Gate 1（M2末）** | — | mQTL可用代谢物>50个 + MNAR效应>15% |

**阶段1：AC核心方法（M3-M6）**

| 任务 | 时间 | 产出 |
|------|------|------|
| MNAR-aware bootstrap理论+实现 | M3-4 | 模块1完成 |
| WC代谢组学实证量化 | M3-5 | Fig 3数据 |
| ENIT框架实现 | M4-5 | 模块2完成 |
| 通路级功效（M_eff校正） | M5-6 | 模块5原型 |
| R包MetaPower v0.1 | M6末 | 可运行软件 |

**阶段2：AC验证+写作（M7-M9）**

| 任务 | 时间 | 产出 |
|------|------|------|
| MTBLS数据集基准验证 | M7-8 | Figs 1-5数据 |
| AC版论文写作 | M8-9 | 初稿 |
| **AC投稿** | M9末 | Bioinformatics/Metabolomics |

**阶段3：NC扩展（M10-M14，依UKB）**

| 任务 | 时间 | 前置条件 |
|------|------|---------|
| MR模块 + RIVW/dIVW | M10-11 | UKB申请批准 |
| UK Biobank NMR分析 | M11-12 | UKB数据访问 |
| MVMR通路内IV处理 | M12-13 | MR完成 |
| NC额外Figures | M13-14 | UKB分析结果 |
| **NC投稿** | M14末 | Nature Methods/Genome Biology |

### 5.6 风险矩阵

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| UKB申请>6月 | 40% | NC延迟 | M2提交；AC不依赖 |
| MNAR bootstrap审稿质疑 | 35% | 需额外模拟 | 预做3种MNAR假设敏感性 |
| MR弱IV无法被RIVW解决 | 25% | NC差异化减弱 | 限定F>10；弱IV单独标注 |
| MetaboAnalyst 7.0抢先 | 20% | 竞争加剧 | 开源R包投稿前发布 |
| WC量化无法复现35% | 30% | 核心论据削弱 | 独立估计本身是贡献 |

### 5.7 Go/No-Go门控

**Gate 1（M2末）**：mQTL可用代谢物<50个 且 MNAR效应<15% → 重定位为纯方法论模拟论文

**AC投稿门控（M9）**：
- MNAR方法优于现有（≥2个真实数据集）
- WC原创量化（≥3个研究效应量分布）
- R包可运行（有文档和vignette）
- 通路级案例（TCA+氨基酸代谢）

**NC投稿门控（M14）**：
- UKB数据访问批准
- MR效应量>100个代谢物完整分析
- WC+弱IV联合校正模拟验证通过

---

## 六、方向 #5：ISF-aware全流程框架（AC 7.5 → NC条件）

### 6.1 科学问题定义

ISF峰占LC-MS特征>70%（Nature Metabolism 2024），但所有工具（ISFrag/MS1FA/MassCube）都是事后注释，不在峰检测阶段介入。

**竞争地图**：
```
                    事后注释           全流程感知
规则引擎/统计   ISFrag/CAMERA/MS1FA/MassCube    空白
机器学习/GNN          空白              ★我们的位置
```

我们的位置是唯一空白象限：**学习型方法 × 全流程感知**。

### 6.2 方法设计

#### ISF检测：GNN架构

**为什么GNN（非规则引擎/RF/XGBoost）**：

现有规则引擎局限：
- 未知碎裂模式无法覆盖（level 2/3识别率下降）
- 不同仪器/源电压条件下规则需重调参
- 无法捕捉高阶关系（多ISF、ISF与同位素/加合物共存）

GNN核心优势：
- RF/XGBoost对每个特征对独立分类（是否ISF关系）
- GNN对整个特征图推断，一次预测整个ISF子图结构
- 能利用传播关系："如果A是B的ISF，C也共洗脱且有质量差，则C很可能也是B的ISF"

**推荐架构**：
- 节点嵌入：m/z残差 + RT标准化 + 强度比 + MS2点积相似度
- 图构建：sliding RT窗口（±0.05 min）内全连接图，边权重由m/z差和相关系数决定
- 模型：GAT（Graph Attention Network）+ 二分类头（ISF/非ISF）
- 对比基线：ISFrag规则引擎 + RF/XGBoost + MassCube内置

**诚实承认**：GNN优势在标准样本上可能不显著，主要优势在复杂未知碎裂场景。需M6消融实验证明。

#### 全流程整合

```
原始RAW → [峰检测:XCMS/MZmine]
  → [ISF Early Flagging] ← 新增：特征表后、过滤前介入
    输入: ms1_features.csv + ms2_spectra.mgf
    输出: features_with_ISF_label.csv
  → [ISF-aware特征过滤]
    策略A(保守): ISF高置信度降权不删除
    策略B(激进): ISF合并到母离子
  → [ISF-aware对齐] ← ISF特征以母离子为锚点
  → [注释] ← ISF特征路由到母离子注释
  → [统计分析] ← ISF标记排除或单独报告
```

#### Dark Metabolome量化

1. NIST/HMDB标准品在不同源电压采集
2. GNN检测ISF → 统计ISF占比（按电压梯度）
3. 去除ISF后剩余未注释 → "真实暗代谢组"比例
4. 对比Giera 70%估计，直接介入Nature Metabolism争论

### 6.3 数据需求

**ISF Ground Truth**：METLIN（931k分子标准品，0eV vs 各碰撞能量）、MassBank.eu、GNPS、MassCube论文mouse数据集（2604 ISF标注）

**不同源电压数据**：标准品混合物×3-5电压梯度，约2-3周实验

**Phase 2临床数据**：MetaboLights + Metabolomics Workbench（5-10个癌症/疾病数据集）

### 6.4 竞争者详细对比（MS1FA）

| 维度 | MS1FA (Bioinformatics 2025) | ISF-GNN框架 |
|------|---------------------------|-------------|
| 核心方法 | 规则引擎+特征分组 | GNN图结构学习 |
| 工具形式 | Shiny App（非pipeline） | Python库（可编程接入） |
| 流程整合 | 独立，事后处理 | 全流程感知 |
| 未知碎裂 | 不能处理 | 可泛化 |
| 临床验证 | 无 | Phase 2目标 |
| Dark Metabolome量化 | 无 | Phase 1目标 |

### 6.5 论文结构

**Phase 1 AC**：ISF-GNN + Dark Metabolome量化
- Intro：70%ISF争论(NatMet 2024) + 现有工具局限
- Methods：图构建/GAT/训练数据/全流程pipeline/暗代谢组实验
- Results：benchmark(vs ISFrag/MS1FA/MassCube) + 源电压ISF比例 + 全流程影响 + 暗代谢组量化
- Discussion：介入Giera争论 + GNN必要性（消融支撑）

**Phase 2 NC升级（B4）**：新增临床假阳性量化
- 对照实验：有/无ISF过滤标志物发现流程对比
- 回顾性分析：重新处理已发表研究原始数据
- 结论："ISF贡献了X%差异特征，Y%被错误报告为生物标志物"

### 6.6 执行时间线

**Phase 1（M1-M12，AC）**：
| 月份 | 任务 |
|------|------|
| M1-2 | METLIN数据+标准品采集（2源电压） |
| M2-4 | 图构建+GAT训练（METLIN预训练） |
| M4-6 | 全流程pipeline（ISF检测→过滤→标准化接口） |
| **M6** | **★消融门控：GNN vs ISFrag F1≥5%** |
| M6-8 | Benchmark：vs ISFrag/MS1FA/MassCube，3数据集 |
| M8-10 | Dark Metabolome量化（3-5电压梯度） |
| M10-12 | 论文+投AC |

**Phase 2（M12-M18，NC B4）**：
| 月份 | 任务 |
|------|------|
| M12-13 | 临床数据集收集（5-10个） |
| M13-15 | 对照实验 |
| M15-17 | 回顾性分析 |
| M17-18 | 升级论文+投NC/NatMethods |

### 6.7 风险矩阵

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| GNN vs RF无明显优势 | 40% | 高 | M6消融；改RF+图特征 |
| MS1FA/MassCube快速迭代 | 35% | 中 | 差异化：GNN泛化+临床假阳性 |
| B4临床缺ground truth | 60% | 高 | 人工ISF干扰实验+跨平台一致性代理 |
| 自采数据周期过长 | 20% | 中 | 先用METLIN/MassCube公开数据 |

### 6.8 Go/No-Go门控

| 时间 | 条件 | 通过标准 | 失败处理 |
|------|------|---------|---------|
| M1 | 训练数据可用 | METLIN/MassCube可下载+含ISF标注 | — |
| **M6** | **GNN消融** | **GNN vs ISFrag F1≥5%** | **改RF+图特征** |
| M10 | benchmark | ≥2数据集超越ISFrag/MS1FA | — |
| M12 | Phase 2启动 | Phase 1接受+≥3临床数据集 | — |
| M15 | Phase 2继续 | 有/无ISF过滤假阳性率差≥5% | — |

---

## 七、方向 #6：SC代谢物→通量约束 Y1（AC 7.0-7.5 → POC后8.5-9.0）

### 7.1 科学问题

能否用单细胞代谢组学直接测量的代谢物浓度（而非转录组推断），通过热力学约束FBA，推断单细胞通量分布？

**竞争者全部基于转录组——空白完全确认**：

| 工具 | 输入 | 核心差距 |
|------|------|---------|
| METAFlux (NC 2023) | scRNA-seq | 间接推断 |
| scFEA (Genome Res 2021) | scRNA-seq | GNN+因子图 |
| scFBA (PLoS CompBio 2019) | scRNA-seq | 仅癌症 |
| Compass (Cell Sys 2021) | scRNA-seq | 通量不可直接量化 |
| MetroSCREEN (Genome Med 2025) | scRNA-seq+细胞互作 | 仍基于转录组 |

### 7.2 方法设计

**理想方案（tFBA）**：ΔG_r' = ΔG_r^0 + RT ln(∏[P_j]/∏[S_i]) < 0 when v_r > 0

**致命约束**：tFBA需绝对浓度(mM)，MALDI-SCM给相对强度。

**降级方案（实际可行）**：通量方向约束——只需相对浓度比较。如果细胞A的glucose:lactate比值高于B，可约束糖酵解通量方向。弱热力学假设但比转录组更直接。

### 7.3 数据

- **HT SpaceM (Cell 2025)**：140,000+细胞，NCI-60×9+HeLa，~100代谢物，73个LC-MS/MS验证
- **关键限制**：73代谢物覆盖Recon3D的4000+节点不足5%
- **最小验证**：HeLa糖酵解抑制实验，~10,000细胞，~50代谢物

### 7.4 时间线与门控

| 月份 | 里程碑 |
|------|--------|
| M2-3 | HT SpaceM数据下载+tFBA框架+Recon3D整合 |
| M3 | 门控：绝对浓度问题，决定完整vs降级版 |
| M4-5 | HeLa验证+METAFlux对比 |
| **M6** | **★Go/No-Go** |

**Go**：r>0.5 vs bulk验证 + ≥3通路优于METAFlux
**No-Go**：r<0.3 → Stop，资源转其他

**总体评估**：POC成功率40-50%，成功后投稿率65%。

### 7.5 风险矩阵

| 风险 | 概率 | 影响 | 应对 |
|------|------|------|------|
| 相对强度无法约束tFBA | 60% | 高 | 降级为通量方向约束 |
| 代谢物覆盖率不足 | 40% | 中 | 聚焦中央碳代谢子网络 |
| MetroSCREEN部分解决 | 20% | 中 | 代谢物直接测量仍是差异化 |

---

## 八、方向 #7：GC-MS自监督预训练（AC 7.0-7.5）

### 8.1 科学问题

DreaMS(NatBiotech 2025)覆盖LC-MS/MS，GC-EI-MS无通用预训练表示模型。SpecTUS/MASSISTANT做结构预测（判别性），非通用表示学习（生成性）。

### 8.2 GC-EI-MS特有挑战

1. EI电离无precursor m/z（不能做masked spectrum modeling）
2. 整数质量（低分辨率）
3. 热降解ISF噪声
4. 不能直接复制DreaMS架构

### 8.3 自监督任务设计

- **任务1**：谱图增强一致性（对比学习）：同一化合物不同条件谱图嵌入相近
- **任务2**：m/z分组预测（masked autoencoder变体）：掩蔽部分碎片峰预测强度
- **任务3**：分子特征预测（辅助弱监督）：元素组成预测

### 8.4 数据规模

| 数据集 | 谱图数量 | 用途 |
|--------|---------|------|
| NIST23 EI（需购买） | 394,054 | 主训练集 |
| MassBank GC-EI（公开） | ~13,000 | 外部验证 |
| NEIMS/RASSP合成 | 1000万+ | 预训练扩充 |

**关键问题**：40万真实 vs DreaMS 7亿，差3个数量级。路径：合成扩增+小模型（10-50M参数）。

### 8.5 与Plan 2系列关系

Benchmark为预训练提供评估框架，预训练为benchmark提供DL基线。两篇同期互引。

### 8.6 时间线

| 月份 | 里程碑 |
|------|--------|
| M1-2 | NIST23数据预处理+baseline实验 |
| M3 | 小规模自监督验证（1万谱图，确认训练信号） |
| M4-6 | 全量预训练+下游迁移 |
| M7-9 | vs SpecTUS/MASSISTANT比较+写作 |
| M15 | 投稿（与benchmark协调） |

### 8.7 风险矩阵

| 风险 | 概率 | 影响 | 应对 |
|------|------|------|------|
| 数据量不足 | 40% | 高 | 合成扩增至1000万+降参数 |
| SpecTUS占据心智 | 35% | 中 | 表示学习vs结构预测区别 |
| GC-MS领域太小 | 30% | 中 | 工业/食品安全/环境场景 |
| 低分辨率嵌入质量差 | 20% | 高 | 强度归一化+峰簇聚合 |

---

## 九、方向 #8：Ensemble场景自适应加权（AC 7.0-7.5 → 8.0，优先级C）

### 9.1 定位

组合C+ benchmark数据 → 引擎特性知识库 → 场景自适应权重 → ensemble特征表。系列第二篇。

### 9.2 方法

1. **引擎特性知识库**（Plan 2产出）：每引擎×场景性能曲线
2. **场景分类器**：输入元数据→场景向量
3. **加权融合**：基于场景向量多引擎特征列表加权合并
4. **不确定性传播**：CP框架扩展为Ensemble级UQ

**前置依赖**：Plan 2 benchmark Phase 1完成。代码共享率~60%。

### 9.3 时间线

M14启动 → M20投稿。利用benchmark数据作为先验，6个月完成。

---

## 十、吸收进其他论文的组件（不独立发表）

| 组件 | 原评分 | 吸收去向 | 额外工作量 |
|------|--------|---------|-----------|
| B8 ISF-MNAR联合建模 | 7.0 | MNAR-VAE(#4)可选实验章节 | +1-2周 |
| Y2 环境代谢物归因 | 6.0 | MNAR-VAE(#4) Discussion段 | +0.5周 |
| TDA 2D峰检测 | 6.5 | 组合C+(#3)可选POC | +1-2周 |
| 保形预测(独立) | 6.0 | 组合A(#1)核心 | — |
| 临床验证(独立) | 6.5 | 组合B(#2)核心 | — |
| consensus | 4.5 | 组合C+(#3)系列 | — |
| 批次效应benchmark | 淘汰→吸收 | 组合C+(#3)批次模块 | — |
| OT谱图相似度 | 淘汰→吸收 | 组合C+(#3)OT诊断 | — |
| CP×benchmark(B1) | 新交叉 | 组合C+(#3)注释评估 | — |
| 暗代谢组一致性(B3) | 新交叉 | 组合C+(#3)核心模块 | — |
| DreaMS嵌入(B7) | 新交叉 | 组合C+(#3)注释一致性 | — |
| 注释感知功效(B2) | 新交叉 | 组合B(#2)敏感度分析 | — |
| 引擎-功效(B5) | 新交叉 | 组合B(#2)+C(#3)桥接 | — |
| CCS可选先验 | 淘汰→吸收 | 组合A(#1) Phase 1 | +1月 |
| 暗代谢组叙事 | 淘汰→吸收 | 组合A(#1)引言动机 | 零成本 |

---

## 十一、永久淘汰方向

| 方向 | 淘汰原因 |
|------|---------|
| 嵌合谱图影响量化 | 6篇论文饱和（含AC 2025.08），无可行拯救路径 |
| MSI端元解卷积 | 参考数据仅10种癌细胞系 + 离子抑制共线性 + Moens 2025先发 |
| 暗代谢组(独立) | Li 2025已发 + ground truth缺失（叙事已吸收进组合A） |
| DIA In Silico Library | cosine 0.35数据质量不可改变 |
| 扩散模型正向MS2 | DiffMS(ICML) + FIORA(NC)双重占位 |
| IsoDistinguish(独立) | MassID占位（CCS维度已吸收进组合A） |
| 孟德尔随机化 | MetaboAnalyst 6.0 + mGWAS-Explorer完全覆盖 |
| 微生物组-代谢组联合 | MicrobiomeAnalyst成熟 |
| 剂量-响应分析 | 工具链完备 |
| MIST制药 | 方法论贡献不足 + 核心验证数据不可得 |
| TDA 1D峰检测 | MassCube(NC 2025)声称100%信号覆盖 |

---

## 十二、执行时间线总览

```
Month:  1    2    3    4    5    6    7    8    9   10   11   12   13   14   ...  20

#4 MNAR-VAE (AC 7.5):
[===数据+基础设施===][==模型实现==][★M5门控:NRMSE≥10%][下游+写作][→AC投稿M8]
                                   [bioRxiv M6]

#1 组合A (NatMethods 8.7-9.0):
[=====Phase 1 CP校准=====][★M3: coverage±5%]
                          [====Phase 2 注释感知加权差异分析====]
                                                              [==Phase 3 贝叶斯通路==]
                                                                          [bioRxiv M11][→NM M12]

#3 组合C+ (NC 8.0-8.5 → NM条件):
[==Docker+数据==][=峰检测基准=][=批次+ISF=][=OT+CP+Multiverse=][★B3暗代谢组★][B5][写][→NC/NM M14]
                                                                           [Go/NM? M11]

#2 组合B (AC 8.5 → NC 50%):
            [基础设施] [===AC核心方法(M3-6)===][==AC验证+写作==][→AC M9]
            [★Gate1 M2: MR+MNAR可行性]                        [===NC: MR+UKB(M10-14)===][→NC M14]

#5 ISF (AC 7.5 → NC):
[==数据==][===GNN开发===][===Pipeline===][★M6消融GNN≥5%][=Benchmark=][暗代谢组][→AC M12]
                                                                               [...Phase 2 NC M12-18...]

#6 SC通量 Y1 (AC 7.0-7.5 → POC后8.5-9.0):
         [预研究][=====POC实验=====][★M6 Go/No-Go: r>0.5+≥3通路][论文写作][→AC M9]

#7 GC-MS预训练 (AC 7.0-7.5):
[数据准备][小实验M3][===全量预训练===][===比较===][写作]             [→AC M15]

#8 Ensemble (AC 7.0-7.5 → 8.0):
                                                                        [→启动M14...M20投稿]
```

---

## 十三、关键门控节点汇总

| 时间 | 方向 | 门控 | 通过标准 | 失败处理 |
|------|------|------|---------|---------|
| **M2** | 组合B | Gate 1: MR+MNAR可行性 | mQTL可用代谢物>50个 + MNAR效应>15% | 重定位为纯方法论模拟论文 |
| **M3** | 组合A | CP覆盖率 | empirical coverage ≥ nominal (±5%) | 退回经验置信估计，去理论保证叙事 |
| **M5** | MNAR-VAE | 改进显著性 | NRMSE降低≥10% vs QRILC | 聚焦特定化学类别 / 缩小为缺失机制分类 |
| **M6** | ISF | GNN消融 | GNN vs ISFrag F1提升≥5% | 改RF+图特征（论文仍可发） |
| **M6** | SC通量Y1 | Go/No-Go | r>0.5 vs bulk + ≥3通路优于METAFlux | Stop，资源转其他方向 |
| **M11** | 组合C+ | NM决策 | 跨引擎稳定暗代谢物>500 + 单引擎独有>30% | 按NC投稿 |
| **M14** | 组合B NC | UKB数据 | 申请批准 + >100代谢物MR完整分析 | 仅AC版 |

---

## 十四、论文产出规划

| 时间 | 论文 | 期刊 | 评分 | 置信度 |
|------|------|------|------|--------|
| M6 | MNAR-VAE bioRxiv占位 | bioRxiv | — | 高 |
| M8 | MNAR-VAE化学先验填补 | Analytical Chemistry | 7.5 | 高 |
| M9 | 组合B AC版: MetaPower | Bioinformatics/Metabolomics | 8.5(AC) | 高 |
| M9 | SC通量约束 Y1（如POC通过） | AC→NM条件 | 7.0-9.0 | 中 |
| M11 | 组合A bioRxiv占位 | bioRxiv | — | 高 |
| M12 | **组合A: 端到端UQ传播** | **Nature Methods** | **8.7-9.0** | **高** |
| M12 | ISF-GNN全流程 Phase 1 | Analytical Chemistry | 7.5 | 中高 |
| M14 | 组合B NC版: MetaPower+MR | Nature Methods/Genome Biology | 8.5(NC) | 中（UKB依赖） |
| M14 | **组合C+: 可重复性图谱** | **NC→NatMethods条件** | **8.0-8.5** | **高** |
| M15 | GC-MS自监督预训练 | Analytical Chemistry | 7.0-7.5 | 中 |
| M18 | ISF Phase 2 临床假阳性(B4) | Nature Communications | 7.5+ | 中 |
| M20 | Ensemble场景自适应 | AC→NC条件 | 7.0-8.0 | 中 |

### 长期战略（18-36个月）

| 方向 | 评分 | 前置依赖 |
|------|------|---------|
| 代谢组学Meta分析方法论 | 7.0-7.5 | 组合B发表后 |
| GC-MS benchmark扩展 | NC级 | 组合C+ Phase 1后 |
| MEWS代谢组学研究质量评分系统 | NC/NM级 | 组合B+C全部完成 |

---

## 十五、共享基础设施

| 组件 | 服务方向 | 建设时间 | 技术栈 |
|------|---------|---------|--------|
| 化学属性查询系统 | #1, #4 | M1-2 | PubChemPy + RDKit |
| MetaboLights数据预处理脚本 | #1, #2, #3, #4 | M1-2 | Python |
| HMDB/GNPS注释pipeline | #1, #3, #5 | M1-2 | Python + REST API |
| DreaMS本地部署 | #3 | M1 | PyTorch + Zenodo权重 |
| Docker化引擎环境(5引擎) | #3, #8 | M1-2 | Docker + docker-compose |
| Snakemake/Nextflow流水线 | #3 | M2 | Snakemake/Nextflow |
| METLIN数据预处理 | #5 | M1 | Python |
| HT SpaceM数据接口 | #6 | M2 | Python |

---

## 十六、核心参考文献

### 直接竞争（需持续跟踪）

- arXiv 2026-03-10 "When should we trust the annotation?" — 组合A Phase 1最直接竞争（Ghent大学Waegeman组）
- MassID bioRxiv 2026-02-11 (Panome Bio) — 注释层+FDR竞争，商业产品
- MassCube Nature Communications 2025 (PMC12216001) — 组合C+基准对比
- MS1FA Bioinformatics 2025 — ISF竞争
- MetaboAnalyst 6.0 (NAR 2024) — 功效+MR模块

### 方法论基础

- MMISVAE (Sci Reports 2025) / GINA (PMC 2023) — MNAR-VAE
- BAUM (BriefBioinf 2024) — 贝叶斯通路分析
- DreaMS (Nature Biotechnology 2025) — 预训练嵌入
- GromovMatcher (eLife 2024) — OT应用先例
- CP for enzyme function (NC 2024) — CP先例
- MetSizeR (BMC Bioinfo 2013) / MultiPower (NC 2020) / SSPA — 功效基线
- ISFrag (Anal. Chem. 2021) — ISF检测基线
- DisCo P-ad (Metabolites 2025) — ENT方法
- RIVW/dIVW estimators (arXiv 2603.06078, 2025) — 弱IV校正
- winnerscurse R package (PLOS Genetics 2023) — WC校正
- MVMR metabolomics (AJHG 2024) — 多变量MR
- imputomics (Bioinformatics 2024) — MNAR缺失比例估计
- SpecTUS (arXiv 2502.05114, 2025) / MASSISTANT (ChemRxiv 2025) — GC-MS

### 领域背景

- Dark Metabolome debate (Nature Metabolism 2024-2025, Giera/Siuzdak)
- 244-study reproducibility crisis (PMC11999569, 2024)
- FDA BMV for Biomarkers (2025)
- HT SpaceM (Cell 2025) — SC代谢组学
- METAFlux (NC 2023) / MetroSCREEN (Genome Med 2025) — SC通量
- tFBA (BMC Systems Biology 2007) — 热力学FBA
- UK Biobank NMR atlas (NC 2023)
- IJE 2023 (PMC10396423) — WC对MR影响
- Mechanism-aware imputation (PMC9109373, 2022) — MNAR框架
- NIST23 EI library — GC-MS数据
- GC-IMS Persistent Homology (ACA 2024) — TDA先例
- Batch correction benchmark (bioRxiv 2025.08)
- XCMS 4.8.0 (AC 2025) / asari (NC 2023) — 引擎参考

---

## 详细Plan文件索引

每个方向的完整压力测试报告、迭代历史、原始调研结果见：

| 方向 | 详细方案 | 行数 |
|------|---------|------|
| MNAR-VAE + 组合A | [Plan1-UQ-Chain.md](plans/Plan1-UQ-Chain.md) | ~410行 |
| 组合C+ + Ensemble | [Plan2-ReproducibilityAtlas.md](plans/Plan2-ReproducibilityAtlas.md) | ~392行 |
| 组合B v2 | [Plan3-ClinicalPower.md](plans/Plan3-ClinicalPower.md) | ~428行 |
| ISF系列 | [Plan4-ISF-Series.md](plans/Plan4-ISF-Series.md) | ~489行 |
| Y1 SC通量 + GC-MS预训练 | [Plan5-EmergingDirections.md](plans/Plan5-EmergingDirections.md) | ~339行 |
