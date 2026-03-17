# Plan 3：临床功效与验证 — 完整执行方案

> 版本：v1.1 | 创建：2026-03-16 | 更新：v1.1 整合两轮独立调研结果
> 覆盖方向：组合B v2（功效+临床+MR因果+Winner's Curse）+ B2注释感知功效 + B5引擎-功效关系

---

## 竞争格局现状（2024-2026搜索结果）

### 现有功效分析工具清单

| 工具 | 发表年份 | 方法核心 | 局限性 |
|------|---------|---------|--------|
| **MetSizeR** (R包) | 2013 | PPCA/PPCCA模型，支持无pilot数据时模拟，有Shiny界面 | 仅限PPCA/PPCCA两种分析方式；不处理MNAR；不考虑多重检验结构 |
| **MetaboAnalyst Power模块** (调用SSPA包) | 2015起内置 | 基于pilot数据估计效应量分布，FDR-adjusted平均功效 | 强依赖pilot数据；SSPA原设计面向基因组；不考虑缺失机制 |
| **MultiPower** (R包, Conesa Lab) | 2020, Nature Communications | 多组学统一功效框架，跨组学质量度量harmonization | 将代谢组学与转录组学同等处理，忽略代谢组学特有的LOD-driven MNAR；无MR整合 |
| **MOPower** (R-Shiny) | 2021 | 多组学数据模拟器+功效计算 | preprint状态；基本等同MultiPower扩展 |
| **G*Power / ssizeRNA** | 通用 | 单变量/RNA-seq | 无法处理代谢组学高维相关结构 |

**结论：工具存在，但存在系统性方法论空白。** 所有工具均不处理MNAR、Winner's Curse、MR因果效应量、通路级功效。

---

## 压力测试结果

### 测试1：功效分析空白——真实存在还是被夸大？

**结论：空白真实存在，但比预想更复杂。**

工具存在（MetSizeR、MetaboAnalyst、MultiPower），但均有明确方法论空白：
- MetSizeR仅支持PPCA/PPCCA，不支持现代差异丰度检验（limma-voom、混合模型）
- 所有工具均假设数据完整或缺失为MAR，不处理MNAR机制
- 没有任何工具整合因果效应量（MR来源）作为功效输入
- 没有工具处理Winner's Curse校正
- 没有通路级功效分析框架

ssizeRNA/RNAseqPower**不能**直接迁移，原因：(1) 代谢组学数据非负计数分布；(2) LOD截断产生的MNAR在RNA-seq中不存在；(3) 通路数据库结构不同（KEGG代谢通路 vs GO生物过程）。

**真正的创新空间**：整合MNAR感知 + Winner's Curse + 因果效应量 + 通路级，形成统一框架。这是现有工具的系统性缺失，不是边缘改进。

### 测试2：MNAR-aware bootstrap的理论基础

**结论：理论基础存在，但尚无直接针对功效分析的发表框架。**

已发表的相关工作：
- PMC8248477（2021）：专门处理代谢组学中非随机缺失与潜因子的估计与推断
- 机制感知插补（PMC9109373）：两步法区分MNAR vs MAR机制
- QRILC（左截断MNAR标准插补方法）：已在蛋白质组学和代谢组学广泛使用

**空白在于**：现有MNAR框架全部针对插补/估计，没有人将其扩展到功效分析。

**风险提示**：MNAR-aware bootstrap在理论上需要对缺失机制做假设（通常是left-censored at LOD），如果假设偏离现实，功效估计可能比简单忽略MNAR更差。

### 测试3：Winner's Curse在代谢组学的实际影响

**结论：影响已被量化，但现有文献主要来自GWAS，代谢组学专用证据有限。**

关键量化数据：
- GWAS研究显示：Winner's Curse在35%的发现关联中导致效应量实质性高估
- IJE 2023实证研究（PMC10396423）：专门检验Winner's Curse对MR估计的影响，发现在UK Biobank NMR代谢组学数据中存在显著偏差
- 2024年meta分析（244项临床代谢组学研究）：85%报告的生物标志物是统计噪声，与Winner's Curse导致的效应量膨胀直接相关

**创新点确认**：Winner's Curse在代谢组学研究设计阶段的系统性校正目前无人做，这是真实空白。

### 测试4：MR因果效应量的实际可得性

**结论：数据可得，但弱IV问题在代谢组学比基因组学更严重。**

可用公开mQTL数据：
- **UK Biobank NMR GWAS**（251个代谢物，~491,000样本，公开）：F统计量通常在10-100范围
- **Science Advances 2024**：mQTL分析方法论文
- MetaboAnalyst 6.0新增的Causal Analysis模块

**关键限制**：MR因果效应量输入只适用于有已知mQTL的代谢物（约30-40%的LC-MS代谢物有公开mQTL）。无mQTL的代谢物必须回退到观察关联效应量。

### 测试5：UK Biobank NMR数据的适用性

| 维度 | NMR (UK Biobank) | LC-MS (untargeted) |
|------|-----------------|-------------------|
| 代谢物数量 | 251 | 1,000-10,000+ |
| 缺失值模式 | 极低（<5%） | 高（20-80%，LOD驱动MNAR） |
| 注释确定性 | 高（目标定量） | 低（MSI 1-4级） |
| mQTL可用性 | 全覆盖 | 部分（~30-40%） |

**影响**：NMR低缺失率使其不适合验证MNAR模块；需要LC-MS数据集验证MNAR。UKB适合验证MR+通路模块。

### 测试6：NC可行性50%是否高估

**结论：50%合理，但依赖UKB申请时间和MR创新深度。**

NC可行的条件：
- UK Biobank数据申请成功（时间风险3-6个月）
- MR模块的弱IV偏差解决方案用现有方法（RIVW/dIVW估计量，2025年arxiv）
- 通路级功效+MR整合的方法论新颖性被审稿人认可

### 测试7：通路级功效的方法论差异化

**结论：有差异化。** 核心在代谢物特有的高内部相关性和覆盖率折扣。

现有基因组学通路功效分析（GSEA等）不处理：
- 代谢通路内代谢物高度相关（底物-产物关系，r>0.7常见）
- 通路覆盖率对功效的影响
- 通路注释不确定性

---

## 1. 战略定位

### 为什么功效分析是代谢组学的关键缺失

代谢组学正经历一场规模性的可重复性危机：2024年针对244项临床代谢组学研究的meta分析发现，2,206个报告显著代谢物中72%只在单一研究中出现，85%被估计为统计噪声。根本原因不是统计方法问题，而是研究设计阶段的系统性失误：**大多数代谢组学研究根本没有做功效分析**。

现有工具（MetSizeR、MetaboAnalyst SSPA模块、MultiPower）存在三个共同缺陷：
1. 均假设数据完整或MAR，忽略代谢组学最常见的MNAR（LOD截断）缺失机制
2. 均基于观察关联效应量作为功效输入，导致Winner's Curse循环
3. 均不包含通路级功效推断

---

## 2. 方法设计

### 模块1：MNAR-aware Bootstrap功效估计

**核心设计**：

1. **缺失机制识别**：基于强度分布的left-censoring检验（KS检验 against truncated normal），区分MNAR（LOD截断）vs MAR vs MCAR
2. **截断参数估计**：用最大似然估计LOD阈值（μ_LOD）和截断比例（π_MNAR）
3. **MNAR-aware重采样**：bootstrap重采样时，根据截断参数生成含正确MNAR结构的模拟数据集
4. **功效计算**：在每个bootstrap样本上用目标检验统计量计算功效，取中位数和95%区间

**与现有方法的差异**：MetSizeR和SSPA从完整数据重采样，隐含假设缺失与检验结果无关。MNAR-aware方法保留了"低丰度代谢物在小样本中更可能完全消失"的信息。

**理论约束**：方法在left-censored MNAR假设下一致，对其他MNAR机制可能产生偏差。需做敏感性分析。

### 模块2：ENIT替代FDR-adjusted功效

**ENIT定义**：

```
ENIT(n) = Σ_i [power_i(n) × π_1_i]
```

ENIT（预期发现真阳性数）比FDR-adjusted平均功效更有临床意义：研究者想知道"花这些钱能发现几个真实的生物标志物"。

**注意**：ENIT本身是已知统计概念，创新在于将其系统化为代谢组学功效分析的主要输出指标，结合π_1的代谢组学先验估计方法。

### 模块3：Winner's Curse校正

**三层校正**：
1. **检测层**：效应量分布的极端值检验
2. **校正层**：Bootstrap Truncated Maximum Likelihood（BTML）估计量，或R包winnerscurse
3. **功效输入层**：校正后效应量作为功效计算输入

**量化影响**：GWAS文献显示WC平均导致35%关联的效应量高估；代谢组学小样本研究中比例预计更高。

### 模块4：MR因果效应量输入（NC核心差异化）

**实施路径**：
1. **数据来源**：UK Biobank NMR GWAS summary statistics（251个代谢物，公开）
2. **IV质量控制**：F统计量>10门控；RIVW估计量处理弱IV+Winner's Curse联合偏差
3. **效应量转换**：MR因果效应量→研究者关心的代谢物~疾病状态差异量
4. **无mQTL代谢物**：标记"MR-ineligible"，回退到WC-corrected观察效应量

**关键挑战**：
- 通路内代谢物共享IV → MVMR框架处理
- NMR范围有限（251个）vs LC-MS（1000+）：建立NMR-to-LC-MS映射

### 模块5：通路级功效分析

**计算框架**：

```
Pathway_power(n, P) = f(
  individual_powers_i(n),    # 通路内各代谢物的单变量功效
  Σ_P,                       # 通路内代谢物协方差矩阵
  coverage_rate(P),          # 当前平台覆盖该通路的比例
  annotation_uncertainty(P)  # 通路注释的置信度
)
```

有效独立测试数（M_eff）用特征值方法估计（Nyholt方法移植到代谢组学）。

### 模块6：临床验证框架整合

**对标2025年FDA生物标志物指导原则**：

| 验证阶段 | 功效框架对应模块 | 输出 |
|---------|--------------|------|
| Discovery | 模块1（MNAR-aware）+ 模块3（WC校正） | 正确功效下的样本量建议 |
| Replication | 模块3（WC校正后效应量） | 独立验证队列最小样本量 |
| Clinical qualification | 模块6（FDA BMV对标） | 分析验证+临床验证检查清单 |

### B2 注释感知功效（吸收）

功效折扣因子：
```
effective_power = raw_power × P(correct_annotation | MSI_level)
```

P(correct_annotation | MSI Level 1) ≈ 0.95, P(MSI Level 3) ≈ 0.3-0.5。

**价值评估**：作为组合B v2的扩展模块而非独立方向，增加框架完整性。工作量约+1个月。

### B5 引擎-功效关系（桥接组合B与C+）

不同引擎（XCMS vs MZmine vs MS-DIAL）产生不同缺失率和特征数量，直接影响MNAR-aware功效估计。

**非单调关系论证**：XCMS缺失率通常高于MZmine → MNAR功效更保守；但XCMS可能检出更多真实特征 → 更高ENIT。"更多特征≠更高功效"因FDR惩罚。

**价值评估**：桥接价值高，为组合C+的benchmark结果提供功效维度解读。作为组合B论文中的一个分析节。

---

## 3. 数据需求与来源

| 数据集 | 用途 | 可获得性 |
|-------|------|---------|
| **MTBLS1 / MTBLS2** | MNAR模块基准测试 | 立即可用 |
| **MTBLS264** | 平台差异验证 | 立即可用 |
| **NIST SRM 1950** | 定量准确性基准 | 可购买（~$400） |
| **UK Biobank NMR GWAS summary stats** | mQTL/IV来源 | 立即可用（公开） |
| **UK Biobank NMR个体数据** | MR模块验证（NC路径） | 申请需3-6个月 |
| **GWAS Catalog mQTL数据** | 非NMR代谢物IV | 立即可用 |

---

## 4. 预期贡献 vs 现有工具

| 功能 | MetSizeR | MetaboAnalyst/SSPA | MultiPower | 本框架 |
|------|---------|-------------------|-----------|-------|
| MNAR感知 | 无 | 无 | 无 | **有** |
| Winner's Curse校正 | 无 | 无 | 无 | **有** |
| 因果效应量输入（MR） | 无 | 无 | 无 | **有（NC）** |
| 通路级功效 | 无 | 无 | 部分 | **有** |
| 注释不确定性折扣 | 无 | 无 | 无 | **有（B2）** |
| 临床验证框架 | 无 | 无 | 无 | **有** |
| ENIT输出指标 | 无 | 无 | 无 | **有** |

---

## 5. 论文结构大纲

### AC版本

**标题候选**：*MetaPower: A framework for power analysis in metabolomics studies accounting for missing data mechanisms and effect size inflation*

**Main Figures（5个）**：
1. 框架总览图：MNAR-aware bootstrap + WC校正 + ENIT输出
2. MNAR对功效的影响：不同MNAR比例下传统 vs MetaPower
3. Winner's Curse量化：代谢组学效应量膨胀经验分布
4. ENIT vs 平均功效：预测准确性比较
5. 通路级功效：TCA循环和脂质通路案例

### NC版本（AC基础上增加）

- Figure 6：MR因果效应量 vs 观察效应量的功效差异（UK Biobank 251代谢物）
- Figure 7（可选）：通路级MR功效（MVMR+通路结构）

**NC核心论据**："我们展示了代谢组学研究的系统性效应量偏差（WC）导致了可重复性危机，并提供了用因果效应量替代观察效应量的方法论解决方案，在UK Biobank 491,000人的数据中验证"

---

## 6. 执行时间线（14个月）

### 阶段0：基础设施（M1-M2）

| 任务 | 时间 | 产出 |
|------|------|------|
| MetaboLights公开数据集下载 | W1-2 | 基准测试数据 |
| 现有工具复现（MetSizeR, SSPA, MultiPower） | W2-4 | 基准线结果 |
| MNAR模拟框架编码 | W3-6 | 模块1原型 |
| UK Biobank GWAS summary stats下载 | W4 | mQTL数据 |
| UK Biobank研究申请提交（NC路径） | M2末 | 申请编号 |

### 阶段1：AC核心方法（M3-M6）

| 任务 | 时间 | 产出 |
|------|------|------|
| MNAR-aware bootstrap方法论+理论证明 | M3-4 | 模块1完成 |
| Winner's Curse代谢组学实证量化 | M3-5 | Fig 3核心数据 |
| ENIT框架实现 | M4-5 | 模块2完成 |
| 通路级功效框架（M_eff校正） | M5-6 | 模块5原型 |
| R包MetaPower AC版本v0.1 | M6末 | 可运行软件 |

### 阶段2：AC验证+写作（M7-M9）

| 任务 | 时间 | 产出 |
|------|------|------|
| MTBLS数据集基准验证 | M7-8 | Figures 1-5数据 |
| AC版本论文写作 | M8-9 | 初稿 |
| **AC投稿节点** | M9末 | 投Bioinformatics/Metabolomics |

### 阶段3：NC扩展（M10-M14，依UK Biobank）

| 任务 | 时间 | 前置条件 |
|------|------|---------|
| MR模块实现 + RIVW/dIVW集成 | M10-11 | UKB申请批准 |
| UK Biobank NMR数据分析 | M11-12 | UKB数据访问 |
| MVMR通路内IV重叠处理 | M12-13 | MR模块完成 |
| NC版本额外Figures | M13-14 | UKB分析结果 |
| **NC投稿节点** | M14末 | 投Nature Methods/Genome Biology |

**关键路径**：UK Biobank申请批准是NC路径唯一外部依赖。AC路径在任何情况下按时推进。

---

## 7. 风险矩阵

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| UK Biobank申请>6个月 | 40% | NC延迟 | M2立即提交；AC路径不依赖UKB |
| MNAR bootstrap理论审稿人质疑 | 35% | 需额外模拟 | 预做3种MNAR假设的敏感性分析 |
| MR模块弱IV问题无法被RIVW完全解决 | 25% | NC差异化减弱 | 限定F>10的代谢物；弱IV单独标注 |
| MetaboAnalyst 7.0发布类似功能 | 20% | 竞争加剧 | 开源R包投稿前发布建立优先权 |
| WC量化在代谢组学无法复现GWAS的35%数字 | 30% | 核心论据削弱 | 独立估计本身就是论文贡献 |
| 通路级功效被认定"方法移植" | 30% | 降档 | 强调代谢物高相关性和覆盖率折扣 |

---

## 8. Go/No-Go门控标准

### AC版本投稿门控（M9）

| 门控条件 | 通过标准 | 时间 |
|----------|----------|------|
| MNAR方法优于现有 | ≥2个真实数据集中更准确预测功效 | M7 |
| WC原创量化数据 | ≥3个研究的效应量分布分析 | M5 |
| R包可运行 | 有文档和vignette | M6 |
| 通路级案例 | TCA循环+氨基酸代谢案例 | M6 |

### NC版本投稿门控（M14）

| 门控条件 | 通过标准 | 时间 |
|----------|----------|------|
| UKB数据访问 | 申请批准 | M8 |
| MR效应量比较 | >100个代谢物完整分析 | M12 |
| WC+弱IV联合校正 | 模拟验证通过 | M11 |
| AC已投/已接收 | AC版本已提交 | M9 |

---

## 论文产出规划

| 论文 | 目标期刊 | 预计投稿 | 状态 |
|------|----------|----------|------|
| MetaPower AC版 | Bioinformatics / Metabolomics | M9 | 核心 |
| MetaPower NC版（+MR） | Nature Methods / Genome Biology | M14 | 条件性（UKB门控） |

---

## 核心参考文献

- MetSizeR (BMC Bioinformatics 2013)
- MultiPower (Nature Communications 2020)
- MetaboAnalyst 6.0 (Nucleic Acids Research 2024)
- 244-study reproducibility crisis (PMC11999569, 2024)
- Winner's Curse MR impact (PMC10396423, IJE 2023)
- RIVW/dIVW estimators (arXiv 2603.06078, 2025)
- UK Biobank NMR atlas (Nature Communications 2023)
- FDA BMV for Biomarkers (2025)
- Mechanism-aware imputation (PMC9109373, 2022)
- MNAR estimation with latent factors (PMC8248477, 2021)
- mQTL analysis methodology (Science Advances 2024)
- BAUM Bayesian metabolomics (Briefings in Bioinformatics 2024)
- DisCo P-ad ENT method (Metabolites 2025)
- winnerscurse R package (PLOS Genetics 2023综述)
- Bayesian Hybrid Shrinkage (arXiv 2511.06318, 2024)
- MVMR metabolomics framework (AJHG 2024)
- MVMR weak instruments (arXiv 2408.09868, 2024)
- imputomics (Bioinformatics 2024)
- WebGestalt 2024 (NAR)
- IEU Open GWAS (gwas.mrcieu.ac.uk)

---

## v1.1 更新：第二轮调研补充发现

### 新增竞争者

| 工具/论文 | 关键信息 |
|---------|---------|
| **DisCo P-ad** (Metabolites 2025) | 最新ENT方法，用距离相关替代皮尔逊相关，本方向应采用 |
| **MetaboAnalyst 6.0 MR模块** | **已有2-sample MR**，但与功效分析框架完全脱节；功效模块仍是简单t-test单变量 |
| **imputomics** (Bioinformatics 2024) | MNAR缺失比例估计工具，可直接用于Gate 1前置验证 |
| **MVMR代谢组学框架** (AJHG 2024) | 多变量MR在代谢组学中的正式框架，弱IV用条件F统计量诊断 |

### MR可行性降级（关键修正）

**致命发现**：LC-MS未靶向代谢物的mQTL数据几乎不存在（每个未靶向feature需要匹配SNP，而未靶向feature没有稳定化学身份）。

**强制降级**：MR模块仅使用：
- UK Biobank NMR biomarkers（325个，GWAS summary statistics部分公开）
- IEU Open GWAS中约100个已有GWAS的靶向代谢物
- **总计约400-425个代谢物可做MR**，远少于LC-MS未靶向的1000-10000+

**影响**：NC版本的"MR因果效应量"claim范围需要缩小为"靶向/NMR代谢物的因果效应量框架"，不能声称覆盖未靶向代谢组学。

### MNAR效应量化预估

- **高缺失率（>30%）数据**：MNAR-aware vs 传统方法功效差异可达15-25%
- **低缺失率（<10%）数据**：效应接近于零
- **关键implication**：MNAR模块的论文价值取决于数据集的缺失率，需要选择高缺失率数据集做验证

### Winner's Curse校正方法精炼

推荐：Bootstrap + Empirical Bayes（SCAM变体）联合，与GWAS文献最一致方法（2023年PLOS Genetics综述）。

代谢组学适配两点：
1. 用代谢物相关矩阵替代LD矩阵
2. 用ENT调整后的等价阈值替代GWAS p<5e-8

### B2注释感知功效的自我削弱问题

**新发现**：当注释候选代谢物效应量相近时（如亮氨酸0.6/异亮氨酸0.4，两者都是支链氨基酸，生物学效应高度类似），折扣因子接近零，独立论点自我削弱。

**修正**：B2作为组合B的"敏感度分析"章节呈现，有价值但不孤立成文。

### 新增早期Gate 1（M2末）

**如果**可用MR代谢物 < 50个 **且** MNAR效应 < 15%：
→ 整个方向应重新定位为纯方法论模拟论文（仍可发Nature Methods，但降低"真实临床验证"的claim）

### 立即可执行动作（本周内）

1. 访问 IEU Open GWAS，下载可用代谢物GWAS数据，清点F>10的代谢物数量（0成本，1周内）
2. 用imputomics估计现有数据集的MNAR缺失比例（2周内）
3. 安装winnerscurse R包，精读源码（适配工作量估算）
