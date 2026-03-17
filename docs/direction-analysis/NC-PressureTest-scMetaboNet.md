# NC 压力测试报告：scMetabo-Net（单细胞代谢组学网络约束 Imputation）

**审查日期**：2026-03-16  
**审查标准**：NC 级别（严格，7+ 才推荐继续）  
**候选方向**：GNN + VAE 结合 KEGG/Recon3D 代谢网络先验，对单细胞代谢组学数据做网络约束 Imputation

---

## 1. 竞争者深度搜索

**评分：3/10**（竞争者密度远高于预期，空白被显著压缩）

### 1.1 已存在的直接竞争者

**MGFEA（Multiple Graph-based Flux Estimation Analysis，bioRxiv 2024.06）**
- 这是最危险的竞争者，完全对应本方向的核心技术组合
- 输入：scRNA-seq 或空间转录组；输出：代谢物水平推断
- 方法：VGAE（Variational Graph Autoencoder）+ 从 GSMM（Genome-Scale Metabolic Models）构建的知识图作为网络先验
- 比 scMetabo-Net 声称的"空白"早发布约 18 个月，且已在 bioRxiv 上公开
- 与本方向的差异仅在于：MGFEA 输入是转录组而非代谢组直接测量值

**MINMA（Bioinformatics 2018，~100+ 引用）**
- 已完整实现"代谢网络 + 缺失值 Imputation"的核心思路
- 方法：SVR + 代谢网络邻居作为预测特征
- 虽然发表于 2018 年且不针对 SC 场景，但核心 idea（代谢网络约束 imputation）已被做过

**PEPerMINT（Bioinformatics ECCB 2024）**
- GNN 用于质谱蛋白质组 imputation，利用肽段-蛋白质网络图作为先验
- 直接类比：同样是"MS 数据 + 网络先验 + GNN imputation"
- 代谢组版本的 PEPerMINT 是显而易见的后续工作，已被认知

**Cross-Platform Metabolomics Imputation（npj Syst Biol Appl，2025/2026）**
- 使用 Importance-Weighted Autoencoder（VAE 变体）进行代谢组 imputation
- 发表于 npj Systems Biology，属于 Nature 旗下期刊
- 核心技术（VAE for metabolomics imputation）与本方向完全重叠

**Multi-View VAE for Metabolomics Imputation（PMC 2023）**
- 多视角变分自编码器，明确用于代谢组 untargeted 数据 imputation

### 1.2 间接但紧密相关的工作

| 工作 | 关系 | 发表地点 |
|------|------|---------|
| scFEA (2021) | GNN + 代谢网络约束估算 SC fluxome | Genome Research |
| COMPASS (2021) | 代谢网络约束 SC 通量（scRNA 输入） | Cell |
| scSpaMet (NC 2023) | SC 空间代谢组分析框架，含深度学习联合嵌入 | Nature Communications |
| HT SpaceM (Cell 2025) | SC 代谢组大规模数据 + 统一计算框架 | Cell |
| METASPACE-ML (NC 2024) | ML 用于 MALDI 代谢组注释 | Nature Communications |

### 1.3 关键结论

本方向声称的三个"空白"均已被削弱：
1. "scRNA imputation 无生化先验" → MGFEA 已用 VGAE + GSMM 做了相同的事（输入是 RNA 而非代谢物，但方法论空白已被占领）
2. "代谢组 imputation 不针对 SC 场景" → MINMA 系列 + VAE 系列正在覆盖，SC 特异性是渐进改进而非颠覆性突破
3. "scFEA/COMPASS 需要 scRNA 输入" → 确实为空白，但这个空白支撑的是"用代谢物测量值直接做"的方向，而非 imputation 本身

---

## 2. 数据可行性

**评分：4/10**（数据规模存在，但验证 ground truth 匮乏，训练可行性存疑）

### 2.1 现有 SC 代谢组数据集规模

| 数据集 | 细胞数 | 代谢物数 | 来源 |
|--------|--------|---------|------|
| HT SpaceM (Cell 2025) | 140,000+ | 73（LC-MS/MS 验证）/ 135 离子（原始） | BioStudies S-BSST2127 |
| scSpaMet (NC 2023) | 19,507 / 31,156 / 8,215（3 组织） | ~数十至百余（MALDI） | 文中可获取 |
| MetCell SC Atlas (NM 2025) | 45,603（小鼠肝脏） | ~800（离子迁移质谱） | 新发布 |

**表面上数据规模充足（尤其 HT SpaceM 14 万细胞）**，但存在根本性问题：

### 2.2 Ground Truth 问题（致命性）

- SC 代谢组**没有独立已知浓度**来验证 imputation 质量
- HT SpaceM 的验证方式是"对比 bulk LC-MS/MS"——这是批量平均值，而非单细胞真值
- 约 54% 分子式能被 bulk LC-MS/MS 检测，74 个代谢物达到 Level 1 注释
- **因此 imputation 的评估标准无法成立**：你填补的值对不对，没有办法知道
- scRNA imputation 领域的 Schaum 等人（2019）用 Tabula Muris 做 holdout 验证，但代谢组缺乏类似资源

### 2.3 训练 GNN + VAE 的数据量是否足够

- GNN+VAE 对 SC 数据的训练要求：通常需要 1 万+ 细胞，且特征要一致（同一组代谢物）
- HT SpaceM 提供了 14 万细胞，但仅检测 73-135 个代谢物，维度极低
- 真正能训练消息传递网络的条件：需要多细胞同时检测同一套 KEGG 代谢物——实际上每个细胞只覆盖 50-200 个代谢物，且不同细胞覆盖的集合**不一致**
- 这使得无法直接构造样本×特征矩阵来训练模型

### 2.4 数据获取可行性

- HT SpaceM 数据公开（BioStudies S-BSST2127）
- METASPACE 提供 10,000+ 公开数据集（metaspace2020.org）
- 数据本身可获取，问题在于如何定义训练目标

---

## 3. 技术可行性

**评分：3/10**（存在多个基础性技术障碍）

### 3.1 网络约束在极稀疏情况下是否有意义

**每细胞 50-200 个代谢物 vs KEGG 总计约 2500 个代谢物 = 覆盖率 2-8%**

- Recon3D 包含 4140 个代谢物、13543 个反应；KEGG 全局代谢图更庞大
- 在 2-8% 覆盖率下，代谢网络中绝大多数节点是未观测的
- GNN message passing 依赖邻居节点传递信息——如果邻居本身也是 missing，消息传递退化为噪声放大
- 尤其是代谢网络存在"hub 代谢物"（如 ATP、NAD+、CoA），这些是代谢通路的交汇点，如果这类关键节点也是 missing，整个约束机制失效

### 3.2 代谢网络拓扑与 GNN 兼容性问题

- 代谢网络是 hypergraph（超图）结构：一个反应涉及多个底物和产物，不是简单的二元边
- 标准 GNN 假设二元边，将代谢反应强行转化为二元图会损失化学计量约束信息
- Recon3D 的有向二部图（代谢物-反应-代谢物）需要特殊的图网络架构
- scFEA 已经用 factor graph 处理了这个问题——本方向如果直接用标准 GNN，结构不对；如果用 factor graph，与 scFEA 的差异只剩"输入是代谢物而非转录组"

### 3.3 VAE 在高维低样本场景的已知问题

- SC 代谢组：每细胞 50-200 个观测值，样本量（细胞数）虽大，但特征向量极短且高度稀疏
- VAE 的 posterior collapse 问题：当输入维度低、缺失比例高时，decoder 绕过 latent space 直接输出先验均值
- SC 代谢组的稀疏结构与 scRNA-seq 不同：scRNA-seq 中"零"来自技术 dropout，而代谢组中"缺失"可能是代谢物真实不存在（MNAR），这两种情况的处理策略根本不同

### 3.4 基础性数学问题

**问题 1：欠定系统**  
设 n 个代谢物、m 个反应，典型值 n=50-200（观测），m=13543（Recon3D 全量）。约束方程数 >> 观测量，系统严重欠定，网络约束无法起到正则化效果，只会引入更多参数。

**问题 2：Imputation 目标不可验证（贝叶斯观点）**  
设 x_obs 是观测代谢物，x_mis 是缺失代谢物。P(x_mis | x_obs, network) 的后验分布无法用 SC 数据的 marginal likelihood 验证，因为没有任何样本同时观测了所有代谢物。这与 scRNA-seq 的情况不同——scRNA-seq 中 bulk RNA-seq 可以提供"所有基因都表达时"的参考分布，而 SC 代谢组没有等价的参考。

**问题 3：代谢物 missing 的性质**  
MALDI-based SC 代谢组的 missing 主要是 MNAR（低于检测限即不检测），而非 MCAR。网络约束的 imputation 实际上是要"预测低丰度代谢物的存在"——但低丰度本身可能是真实的细胞异质性，而非技术丢失，imputation 会抹去真实的生物学信号。

---

## 4. NC 级别评估

**评分：3/10**

### 4.1 发文趋势

单细胞代谢组学在 2024-2025 年发表势头强劲：
- HT SpaceM → Cell（2025）：技术方法类，最高档
- MetCell → Nature Methods（2025）：技术+计算
- Deep-coverage SC metabolomics → Nature Methods（2025，两篇同期）
- scSpaMet → Nature Communications（2023）：计算分析框架

NC 在这个领域**欢迎高质量论文**，但趋势是：技术突破 > 计算方法。纯计算 imputation 方法在 NC 上的评审会非常严格，尤其是：
- 与现有方法的差异要足够显著
- 必须有真实 SC 代谢组数据的严格验证
- imputation 是否真的改善了下游分析（不仅仅是填补了值）

### 4.2 Imputation 方法的 incremental 风险

scRNA-seq 领域的教训：
- 2016-2020 年 imputation 论文爆发（MAGIC、SAVER、scImpute 等）
- Andrews & Hemberg (F1000Research 2019) 明确指出：imputation 引入假信号，多数情况下不应该 impute
- Genome Biology (2020) 系统评估：多数 imputation 方法在下游分析（clustering、trajectory）中并不优于不 impute
- 2021 年"zero-inflation controversy"（Genome Biology）：大量 scRNA zeros 是真实的，不是 technical dropout
- 代谢组领域 2025 年出现了"To Impute or Not To Impute"（JASMS 2025）的讨论，类似 scRNA 领域 2019-2021 年的转折

**本方向恰好进入了一个审查越来越严格的方向，而不是越来越宽松。**

### 4.3 "代谢网络约束"的 novelty 评估

- 蛋白质组：PEPerMINT（GNN + 蛋白质-肽段网络，Bioinformatics 2024）已做
- 转录组：scFEA（GNN + 代谢网络，Genome Research 2021）已做，MGFEA（VGAE + GSMM，bioRxiv 2024）已做
- 代谢组（非 SC）：MINMA（SVR + 代谢网络，Bioinformatics 2018）已做
- **代谢网络约束 imputation 在 SC 代谢组直接测量值上的应用**：这是唯一剩余的空白，但这个空白的价值受到上述技术障碍的严重限制

---

## 5. 致命风险识别

### 风险 1：Reviewer 直接指出 MGFEA 覆盖了核心 idea
- **概率**：80%
- **原因**：MGFEA 使用 VGAE + GSMM 做 SC 级别代谢物推断，与本方向方法论高度重叠；任何熟悉这个领域的 Reviewer 都会引用它
- **后果**：需要明确区分"基于代谢物测量做 imputation"与"基于转录组推断代谢物"的差异，但这个区分只是输入数据类型不同，不是方法论创新

### 风险 2：Ground truth 缺失导致评估不可信
- **概率**：70%
- **原因**：没有已知浓度的 SC 代谢组 ground truth，所有评估只能做 in silico 模拟（人为制造 missing 然后恢复）。Reviewer 会质疑：你的评估不代表真实 SC missing 的情况
- **后果**：论文的可信度严重下降，可能被要求提供湿实验验证，而这在当前技术条件下极难实现

### 风险 3：代谢组 missing 是 MNAR，imputation 反而引入偏差
- **概率**：60%
- **原因**：MALDI-MSI 的检测下限效应使大量 missing 是 MNAR。对 MNAR 数据进行 imputation 的效果通常劣于直接分析观测值（有大量 bulk 代谢组文献支持）
- **后果**：方法本身的应用场景合理性受到根本质疑

### 风险 4：网络约束在 2-8% 覆盖率下失效
- **概率**：65%
- **原因**：每细胞仅检测 50-200 个代谢物，而 KEGG 网络约 2500 个节点，大量邻居节点 missing 使 message passing 退化
- **后果**：消融实验会显示"有没有网络约束结果差不多"，方法的核心卖点无法体现

### 风险 5：被定性为 incremental（GNN imputation = PEPerMINT 的代谢组版本）
- **概率**：55%
- **原因**：PEPerMINT（GNN for proteomics imputation）已发表于 Bioinformatics 2024；Reviewer 会问"这不就是把 PEPerMINT 用在代谢组上吗"
- **后果**：需要证明代谢组场景有根本性的新挑战，而不仅仅是换一个数据类型

---

## 6. 总结评估

### 评分汇总

| 维度 | 得分 | 关键问题 |
|------|------|---------|
| 竞争者密度 | 3/10 | MGFEA (2024) 高度重叠，MINMA/PEPerMINT 占据相关空间 |
| 数据可行性 | 4/10 | 数据存在但无 ground truth，训练目标不可验证 |
| 技术可行性 | 3/10 | 网络约束在 2-8% 覆盖率下退化，MNAR 问题根本性 |
| NC 级别 | 3/10 | Incremental 风险高，imputation 方向审查趋严 |
| **综合得分** | **3/10** | **低于 7 分门槛，不推荐进入执行** |

### 推荐结论：**不推荐进入执行阶段**

核心原因有三条，按严重程度排列：

1. **Ground truth 缺失是根本性障碍**：SC 代谢组 imputation 的质量无法用现有数据验证。这不是可以通过改进方法解决的工程问题，而是领域的固有限制。任何声称"imputation 效果好"的结论都是循环论证（用假设来验证假设）。

2. **MGFEA 已占据方法论高地**：2024 年 bioRxiv 上 MGFEA 使用 VGAE + GSMM 做 SC 代谢物推断，与本方向的技术路线高度重叠。区分点（"输入是代谢物测量值而非转录组"）虽然存在，但不足以支撑 NC 级别的创新性声明。

3. **Imputation 的领域态度正在反转**：从 scRNA-seq 的教训（Andrews & Hemberg 2019，zero-inflation controversy 2022）到代谢组的"To Impute or Not To Impute"（2025），都指向同一个方向：reviewer 对 imputation 工作越来越怀疑，要求越来越高的验证标准。

---

## 7. Pivot 方向建议

如果要在 SC 代谢组计算方向保留投入，以下方向具有更高的成功概率：

### Pivot A：SC 代谢组与转录组的整合分析框架（评分潜力：6-7/10）
- 核心价值：HT SpaceM / MetCell 产生大量数据，但分析框架（joint embedding of metabolomics + transcriptomics）尚不成熟
- 已有工具（scSpaMet）局限于特定实验平台，泛用分析框架存在空白
- 竞争者少，下游验证可通过"代谢-转录相关性"来衡量，不依赖 ground truth
- 风险：scSpaMet 已经做了一部分

### Pivot B：SC 代谢组数据的质量控制与特征选择（评分潜力：5-6/10）
- 核心价值：HT SpaceM 论文本身指出 dataset-wide dropout 问题，但 QC 方法论不成熟
- 这是技术性强、有实际需求的方向
- 发表前景：Nature Methods 类，技术方法文章
- 风险：可能太窄，影响力有限

### Pivot C：基于代谢网络的 SC 代谢通量推断（不做 imputation，而是做通量估算）（评分潜力：7/10）
- 核心价值：COMPASS/scFEA 需要 scRNA 输入，HT SpaceM 提供的是直接代谢物测量——将两者结合（用代谢物测量值约束通量模型）是真正新颖的方向
- 技术基础：Flux Balance Analysis + SC 代谢物测量作为约束，这是与 MGFEA 完全不同的问题定义（通量 vs imputation）
- 竞争者：目前没有找到直接做这件事的工作
- 验证：通量预测可以通过 13C 标记同位素实验（如 isotope tracing NC 2025 那篇）部分验证

---

## 参考文献

- [MGFEA: Inferring metabolite states from spatial transcriptomes using multiple GNN (bioRxiv 2024)](https://www.biorxiv.org/content/10.1101/2024.06.12.598759v3.full)
- [HT SpaceM: High-throughput SC metabolomics (Cell 2025)](https://www.cell.com/cell/fulltext/S0092-8674(25)00929-8)
- [PEPerMINT: GNN for proteomics imputation (Bioinformatics 2024)](https://academic.oup.com/bioinformatics/article/40/Supplement_2/ii70/7749076)
- [Cross-platform metabolomics imputation via IWAE (npj Syst Biol Appl 2025/2026)](https://www.nature.com/articles/s41540-025-00644-5)
- [MINMA: Metabolic network constrained imputation for LC-MS (Bioinformatics 2018)](https://academic.oup.com/bioinformatics/article/34/9/1555/4764003)
- [scSpaMet: SC spatial metabolomics (Nature Communications 2023)](https://www.nature.com/articles/s41467-023-43917-5)
- [False signals induced by single-cell imputation (F1000Research 2019)](https://pmc.ncbi.nlm.nih.gov/articles/PMC6415334/)
- [To Impute or Not To Impute in Untargeted Metabolomics (JASMS 2025)](https://pubs.acs.org/doi/10.1021/jasms.4c00434)
- [scFEA: GNN for SC flux estimation (Genome Research 2021)](https://pmc.ncbi.nlm.nih.gov/articles/PMC8494226/)
- [Deep-coverage SC metabolomics via ion mobility MS (Nature Methods 2025)](https://www.nature.com/articles/s41592-025-02970-2)
