# AC级压力测试：跨引擎Benchmark / GC-MS预训练 / 多引擎共识

**生成时间**: 2026-03-16  
**调研范围**: 2023-2026  
**覆盖引擎**: MassCube(NC 2025)、SpecTUS(arXiv 2025-02)、DreaMS(Nature Biotechnology 2025)、XCMS、MZmine、MS-DIAL、asari

---

## 方向1：跨引擎系统性基准测试

**当前评分**: NC 7.0（↓1.0 压力修正后）

---

### 1. 竞争者清单

#### 直接竞争（已发表benchmark）

| 竞争者 | 时间 | 期刊 | benchmark规模 | 性质 |
|--------|------|------|--------------|------|
| MassCube | 2025-07 | Nature Communications | 4引擎（MassCube/MS-DIAL/MZmine3/XCMS），8个LC-MS文件，7种基质 | 自我推销式benchmark，作者=工具开发者 |
| Modular comparison (Analytical Chemistry) | 2024 | Analytical Chemistry | 4引擎（XCMS/Compound Discoverer/MS-DIAL/MZmine），牛唾液，离子交换色谱 | 第三方，但单数据类型 |
| 2025 Cancer Urine Study (JPR) | 2025 | J Proteome Research | 5引擎（MZmine/XCMS/MS-DIAL/iMet-Q/Peakonly），尿液临床样本 | 第三方，但聚焦单类应用 |
| 2022 Mechanistic Analysis (Anal Chem) | 2022 | Analytical Chemistry | 5算法机理分析 | 机理研究，非全流程benchmark |
| XCMS 2025 更新 (Anal Chem) | 2025 | Analytical Chemistry | XCMS生态系统更新，含部分比较 | 工具更新性论文 |

#### 间接威胁

- **asari (NC 2023)**：已经有自己的NC发表，且已被MetaboAnalyst 6.0集成
- **MetaboAnalystR 4.0 (NC 2024)**：整合了asari，形成了事实上的标杆工作流
- **UmetaFlow (J Cheminformatics 2023)**：用MTBLS ground-truth数据验证，检出率>90%

---

### 2. MassCube Benchmark深度解剖

**MassCube benchmark的具体设计**：
- 数据集：220,000条合成峰（110K单峰 + 110K双峰，参数：SNR、强度比、峰分辨率）+ 8个实验LC-MS文件（Orbitrap QExactive + Bruker QTOF Impact2）
- 基质：NIST SRM1950血浆、小鼠血浆、NIST RGTM10162粪便、人血清、鼠粪便、果蝇全身、人尿液
- 评价指标：单峰/双峰检测准确率（TP rate）、峰不对称因子、高斯相似度、处理速度、内存占用
- 对比引擎：仅4个（MassCube/MS-DIAL 4.90/MZmine3 3.90/XCMS 4.0.0）
- **明显缺失**：asari未纳入（论文提到asari优于XCMS但未直接比较）；无全流程统计分析比较；无注释层比较；无归一化层比较；无不同色谱方法（仅RP/HILIC）比较

**关键结论**：MassCube的benchmark存在明显局限——
1. 自家人裁判，非独立第三方
2. 评价维度停留在峰检测准确率，不覆盖对齐→归一化→统计→注释全流程
3. 作者自己承认："external validated datasets for rigorous benchmarking are still missing"
4. 未纳入asari（最重要的竞争对手之一）
5. 无GC-MS、DI-MS、IMS数据

---

### 3. 威胁与解决方案

#### 威胁1：MassCube已经做了benchmark，领地被占

**解决方案**：三层差异化，每层都比MassCube更进一步：

**第一层——引擎覆盖更全**：MassCube比了4个引擎，我们比6-7个：XCMS + MZmine3 + MS-DIAL + asari + MassCube + OpenMS + （可选）El-MAVEN。特别是必须包含asari（NC 2023，MassCube故意回避了）。

**第二层——全流程评价**：MassCube只评了峰检测准确率，我们覆盖完整流程：
- 峰检测（TP rate, false positive rate）
- 特征对齐（alignment accuracy on ground-truth spike-in）
- 归一化效果（CV降低率、QC样本稳定性）
- 统计检验下游影响（不同引擎→不同biomarker list的重叠率）
- 注释一致性（相同特征在不同引擎输出的注释一致性）

**第三层——多维数据类型**：MassCube只做LC-MS（RP+HILIC），我们加入：
- 不同仪器厂商（Thermo、Waters、Bruker、Agilent）
- 不同数据采集模式（DDA、DIA、全扫描）
- 不同生物基质（血浆、尿液、CSF、组织、细胞）
- 不同研究场景（临床biomarker、环境暴露组、食品）

#### 威胁2：已经有多篇第三方benchmark论文（Anal Chem 2024、JPR 2025）

**解决方案**：这些论文的共同缺陷是"碎片化"——每篇只比2-4个引擎、1种数据类型、1个评价维度。没有一篇做过系统性全覆盖。明确在论文中引用这些研究并指出空白：

> "现有比较研究的局限是碎片化——每项研究只覆盖特定数据类型或评价维度（ref）。本研究首次对全流程、多引擎、多数据类型进行系统性比较，并建立可复现的benchmark框架。"

#### 威胁3：这类"工具比较"论文的新颖性不足，期刊可能认为"不够有趣"

**解决方案**：引入 **Multiverse分析框架** 作为独特卖点——

传统benchmark问"哪个引擎最好"，Multiverse benchmark问"参数选择和引擎选择对最终结论有多大影响"。具体：
- 固定同一数据集，对每个引擎各设置3-5种参数组合（例如XCMS的centWave参数、peakwidth等）
- 运行所有组合，生成"分析宇宙"（analysis multiverse）
- 量化：结论稳健性（有多少比例的引擎×参数组合得到相同的top biomarkers？）
- 输出：稳健性评分和不确定性地图（uncertainty map）

这个框架：(a) 在方法论层面有独立新颖性；(b) 直接回答了临床代谢组学的可复现性危机；(c) 与2025年新发表的JPR discrepancy论文形成对话，但提供解决方案而非只描述问题。

#### 威胁4：公开ground-truth数据集不足，benchmark结论可能被质疑

**解决方案**：利用已有公开数据集 + 构造新的spike-in验证集：
- **现有公开数据集**：MTBLS733/MTBLS736（已被UmetaFlow等使用的标杆数据集）；Analytical Chemistry 2024模拟LC-MS数据集（已知peak位置和强度）；MassCube的8个文件（公开在GitHub）
- **spike-in设计**：设计一个3种浓度梯度×5种化合物类别的标准品混合物实验（不需要自己采集——与MetaboLights提交数据的合作者合作，或使用NIST SRM 1950混合物的已有数据）
- **关键**：只要使用了可公开获取的数据集，可重复性就有保障

---

### 4. 数据可得性评估

| 数据源 | 可得性 | ground-truth质量 | 说明 |
|--------|--------|-----------------|------|
| MTBLS733/736 | 公开 | 中等（人工标注） | 最广泛使用的benchmark数据集 |
| MassCube GitHub数据 | 公开 | 合成峰（明确ground truth） | 合成数据，真实性有限 |
| Anal Chem 2024模拟数据集 | 公开 | 高（已知fold change） | 较新，引用量低，可作为新benchmark基础 |
| MetaboLights公开数据 | 公开 | 低（无spike-in） | 可用于多样性，不适合accuracy评估 |
| MassBank/GNPS公开LC-MS文件 | 公开 | 低 | 无标注 |

**结论**：ground-truth数据是该方向最大的工程挑战。建议主要使用合成数据+MTBLS733/736，同时设计一个轻量级spike-in验证实验（20-30个标准化合物，3个浓度）。

---

### 5. 技术可行性评估

- 引擎安装和运行：全部开源，Python/R均可，可行性高
- 参数标准化：各引擎参数空间大，需要明确的参数选择协议（这本身就是论文贡献之一）
- Multiverse计算量：每个引擎×5参数组合×6数据集 = ~150次运行，单次<1小时，总计可控
- 统计分析：下游生物标志物比较需要有生物学意义的数据（需要case/control设计的数据集）
- "活的platform"（leaderboard）：技术上可行（GitHub + 静态网页），但维护成本高，论文审稿人对此要求不明确，可作为"future work"而非核心主张

---

### 6. 解决方案实施后的潜在论文档次提升

**核心重构策略**：不定位为"工具比较"，而定位为"代谢组学可复现性危机的量化分析与解决框架"

- 核心叙事：同一数据集、不同引擎→最终biomarker list重叠率低于X%（这是现象）；Multiverse分析量化了不确定性来源（这是分析）；基于共识的稳健推荐协议是解决方案（这是贡献）
- 对标引用：与可重复性危机（Nature 2016 Begley et al.）、基因组学multiverse分析（Nature Human Behaviour 2020 Botvinik-Nezer et al.）对齐，跨领域引用潜力大
- 如果执行充分（6+引擎、全流程、Multiverse框架、spike-in验证），可以支撑NC正刊或Nature Methods短文

---

### 7. 调整后评分

**调整后：NC 7.5 / 10**（从7.0提升0.5）

**理由**：
- MassCube的benchmark存在明显空白（缺asari、缺全流程、缺Multiverse、只比4引擎），可以超越
- Multiverse框架将工具比较论文升格为方法论贡献，差异化清晰
- ground-truth数据问题有解决路径（公开数据集+轻量spike-in）
- 主要风险：执行复杂度高，参数标准化本身有争议性；审稿人可能仍认为"工具比较不够原创"
- 如果"活的platform"可以实现，可进一步升至8.0

---

## 方向2：GC-MS专属自监督谱图预训练

**当前评分**: AC 7.0

---

### 1. 竞争者清单

#### 直接竞争（EI谱图深度学习）

| 竞争者 | 时间 | 机构/期刊 | 核心任务 | 与目标方向的重叠 |
|--------|------|---------|---------|----------------|
| **SpecTUS** | 2025-02 (arXiv) | Czech 研究组 | 从EI谱图de novo生成分子SMILES，354M参数BART变换器，在17M合成谱图（NEIMS+RASSP生成）上预训练后在NIST20 232K实验谱上微调 | **高度直接竞争**：已经做了EI谱图预训练，且在de novo结构注释上超越NIST library search |
| **NEIMS** (2019, ACS Central Sci) | 2019 | Google | MLP预测EI谱图，从结构→谱图方向 | 基础工作，已过时 |
| **RASSP** (GNN) | 2022+ | - | GNN预测EI谱图，优于NEIMS | 已有人在用来生成训练数据（SpecTUS用了它） |
| **MoMS-Net** (Sci Reports 2024) | 2024 | - | GNN+结构motif预测质谱 | 与EI领域部分重叠 |
| **Hybrid DL EI-MS** (IJMS 2025) | 2025-01 | - | GNN编码器+ResNet解码器+cross-attention预测EI谱，Recall@10≈80.8% | 谱图预测方向，非自监督表示学习 |
| **DreaMS** (Nat Biotechnology 2025) | 2025-05 | MIT/Pluskal Lab | LC-MS/MS自监督预训练，700M谱图，masked peak prediction + 保留时间序排对比 | 定义了LC-MS领域的标杆 |
| **NIST 2023 AI-RI** | 2023 | NIST | 为所有EI数据加入AI预测保留指数 | 官方工具增强，非开放模型 |

#### 关键发现：SpecTUS是已存在的直接竞争者

SpecTUS（2025-02，arXiv，尚未正式发表在高分期刊）做的是：
1. 用NEIMS/RASSP生成17.2M合成EI谱图作为预训练数据
2. 在NIST20 232K实验谱上微调
3. 输入EI谱→输出SMILES，de novo注释
4. 在28K测试谱上，单条建议的精确重构率43%，优于NIST library hybrid search的76%

**这直接占领了"EI谱图预训练→结构注释"这个坑位**。

---

### 2. 每个威胁的解决方案

#### 威胁1：SpecTUS已经做了EI谱图预训练+de novo注释

**分析**：SpecTUS的具体局限性——
1. 使用合成谱图（NEIMS/RASSP生成）而非真实EI谱图预训练，存在domain gap（合成谱≠实验谱）
2. 任务聚焦在单一下游任务（de novo结构生成），不是通用representation
3. 预训练任务设计是监督式（合成谱→SMILES配对），不是真正的自监督（无需标签）
4. 不支持GC-MS工作流中的其他任务：保留指数预测、同系物分类、化合物类别预测
5. 没有解决GC-MS数据处理流程中的上游问题（峰提取、解卷积）

**解决方案**：四个可能的差异化角度：

**角度A——真正的自监督（无需合成数据）**：
DreaMS的精华是用真实谱图做自监督，SpecTUS用的是合成数据配对监督。真正的GC-MS自监督任务可以设计为：
- 保留时间对比学习（同RT区间的谱→相似分子）
- Masked peak prediction（遮蔽30%的m/z bin→预测）
- 多采集条件一致性（同化合物不同仪器/温度→相似表示）

这需要大规模GC-MS实验数据集，而非合成谱（关键见数据可得性）。

**角度B——通用representation而非单一任务**：
定位为GC-MS的DreaMS——预训练一个通用编码器，然后在5-6个下游任务上评估：
保留指数预测、化合物类别预测、环境样品未知物分类、毒理学相关性预测、同系物识别
这与SpecTUS只做de novo注释形成互补而非竞争。

**角度C——专注未知化合物（dark metabolome GC-MS侧）**：
NIST匹配率在已知化合物上>90%，但对未知化合物（NIST库外）完全失效。预训练模型的价值在于用学到的representation对未知化合物做类别预测、毒性预测、来源推断。

**角度D——GC×GC-MS（二维气相）专属模型**：
GC×GC-MS是GC-MS的高分辨率版本，数据量大（2D色谱图），几乎没有深度学习工作。但这是更小的细分市场。

#### 威胁2：GC-MS社区规模小于LC-MS，引用潜力不足

**量化分析**：
- NIST23 EI库：347K化合物，394K谱图（训练数据足够，但规模小于GNPS的700M LC-MS/MS谱）
- MassBank GC-MS部分：相对较少，主要是LC-MS
- SpecTUS用了NIST20的232K实验谱，规模可行

**解决方案**：不依赖社区规模，依赖任务普遍性。GC-MS在环境代谢组学、食品安全、法医毒理学领域的应用量大。如果论文的应用案例覆盖：(1) 环境暴露组学未知化合物分类；(2) 食品成分库扩充；(3) 法医毒理学新精神活性物质识别——则跨领域引用潜力很高。

#### 威胁3：EI谱图确定性碎裂→"已经够好了"，预训练增量价值有限

**反驳**：NIST match rate>90%仅对NIST库内化合物成立。环境样品中，库外未知物的比例可达50-80%（Schymanski et al., 2014等文献记载）。预训练模型在库外化合物的类别预测和结构推断上，才是价值所在。

---

### 3. 数据可得性评估

| 数据源 | 谱图数量 | 是否开放 | 质量 |
|--------|---------|---------|------|
| NIST23 EI Library | 394K谱/347K化合物 | **商业授权**（约$3K/套） | 最高 |
| NIST20（SpecTUS用的） | 356K谱 | **商业授权** | 最高 |
| MassBank.EU GC部分 | <5K EI谱 | 开放 | 中等 |
| MoNA GC-MS部分 | ~50K EI谱（含NIST子集） | 部分开放 | 中等 |
| GNPS GC-MS | 数万级 | 开放 | 低（实验质量参差） |
| 合成谱（NEIMS/RASSP） | SpecTUS已生成17M | 开放（Hugging Face） | 低（domain gap） |

**关键瓶颈**：要做"真正的自监督"（无需配对标签），需要大量无标注EI谱，但GC-MS公开实验谱远少于LC-MS/MS（GNPS有700M MS/MS谱，EI公开实验谱只有<100K级别）。

**可行路径**：利用SpecTUS已公开的17M合成谱作为预训练基础，设计自监督任务（不需要SMILES标签），只用谱图本身的结构学习representation——这在数据上是可行的。

---

### 4. 技术可行性评估

- 模型架构：Transformer对离散谱图（m/z bin化）适用，参考DreaMS/SpecTUS已有先例
- 自监督任务设计：Masked peak prediction技术上直接可实现
- 对比学习：需要"正样本对"定义（同化合物不同实验谱），在NIST库中可通过compound ID获取（同一化合物有多条谱）
- 微调和下游评估：需要保留指数数据（NIST23含492K RI）、化合物类别标注（ClassyFire）
- 计算资源：354M参数模型（SpecTUS规模），A100 GPU，预训练需要数天，可行

---

### 5. 解决方案实施后的潜在论文档次提升

**核心差异化重构**：

如果采用"角度B——通用representation"：
- 定位为"GC-MS领域的DreaMS"
- 预训练 + 6个下游任务系统性评估
- 与SpecTUS的区别：我们是真正的无监督representation，它是监督式de novo生成；我们支持多任务，它只做结构注释

**潜在期刊**：DreaMS发在Nature Biotechnology（5/2025），这个档次需要：(a) 足够大的预训练数据集；(b) 多个下游任务超越SOTA；(c) 新发现（类似DreaMS Atlas）。GC-MS版本的数据规模远小于DreaMS的700M谱，期刊档次可能降至Nature Communications或Analytical Chemistry。

**最现实评估**：若执行充分（真正自监督任务+6下游任务+未知化合物应用案例），可达NC级别，但需要明确回应SpecTUS已有工作。

---

### 6. 调整后评分

**调整后：AC 6.5 / 10**（从7.0降低0.5）

**理由**：
- SpecTUS的存在是真实的威胁——虽然在arXiv尚未发表在高分期刊，但它已经占领了"EI谱图预训练"的核心坑位
- 差异化路径存在但需要明确重构（通用representation而非de novo注释）
- 数据瓶颈比LC-MS严重（公开实验EI谱<100K，DreaMS用了700M）
- 如果SpecTUS在审稿期间被Nat Methods/NC接收，直接竞争风险上升
- 优势：真正的自监督（无需配对标签）是清晰的差异化点，目前EI领域尚无
- 最大不确定性：GC-MS社区能否支撑NC级论文的影响力（引用数天花板）

---

## 方向3：多引擎共识特征提取算法

**当前评分**: 5.5（↓1.5 压力修正后）

---

### 1. 竞争者清单

| 竞争者 | 时间 | 核心主张 | 对本方向的威胁 |
|--------|------|---------|--------------|
| **MassCube (NC 2025)** | 2025-07 | 一个足够好的引擎可以替代多引擎拼凑 | 直接叙事竞争 |
| **JPR Discrepancy Study** (2025) | 2025-03 | 描述了XCMS vs MZmine2在癌症细胞/组织/体液中的不一致性 | 证明了多引擎不一致性，但未提解决方案 |
| **MetaboAnalystR 4.0 (NC 2024)** | 2024 | 整合asari为标准工作流 | 事实上的单引擎解决方案 |
| **Anal Chem 2024 Modular Study** | 2024 | 4引擎模块化比较，发现8%特征在所有引擎中共识 | 量化了共识率极低的问题（可作为motivation，也可作为威胁） |
| **QuanFormer (Anal Chem 2025)** | 2025 | 深度学习peak quantification，96.5% AP | AI峰检测路线，可能绕过共识问题 |

---

### 2. "一个好引擎够了"的反驳证据

从已发表文献提取具体证据：

1. **Anal Chem 2024 Modular Study**：4引擎只有约8%的特征被所有引擎共同检出。即使在MassCube"准确率最高"的场景下，单引擎还是会漏掉大量特征。

2. **JPR Discrepancy Study (2025)**：XCMS vs MZmine2在癌症细胞/组织/体液中的biomarker list显著不一致，且"regardless of sample types, solvent gradient phases, RT or m/z tolerances"——说明这不是参数问题，是算法设计根本差异导致的盲区（blind spots）。

3. **MassCube自身数据的漏洞**：MassCube在双峰准确率上（95.2% vs MS-DIAL 94.3%）提升不显著，在单引擎实验谱处理上没有展示"near-zero false negative"。结合JPR 2025的数据，可以论证：即使是"最好的引擎"也有系统性盲点。

4. **色谱条件依赖性**：不同引擎对不同色谱条件（HILIC vs RP，宽峰vs窄峰，低质量谱vs高质量谱）的适应性不同。没有一个引擎在所有条件下都最优。

---

### 3. Consensus vs Ensemble的重定位分析

**Consensus（取交集）**：
- 优点：高可靠性（只保留被多个引擎确认的特征）
- 缺点：Anal Chem 2024数据显示4引擎共识率只有8%→极大丢失信息；审稿人会问"为什么不用一个更好的引擎"

**Ensemble（加权投票/并集过滤）**：
- 优点：保留更多特征，用投票权重过滤噪声；可以用生物学验证（spike-in）证明Recall提升
- 缺点：会引入更多false positives；算法复杂度高；需要严格的FDR控制

**建议的重定位**：不应该是"取交集"的保守共识，而是"加权ensemble"——

设计框架：
1. 用benchmark数据（方向1的结果）量化每个引擎在不同场景下的precision/recall
2. 基于场景（数据类型、色谱条件）动态分配引擎权重
3. 高权重引擎的特有检测也纳入，但标注置信度分级
4. 最终输出：带置信度标注的feature list，而非简单的有/无

这个框架比"共识"更有实用价值，比"选一个引擎"更有科学意义。

---

### 4. 与benchmark的协同可能性

**协同设计**：方向1（benchmark）是方向3（ensemble）的数据基础——

- benchmark论文建立了每个引擎的精确precision/recall矩阵（分场景）
- ensemble论文用这个矩阵设计自适应权重方案
- 两篇论文形成系列：Paper 1 = "Systematic benchmark reveals engine-specific blind spots in metabolomics"；Paper 2 = "Adaptive ensemble feature extraction exploiting engine-specific strengths"

这种系列设计在方法学领域是常见的高影响力策略（类似DESeq2 + edgeR + limma voom三篇的关系）。

---

### 5. 数据可得性评估

方向3依赖方向1的benchmark数据，数据来源相同（见方向1数据可得性）。额外需要：
- spike-in数据（用于验证ensemble的Recall提升）：与方向1共享
- 生物学验证数据（在真实case/control数据上，ensemble biomarker list的生物学意义是否更强）：需要现有公开临床代谢组学数据集

---

### 6. 技术可行性评估

- 算法核心：特征匹配（mz/RT容差内的跨引擎特征配对）是成熟问题，MZmine的ADAP等已有算法
- 权重学习：可以用监督学习（以spike-in ground truth为标签）或无监督（以生物学意义为proxy）
- FDR控制：需要严格的统计框架，否则ensemble会膨胀假阳性
- 计算量：每个样本集需要运行6+引擎，但只需离线一次，不影响用户体验
- 实际可行性：中等偏高，但需要解决特征配对的算法细节

---

### 7. 解决方案实施后的潜在论文档次提升

**重构后叙事**：

从"共识特征提取"（防御性、被动）重构为"多引擎自适应集成（Adaptive Multi-Engine Ensemble for Metabolomics）"：

> "单一引擎存在系统性盲点（evidence from JPR 2025 + benchmark数据），且盲点具有场景依赖性（XCMS在宽峰场景漏检，MZmine在低信噪比漏检）。我们设计了基于场景识别的自适应权重集成框架，在spike-in验证集上将特征Recall从最佳单引擎的X%提升至Y%，同时控制FPR在Z%以内。"

这个叙事：
1. 有具体数据支撑（非猜测）
2. 回应了MassCube的"单引擎够了"（给出了反证）
3. 有实际应用价值（临床代谢组学biomarker稳健性）

**但**：这个方向在独立发表时，如果没有方向1 benchmark数据的支撑，论证会很薄弱。最强的执行路径是"方向1 benchmark + 方向3 ensemble"作为系列。

---

### 8. 调整后评分

**独立发表：4.5 / 10**（从5.5进一步降低1.0）

**与方向1系列发表：6.5 / 10**

**理由（独立发表）**：
- MassCube的叙事威胁比预期更难反驳——即使有JPR 2025的discrepancy数据，审稿人可以说"换个更好的引擎就解决了"
- "取交集"丢失8%以外的特征，这个问题在重构为ensemble后有所缓解，但FDR控制成为新的挑战
- 独立发表时缺乏benchmark数据支撑，自身baseline弱
- 发表档次难超Analytical Chemistry，NC可能性低

**理由（系列发表）**：
- 作为方向1的延伸，有完整的benchmark数据支撑
- 系列论文的第二篇通常比第一篇降一个档次（Anal Chem→JASMS或类似）
- 整体研究规划更完整，更容易获得基金和后续合作

---

## 综合比较与优先级建议

| 方向 | 原评分 | 调整后 | 执行复杂度 | 被竞争者颠覆风险 |
|------|--------|--------|-----------|----------------|
| 方向1：跨引擎Benchmark | NC 7.0 | **NC 7.5** | 高（6引擎×全流程×多数据类型） | 中（MassCube已发，但空白明确） |
| 方向2：GC-MS预训练 | AC 7.0 | **AC 6.5** | 高（NIST数据获取+预训练计算） | 高（SpecTUS已在arXiv） |
| 方向3：多引擎共识 | 5.5 | **4.5（独立）/ 6.5（系列）** | 中（算法设计为主） | 高（MassCube叙事威胁强） |

### 优先级推荐

**最优执行路径**：方向1 + 方向3系列（而非单独执行任意一个）

- 方向1先行，建立benchmark框架和数据资产
- 方向3作为方向1的自然延伸，利用已有数据资产
- 方向2可以并行，但需要解决SpecTUS竞争和数据规模问题

**方向2的条件性推荐**：如果能获得NIST库商业授权 + 设计真正自监督任务（区别于SpecTUS的监督式预训练），则仍值得推进。否则等待SpecTUS发表在高分期刊后再评估是否有足够差异化空间。

---

## 参考资料

- [MassCube: NC 2025](https://www.nature.com/articles/s41467-025-60640-5)
- [MassCube PMC全文](https://pmc.ncbi.nlm.nih.gov/articles/PMC12216001/)
- [DreaMS: Nature Biotechnology 2025](https://www.nature.com/articles/s41587-025-02663-3)
- [SpecTUS: arXiv 2025-02](https://arxiv.org/abs/2502.05114)
- [Modular Comparison Anal Chem 2024](https://www.sciencedirect.com/science/article/pii/S0003267024012923)
- [JPR Discrepancy Study 2025](https://pubs.acs.org/doi/10.1021/acs.jproteome.5c00434)
- [JPR Discrepancy bioRxiv](https://www.biorxiv.org/content/10.1101/2025.03.04.641559v1)
- [QuanFormer Anal Chem 2025](https://pubs.acs.org/doi/10.1021/acs.analchem.4c04531)
- [asari NC 2023](https://www.nature.com/articles/s41467-023-39889-1)
- [Hybrid DL EI-MS IJMS 2025](https://www.mdpi.com/1422-0067/27/3/1588)
- [MetaboAnalystR 4.0 NC 2024](https://www.nature.com/articles/s41467-024-48009-6)
- [XCMS 2025 Anal Chem](https://pubs.acs.org/doi/10.1021/acs.analchem.5c04338)
- [NIST Mass Spectral Library](https://www.nist.gov/programs-projects/electron-ionization-library-component-nistepanih-mass-spectral-library-and-nist-gc)
- [Machine Learning in Small-Molecule MS (Annual Reviews)](https://www.annualreviews.org/content/journals/10.1146/annurev-anchem-071224-082157)
