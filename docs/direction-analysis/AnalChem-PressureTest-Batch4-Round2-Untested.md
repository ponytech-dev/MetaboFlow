# Analytical Chemistry 发表可行性压力测试 — Batch 4（Round 2未测试方向）

**审查日期**: 2026-03-16
**审查员**: Research Scout（严格压力测试模式，Analytical Chemistry Associate Editor视角）
**被审方向**: Round 2 NC Discovery中因优先级下降未做正式压力测试的5个方向
**参照基准**: AbsoluteQuant已否决报告（3.5/10）；Batch 1、Batch 2已有评估框架
**评估目标**: 判断降级至Anal Chem是否可行，或直接删除

---

## 执行摘要

| 方向 | 来源 | 初评 | Anal Chem判断 | 核心理由 |
|------|------|------|-------------|---------|
| 绝对浓度重建 | Fundamentals C | ★★★★ | **冗余删除** | 与AbsoluteQuant重叠>85%，已否决 |
| 因果网络图谱 | Fundamentals D | ★★★★ | **不通过** | UK Biobank MR体系2024-2025已大规模系统覆盖；Anal Chem不接受流行病学工具 |
| 代谢状态OT轨迹 | CrossDiscipline 3 | 7.5 | **条件保留** | OT在代谢组学的应用仍是真实空白，但生物学合理性论证是必要前置 |
| 伪绝对量化 | IndustryPain P2 | 7.0 | **冗余删除** | 与AbsoluteQuant/绝对浓度重建高度重叠，RF数据库构建路径几乎完全相同 |
| 暴露组学对齐 | IndustryPain P3 | 6.5 | **不通过（边界）** | NORMAN工具链+Scannotation+RT预测方向在2025年快速填补；核心差异化主张脆弱 |

---

## 方向1：绝对浓度重建（Fundamentals C，★★★★）

### 判断：冗余删除（直接删除，与已否决方向重叠>85%）

### 重叠度评估

已否决方向AbsoluteQuant（NC压力测试，3.5/10）的核心方案：
- 响应因子先验 + 内源代谢物锚点 → 推断浓度
- NIST SRM 1950作为训练/验证锚点
- ML校正函数覆盖多代谢物

本方向Fundamentals C的核心方案：
- 响应因子先验 + SRM 1950锚点 → 推断浓度
- 声称差异：使用代谢网络化学计量约束传播浓度

**重叠度分析**：

两者在以下维度完全重合：问题定义（无内标非靶向绝对定量）、数据来源（SRM 1950 + HMDB浓度参考）、核心障碍（响应因子预测精度天花板、锚点个体间变异）。唯一声称差异——"化学计量约束网络传播"——在AbsoluteQuant报告中已作为Pivot C（"方向C：代谢网络化学计量约束"）明确讨论，并判断这是NC-Fundamentals.md中方向C的核心方案（第287-299行）。

AbsoluteQuant报告的致命问题在本方向中一个未解决：
1. Pyxis（Matterworks，2024 bioRxiv + 商业产品）完全覆盖
2. IROA TruQuant（NC 2025）已占位
3. 锚点CV 46.6%导致误差传播不可收敛
4. 化学计量约束在开放代谢组（非FBA闭合系统）中假设不成立——非靶向代谢组学中大量代谢物的酶动力学反应式未知，无法建立有效的化学计量方程

**重叠度：>85%**。不存在实质差异化空间。

### Anal Chem可行性评分：1/10

**判定**：冗余删除。不进入Anal Chem评估流程，属于与已否决方向的逻辑重复。

---

## 方向2：因果网络图谱（Fundamentals D，★★★★）

### 判断：不通过（Reject）

### 竞争者深度搜索结果

**搜索关键词**：causal metabolomics、metabolic network inference causal、mQTL network、metabolomics causal discovery 2025

**2024-2025年竞争者矩阵**：

| 研究/工具 | 发表时间 | 期刊 | 核心内容 | 威胁等级 |
|---------|---------|------|---------|---------|
| Genome-wide metabolomics GWAS | 2024 | **Nature** | 136,016人33队列，400+独立位点，mQTL系统图谱 | **致命** |
| UK Biobank代谢组表型图谱 | 2025 | **Nature Metabolism** | 274,241人，313代谢物×1386疾病×3142特征，52,836关联对 | **致命** |
| Genetic atlas plasma metabolome | 2025 | **Nature Communications** | 254,825人，24,438独立变异-代谢物关联，MR因果分析 | **致命** |
| Genetic atlas 40 diseases | 2025 | **Genome Medicine** | 249代谢物×40疾病metQTL，因果代谢物到疾病风险映射 | **致命** |
| Metabolome-wide MR psychiatric | 2025 | **BMC Medicine** | ~1000代谢物×精神/神经退行疾病，85个因果效应 | 高 |
| MetaboAnalyst mGWAS-Explorer 2.0 | 已淘汰原因之一 | — | MR分析工具，M11.3淘汰理由 | 高 |

**核心发现**：UK Biobank mQTL+MR体系在2024-2025年经历了爆炸式增长——Nature 2024的400+位点GWAS、Nature Metabolism 2025的1.4M关联图谱、Nature Communications 2025的254,825人遗传架构分析，已经系统性地完成了"从mQTL推断代谢物-表型因果"这个核心科学问题的大规模实证工作。这些论文不仅规模碾压，其作者也在持续发表后续工作，时间窗口已基本关闭。

### Anal Chem可行性评估

**Q1：Anal Chem接受因果推断/MR类型的论文吗？**

不接受。Anal Chem的核心范围是分析化学方法论（质谱、色谱、检测、定量）。基于UK Biobank NMR数据+GWAS+MR的因果网络研究属于遗传流行病学/计算生物学，投稿至Anal Chem本身就是错误定向。审稿人第一步就会以"out of scope"退稿，不会进入方法论评审。

**Q2：是否存在"代谢网络因果推断算法"的角度能发Anal Chem？**

理论上存在，但实际上被以下现有工作封堵：
- NetCoupler（Bioinformatics 2023）：代谢组-疾病因果链估计
- MINIE（npj Systems Biology 2025）：多组学时间序列贝叶斯网络
- COVRECON（2025）：代谢组学因果分子动态识别
- MR体系（如MR-Egger、weighted-mode）已高度成熟

**Q3：与UK Biobank GWAS已发表体系的差异化空间？**

几乎不存在。UK Biobank 2024-2025的系列论文已覆盖：遗传工具变量（mQTL）、双向MR、共定位分析、多效性控制、大规模疾病关联。本方向在NC-Discovery-Fundamentals.md中的方案（MR+Granger因果+贝叶斯网络整合）在UK Biobank系列论文中已被不同程度实现。

**Q4："时序因果层"（Granger）是否有差异化？**

Granger因果在代谢组学中已有MINIE（npj 2025）覆盖。纵向代谢组学数据的稀缺性（每周2-3次采样的高频纵向数据极少，iHMP等公开数据集有采样频率不足的问题）使Granger因果检验的统计功效存疑。

### Anal Chem可行性评分：2/10

**判定**：不通过。双重障碍：期刊scope不匹配 + 竞争格局已被2024-2025年系列高影响力论文清零。不建议降级至任何期刊，该科学问题的核心工作已由统计遗传学领域完成。

---

## 方向3：代谢状态OT轨迹（CrossDiscipline 3，7.5）

### 判断：条件保留（45%通过概率，需2个月概念验证）

### 竞争者搜索结果

**搜索关键词**：optimal transport metabolomics、Waddington-OT metabolomics、trajectory inference metabolomics

**竞争者矩阵**：

| 工具/研究 | 发表 | 核心内容 | 与本方向重叠 |
|---------|------|---------|---------|
| Waddington-OT | Cell 2019 | scRNA-seq OT轨迹推断 | **源方法**（转录组学） |
| GromovMatcher | eLife 2024 | OT用于跨数据集特征对齐 | 低（对齐≠轨迹） |
| TIGON | Nat. Machine Intelligence 2023 | 动态不平衡OT+种群增长重建 | 中（scRNA场景） |
| RM-ASCA+ | PLOS CB 2023 | 纵向代谢组学混合效应ASCA | 中（同一问题不同方法） |
| ALASCA | Frontiers 2022 | 纵向多变量代谢组学ASCA框架 | 中 |
| MetaboDynamics | — | 代谢组学时间序列统计关联 | 低（不推断方向） |
| moscot | GitHub | 多组学单细胞OT工具 | 低（scRNA导向） |

**关键发现**：将OT轨迹推断用于纵向代谢组学数据（样本级而非细胞级）至今没有发表的同行评审论文。GromovMatcher（eLife 2024）做的是跨数据集对齐，RM-ASCA+做的是统计分解而非轨迹推断，两者在问题定义上与本方向不同。文献空白是真实的，但这个空白既可能是"尚未被填补"，也可能是"有人试过但发现不work"。

### Anal Chem压力测试

**Q1：OT轨迹推断在代谢组学中的生物学合理性——"代谢最小代价转变"假设成立吗？**

这是最关键也最难回答的问题。

OT的核心假设是：状态A到状态B的转变遵循"最小传输代价"原则（Wasserstein距离最小化）。在转录组学中，这个假设的合理性来自：细胞发育是受基因调控驱动的有序过程，不会随机跳跃到任意基因表达状态。

在代谢组学中，这个假设有以下挑战：
- 代谢物浓度受饮食、运动、采样时间的剧烈影响（同一个体24小时内代谢谱变异可达30-50%）
- 代谢物变化可以是非线性急剧跳变（如餐后胰岛素分泌导致血糖骤降）
- 代谢状态转变是否符合"最小代价路径"？生化反应速率由酶活性决定，不受"最小代价"原则约束

**反驳的角度**：在慢性疾病进展（如T2D前驱阶段→T2D）或发育过程（胎儿→新生儿）等慢时间尺度场景，代谢状态转变可能确实是平滑渐进的，OT假设的合理性更高。

**关键问题**：Anal Chem审稿人（分析化学背景）对这一计算生物学假设的验证要求较低，但若投Nature Methods审稿人对计算框架的生物学合理性要求更高。Anal Chem的审稿视角更关注：方法是否产出可解释的分析化学结果。

**Q2：公开纵向代谢组学数据集是否够支撑验证？**

数据状况：
- iHMP-T2D（Snyder Lab）：约100天，每周2-3次采样，73人。代谢组覆盖1,000+代谢物。最合适。
- MetaboLights纵向数据集（MTBLS）：存在但质量不均，采样频率普遍不足
- Stanford CGM整合代谢组：持续血糖+时序代谢组，但公开程度有限

**采样密度问题**：OT轨迹推断需要足够多的时间点快照以估计连续传输。iHMP T2D数据集采样密度（每周2-3次）与scRNA-seq（通常5-10个时间点，每点数千细胞）相比：样本数量(73人 vs 数千细胞)和时间点数量(100天周频采样)在数学上是否足以稳定估计OT传输计划，需要通过模拟验证。

**Q3：与RM-ASCA+的实质差异——为什么Anal Chem会接受OT而不是说"用RM-ASCA+就够了"？**

关键差异：
- RM-ASCA+：统计分解框架，分离时间主效应、个体差异、干预效应——告诉你"什么变化了"
- OT轨迹：推断代谢状态转变的**方向性**和**路径**——告诉你"怎么变化的"

这个差异有实质意义。但Anal Chem审稿人会追问：在实践中，"方向性路径"对于分析化学问题（如生物标志物发现、代谢组学临床应用）比RM-ASCA+的统计分解提供了什么额外的分析价值？

**可防御的差异化主张**：OT传输计划可以识别代谢状态转变过程中哪些代谢物作为"主驱动因素"（高传输概率），这对于发现关键中间代谢物（如T2D进展过程中的胰岛素抵抗代谢指标）有直接分析价值，RM-ASCA+不提供这种解释。

**Q4：Anal Chem的scope是否接受这类计算工具论文？**

接受。Anal Chem每年发表多篇metabolomics数据分析方法论文（如MetaboAnalystR 4.0的NC、RM-ASCA+的PLOS CB），对计算方法有明确的接受度。关键是：论文需要有清晰的分析化学问题定义 + 方法在真实代谢组学数据上的演示 + 与已有方法的实验对比。OT轨迹框架如果能在iHMP-T2D数据上产出"T2D进展关键代谢节点"这样具体的生物学结果，Anal Chem可以接受。

**Q5：计算时间和可用性——OT对代谢组学数据规模是否可行？**

代谢组学纵向数据规模（73人 × 100个时间点 × 1000代谢物）与scRNA-seq相比（数千细胞 × 数万基因）规模小得多。Python OT库（POT）对这个规模的entropic OT是可行的，不存在M10.1那样的计算速度障碍。

### 条件通过的核心要求

必须在2个月概念验证中满足以下三点：

1. **生物学合理性验证**：在iHMP-T2D数据（公开）上，OT轨迹推断的代谢状态转变路径是否与已知T2D生化进展（胰岛素抵抗→β细胞功能下降→高血糖）在方向上一致？若OT轨迹与生化知识完全矛盾，则删除。

2. **差异化论证**：OT轨迹能否识别RM-ASCA+无法识别的"关键转变节点代谢物"？需要有可量化对比（如：RM-ASCA+给出时间效应系数，OT轨迹给出状态转变传输概率矩阵，两者识别的Top-20代谢物重叠度）。

3. **Anal Chem期刊定位**：分析化学问题框架——明确定义"代谢状态轨迹分析"对非靶向代谢组学数据解读的具体贡献，而非作为计算生物学工具推销给分析化学读者。

### Anal Chem可行性评分：5/10（概念验证通过后可升至7/10）

**判定**：条件保留。文献空白真实，方法迁移路径清晰，但OT假设的代谢学合理性是硬门槛。设2个月概念验证决策点。若验证结果与生化知识不符，或无法展示优于RM-ASCA+的解释价值，则删除。

---

## 方向4：伪绝对量化（IndustryPain P2，7.0）

### 判断：冗余删除（直接删除，与已否决方向重叠>90%）

### 重叠度评估

**本方向的核心技术路径**（NC-Discovery-IndustryPain.md，P2方向）：
- 从NIST SRM 1950提取ESI响应因子（RF）
- 用化合物SMILES/分子描述符训练RF预测模型（GBM/GNN）
- 全局校准框架实现"伪绝对量化"

**AbsoluteQuant已否决报告**（NC-PressureTest-AbsoluteQuant.md，3.5/10）：
- 竞争者：Pyxis使用Transformer + StandardCandles，闭源商业，2024年已有产品和系列A融资
- 竞争者：Kruve lab随机森林预测ESI响应因子，2020 Scientific Reports已开源
- 竞争者：SCALiR（Analytical Chemistry 2024）：自动化标准曲线拟合，R²=0.99，77代谢物
- 竞争者：IROA TruQuant（NC 2025）：覆盖539代谢物

**重叠度分析**：

| 维度 | 伪绝对量化（P2） | AbsoluteQuant（已否决） |
|------|--------------|---------------------|
| 问题定义 | 无标准品非靶向伪绝对定量 | 无标准品非靶向绝对定量 |
| 数据来源 | NIST SRM 1950 + Biocrates | NIST SRM 1950 + HMDB |
| 核心算法 | RF预测模型（GBM/GNN） | ML校正函数（同类） |
| 锚点策略 | SRM 1950锚点 | 内源代谢物锚点 |
| 主要竞争者 | Pyxis、Kruve lab | Pyxis、Kruve lab（完全相同） |

两者的差异仅在命名（"伪绝对"vs"绝对"）和训练数据的微小差异（Biocrates vs HMDB），但面对的竞争格局、技术障碍、数据来源完全相同。

**最新搜索补充**：2024年Analytical Chemistry发表了MRMQuant（靶向MRM自动化定量），2025年还有RT预测+半定量方向（Frontiers，2025）的进一步占位。RF预测方向没有出现新的有利空间。

**重叠度：>90%**。

### Anal Chem可行性评分：1/10

**判定**：冗余删除。两个方向实质上是同一方向的不同描述，既然AbsoluteQuant已经以3.5/10被否决（Pyxis致命竞争），伪绝对量化无任何新的突破点，直接删除。

---

## 方向5：暴露组学对齐（IndustryPain P3，6.5）

### 判断：不通过（边界情形，倾向不通过）

### 竞争者深度搜索结果

**搜索关键词**：exposomics data harmonization、non-targeted screening alignment、exposome mass spectrometry cross-lab、NORMAN suspect screening network

**竞争者矩阵（2024-2025）**：

| 工具/研究 | 时间 | 来源 | 核心内容 | 与本方向重叠度 |
|---------|------|------|---------|------------|
| NORMAN-SLE + 识别评分框架 | 持续更新 | NORMAN Network | 半定量可疑筛查、跨实验室识别置信度框架 | 高（标准化方向） |
| Scannotation | 2023 | Environ. Sci. Tech. | LC-HRMS非靶向预注释自动化工具 | 中（注释层）  |
| GromovMatcher | eLife 2024 | — | OT跨数据集特征对齐 | **高**（直接竞争，RT不变量对齐） |
| Eclipse | 2025 | — | 跨实验室特征对齐工具 | 高（直接竞争） |
| metabCombiner 2.0 | 2024 | — | 多LC-MS数据集特征匹配 | 高（直接竞争） |
| AI-based RT prediction (QSRR) | Frontiers 2025 | Frontiers PH | 保留时间预测+跨平台校准，内源化合物作内标校准 | **高**（填补本方向核心方案） |
| Computational MS for exposomics | Anal. Bioanal. Chem. 2025 | — | NTS计算质谱综述，强调开放标准+共享谱图库 | 高（方向框架层） |
| Exposome computational standards | ScienceDirect 2026 | — | 暴露组关联研究标准化、联邦数据基础设施 | 高（标准化框架） |

**关键发现（2025年新增）**：

2025年的快速发展使本方向的差异化空间显著收窄：

1. **RT预测+跨平台校准（Frontiers PH 2025）**：直接覆盖本方向的核心技术——内源化合物作为内标校准的跨平台RT传递，包括深度学习、GNN、迁移学习方法。这与本方向"不依赖化合物注释的跨研究对齐"的主张构成直接竞争。

2. **GromovMatcher（eLife 2024）**：本方向在NC-Discovery-IndustryPain.md中声称"基于质量差网络的跨研究异质对齐从未被系统研究"——但GromovMatcher已经用OT实现了"不依赖RT的特征对齐"（利用特征强度相关性而非RT），与本方向的"质量差网络图匹配"在技术原理上高度相似。

3. **Eclipse和metabCombiner 2.0**：均在2024-2025年更新，覆盖了跨实验室特征对齐的工程问题。

### Anal Chem压力测试

**Q1：本方向的"基于质量差网络的跨研究异质对齐"与GromovMatcher的差异是什么？**

GromovMatcher的原理：利用特征强度相关性结构（Gromov-Wasserstein距离，比较两个数据集内部特征间的距离矩阵），不依赖RT，实现跨数据集对齐。

本方向的原理：利用质量差网络的拓扑结构（分子内部碎片间的质量差模式），不依赖RT，实现跨数据集对齐。

差异：GromovMatcher用特征强度协变结构，本方向用质量差网络拓扑结构。两者都是"仪器无关特征"的不同选择。技术上有差异，但解决的是同一个问题（无RT跨数据集对齐），Anal Chem审稿人会将本方向定位为GromovMatcher的改进变体，要求提供在相同数据集上明显优于GromovMatcher的定量证明。

**Q2：NORMAN工具链的存在是否构成竞争？**

NORMAN的竞争体现在标准化框架层面（识别置信度框架、半定量标准），不是算法层面的特征对齐工具。但NORMAN生态的持续扩展（2023年指导文件、新的识别评分框架）意味着：任何在Anal Chem投稿的暴露组学计算工具，都会被要求展示与NORMAN框架的兼容性和优于NORMAN现有工具的表现。

**Q3："监管接口"定位（EPA/EFSA）是否能支撑Anal Chem的论文价值主张？**

支撑力有限。Anal Chem的论文价值主张需要建立在方法学创新和分析化学验证上，不能主要依靠"满足监管需求"作为创新点。监管接口可以作为论文的应用价值陈述，但不能替代方法论创新的论证。

**Q4：无合作EPA/NORMAN数据，能否用公开暴露组学数据集验证？**

存在公开数据集（DSSTox、NORMAN NTS数据库、EPA暴露组数据），但这类数据的质量异质性极高（不同实验室、不同方法、不同采样时间），正是要对齐的问题本身，用于方法验证时存在循环论证风险——用需要对齐的数据来验证对齐方法，且没有"真值"确认对齐是否正确。

**Q5：计算可行性——图匹配算法在大规模暴露组学数据上是否可行？**

图同构和图核匹配在大规模数据上是计算困难问题（NP-hard）。对于包含数千个节点（特征）的质量差网络，精确图匹配不可行，需要近似算法（如WL kernel、node2vec嵌入等）。Anal Chem审稿人会要求在实际规模（数据集中的5,000-50,000个特征）的数据上报告计算时间，GromovMatcher用entropic OT在这个规模上已有实用实现。

### Anal Chem可行性评分：4/10

**判定**：不通过。核心竞争格局在2024-2025年快速变化：GromovMatcher（eLife 2024）和AI-based RT预测（Frontiers 2025）已填补了本方向声称的主要技术空白。质量差网络图匹配方案相比GromovMatcher的优势难以在实验上快速确立，且图匹配的计算复杂度是实际挑战。

唯一保留情景（不适用于Anal Chem，改投Environ. Sci. Tech.）：专注暴露组学特定场景（未知工业污染物的跨实验室特征对齐），强调GromovMatcher在完全未注释特征上的局限性，用环境化学物的质量差网络（基于已知碎片化规律）提供更强的化学先验约束。但这需要环境化学合作伙伴提供真实NTS数据，且期刊应改为Environ. Sci. Tech.（IF~11），不是Anal Chem。

---

## 综合处置决定

| 方向 | 与已否决方向重叠 | Anal Chem评分 | 判定 | 处置 |
|------|-------------|-------------|------|------|
| 绝对浓度重建（Fundamentals C） | >85%（AbsoluteQuant） | 1/10 | 冗余删除 | **永久删除**，不进入任何期刊评估 |
| 因果网络图谱（Fundamentals D） | 无直接重叠，但UK Biobank 2024-2025已完成 | 2/10 | 不通过 | **删除**（科学问题已被流行病学领域占领，且期刊scope不匹配） |
| 代谢状态OT轨迹（CrossDiscipline 3） | 无重叠，文献空白真实 | 5/10（POC后可至7/10） | 条件保留 | **保留，设2个月POC决策点** |
| 伪绝对量化（IndustryPain P2） | >90%（AbsoluteQuant） | 1/10 | 冗余删除 | **永久删除**，与已否决方向完全重叠 |
| 暴露组学对齐（IndustryPain P3） | 无直接重叠 | 4/10 | 不通过 | **删除**（GromovMatcher+RT预测已填补核心空白，替代期刊需环境化学合作者） |

---

## 关键发现：为什么这轮测试结果与初评分数差距如此大

初评给出★★★★和7.0-7.5分的理由都是科学问题重要性——绝对定量、因果网络、暴露组学对齐确实是代谢组学领域的真实痛点。但压力测试揭示的模式与Round 2 NC压力测试中观察到的一致：

**科学问题的重要性≠方向的可做性**

具体失败模式：
1. **Fundamentals C和P2（两个删除方向）**：与已否决方向高度重叠，不是新发现的失败，而是命名掩盖了同质性。这类"换壳方向"是最浪费资源的——相同的竞争格局、相同的技术障碍，只是重新包装了问题描述。
2. **Fundamentals D（因果网络）**：科学问题重要性极高，但时间窗口在NC-Discovery阶段（2026-03-16）已接近关闭。UK Biobank的mQTL+MR系列研究在2024-2025年形成了近乎完备的系统性覆盖，计算方法上（MR工具链成熟、MINIE等已有实现）没有遗留的算法空白。
3. **P3（暴露组学对齐）**：2025年的快速进展（GromovMatcher发表于eLife 2024、RT预测方向快速成熟）使6个月前的空白判断失效。调研日期在NC-Discovery报告完成时是正确的，但未进入即时压力测试使评估滞后。

**唯一存活方向（CrossDiscipline 3，OT轨迹）的存活理由**：文献空白在2025年3月仍然真实（OT轨迹用于代谢组学纵向数据，零同行评审文献），且技术迁移路径清晰（Python OT库成熟、iHMP-T2D公开数据可用）。但这个空白的成立依赖OT假设在代谢组学中的合理性，这是可以通过2个月POC快速验证的硬问题。

---

## 参考资料

- [Pyxis: A scalable approach to absolute quantitation in metabolomics (bioRxiv 2024)](https://www.biorxiv.org/content/10.1101/2024.09.09.609906v1)
- [Matterworks Pyxis LSM-MS2 Launch (2025)](https://www.matterworks.ai/pyxis-lsm-ms2-launch)
- [Genome-wide characterization of circulating metabolic biomarkers, Nature 2024](https://www.nature.com/articles/s41586-024-07148-y)
- [Mapping the plasma metabolome to human health and disease in 274,241 adults, Nature Metabolism 2025](https://www.nature.com/articles/s42255-025-01371-1)
- [Genetic architecture of plasma metabolome in 254,825 individuals, Nature Communications 2025](https://www.nature.com/articles/s41467-025-62126-w)
- [Genetic atlas of plasma metabolome across 40 human common diseases, Genome Medicine 2025](https://genomemedicine.biomedcentral.com/articles/10.1186/s13073-025-01578-7)
- [Metabolome-wide causal effects on psychiatric disorders, BMC Medicine 2025](https://link.springer.com/article/10.1186/s12916-025-04129-4)
- [Optimal transport for automatic alignment of untargeted metabolomic data (GromovMatcher), eLife 2024](https://elifesciences.org/articles/91597)
- [Analysis of high-dimensional metabolomics data with complex temporal dynamics using RM-ASCA+, PLOS CB 2023](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011221)
- [Waddington-OT: Developmental trajectories from single-cell gene expression, Cell 2019](https://www.cell.com/cell/pdf/S0092-8674(19)30039-X.pdf)
- [TIGON: Growth and dynamic trajectories from single-cell transcriptomics, Nature Machine Intelligence 2023](https://www.nature.com/articles/s42256-023-00763-w)
- [AI redefines mass spectrometry RT prediction for Human Exposome Project, Frontiers PH 2025](https://www.frontiersin.org/journals/public-health/articles/10.3389/fpubh.2025.1687056/full)
- [Computational mass spectrometry for exposomics in non-target screening, Anal. Bioanal. Chem. 2025](https://link.springer.com/article/10.1007/s00216-025-06093-7)
- [NORMAN Suspect List Exchange (NORMAN-SLE)](https://www.norman-network.com/?q=suspect-list-exchange)
- [Scannotation: A Suspect Screening Tool for LC-HRMS Exposome, Environ. Sci. Tech. 2023](https://pubs.acs.org/doi/10.1021/acs.est.3c04764)
- [Challenges and recent advances in quantitative MS-based metabolomics, Anal. Sci. Adv. 2024](https://chemistry-europe.onlinelibrary.wiley.com/doi/full/10.1002/ansa.202400007)
- [IROA TruQuant: Ion suppression correction for non-targeted metabolomics, Nature Communications 2025](https://www.nature.com/articles/s41467-025-56646-8)

---

*审查时间：2026-03-16*
*文献检索：WebSearch × 8次，覆盖Pyxis更新、UK Biobank mQTL-MR体系、OT轨迹推断、RM-ASCA+、NORMAN工具链、暴露组学对齐方向*
*参照内部报告：NC-PressureTest-AbsoluteQuant.md（主要参照）、NC-Discovery-Fundamentals.md、NC-Discovery-CrossDiscipline.md、NC-Discovery-IndustryPain.md*
