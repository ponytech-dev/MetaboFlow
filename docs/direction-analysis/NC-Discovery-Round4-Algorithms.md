# NC 候选方向调研报告 — 第 4 轮：新算法范式 + 技术瓶颈

**日期**：2026-03-16  
**调研员**：Research Scout (Claude Sonnet 4.6)  
**背景**：前 3 轮 11 个候选均被否决或已先发，本轮聚焦新算法范式与具体技术瓶颈寻找空白。

---

## 一、视角 1：2024-2025 新算法范式在代谢组学的应用

### 1.1 Flow Matching / Rectified Flow

**搜索结果**：Flow Matching 在分子生成领域高度活跃（FlowMol、PropMolFlow 发 Nature Computational Science 2025）。但这些工作全部聚焦蛋白质/小分子 3D 结构生成，**不处理质谱谱图**。

**空白判断**：在代谢组学质谱场景，flow matching 可能的应用方向是"谱图-结构"双向生成（给定质谱生成分子结构，或给定结构生成质谱）。但目前 CFM-ID、FIORA（GNN）、DreaMS（Transformer）已先占。Flow matching 带来的优势（更直的 ODE 路径、更少步数）在质谱场景价值不明，且代谢物结构空间的离散-连续混合使 flow matching 实现复杂。

**结论**：此方向已被 FIORA 和 DreaMS 从不同角度覆盖，flow matching 在质谱的优势尚不明确，**暂不推荐**。

---

### 1.2 Neural ODE 在代谢动力学

**搜索结果**：
- SNODEP（2024 arXiv）：用神经 ODE process 预测代谢通量，输入 scRNA-seq，输出时变 flux/balance。
- KinDL（2025 bioRxiv）：从蛋白质组时序数据预测代谢物浓度时序，90-99% 准确率。
- npj Systems Biology 2025：机器学习+逆 ODE 推断不同条件下代谢网络动力学差异。

**空白判断**：以上工作都是"已知代谢网络结构 → 预测动力学"，或者输入 transcriptomics/proteomics 数据。**缺失的是**：直接从实测的稀疏代谢组时序数据（真实临床纵向研究，4-7 个时间点）推断个体级代谢动力学模型，并实现"跨个体泛化"（即给定新个体的 baseline 代谢组，预测其时序轨迹）。

**竞争者状态**：SNODEP 聚焦 flux 预测（不是代谢物浓度），数据来源是 scRNA；KinDL 需要蛋白质组输入。直接从临床纵向代谢组学时序数据做个体化 ODE 建模的工作**目前搜索结果干净**。

**初步兴趣**：中等。需要进一步核查公开纵向数据的可用性。

---

### 1.3 Conformal Prediction 在质谱

**搜索结果**：
- CPOD（Chemometrics and Intelligent Lab Systems 2025 Sep）：CP + Mahalanobis distance 用于 LC-MRM 数据的样本和峰双重异常检测，已发表。
- MassID（2026 Feb bioRxiv）：FDR 控制的代谢物注释概率，接近 CP 的精神。

**空白判断**：CP 在代谢组学的应用主要是 QC 异常检测（已被 CPOD 覆盖）和注释 FDR（MassID 已在做）。**未被覆盖的**：将 conformal prediction 用于定量校准的不确定性区间——即给定实验室间/批次间的质量偏移，用 CP 给每个测量浓度提供分布无关的置信区间。这与普通批次校正不同：CP 提供的是统计保证（coverage guarantee），而不只是点估计。

**竞争者状态**：CP 用于代谢物定量校准尚未有专门工作，搜索结果干净。但这是一个**方法论工具**类工作，NC 影响面存疑（更像 Anal Chem/J Proteome Res 方向）。

---

### 1.4 GNN 在代谢组学

**搜索结果**（2024-2025 活跃区域）：
- **MetDNA3**（Nature Communications 2025）：两层 GNN 网络注释，知识图谱 + 数据驱动，先发。
- **FIORA**（Nature Communications 2025 Mar）：GNN 预测键断裂概率 → 质谱预测，已发表。
- **scFEA/COMPASS** 系列：GNN 预测单细胞代谢通量，已成熟。
- **MS2MP**（2025）：GNN 直接从 MS/MS 预测 KEGG pathway，无需先注释，有趣但已在做。
- **ChemEmbed**（2025 bioRxiv）：多维分子嵌入 + 增强 MS/MS 数据，超越 SIRIUS。

**空白判断**：GNN 在谱图预测（FIORA）、网络注释（MetDNA3）、通量预测（scFEA）已被主要占据。**未被覆盖**：GNN 用于代谢物"同分异构体区分"——即利用分子图的拓扑差异（而非 SMILES 字符串）来预测不同异构体的 MS/MS 谱图差异。这是 FIORA 的扩展，但 FIORA 主要关注 `bond breaking` 模式，不专门针对异构体区分。

**竞争者状态**：部分重叠但未被直接覆盖，见视角 2 的异构体问题。

---

### 1.5 Mamba / State Space Model

**搜索结果**：搜索结果**完全没有** Mamba 在质谱/代谢组学的应用。Mamba 的应用集中在视觉和基因组学。

**空白判断**：质谱信号在本质上是一个"峰列表"（离散集合），不是连续时序，Mamba 的序列建模优势（长程依赖）在这里价值不明。**有价值的场景**可能是 MS imaging 的"空间序列建模"——MSI 数据可以看作沿扫描方向的像素序列，Mamba-ND 可能适合。但 MetaboFM（ViT 架构，2025 Oct 预印本）已在做 MSI foundation model，且 ViT 表现已很好。

**结论**：Mamba 在代谢组学的空白确实存在，但需要找到比 Transformer 有明显优势的具体场景。目前没有找到有说服力的切入点，**暂不推荐**。

---

### 1.6 RAG 范式在谱图检索

**搜索结果**：无代谢组学+RAG 的专门工作。MVP（multiview contrastive learning 2025 bioRxiv）做了谱图-分子联合嵌入空间，接近 RAG 的检索精神，但架构不同。

**空白判断**：标准 RAG = 向量检索 + LLM 生成。在代谢组学中，潜在的实现是："给定未知谱图 → 检索最相似的已知谱图 + 对应结构 → LLM 推理可能的结构变体"。这与现有的 spectral matching + in silico prediction 不同：RAG 的优势是把"语境"（相似化合物的碎裂规律）注入生成过程。DeepMet（Nature 2026）已在做类似的事（化学语言模型学习已知代谢物的生物合成逻辑）。

**结论**：RAG 精神在代谢物结构生成方面被 DeepMet 部分覆盖，独立 RAG 方法论工作的 NC 价值不高，**暂不推荐**。

---

### 1.7 Foundation Model — DreaMS 之后的空白

**搜索结果**：
- **DreaMS**（Nature Biotechnology 2025）：24M 谱图预训练，201M 谱图 Atlas，多个下游任务均 SOTA。
- **MetaboFM**（2025 Oct 预印本）：~4000 个公开 MSI 数据集的 ViT 模型，MSI 场景。
- **Foundation model for proteomics**（2025 arXiv）：蛋白质组场景。
- **Self-supervised learning from small-molecule MS**（Nature Biotechnology 2025）：与 DreaMS 同期。

**空白判断**：  
DreaMS 处理 MS/MS 谱图（片段质谱），MetaboFM 处理 MS1 imaging 数据。**DreaMS 的明确局限**：
1. 只处理 MS/MS，不处理 MS1 特征（保留时间、精确质量的联合利用）
2. DreaMS 的预训练目标是"预测 masked peaks"，对于未知化合物的结构推断能力有限
3. DreaMS 没有处理多种加合物形式的统一表示

**真正的空白**：把 DreaMS 的谱图嵌入与 RT 预测（RT-Transformer）、CCS 预测（HyperCCS）和精确质量进行多模态融合的统一 foundation model，且能给注释提供校准的概率输出（对标 MassID 的 FDR 控制）。这比单独的 DreaMS 多了多模态融合和不确定性校准两个维度。

---

### 1.8 自监督学习的最新进展

**搜索结果**：
- CMSSP（Analytical Chemistry 2025）：对比谱图-结构预训练，代谢物鉴定。
- SpecEmbedding（2025）：监督对比学习，replicated spectra 作正样本。
- MVP/MultiView（2025 bioRxiv）：多视角对比学习（分子图+指纹+谱图+共识谱图）。
- Learning from All Views（2025 bioRxiv Nov）：多视角对比框架用于代谢物注释。

**空白判断**：对比学习在谱图嵌入领域已相当饱和。差异化空间：针对**同分异构体**的细粒度对比学习（现有方法的正样本通常是同一化合物的不同谱图，但同分异构体对之间的细微差异没有被专门利用）。

---

## 二、视角 2：代谢组学日常技术瓶颈

### 2.1 Peak Alignment — RT 对齐

**搜索结果**：
- ChromAlignNet（已发表，GC-MS）：深度学习峰对齐，99% TPR。
- RT-Transformer（Bioinformatics 2024）：跨方法 RT 预测，~27-33 秒误差，已发表 NC 级别。
- MDL-TL（Analytical Chemistry 2025）：多数据集联合训练，word2vec 编码色谱参数。

**空白判断**：RT 对齐的主要剩余问题是**跨平台对齐**（不同仪器、不同实验室、不同年份的同一样品），RT-Transformer 用 transfer learning 部分解决，但实际用于 inter-lab 数据整合的系统性工具仍有空缺。然而这偏工程，NC 价值有限。

**结论**：RT 对齐的主要算法问题基本已解决，**不推荐**。

---

### 2.2 Missing Value Imputation

**搜索结果**：  
"To Impute or Not To Impute"（JASMS 2025）：系统性评估，结论是 MNAR 数据不能被 kNN/RF 处理，会产生扭曲的填补值。PX-MDC（Scientific Reports 2023）：用 PSO+XGBoost 分类缺失机制类型。

**空白判断**：  
MNAR 的根本问题是"低于检测限的值具有信息量"（absence of evidence ≠ evidence of absence）。现有深度学习填补方法（VAE、GAIN）没有专门针对代谢组学 MNAR 的机制建模。**潜在空白**：把代谢物的化学性质（极性、分子量、预测 logP）和 LC 方法参数作为 MNAR 机制的 informative priors，构建 MNAR-aware 的生成模型，使填补值本身具有校准的不确定性。

**竞争者状态**：此方向有多篇评估性文章，但没有专门用化学性质驱动 MNAR 机制建模的工作，搜索**较干净**。

**NC 可行性**：中等。是真实痛点，但可能偏统计方法论，影响面取决于 benchmark 的系统性。

---

### 2.3 Feature Annotation — 覆盖率 < 10% 的根本问题

**搜索结果**：  
- DeepMet（Nature 2026 Jan）：化学语言模型预测潜在未知代谢物结构，验证率 60%。
- MassID（2026 Feb bioRxiv）：端到端管道，FDR < 5% 下注释 1200+ 化合物，近完全注释。
- MetDNA3（NC 2025）：网络传播注释 12,000+ 推断代谢物。
- Dark matter 综述（2025）：ISF 占 METLIN 数据库 70% 的 MS/MS 特征。

**空白判断**：  
DeepMet 解决"生成候选结构"，MassID 解决"FDR 控制注释"，MetDNA3 解决"网络传播"。**真正未解决的**：把这三个维度统一——给定未知谱图，同时输出（1）候选结构的概率排名（2）每个候选的校准置信度（3）与已知代谢网络的生化合理性评分。这三者目前是分离的工具链，没有统一框架。

**但注意**：这个方向与之前被否决的"统一注释框架"高度重叠，需要找到算法创新的新支点，不能是纯工程集成。

---

### 2.4 Adduct Annotation — 加合物注释

**搜索结果**：  
2025 Feb bioRxiv：系统分析 LC-MS 中 ISF 的规律，发现 ISF 占公开数据集中 <10% 的特征（但占 METLIN 数据库 70%）。现有工具（CAMERA, mzMine）基于规则，错误率高。

**空白判断**：  
加合物（[M+Na]+、[M+NH4]+ 等）和 ISF 的同时、系统性预测——即给定 MS1 特征集，在无先验知识情况下，把同一化合物的所有离子形式（母体离子、加合物、ISF、同位素）聚类成一个"feature group"，且给出每个离子形式的概率。现有方法（Khipu 2025）已做了 khipu-based pre-annotation，但仍基于规则。**深度学习驱动的加合物-ISF 联合预测**尚无专门工作。

**竞争者状态**：Chi et al. 2025 的 khipu 方法是规则系统，深度学习版本空白较干净。

---

### 2.5 同分异构体区分

**搜索结果**：  
- RT 预测辅助异构体区分（RT-Transformer 2024）：可区分保留时间差异 >60s 的异构体。
- 2025 bioRxiv：同位素追踪辅助代谢物鉴定，提供正交信息。
- 离子淌度/CCS：2025 研究中 0.4% CCS 误差可区分同质量脂质异构体。

**空白判断**：  
多维度联合区分：MS2 + RT + CCS 三维信息的**贝叶斯融合框架**，专门针对同分异构体对（positional isomers, cis/trans, enantiomers）。关键是：当 MS2 无法区分时，RT 和 CCS 能贡献多少信息？如何量化"可区分性"并提供校准的概率输出？  
现有工具（SIRIUS+CSI:FingerID）没有明确处理"多个候选得分相近时的异构体区分"。

**竞争者状态**：RT+CCS 联合注释有工作（2025 MSI 流程），但专门针对异构体对的贝叶斯区分框架**较干净**。

---

### 2.6 谱图库覆盖率

**搜索结果**：  
- FIORA（NC 2025）：GNN 预测键断裂 → 高质量 in silico 谱图，扩充库覆盖率。
- DreaMS（Nat Biotech 2025）：自监督预训练，下游 fingerprint 预测 SOTA。
- In silico spectral library for 120,514 compounds（Springer 2025）：基于 NORMAN 名单的正向预测库。
- SingleFrag（Briefings in Bioinformatics 2025）：深度学习工具预测 MS/MS 片段和谱图。

**空白判断**：  
in silico 谱图生成已有多个强工具。**剩余核心问题**：生成的 in silico 谱图的**可靠性评估**——哪些谱图是可信的？哪些是错误的？现有工具都给出谱图但没有可靠的不确定性估计。**Uncertainty-aware in silico spectrum prediction**：输出谱图的同时给出每个碎片峰的校准置信区间，使用户知道哪些片段是可信的（用于注释），哪些是不可信的（应忽略）。

**竞争者状态**：不确定性量化在代谢物谱图预测中几乎没有专门工作，搜索**干净**。

---

### 2.7 CCS 预测的最新进展

**搜索结果**：  
- HyperCCS（Analytical Chemistry 2025）：化学大语言模型微调，改进 CCS 预测。
- 2025 MSI 流程：cyclic IMS + ML 预测 CCS，平均误差 0.4%，可区分同质量脂质。
- DeepCCS（2019）到 HyperCCS（2025）：CCS 预测精度稳步提升。

**空白判断**：  
CCS 预测的泛化问题：大多数 ML-CCS 方法在训练集之外泛化性差（benchmark 指出）。**专门针对 out-of-distribution（OOD）化合物的 CCS 预测**：用 conformal prediction 或贝叶斯方法量化预测不确定性，让用户知道"此化合物的 CCS 预测可靠性如何"。这与 HyperCCS 不同：不是提高平均精度，而是提供逐样本的可靠性保证。

**竞争者状态**：这与前面 2.6 的 uncertainty quantification 主题相似，都是 UQ 应用。

---

### 2.8 嵌合谱图解卷积

**搜索结果**：  
- DecoID（Nature Methods 2021）：LASSO 混合谱图分解，已发表。
- DNMS2Purifier（Analytical Chemistry 2023）：de novo 清洗嵌合谱图，已发表。
- DI-MS2（Rapid Comm Mass Spec 2026）：直接进样模式通过步进式隔离窗口解卷积，新方法。
- CHIMERYS（Nature Methods 2025）：蛋白质组学嵌合谱图，已发表但是蛋白质组。

**空白判断**：  
代谢组学嵌合谱图的主要剩余问题：**DIA 数据的嵌合谱图**问题比 DDA 严重得多（每个 cycle 里多个前体共同碎裂）。现有 DecoID 是 DDA 方法。DIA 专用的深度学习嵌合谱图解卷积（区别于 DecoMetDIA 的 SWATH 规则方法）是一个明确空白。

**但需要核查**：之前第 2 轮已否决 DIA library-free（通用版 cosine 仅 0.35，脂质版已被 MS-DIAL5+LipidIN 占）。DIA 嵌合谱图解卷积与 DIA library-free 注释有重叠——需要审慎评估。

---

## 三、视角 3：代谢组学与其他组学的方法论差距

### 3.1 蛋白质组学有而代谢组学没有的

| 蛋白质组学工具 | 代谢组学等价需求 | 空缺程度 |
|---|---|---|
| Percolator（半监督 FDR 控制） | 代谢物注释 FDR 控制 | MassID 2026 已在解决 |
| DeepLC（LC 保留时间预测） | RT-Transformer 2024 已覆盖 | 已解决 |
| AlphaPeptStats（统计框架） | MetaboAnalystR 4.0 2024 覆盖 | 基本解决 |
| Protein isoform resolution | **代谢物异构体区分** | **明确空缺** |
| Spectral archive（PXD/PRIDE） | 代谢组学存档标准 | 基础设施问题，非算法 |

**结论**：蛋白质组学视角下，代谢物异构体区分是最明确的算法空缺。

---

### 3.2 基因组学算法在代谢组学的等价需求

**Variant calling 等价**：代谢组学没有直接等价概念——代谢物没有等位基因。但"代谢 QTL（mQTL）分析"有一定相似性（找哪个基因位点影响代谢物水平），已有工作（2024 Nature Genetics）。

**Phasing 等价**：无明显等价需求。

**结论**：基因组学算法迁移的代谢组学需求不清晰，**不推荐**。

---

### 3.3 单细胞 RNA-seq 方法论差距

**搜索结果**：  
- trajectory inference（pseudotime）：scFEA/COMPASS 已把 GNN flux 与 scRNA 结合，有工作。
- 降维/聚类：标准 UMAP/Leiden 已应用于 SC-metabolomics。
- **核心未解决问题**：单细胞代谢组的**数据稀疏性**——每个细胞只能检测 50-200 个代谢物（vs. scRNA 的 10,000+ 基因），且 dropout 率极高。

**空白判断**：  
scRNA-seq 的 imputation 方法（MAGIC、SAVER、scImpute）基于"基因共表达"的先验，在单细胞代谢组学中等价物是"代谢物共现的生化约束"（同一通路的代谢物应相关）。**把代谢网络先验注入单细胞代谢组 imputation** 是一个明确的方法论空缺。

**竞争者状态**：搜索到的 HT SpaceM（2025 Cell）专注测量方法而非计算。S2IsoMEr（2025）处理分子模糊性。**代谢网络约束的单细胞代谢组 imputation 搜索干净**。

---

## 四、NC 候选方向综合提案

### 候选 A：Uncertainty-Aware In Silico Spectrum Prediction（谱图预测不确定性）

**科学问题**：当前 in silico 谱图预测工具（CFM-ID、FIORA）输出谱图但没有可靠的逐峰不确定性估计，导致用户无法判断预测的哪些片段可信、哪些是 hallucination。

**为什么是空白**：FIORA（NC 2025）做了 GNN 谱图预测，但输出是点估计（概率值），没有校准的区间。DreaMS 做了 fingerprint 预测的不确定性量化，但没有延伸到谱图预测。在蛋白质组学中，谱图预测的不确定性量化（如 pDeep3 的 Monte Carlo dropout）已有先例，但代谢组学无对应工作。

**算法创新点**：  
- 用 conformal prediction 在 FIORA/CFM-ID 的预测之上构建逐峰的 marginal coverage 保证  
- 或用 deep ensemble + temperature scaling 给出校准的 fragment probability 分布  
- 关键贡献：证明 UQ 可以提高下游注释准确率（高不确定性的预测片段应降权）

**数据来源**：GNPS GeMS（数百万谱图，公开），NIST 23（需申请，但有子集公开），MassBank（公开）

**竞争者分析**：
- FIORA（NC 2025）：无不确定性输出
- DreaMS（Nat Biotech 2025）：fingerprint UQ，非谱图 UQ
- MDPI Int J Mol Sci 2024：MS 性质预测的 UQ（标注不可靠预测），提到了问题但没有系统解决
- **搜索干净度**：较干净，无直接竞争者

**NC 可行性初评**：  
- 影响面：中等偏高（所有做 in silico 谱图的用户都受益）  
- 算法创新：有（conformal prediction 在谱图预测的 coverage guarantee 是新的）  
- 单人 12-18 月：可行（在 FIORA 基础上扩展，数据公开）  
- 风险：结果可能只是 marginal 改进，"UQ 是否真的有用"需要强有力的 downstream task 验证

**初评分**：6.5/10

---

### 候选 B：代谢网络约束的单细胞代谢组 Imputation（scMetabo-Net）

**科学问题**：单细胞代谢组学数据极稀疏（每细胞 50-200 代谢物，高 dropout），现有 imputation 方法（为 scRNA 设计）忽略了代谢网络的生化约束，导致填补值违反代谢可行性（例如，催化同一反应的底物和产物应相关）。

**为什么是空白**：  
- scRNA imputation 方法（MAGIC、SAVER）假设基因共表达，无生化结构先验  
- 代谢组 imputation（kNN、RF）处理整体缺失，不针对 SC 场景  
- scFEA/COMPASS 预测通量而非浓度，且需要 scRNA 输入  
- **直接从单细胞代谢组数据 + 代谢网络先验做 imputation 的工作：搜索干净**

**算法创新点**：  
- 把 KEGG/Recon3D 代谢网络编码为 GNN 的边约束  
- 设计 metabolic-constraint VAE（MC-VAE）：decoder 的生成分布受代谢网络约束（相邻代谢物的协方差由反应化学计量矩阵 S 决定）  
- 或用 message passing 在代谢网络图上传播已测量代谢物的信号来填补未测量的

**数据来源**：  
- HT SpaceM（2025 Cell，Rappez et al.，MALDI SC-metabolomics，公开）  
- METASPACE（空间代谢组单细胞数据，公开）  
- scSpaMet（NC 2023，已公开）

**竞争者分析**：
- S2IsoMEr（2025）：处理分子模糊性，非 imputation
- HT SpaceM（2025 Cell）：测量方法，非计算
- scFEA（Genome Research 2021）：flux 预测，需 scRNA  
- **搜索干净度**：较干净

**NC 可行性初评**：  
- 影响面：高（SC 代谢组学是 2024-2025 的热点，Cell/Nature Methods 最近都发了 SC 代谢组方法）  
- 算法创新：高（代谢网络约束 + 生成模型的结合是新颖的）  
- 单人 12-18 月：可行，但需要较深的 GNN 建模经验  
- 风险：SC 代谢组公开数据集规模仍小（HT SpaceM 最大），可能限制模型的 generalization 验证

**初评分**：7.5/10

---

### 候选 C：多维证据的同分异构体区分贝叶斯框架（IsoDistinguish）

**科学问题**：代谢组学中约 30-40% 的注释候选有结构异构体（位置异构体、顺反异构体）具有几乎相同的 MS2，当前注释工具（SIRIUS、CFM-ID）对异构体候选的评分差异 <0.05，无法区分，用户只能选"均报告"或"随机选一"。

**为什么是空白**：  
- RT 预测（RT-Transformer）可以辅助区分，但没有与 MS2 和 CCS 的系统性融合  
- CCS 预测（HyperCCS）单独用，但没有与 MS2 和 RT 的联合贝叶斯框架  
- 2025 MSI 流程把 CCS 用于脂质异构体，但只是单一场景  
- **专门针对任意代谢物同分异构体对的 MS2+RT+CCS 贝叶斯区分框架：搜索干净**

**算法创新点**：  
- 把 MS2 相似度、RT 偏差、CCS 偏差建模为三个独立的似然函数  
- 用贝叶斯更新给出"候选 A vs. 候选 B（同分异构体）的后验概率比"  
- 关键贡献：首次系统量化"哪些情况下 RT/CCS 可以打破 MS2 对异构体的区分平局"  
- 扩展：建立"同分异构体可区分性图谱"——对 HMDB 中的所有异构体对预测可区分性

**数据来源**：  
- NIST 23（多仪器、多条件的标准品谱图，公开子集）  
- HMDB（结构数据库，公开）  
- MetaboLights（有 RT 标注的公开数据集）  
- AllCCS/CCS Atlas（CCS 数据，公开）

**竞争者分析**：
- RT-Transformer（Bioinformatics 2024）：RT 预测，非异构体专用框架  
- HyperCCS（Anal Chem 2025）：CCS 预测，非异构体融合  
- 2025 Spatial Metabolomics Annotation（JASMS 2025）：CCS+MS2 用于脂质，单场景  
- **搜索干净度**：干净（最干净的候选之一）

**NC 可行性初评**：  
- 影响面：高（异构体区分是所有代谢组学实验室的共同痛点）  
- 算法创新：中高（贝叶斯融合本身不新，但在此场景是首次系统化）  
- 单人 12-18 月：可行（不需要新数据，在现有预测工具基础上构建融合层）  
- 风险：如果 RT+CCS 预测本身误差较大，融合后可能改善有限；需要在大规模同分异构体 benchmark 上验证（NIST 中有多少同分异构体对？需要核查）

**初评分**：7.0/10

---

### 候选 D：Neural ODE 驱动的个体化纵向代谢动力学模型（MetaboODE）

**科学问题**：现有纵向代谢组学分析（4-7 个临床时间点）只做横截面的差异分析或混合效应模型（ANOVA），无法捕捉个体内的连续代谢状态轨迹，也无法预测新个体在干预后的代谢演化。

**为什么是空白**：  
- SNODEP（2024）：预测代谢通量，输入是 scRNA，不直接适用于临床纵向代谢组数据  
- KinDL（2025 bioRxiv）：需要蛋白质组时序数据，代谢组是输出而非输入  
- ODE-based mechanistic modeling：需要已知反应网络，无法处理未注释代谢物  
- **直接从稀疏临床纵向代谢组数据学习个体化 ODE 并泛化：搜索干净**

**算法创新点**：  
- 用 Latent ODE（Rubanova et al. 2019）的框架，但加入代谢组学专用先验：  
  (1) 代谢物间的相关性先验（来自代谢网络）  
  (2) 时间点稀疏性处理（不规则采样，最少 2-3 个时间点就能推断轨迹）  
- 模型输出：个体的代谢状态轨迹（连续）+ 对指定时间点的预测  
- 关键贡献：第一个专门设计用于临床纵向代谢组（不需要额外 omics 数据）的 latent ODE 方法

**数据来源**：  
- Alzheimer's disease 纵向代谢组（medRxiv 2025，4063 样本，1430 参与者，7 年）  
- MetaboLights 上的多个纵向干预研究  
- HMDB 数据作为代谢网络先验

**竞争者分析**：
- RM-ASCA+（已被否决）：是统计分解方法，不是 ODE 建模  
- SNODEP（2024）：有 ODE，但输入是 scRNA，目标是 flux  
- **搜索干净度**：干净

**NC 可行性初评**：  
- 影响面：中高（纵向代谢组是临床研究热点，但数据仍稀缺）  
- 算法创新：高（latent ODE + 代谢网络先验是新颖组合）  
- 单人 12-18 月：可行，但需要扎实的 ODE 建模经验  
- 风险：公开的临床纵向代谢组数据集数量有限，验证可能受限；且这个方向与 SNODEP 的概念差距需要明确阐明（narrative 要清晰）

**初评分**：6.5/10

---

### 候选 E：MNAR-aware 代谢组缺失值生成模型（MetaboMNAR）

**科学问题**：代谢组学中 20-60% 的特征有缺失值，且大多数是 MNAR（Missing Not At Random，即低于检测限）。现有方法（kNN、RF、QRILC）或者无法处理 MNAR，或者要求假设正态分布，导致填补值扭曲下游统计分析。

**为什么是空白**：  
- 现有最佳方法（QRILC）假设截断正态分布，与真实 MNAR 机制不符  
- 没有方法把代谢物的化学性质（极性、疏水性、分子量、检测限与结构的关系）作为 MNAR 机制的 informative prior  
- **用化学性质驱动 MNAR 机制建模的生成模型：搜索干净**

**算法创新点**：  
- 把 MNAR 机制建模为：P(missing | value, chemical_properties)  
  其中 chemical_properties 包括 logP、极性表面积、分子量  
- 用 variational autoencoder（VAE）+ MNAR 专用 decoder 填补，decoder 受化学性质约束  
- 关键贡献：首次用化学结构先验来指导 MNAR 填补，并用 calibration metrics 验证

**数据来源**：完全公开（MetaboLights、HMDB 结构数据、公开 LC-MS 数据集）

**竞争者分析**：  
- QRILC：假设截断正态，不用化学先验  
- PX-MDC（2023）：分类缺失机制类型，但不做填补  
- "To Impute or Not"（JASMS 2025）：评估文章，不提供新方法  
- **搜索干净度**：较干净

**NC 可行性初评**：  
- 影响面：高（缺失值是所有代谢组学数据分析的普遍问题）  
- 算法创新：中（VAE 用于缺失值不新，但 MNAR 化学先验是新的）  
- 单人 12-18 月：可行  
- 风险：需要收集大量代谢物的化学性质数据（但 HMDB 已有）；"改善幅度"可能不大，需要很好的 benchmark 设计

**初评分**：6.0/10

---

## 五、候选方向综合排名

| 排名 | 候选 | 初评分 | 竞争者干净度 | 关键风险 |
|------|------|--------|------------|---------|
| 1 | B：单细胞代谢网络 Imputation | 7.5 | 较干净 | SC 数据规模小 |
| 2 | C：同分异构体贝叶斯区分框架 | 7.0 | **最干净** | RT/CCS 预测误差传播 |
| 3 | A：谱图预测不确定性量化 | 6.5 | 较干净 | 下游 task 改进幅度 |
| 4 | D：纵向代谢 latent ODE | 6.5 | 干净 | 数据集规模，SNODEP 差异阐明 |
| 5 | E：MNAR 化学先验 VAE | 6.0 | 较干净 | 改进幅度需强 benchmark |

**最推荐进入压力测试的方向**：候选 B 和候选 C。

- **候选 B**（单细胞代谢网络 imputation）：时机好（SC 代谢组 2024-2025 爆发），算法创新点清晰，但需要核查 HT SpaceM 等数据集的规模是否足够。
- **候选 C**（同分异构体贝叶斯区分）：竞争者最干净，问题是每个实验室都有的痛点，算法不复杂但 narrative 强。需要核查 NIST 23/HMDB 中同分异构体对的数量和质量。

---

## 六、已排除方向快速说明

| 方向 | 排除原因 |
|------|---------|
| Flow matching 用于代谢物结构 | FIORA、DreaMS 已占，flow matching 在质谱场景优势不明确 |
| Mamba 在代谢组学 | 质谱数据非连续序列，ViT 在 MSI 已够好（MetaboFM） |
| RAG 谱图检索 | DeepMet（Nature 2026）已覆盖核心精神 |
| RT 对齐 | ChromAlignNet、RT-Transformer 已解决主要问题 |
| Batch effect 深度学习 | NormAE、RALPS 已有多个工作，竞争饱和 |
| DIA 嵌合谱图 | 与已否决的 DIA library-free 方向重叠高 |
| 基因组学算法迁移 | 代谢组无明确等价需求 |

---

## 七、下一步行动建议

1. **候选 B 数据可行性核查**：
   - 下载 HT SpaceM 数据集，确认 cell 数量和代谢物数量
   - 搜索 METASPACE 中公开的 SC 数据集规模
   - 评估是否有足够的同类型数据做 cross-validation

2. **候选 C 数据可行性核查**：
   - 在 NIST 23 公开子集中统计有多少同分异构体对（相同分子式，不同结构）
   - 在 MetaboLights 上查找同时有 MS2 + RT + CCS 标注的标准品数据集
   - 评估 HyperCCS 和 RT-Transformer 在同分异构体对上的实际误差

3. **候选 A 进一步评估**：
   - 查看 MDPI Int J Mol Sci 2024 的"UQ for MS-related properties"是否已覆盖谱图预测（而非只是 RT/CCS）
   - 确认 FIORA 的输出是否已有某种不确定性表示

---

## 八、参考资料

- [DreaMS - Nature Biotechnology 2025](https://www.nature.com/articles/s41587-025-02663-3)
- [MetaboFM preprint - bioRxiv 2025](https://www.biorxiv.org/content/10.1101/2025.10.23.684227v1)
- [FIORA - Nature Communications 2025](https://www.nature.com/articles/s41467-025-57422-4)
- [MetDNA3 - Nature Communications 2025](https://www.nature.com/articles/s41467-025-63536-6)
- [DeepMet - Nature 2026](https://www.nature.com/articles/s41586-025-09969-x)
- [MassID - bioRxiv 2026](https://www.biorxiv.org/content/10.64898/2026.02.11.704864v1)
- [HT SpaceM - Cell 2025](https://www.cell.com/cell/fulltext/S0092-8674(25)00929-8)
- [SNODEP - arXiv 2024](https://openreview.net/forum?id=hs1AWLx6U5)
- [CPOD - ScienceDirect 2025](https://www.sciencedirect.com/science/article/pii/S0169743925002242)
- [RT-Transformer - Bioinformatics 2024](https://academic.oup.com/bioinformatics/article/40/3/btae084/7613958)
- [HyperCCS - Analytical Chemistry 2025](https://pubs.acs.org/doi/10.1021/acs.analchem.5c03492)
- [To Impute or Not - JASMS 2025](https://pubs.acs.org/doi/10.1021/jasms.4c00434)
- [Systematic pre-annotation ISF - bioRxiv 2025](https://www.biorxiv.org/content/10.1101/2025.02.04.636472v2.full)
- [Spatial Metabolomics CCS Annotation - JASMS 2025](https://pmc.ncbi.nlm.nih.gov/articles/PMC12142677/)
- [MVP Multiview - bioRxiv 2025](https://www.biorxiv.org/content/10.1101/2025.11.12.688047v1)
- [ChemEmbed - bioRxiv 2025](https://www.biorxiv.org/content/10.1101/2025.02.07.637102v1)

