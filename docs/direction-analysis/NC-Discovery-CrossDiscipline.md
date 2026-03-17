# 跨学科方法移植 — 代谢组学/质谱分析 NC级方向发现报告

**调研日期**: 2026-03-16
**调研方法**: 系统文献搜索（WebSearch × 14次）覆盖基因组学/蛋白质组学/AI/物理数学/空间组学五个源领域
**前提约束**: 排除所有已否决方向（见 00-SUMMARY-RANKING.md、01-NC-STRATEGY-FINAL.md）

---

## 已否决方向（不再提出）

| 类别 | 已否决原因 |
|------|---------|
| DreaMS LC-MS预训练 | Nature Biotech 2025两篇同期占位，创新性≈0 |
| 暗代谢组 | Li et al. bioRxiv 2025已做61数据集 |
| OT谱图相似度（M10.1） | FlashEntropy已占位，速度瓶颈 |
| TDA峰检测（M10.2） | 已作为现有方向评估 |
| 批次效应benchmark | ~15篇比较研究，空间收窄 |
| MSI端元解卷积（M10.6） | 需实验合作 |
| MR分析/微生物组联合 | 已淘汰 |

---

## 文献情报汇总

### 1. 基因组学/蛋白质组学革命性进展

**DIA-NN范式（蛋白质组学）**
- DIA-NN (Nature Methods 2020)：深度神经网络 + 干扰校正，实现library-free library DIA蛋白质组学
- MaxDIA (Nature Biotech 2021)：全自动library-free DIA流程
- 代谢组学现状：DIAMetAlyzer (NC 2022)、MetaboMSDIA (2023)做了DIA工作流，**但核心瓶颈仍是multiplexed MS2谱图解卷积——代谢物没有蛋白质的序列database约束，library覆盖率<10%**
- 空白：DIA代谢组学中的library-free + FDR控制 + in silico谱图预测三者联动，完全没有等价于DIA-NN的系统性解决方案

**单细胞组学框架（Scanpy/AnnData生态）**
- HT SpaceM (Cell 2025)：高通量单细胞代谢组学，使用Scanpy v1.9.1做下游分析
- MAGPIE (NC 2025)：空间转录组 + 代谢组对齐框架，依赖scanpy
- SpaMTP (bioRxiv 2024)：整合Seurat做代谢组学细胞中心分析
- **空白：scRNA-seq有Waddington-OT (Nature Biotech 2025)、STORIES (Nature Methods 2025)等轨迹推断工具；单细胞/空间代谢组学完全缺乏等价的代谢状态轨迹推断方法**

**空间组学 cell-type deconvolution**
- 空间转录组学：RCTD/cell2location是benchmark top performer（Bioinformatics 2024综述）
- MALDI-MSI：scRNA-seq参考图谱辅助解卷积已被尝试（Nature Methods 2024 mass cytometry + MSI），但无独立通用计算工具
- SpatialMETA (NC 2025)：条件变分自编码器跨模态整合；haCCA (Comm Bio 2026)：多模块对齐
- **空白：MSI数据的cell-type deconvolution没有等价于RCTD/cell2location的专用工具——现有方法要么需要实验配对数据，要么只做粗糙的clustering**

### 2. AI/机器学习前沿

**扩散模型/生成式AI**
- DiffMS (arXiv 2025)、DiffSpectra (arXiv 2025)：扩散模型用于MS→分子结构预测
- **关键发现**：所有扩散模型都在做"谱图→结构"的逆问题；**"结构/分子→谱图"的正向生成几乎没有人用扩散模型做**
- 正向谱图生成（in silico MS/MS）是DIA library-free和暗代谢组的共同瓶颈
- MassSpecGym (NeurIPS 2024)严格benchmark显示：即使top-10 accuracy在leakage-controlled条件下只有4.1%——逆问题极难
- 正向问题（结构→谱图）相对容易，NEIMS/CFM-ID已有基础，**但完全没有用扩散模型做的**

**因果推断**
- MINIE (npj Sys Bio 2025)：多组学时间序列网络推断，贝叶斯回归
- COVRECON (2025)：代谢组学因果分子动态识别
- NetCoupler：代谢组-疾病因果链接估计
- **空白：这些方法做的是"哪些代谢物在因果网络中直接关联"——但缺乏从代谢组学时间序列数据推断代谢通量方向（即通量causal graph）的方法。现有通量分析(FBA)需要先验化学计量约束，而数据驱动的因果通量方向发现几乎没人做**

**Foundation model下游任务**
- DreaMS已占LC-MS/MS预训练
- SpecTUS做了GC-MS EI结构预测
- **空白：DIA代谢组学in silico谱图预测（正向生成）作为DIA library-free的核心组件，尚无foundation model级别的系统性攻克**

### 3. 物理/数学/信息论

**信息论**
- Spectral entropy (Nature Methods 2021) 已成熟，FlashEntropy实现 >10,000× 加速
- Ion entropy FDR (Briefings in Bioinformatics 2024) 已做
- **结论：信息论在谱图相似度方向已被充分挖掘，该方向创新空间关闭**

**压缩感知**
- FT-ICR MSI的压缩感知已有实现（40%采样重建）
- **结论：工程应用明确，但学术创新已被占据，非代谢组学算法的核心痛点**

**IMS（离子淌度）作为"第四维"**
- Met4DX (NC 2023)：4D峰检测（RT+m/z+CCS+MS2），已发NC
- MINIE整合multi-omic时间序列贝叶斯推断
- **空白：IMS-MS产生的4D数据的in silico CCS预测 + DIA去卷积联动，目前工具链断裂**

---

## 核心候选方向深度评估

基于以上情报，提出5个真正的跨学科方法移植方向：

---

## 方向一：代谢物DIA "In Silico Library" 引擎 — 蛋白质组学DIA-NN范式移植

### 方法论同构性

| 蛋白质组学DIA-NN | 代谢组学等价 |
|----------------|------------|
| 肽序列→理论碎裂规则生成in silico library | 分子结构→in silico MS2谱图预测 |
| MS/MS谱图去卷积（神经网络干扰校正） | multiplexed DIA谱图去卷积 |
| Target-decoy FDR控制 | 代谢物注释FDR |
| Library-free全自动工作流 | 当前代谢组学DIA没有等价工具 |

### 同构问题严重程度

**极高**。代谢组学DIA的核心瓶颈是：
1. 无法从结构预测MS2（蛋白质有碎裂规则，小分子没有通用规则）
2. DIA产生multiplexed MS2，去卷积极其困难（无precursor assignment）
3. library覆盖率<10%，library-based DIA代谢组学严重受限
4. DIAMetAlyzer虽有FDR，但依赖实验library

### 空白确认

- MaxDIA (Nature Biotech 2021)是蛋白质组学library-free DIA的里程碑
- 代谢组学中**没有等价工具**
- DreaMS只做了representation learning，没有做DIA deconvolution
- in silico MS2预测（NEIMS/CFM-ID/MS2DeepScore）存在，但与DIA去卷积的整合缺口巨大

### 核心技术方案

1. **In silico MS2生成层**：用CFM-ID/MS2DeepScore生成候选结构的理论谱图库（覆盖PubChem/HMDB全子结构空间）
2. **DIA解卷积层**：开发神经网络-based multiplexed MS2 demultiplexing，利用理论谱图作为先验模板
3. **FDR控制层**：基于decoy理论谱图的per-query置信度（直接对应DIA-NN的target-decoy FDR）
4. **端到端工作流**：输入raw DIA数据 → 输出带FDR控制的代谢物候选列表

### 竞争格局

- DIAMetAlyzer (NC 2022)：依赖实验library，无in silico生成能力
- MetaboMSDIA (2023)：做了DIA文件处理，无FDR
- **没有工具整合in silico预测 + DIA解卷积 + FDR控制三层**

### 发表潜力评估

- 源方法成熟度：8/10（DIA-NN 2020已证明paradigm）
- 代谢组学问题严重程度：9/10（library覆盖率<10%是公认瓶颈）
- 已有人做了吗：否（空白明确）
- 能否纯干实验完成：是（公开DIA数据集+公开in silico预测工具）
- **发表潜力：Nature Methods / Nature Communications（8/10）**

---

## 方向二：MALDI-MSI细胞类型解卷积 — 空间转录组学deconvolution范式移植

### 方法论同构性

| 空间转录组学deconvolution | MSI代谢组学等价 |
|--------------------------|--------------|
| Visium spot = 混合多细胞类型的bulk RNA信号 | MSI pixel = 混合多细胞类型的代谢物信号 |
| scRNA-seq单细胞参考图谱 | 单细胞代谢组学参考谱（SpaceM/HT SpaceM） |
| RCTD/cell2location：贝叶斯推断细胞类型比例 | MSI像素中各细胞类型的代谢贡献比例 |
| 输出：per-spot cell-type fraction + cell-type specific expression | 输出：per-pixel cell-type fraction + cell-type specific metabolic profile |

### 同构问题严重程度

**极高**。MSI数据的根本挑战之一：
- 常规MSI分辨率10-50 μm/pixel，每个pixel包含多种细胞
- 肿瘤微环境中肿瘤细胞/免疫细胞/基质细胞的代谢信号严重混叠
- 现有MSI分析（clustering）完全忽视了混叠问题，只做空间聚类

### 空白确认

- HT SpaceM (Cell 2025)已建立单细胞代谢组学参考数据的生成方法
- SpatialMETA/MAGPIE做了转录组+代谢组的空间对齐，但**不做代谢信号的细胞类型解卷积**
- Nature Methods 2024 (mass cytometry + MSI)需要实验配对数据，不是纯计算方法
- **没有工具专门将scRNA-seq参考图谱用于MSI信号的细胞类型解卷积**

### 核心技术方案

1. **参考库建立**：从HT SpaceM或公开单细胞代谢组学数据集提取细胞类型特异性代谢谱（参照cell2location用scRNA-seq建参考）
2. **统计模型**：适配negative-binomial模型（因MS强度分布与转录组不同，需用Poisson-Lognormal或Gamma-Poisson）处理MSI强度异质性
3. **空间正则化**：加入空间连续性先验（相邻像素细胞类型组成应平滑变化），类似CARD的空间感知版本
4. **评估框架**：用配对MALDI+scRNA-seq数据集（如spatially resolved MASLD liver, Nature Genetics 2025）验证

### 竞争格局

- 空间转录组学deconvolution已有>10个工具（RCTD、cell2location、CARD、Spotlight等）
- MSI侧：**完全空白**，连preprint都没有
- MALDI MSI高分辨率（单细胞级）才刚兴起（扩展协议2024），低分辨率MSI的混叠问题更迫切

### 发表潜力评估

- 源方法成熟度：9/10（RCTD/cell2location方法论完全成熟）
- 代谢组学问题严重程度：8/10（MSI解读的核心障碍）
- 已有人做了吗：否（文献真空）
- 能否纯干实验完成：是（公开MSI数据集 + 公开scRNA-seq参考 + 公开deconvolution代码可直接适配）
- **发表潜力：Nature Methods / Nature Communications（8.5/10）**

**额外优势**：HT SpaceM刚发Cell 2025，意味着单细胞代谢参考数据正在快速积累——方法出来后立刻有数据可用。这个时间窗口是近1-2年。

---

## 方向三：代谢状态轨迹推断 — scRNA-seq OT轨迹方法移植

### 方法论同构性

| scRNA-seq轨迹推断（Waddington-OT/STORIES） | 代谢组学等价 |
|------------------------------------------|------------|
| 细胞在基因表达空间中的状态 | 样本/细胞在代谢物空间中的代谢状态 |
| 时间序列scRNA-seq快照 | 纵向代谢组学时间点数据（干预、疾病进展、发育） |
| OT推断细胞状态转变的概率流 | OT推断代谢状态的转变路径（哪些代谢物共同变化？） |
| Waddington landscape（细胞分化势能面） | 代谢landscape（哪些代谢状态是稳定/不稳定的？） |
| 输出：细胞发育轨迹、基因调控网络方向 | 输出：代谢通量方向、代谢物因果驱动链 |

### 同构问题严重程度

**高**。代谢组学时间序列数据（纵向研究、干预研究、代谢疾病进展）面临的核心挑战：
- 现有工具（MetaboDynamics、MINIE）只做统计关联，不推断方向
- 代谢物变化的因果方向（A导致B还是B导致A）靠生化知识输入，非数据驱动
- OT方法的优势：不需要假设ODEs，只需要时间点"快照"（与FBA/ODEs形成方法互补）

### 空白确认

- Waddington-OT (Cell 2019)、Gene Trajectory (Nature Biotech 2025)、STORIES (Nature Methods 2025) 全在转录组学
- scRNA-seq的OT轨迹推断已发Nature Methods 2025 primer review
- **代谢组学中使用OT做longitudinal轨迹推断：文献零篇**（搜索结果确认）
- MINIE (npj Sys Bio 2025)是最近的时间序列代谢网络推断，但用贝叶斯回归，不用OT

### 核心技术方案

1. **代谢OT轨迹**：将Waddington-OT的框架应用于代谢物特征矩阵（N_samples × M_metabolites），推断代谢状态之间的转变概率
2. **代谢landscape重建**：用entropic OT估算代谢势能面，识别稳定代谢态（cancer, healthy, pre-disease）和转变路径
3. **通量方向推断**：将OT轨迹与已知代谢通路图对比，推断通路激活方向（区别于FBA的硬约束方法）
4. **关键创新点**：处理代谢组学特有的挑战——高噪声、缺失值、稀疏性——OT本身对这些有天然鲁棒性

### 局限性评估

- OT在代谢组学中的合理性假设：代谢状态变化遵循某种"最小代价"原则（与转录组学相比，这一假设在代谢组学中更难验证）
- 需要真正的纵向时间序列数据（横截面数据不适用）——但公开纵向代谢组学数据集存在（人类衰老、IBD、疫苗接种）

### 发表潜力评估

- 源方法成熟度：8/10（OT轨迹推断在转录组学已成熟）
- 代谢组学问题严重程度：7/10（纵向代谢研究的分析工具落后）
- 已有人做了吗：否（文献空白）
- 能否纯干实验完成：是（公开纵向代谢组学数据集）
- 最大风险：OT轨迹推断需要假设验证，"代谢最小代价转变"的生物学合理性需要论证
- **发表潜力：Nature Methods / Nature Communications（7.5/10）**

---

## 方向四：DIA代谢组学 FDR控制的谱图库体系 — MaxDIA范式移植

*注：此方向与方向一高度相关，可作为方向一的早期简化版本（仅做FDR体系，不做in silico生成）。*

### 核心差异

方向一是完整的"DIA-NN移植"（in silico预测 + 解卷积 + FDR）
方向四仅聚焦"MaxDIA移植"中的FDR控制层：

- 代谢组学DIA数据中，DIAMetAlyzer (NC 2022)已做FDR控制，但依赖实验library
- **真正的空白**：实验library覆盖率<10%时的FDR控制——当没有谱图匹配时如何控制假发现？
- 提出：基于null distribution modeling（而非target-decoy）的代谢物DIA FDR框架

**结论：这个方向本质上是方向一的子集，建议合并进方向一，不单独列为独立方向。**

---

## 方向五：代谢组学 In Silico MS/MS 扩散模型 — 正向谱图生成

### 方法论同构性

| 蛋白质结构预测（AlphaFold/ESMFold）范式 | 代谢谱图生成等价 |
|--------------------------------------|----------------|
| 从序列生成结构（正向问题，有理论指导） | 从分子结构生成MS2谱图（正向问题，有碎裂化学规律） |
| 扩散模型在蛋白质结构生成的成功 | 扩散模型用于MS2正向生成 |
| 条件生成：序列→结构 | 条件生成：SMILES+能量+加合物→MS2谱图 |

### 关键观察

- 现有文献（DiffMS、DiffSpectra 2025）全部做**逆问题**（谱图→结构），且在严格benchmark下准确率只有4.1%
- **正向生成**（结构→谱图）相对容易（NEIMS 85%准确率，CFM-ID已可用），但尚无扩散模型实现
- 扩散模型做正向生成的优势：可以**显式建模不确定性**（碎裂路径的多样性），生成谱图的置信区间——这是现有点估计方法（NEIMS/CFM-ID）完全做不到的

### 核心创新点（区别于已有工作）

1. **概率性MS2生成**：扩散模型生成MS2谱图的分布（不只是单点预测），捕获碎裂的随机性
2. **条件化因素**：能量（collision energy）、加合物类型（[M+H]+/[M+Na]+等）、仪器类型显式建模
3. **应用场景**：为DIA library-free流程提供理论谱图分布（与方向一协同），也可以直接改善in silico library的覆盖率

### 竞争格局

- 正向生成：NEIMS（神经网络点估计）、CFM-ID（概率性但基于Monte Carlo碎裂）
- **扩散模型做正向生成：无任何工作**
- DiffMS/DiffSpectra只做逆问题

### 发表潜力评估

- 源方法成熟度：9/10（扩散模型已在分子生成、蛋白质设计中成熟）
- 代谢组学问题严重程度：8/10（in silico谱图预测精度是核心瓶颈）
- 已有人做了吗：否（逆问题≠正向问题）
- 能否纯干实验完成：是（HMDB/MassBank公开实验谱图 + RDKit结构处理）
- 最大风险：正向问题已有NEIMS/CFM-ID，必须论证扩散模型的**概率性输出**是真正的新价值而非边际改进
- **发表潜力：Nature Methods / Analytical Chemistry（7/10）**

---

## 综合排名与评估矩阵

| 方向 | 方法论同构性 | 空白确认度 | 技术可行性 | 发表潜力 | 竞争时间窗口 | **综合** | 目标期刊 |
|------|------------|----------|----------|--------|------------|--------|---------|
| **方向二：MSI细胞类型解卷积** | 极强（1:1映射RCTD/cell2location） | 极高（文献零篇） | 高（源代码可直接适配） | 8.5 | 18-24月 | **8.5** | Nature Methods / NC |
| **方向一：代谢物DIA In Silico Library引擎** | 极强（DIA-NN全套范式） | 高（三层联动空白） | 中高（需整合3个技术组件） | 8.0 | 12-18月 | **7.8** | Nature Methods / NC |
| **方向三：代谢状态OT轨迹推断** | 强（Waddington-OT移植） | 高（文献空白） | 中（需验证OT假设在代谢组学的合理性） | 7.5 | 18-24月 | **7.0** | Nature Methods / NC |
| **方向五：扩散模型正向MS2生成** | 中强（正向生成类比蛋白质结构预测） | 中（逆问题有人做，正向尚无） | 高（扩散模型基础设施成熟） | 7.0 | 12-18月 | **6.8** | Nature Methods / Anal Chem |

---

## 详细分析：为什么是这5个方向，不是别的

### 已排除的看似有希望的方向

**因果推断/do-calculus移植**
- MINIE (2025)、COVRECON (2025)已做了代谢组学时间序列因果网络推断
- 文献空白不够干净，竞争者明确，不优先

**Long-read sequencing类比**
- IMS（离子淌度）作为"第四维"的类比：Met4DX (NC 2023)已做4D峰检测，空白已占据
- 压缩感知MSI：已有实现，工程改进而非算法创新

**基因组学variant calling共识方法**
- 这是"多引擎共识特征提取"（ALT2 综合7.0）的同构问题
- 该方向已在当前方向图谱中，不再作为跨学科发现新增

**蛋白质语言模型移植**
- T5ProtChem等unified模型已在做protein-molecule跨模态
- 代谢组学没有"序列"概念，移植的概念上不直接，需要大量重新设计

---

## 执行优先级建议

### 最优战略路径

```
立即启动（可与现有方向并行）：
├── 方向二（MSI解卷积）：技术可行性最高，源代码可直接适配
│   ├── 第1-2月：下载RCTD/cell2location代码，适配MSI强度模型
│   ├── 第3月：用spatially resolved MASLD liver (Nature Genetics 2025) 数据验证
│   ├── 第6月：benchmark vs 现有MSI clustering
│   └── 第12月：投稿Nature Methods
│
评估后启动（需先做可行性验证）：
├── 方向一（DIA In Silico Library）：
│   ├── 门控实验：用MetaboMSDIA + CFM-ID组合，在MTBLS DIA数据集上测试三层联动可行性
│   ├── 门控标准：in silico预测谱图的FDR控制是否能达到实验library的80%效果
│   └── 通过门控（概率~50%）→ 全力推进，目标NC
│
中期启动（方向一数据积累后）：
└── 方向三（OT轨迹）：
    ├── 用MetaboDynamics做的公开纵向数据集测试OT轨迹
    └── 关键验证：OT轨迹在代谢时间序列中是否与生化知识一致
```

### 方向二与方向一的协同效应

- 方向二（MSI deconvolution）：将scRNA-seq参考代谢谱用于空间MSI解析
- 方向一（DIA library-free）：扩大in silico library覆盖率
- **两者共同解决的是代谢组学的"注释覆盖率 < 10-30%"问题，但从不同角度出发，不相互竞争**

---

## 数据集资源

| 方向 | 公开数据集 | 访问路径 |
|------|----------|---------|
| 方向二（MSI解卷积） | MALDI-MSI + scRNA-seq配对数据（MASLD liver, Nature Genetics 2025）；HT SpaceM Cell 2025数据集 | EMBL-EBI / Zenodo |
| 方向二（MSI解卷积） | MetaboLights公开MALDI-MSI数据集 | MTBLS系列 |
| 方向一（DIA library） | SWATH-MS代谢组学（iProX/MetaboLights）；PXD系列DIA数据集 | ProteomeXchange / MetaboLights |
| 方向三（OT轨迹） | 纵向人类代谢组学（Stanford / PRISM衰老研究）；IBD代谢组学时间序列 | MTBLS、MetabolomicsWorkbench |
| 方向五（扩散模型正向生成） | HMDB实验谱图；MassBank；MassSpecGym (NeurIPS 2024) | HMDB.ca / MassBank / GitHub |

---

## 与现有方向体系的关系

| 本报告新提出方向 | 与现有方向的关系 |
|---------------|--------------|
| 方向二（MSI解卷积） | **全新**，不在现有图谱中，无重叠 |
| 方向一（DIA In Silico Library） | **全新**，现有M10.4（保形预测）关注注释不确定性，方向一关注library-free DIA解卷积，问题层次不同 |
| 方向三（OT轨迹） | 与M10.1（OT谱图相似度）**不同**：M10.1做谱图相似度计算，方向三做时间序列状态轨迹推断，完全不同场景 |
| 方向五（扩散模型正向MS2） | 部分与M10.5（DreaMS）相关，但DreaMS已淘汰；方向五做**正向生成**而非representation learning |

---

## 结论

**最高优先级推荐：方向二（MSI细胞类型解卷积）**

理由：
1. 与空间转录组学RCTD/cell2location的方法论同构性最强（1:1映射）
2. 文献空白最干净（没有任何preprint）
3. 时间窗口：HT SpaceM Cell 2025刚出，数据正在积累，工具需求正在出现
4. 技术可行性最高（RCTD/cell2location代码开源，只需适配MSI强度分布模型）
5. 目标期刊最高（Nature Methods或NC）

**第二优先级：方向一（代谢物DIA In Silico Library引擎）**

理由：
1. DIA-NN在蛋白质组学的影响力证明了这个范式的价值
2. 代谢组学DIA的核心瓶颈（library<10%+无FDR）是公认的重大问题
3. 需要先做门控实验验证可行性（in silico预测精度是否足够）

---

*报告生成时间：2026-03-16*
*文献检索覆盖：WebSearch × 14次，关键词涵盖DIA、单细胞代谢组学、空间组学、扩散模型、因果推断、OT轨迹、MSI解卷积等方向*
