# Plan 4: ISF系列 — 完整执行方案

> 版本：v1.0 | 创建：2026-03-16
> 覆盖方向：ISF-GNN全流程框架(AC) + B4临床假阳性(NC升级) + B8 ISF-MNAR联合建模 + GC-MS热降解扩展

---

## 第一步：竞争格局现状（2025-2026搜索结果）

**关键发现总结：**

1. **Nature Metabolism 2024 重磅论文**（Giera et al.）：ISF可解释超过70%的LC-MS/MS峰，挑战"暗代谢组"概念——这篇论文是整个ISF方向的导火索。2025年有反驳论文（"Discovery of metabolites prevails amid in-source fragmentation"），称82%的分子仍无法注释，暗代谢组依然存在。这场学术争论本身就证明ISF是当前最热门争议领域。

2. **MS1FA（Bioinformatics 2025年4月）**：整合了MS1+MS2数据的ISF注释工具，是一个Shiny app，采用基于相关性+质量差的规则引擎+特征分组，**不是ML/GNN方案**。

3. **ISFrag（Anal. Chem. 2021）**：R包，规则引擎方案，3级置信度识别，level 1 100%准确率。

4. **MassCube（Nat. Commun. 2025）**：端到端处理框架，用Pearson相关+m/z差+MS/MS相似度识别ISF，**不是独立ISF检测工具**，是集成在处理流程中的一个模块。从mouse数据集检测出2604个ISF。

5. **无GNN方案**：当前没有任何发表的GNN用于ISF检测的工作。这是真实空白。

---

## 1. 战略定位

ISF是代谢组学数据质量的系统性漏洞，而非边缘问题。关键数据点：

- ISF峰在典型LC-MS/MS数据集中占比超过70%（Nature Metabolism 2024）
- 85%的临床假阳性标志物来自ISF及相关伪影（GALE数据库引用研究）
- 244项癌症代谢组学研究中72%的报告代谢物只被一项研究发现，实际假阳性率高达85%（PMC11999569，2025）
- 临床代谢组学再现性危机的核心原因之一正是ISF未被系统处理

当前方案的共同缺陷：都是**事后注释**工具（检测到再处理），没有一个做到**全流程感知**（在峰检测阶段就介入）。MS1FA、ISFrag、MassCube都是在特征表生成后才工作。

**我们的核心差异化定位**：从"ISF检测工具"升级为"ISF感知的代谢组学全流程框架"，并在此基础上量化ISF对临床标志物的系统性污染。

---

## 2. 方向A：ISF-aware全流程框架

### 2.1 科学问题定义

**核心问题**：现有代谢组学流程（XCMS/MZmine/MassCube）在峰检测阶段就把ISF当作真实特征处理，导致下游所有步骤（对齐、注释、统计）都污染ISF误差。当前工具在特征表生成后才做ISF清理——这是亡羊补牢，因为峰检测阶段的特征边界划定、积分、插值都已经用了被污染的数据。

**量化的科学贡献**：
1. 峰检测阶段ISF早期识别能减少多少下游假阳性特征
2. ISF去除后真实代谢物鉴定率（annotation rate）提升幅度
3. Dark Metabolome中有多少比例是ISF vs 真实未知代谢物（直接介入2025年Nature Metabolism争论）

### 2.2 方法设计

#### ISF检测模块：GNN vs 替代方案的论证

**为什么需要GNN（不是规则引擎，不是RF/XGBoost）**：

现有方案（ISFrag、CAMERA、MassCube）使用规则引擎：
- 基于固定m/z差（水损失18Da、氨损失17Da等已知碎裂）
- 基于RT共洗脱（同一母离子的ISF片段RT相同）
- 基于Pearson相关（ISF强度与母离子正相关）

这些规则的根本局限：
- 未知碎裂模式无法覆盖（level 2/3识别率明显下降）
- 不同仪器平台、不同源电压条件下碎裂规律不一样，规则需要重新调参
- 无法捕捉高阶关系：一个母离子产生多个ISF、ISF之间的关系、ISF与同位素/加合物同时存在时的区分

**GNN的核心优势**：
- 将同一扫描窗口内的m/z特征构建为节点图，节点特征包括：m/z、RT、强度轮廓、MS2有无
- 边权重：m/z差（是否对应已知/未知碎裂）、RT差（co-elution得分）、强度相关系数
- GNN在图上做消息传递，学习"母离子-ISF子图"的结构模式
- 关键：**GNN能学到RF/XGBoost学不到的结构性关系**——ISF网络是图结构问题，不是独立样本分类问题

**和RF/XGBoost的本质区别**：
- RF/XGBoost：对每个特征对独立分类（是否ISF关系）
- GNN：对整个特征图做推断，一次预测整个ISF子图结构，能利用"如果A是B的ISF，C也共洗脱且有质量差，则C很可能也是B的ISF"这类传播关系

**但需要诚实承认**：GNN的优势在标准样本（已知碎裂规律丰富）上可能不显著，主要优势在复杂未知碎裂场景。Phase 1需要做消融实验来证明GNN vs RF的必要性，否则审稿人会质疑。

**推荐架构**：
- 节点嵌入：m/z残差（与已知碎裂差的偏差）+ RT标准化值 + 强度比 + MS2点积相似度（有MS2时）
- 图构建：sliding RT窗口（±0.05 min）内所有特征对构建全连接图，边权重由m/z差和相关系数决定
- 模型：GAT（Graph Attention Network）+ 二分类头（ISF/非ISF）
- 对比基线：ISFrag规则引擎 + RF/XGBoost + MassCube内置方案

#### 全流程整合架构

**关键接口设计**（这是技术挑战最大的部分）：

```
原始RAW文件
    ↓
[峰检测：XCMS/MZmine]
    ↓
[ISF Early Flagging Module]  ← 新增：在特征表生成后、特征过滤前介入
    - 输入：ms1_features.csv + ms2_spectra.mgf（如有）
    - 输出：features_with_ISF_label.csv（每个特征标注ISF置信度分）
    ↓
[ISF-aware特征过滤]
    - 策略A（保守）：ISF高置信度特征降权，不删除
    - 策略B（激进）：ISF特征合并到母离子，保留母离子强度
    ↓
[特征对齐：跨样本]  ← 此步骤需ISF感知：ISF特征的对齐策略与真实特征不同
    - ISF特征对齐以母离子为锚点
    ↓
[注释：SIRIUS/CSI:FingerID]
    - ISF特征直接路由到母离子注释，不独立注释
    ↓
[统计分析]
    - ISF标记特征在差异分析中被排除或单独报告
```

**技术挑战诚实评估**：
- MS1FA/ISFrag都是独立运行，与XCMS的接口不统一，需要开发标准化输入输出格式
- 峰检测本身（ROI提取）不感知ISF，想要在峰检测阶段更早介入需要修改XCMS底层，难度高，Phase 1建议在特征表层面接入
- 特征对齐步骤的ISF感知是难点：ISF在不同样本间的存在是随机性的（取决于源电压稳定性），这会给对齐算法带来额外的RT差异误差

#### Dark Metabolome影响量化方法

1. 用NIST/HMDB标准品混合物（已知组成）在不同源电压条件下采集数据
2. GNN检测ISF → 统计ISF特征占总特征比例（按电压梯度）
3. 去除ISF后剩余未注释特征数量 → 量化"真实暗代谢组"比例
4. 对比Giera et al. 70%估计 vs 我们基于GNN的精确估计
5. 直接介入Nature Metabolism的争论，给出更严格的方法论答案

### 2.3 数据需求与来源

**ISF Ground Truth数据集**（可获得性高）：
- METLIN数据库：931,000个分子标准品，0eV vs 各碰撞能量对比，公开可用（metlin.scripps.edu）
- MassBank.eu：高质量参考谱库，含ISF相关谱
- GNPS公共数据集：多个公开LC-MS数据集，部分有ISF注释
- MassCube论文附带的mouse数据集（Nat. Commun. 2025，已有ISF标注2604个）

**不同源电压条件数据**：
- 自采：用标准品混合物，在3-5个源电压梯度（正常/高电压）下采集
- 成本低：只需要标准品+仪器时间，约2-3周实验

**临床数据集（Phase 2 B4用）**：
- MetaboLights：大量公开临床代谢组学数据
- Metabolomics Workbench（NIH）：有多个癌症/疾病相关数据集
- MTBLS733（Comprehensive evaluation数据集）：已有多工具对比处理结果
- **重要限制**：没有公开数据集有"ISF假阳性标志物"的ground truth标签，需要设计对照实验

### 2.4 预期贡献

1. 首个基于GNN的ISF检测方法，超越现有规则引擎（level 2/3 ISF识别率提升目标：20%+）
2. 首个量化"ISF在Dark Metabolome中的精确比例"的严格方法学研究
3. 开源框架：ISF-aware全流程处理pipeline，可直接嵌入XCMS/MZmine工作流
4. Phase 2：首个量化"ISF导致的临床标志物假阳性率"的系统性研究

### 2.5 论文结构大纲

**Phase 1：Analytical Chemistry / Bioinformatics（AC）**

```
Title: ISF-GNN: A Graph Neural Network Framework for In-Source Fragmentation
       Detection and Its Impact on the Dark Metabolome

1. Introduction
   - ISF问题的严重性（70%峰，引用Nature Metabolism 2024争论）
   - 现有工具的局限（规则引擎、事后处理）
   - 本文贡献：GNN检测 + 全流程整合 + Dark Metabolome量化

2. Methods
   2.1 图构建：特征图的节点/边定义
   2.2 GAT模型架构
   2.3 训练数据：METLIN + 自采标准品数据
   2.4 全流程整合pipeline
   2.5 Dark Metabolome量化实验设计

3. Results
   3.1 标准品数据集benchmark（vs ISFrag/MS1FA/MassCube）
   3.2 不同源电压条件下的ISF比例估计
   3.3 全流程整合对特征数量和注释率的影响
   3.4 Dark Metabolome精确量化

4. Discussion
   4.1 介入Giera vs 反驳方的争论，给出数据
   4.2 GNN vs 规则引擎的必要性（消融实验支撑）
   4.3 局限性

5. Conclusion
```

**Phase 2：Nature Communications / Nature Methods（NC升级版，B4）**

```
新增第5章：临床假阳性量化
5.1 实验设计：对照实验（有/无ISF过滤的临床标志物发现流程对比）
5.2 在N个公开临床数据集上应用ISF-GNN
5.3 ISF导致的假阳性标志物比例量化
5.4 已发表临床代谢组学研究的回顾性分析

核心结论目标：
"In N公开临床代谢组学数据集中，ISF贡献了X%的差异特征，
其中Y%的特征可能被错误报告为疾病生物标志物"
```

### 2.6 执行时间线

**Phase 1（M1-M12，AC版）**

| 月份 | 任务 |
|------|------|
| M1-M2 | 数据准备：METLIN公开数据下载 + 标准品混合物采集（2个源电压条件） |
| M2-M4 | 图构建模块开发 + GAT模型训练（用METLIN做预训练） |
| M4-M6 | 全流程pipeline开发（ISF检测→特征过滤→输出标准化接口） |
| M6-M8 | Benchmark实验：vs ISFrag/MS1FA/MassCube，3个公开数据集 |
| M8-M10 | Dark Metabolome量化实验（3-5个源电压梯度，NIST参考标准） |
| M10-M12 | 论文撰写 + 投稿（目标：Analytical Chemistry或Bioinformatics） |

**Phase 2（M12-M18，NC升级，B4临床假阳性）**

| 月份 | 任务 |
|------|------|
| M12-M13 | 临床数据集收集（MetaboLights + Metabolomics Workbench，5-10个数据集） |
| M13-M15 | 对照实验：有/无ISF过滤的标志物发现流程对比 |
| M15-M17 | 回顾性分析：重新处理已发表研究的原始数据 |
| M17-M18 | 升级论文 + 投稿（目标：Nature Communications / Nature Methods） |

### 2.7 风险矩阵

| 风险 | 概率 | 影响 | 缓解方案 |
|------|------|------|----------|
| GNN vs RF无明显优势（消融实验失败） | 中（40%） | 高 | Phase 1提前做消融实验；若无优势则改用RF+图特征，仍保留图结构优势叙述 |
| MS1FA/MassCube快速迭代，抢占全流程整合 | 中（35%） | 中 | 差异化强调GNN泛化性（跨平台，未知碎裂）和临床假阳性量化（他们没做） |
| 临床数据集无法量化ISF假阳性（缺ground truth） | 高（60%） | 高 | 设计对照实验：人工添加ISF干扰→验证流程可检出；Phase 2数据需求明确标注此风险 |
| 自采数据实验周期过长 | 低（20%） | 中 | 先用METLIN/MassCube公开数据做Phase 1，降低对自采数据的依赖 |
| Nature Metabolism争论过度消耗注意力 | 低（15%） | 低 | 论文清晰定位为"方法学贡献"，不过度押注争论结果 |

---

## 3. 方向B：ISF-MNAR联合建模 B8

### 3.1 科学问题定义：为什么这是一个真问题

**背景**：MNAR（Missing Not At Random）在代谢组学中通常被定义为"低于检测限导致的缺失"，其特征是：高缺失比例的特征往往是低浓度代谢物，缺失本身携带浓度信息。现有MNAR填补方法（QRILC、left-censored VAE）都基于这个假设。

**ISF-MNAR污染的核心逻辑**：

ISF特征的缺失模式完全不同于真实MNAR：
- ISF特征是否出现，取决于仪器**源电压稳定性**和**母离子当次注射的浓度/离子化效率**
- 在不同批次、不同仪器状态下，同一ISF特征可能出现或不出现——**这是近似MAR/MCAR，不是MNAR**
- 但当这些ISF特征被当作真实代谢物处理时，它们的缺失被误判为MNAR（"这个代谢物在某些样本中浓度太低，低于检测限"）

**实证支持（间接）**：
- MassCube论文（2025）显示ISF特征在样本间的强度高度依赖母离子强度，而母离子强度在样本间变化会放大ISF的随机性
- "mechanism-aware imputation"论文（BMC Bioinformatics 2022）已经证明错误判断缺失机制（MNAR vs MAR）会显著损害填补质量
- 但目前**没有任何论文明确研究ISF假阳性特征污染MNAR填补**这一特定问题

**理论论证链**：
1. ISF特征占总特征比例：10-70%（保守估计20-30%，依仪器条件）
2. ISF特征的缺失模式：MAR/MCAR（因为源电压波动是随机的）
3. 被误判为MNAR处理后的系统性偏差：QRILC会把MAR缺失的ISF特征填补为极低值，引入虚假的"低浓度代谢物"信号
4. 这个偏差会传递到下游差异分析，进一步放大假阳性

### 3.2 方法设计

**联合建模框架**：

```
步骤1：ISF检测（依赖方向A的GNN模块）
    → 输出：每个特征的ISF置信度分 p_ISF

步骤2：条件缺失机制分类
    → 对高置信度ISF特征（p_ISF > threshold）：
        强制重分类为MAR/MCAR，不按MNAR处理
    → 对低ISF置信度特征：
        保留原有mechanism-aware分类

步骤3：ISF-aware填补
    策略A：排除ISF特征，只对真实特征做填补
    策略B：ISF特征用MAR填补方法（kNN/RF），非ISF特征用MNAR填补方法（QRILC）
    策略C：用ISF置信度分做软加权混合填补

步骤4：影响量评估
    → 对比"是否排除ISF特征"的填补质量（用标准品数据集ground truth验证）
    → 量化下游差异分析的假阳性率变化
```

**模型选择**：方向A的GNN直接复用，B8是downstream应用，不需要重新建模。

### 3.3 前置依赖与启动条件

**硬依赖**：
- 方向A GNN模型完成并验证（M6+ 才能启动B8）
- MNAR-VAE填补框架（如已开发）或使用现有工具（mechanism-aware imputation）

**启动门控**：
- 方向A Phase 1论文投稿后（M12）启动B8正式开发
- 在M6-M8期间可做概念验证（proof-of-concept）：用MassCube ISF标注数据验证ISF特征缺失模式是否确为MAR/MCAR

### 3.4 影响量预估

**乐观场景**（ISF占比高，缺失率高）：
- 如果ISF特征占总特征20-30%，且平均缺失率40%
- 约8-12%的总缺失值被错误机制处理
- 对差异分析影响：可能放大10-20%的假阳性特征

**保守场景**：
- 如果ISF占比10%，缺失率20%
- 约2%总缺失值受影响
- 影响量较小，论文价值下降

**这是B8的核心不确定性**：影响量能否支撑一篇独立论文，需要M6-M8的概念验证来判断。

### 3.5 Go/No-Go门控

| 门控条件 | 通过标准 | 判断时间 |
|----------|----------|----------|
| ISF特征缺失模式验证 | ISF特征的缺失rate与MNAR指标（低值-高缺失相关）显著低于真实特征（p<0.05） | M8 |
| 影响量验证 | ISF-aware填补 vs 传统填补的假阳性率差异 > 10%（绝对值） | M10 |
| 文献空白确认 | 搜索确认无已发表的ISF+MNAR联合建模工作 | M1（已部分确认，当前无相关论文） |

**当前评估**：文献空白已确认（搜索无结果），理论基础成立，但影响量不确定性高。建议作为方向A的延伸应用，而非独立优先方向。目标期刊：Bioinformatics / Analytical Chemistry（与方向A系列论文策略吻合）。

---

## 4. GC-MS热降解扩展

### 4.1 与LC-MS ISF的方法论差异

| 维度 | LC-MS ISF | GC-MS热降解 |
|------|----------|------------|
| 发生阶段 | 离子源（ESI电喷射电离时） | 进样口（高温裂解，250-350°C） |
| 驱动因素 | 电场强度/源电压 | 温度/分析物热稳定性 |
| 可控性 | 可通过降低源电压减少 | 可通过低温进样减少，但会损失挥发性 |
| 产物规律 | 已知碎裂规律（水损失、氨损失等） | 热裂解规律（脱水、酯化、环化产物） |
| 检测难度 | RT完全相同（共洗脱） | RT不同（热裂解产物有自己的色谱行为） |
| 数据库支持 | METLIN有ISF谱 | 热裂解产物谱库极度匮乏 |
| 现有工具 | ISFrag/CAMERA/MassCube | 几乎没有专用工具 |

**方法论上的本质差异**：
- LC-MS ISF的GNN方法不能直接迁移到GC-MS热降解，因为GC-MS热裂解产物有独立的RT，不共洗脱，图结构不同
- GC-MS热降解检测更依赖**热裂解化学知识库**（类似SIRIUS的碎裂树），而非共洗脱相关性
- 需要重新设计图结构：可能是基于化学相似性（母体vs裂解产物的结构差异）而非RT共洗脱

### 4.2 独立价值评估

**支持独立价值的论据**：
- GC-MS仍是代谢组学主要平台之一，尤其是挥发性代谢物、脂肪酸分析
- 热裂解产物问题被广泛认知（"small molecules can't take the GC-MS heat" — Gen. Eng. News 2024）
- 没有任何ML/DL方法专门针对GC-MS热降解检测
- 与LC-MS ISF系列能形成"质谱数据质量"主题系列

**反对独立优先发展的论据**：
- 方法论需要重新设计，不是简单迁移
- GC-MS市场份额持续缩小（LC-MS占主导）
- 热裂解产物的ground truth数据更难获取（需要纯标准品+多温度梯度实验）
- 审稿人会要求比较：为什么不用已知的化学知识库方法？

### 4.3 系列论文规划

**建议策略**：作为方向A的扩展讨论，不独立优先。

- 在方向A论文的Discussion中提及GC-MS类比，增加影响力
- 如果方向A论文发表后有良好反响，可作为独立follow-up（论文3或4）
- 核心卖点：完整的"质谱数据质量"系列，覆盖LC-MS和GC-MS两大平台

**如果独立开发**，优先数据：
- NIST GC-MS谱库（覆盖部分热裂解产物）
- 公开GC-MS代谢组学数据集（如MetaboLights中的尿液/植物数据集）
- 关键化学参考：已知热不稳定代谢物（核苷酸、糖磷酸酯、辅酶A酯类）

---

## 5. 竞争格局总结

### 5.1 MS1FA详细对比

| 维度 | MS1FA（Bioinformatics 2025） | 我们的ISF-GNN框架 |
|------|---------------------------|-----------------|
| 发表状态 | 已发表（2025年4月） | 待开发 |
| 核心方法 | 规则引擎 + 特征分组（MS1 m/z差 + 相关性） | GNN（图结构学习，跨特征关系） |
| 数据要求 | MS1（最低要求）或 MS1+MS2 | MS1（必须）+ MS2（增强） |
| 工具形式 | Shiny App（交互式，非pipeline） | Python库（可编程接入XCMS/MZmine） |
| 流程整合 | 独立运行，事后处理 | 全流程感知，峰过滤阶段介入 |
| 未知碎裂 | 不能处理（依赖已知m/z差列表） | 可泛化（GNN学习未知模式） |
| 临床验证 | 无 | Phase 2目标 |
| Dark Metabolome量化 | 无 | Phase 1目标 |
| 平台泛化性 | 中（参数需调整） | 高（迁移学习） |

**核心差异化总结**：
1. MS1FA是工具，我们做框架（可编程接入现有流程）
2. MS1FA只做检测和注释，我们做检测+全流程影响量化
3. MS1FA不碰临床影响，我们直接量化临床假阳性
4. MS1FA用规则引擎，我们用GNN（可学习、可泛化）

**MS1FA的真正威胁**：它发表于2025年4月，占据了"综合ISF注释工具"的位置，我们必须在论文中正面回应"MS1FA已经做了什么，我们为什么还需要"。答案应该是：MS1FA是静态规则工具，我们是学习型框架，且我们做了MS1FA没有做的临床量化。

### 5.2 差异化策略

**竞争地图**（按检测方法 × 流程覆盖维度）：

```
                    事后注释    全流程感知
规则引擎/统计   ISFrag/CAMERA/MS1FA/MassCube    空白
机器学习/GNN          空白              我们的目标位置
```

我们的位置是唯一空白的象限：**学习型方法 × 全流程感知**。

---

## 6. 压力测试结果

### 问题1：MS1FA竞争深度

**结论：中等威胁，可正面应对。** MS1FA已占据"综合注释工具"位置，但它是Shiny App（非pipeline）、规则引擎（非学习型）、无临床验证。我们需要明确声明"我们不做另一个注释工具，我们做全流程ISF感知框架"。

### 问题2：GNN vs RF的必要性

**结论：需要消融实验支撑，不能只凭理论主张。** GNN的理论优势在于图结构推断（ISF网络的传播关系），但在标准评测数据集上能否显著优于RF+图特征，需要M4-M6的实验结果。如果消融实验显示GNN优势不明显（delta < 5% F1），应坦诚降格为"图特征增强的RF方案"，仍然比规则引擎有优势，论文可发表性不受影响。

### 问题3：全流程整合的技术挑战

**结论：难度高，但可分阶段。** 最大技术挑战是接口标准化（XCMS/MZmine/MassCube的特征表格式各不相同）。Phase 1建议仅支持mzML + XCMS/MZmine输出格式，明确不覆盖MassCube（它已有内置ISF处理）。接口设计可以学习MassCube的approach：先做correlation-based图，再叠加GNN。

### 问题4：B4临床假阳性量化的数据可得性

**结论：这是Phase 2最大风险。** 真正的ground truth（某个标志物是否真实生物学标志物）无法从公开数据集直接获取。推荐的实验设计策略：
- **方案A**（可行性高）：在已知组成的QC样本中人工加入高源电压采集数据，然后模拟临床标志物发现流程，统计ISF特征被错误选为标志物的比例
- **方案B**（可行性中）：在多平台重复测量的公开数据集（如NIST参考标准）中，对比有/无ISF过滤的标志物列表，用跨平台一致性作为"假阳性"代理指标
- **方案C**（可行性低，需合作）：回顾性分析已发表的临床数据，重新处理原始数据并比较标志物列表

### 问题5：B8 ISF-MNAR联合的理论基础

**结论：理论基础成立，但实证证据尚缺。** ISF特征的缺失模式为MAR/MCAR的论证是合理的（源电压波动是随机干扰，不与代谢物浓度相关）。但需要用真实数据验证（M6-M8概念验证）。当前无直接文献证据，这既是风险（证伪风险），也是novelty（完全未被探索）。

### 问题6：B8的实际影响量

**结论：不确定性高，是B8的主要Go/No-Go判断因素。** 根据MassCube数据（mouse数据集：2604 ISF/总特征数~20000，约13%），如果缺失率在20-40%范围，ISF污染的缺失值约占总缺失值的3-7%。这个量级是否足以支撑独立论文，取决于是否能观测到显著的下游差异分析假阳性率变化。M8的概念验证将是关键决策节点。

### 问题7：GC-MS热降解的独立价值

**结论：有价值，但不是现在。** 方法论需要重新设计（非直接迁移），实验数据获取更难，市场规模小于LC-MS ISF。建议在方向A论文发表后（M12+）再评估是否独立开发。近期价值：在方向A论文中用一段Discussion提及，增加系列感和影响力。

---

## 7. Go/No-Go门控标准

### 方向A（ISF-GNN全流程框架）

| 阶段 | 门控条件 | 通过标准 | 时间节点 |
|------|----------|----------|----------|
| Phase 1启动 | 训练数据可用性 | METLIN/MassCube公开数据可下载，含ISF标注 | M1 |
| GNN开发继续 | 消融实验结果 | GNN vs ISFrag规则引擎 F1提升 ≥ 5%（若未达到，改RF+图特征） | M6 |
| Phase 1投稿 | benchmark结果 | 在 ≥2个独立数据集上超越ISFrag/MS1FA | M10 |
| Phase 2启动（B4） | Phase 1接受 + 临床数据获取 | 至少3个公开临床数据集可处理，ISF处理有明显影响 | M12 |
| Phase 2继续 | 对照实验结果 | 有/无ISF过滤的假阳性率差异 ≥ 5%（绝对值） | M15 |

### 方向B（ISF-MNAR，B8）

| 阶段 | 门控条件 | 通过标准 | 时间节点 |
|------|----------|----------|----------|
| 概念验证 | ISF缺失模式分析 | ISF特征缺失与强度负相关性显著低于真实特征（p<0.05） | M8 |
| 正式开发 | 影响量验证 | ISF-aware填补 vs 传统填补假阳性率差异 > 10% | M10 |
| 独立论文决策 | 综合评估 | 影响量达标 + 方向A已有预印本（有框架背书） | M12 |

### GC-MS热降解扩展

| 条件 | 说明 |
|------|------|
| 启动前提 | 方向A Phase 1投稿完成（M10+） |
| 独立立项前提 | 方向A得到良好同行反响 + 有GC-MS数据合作方 |
| 近期行动 | 仅在方向A论文Discussion中提及，不投入开发资源 |

---

## 附：核心参考文献

- Giera et al. "The Hidden Impact of In-Source Fragmentation" (Nature Metabolism 2024)
- "The Dark Metabolome/Lipidome and ISF" (Analytical Science Advances 2025)
- "Discovery of metabolites prevails amid ISF" (Nature Metabolism 2025)
- MS1FA: Shiny app for ISF annotation (Bioinformatics 2025)
- ISFrag: De Novo ISF Annotation (Anal. Chem. 2021)
- MassCube: End-to-end Metabolomics (Nat. Commun. 2025)
- Mechanism-aware imputation (BMC Bioinformatics 2022)
- 244-study cancer metabolomics reproducibility (PMC11999569, 2025)

---

## 论文产出规划

| 论文 | 目标期刊 | 预计投稿 | 状态 |
|------|----------|----------|------|
| ISF-GNN + Dark Metabolome | Analytical Chemistry / Bioinformatics | M10-M12 | Phase 1 核心 |
| ISF临床假阳性量化（B4升级） | Nature Communications / Nature Methods | M17-M18 | Phase 2 条件性 |
| ISF-MNAR联合建模（B8） | Bioinformatics / Anal. Chem. | M14-M16 | 条件性（M8门控） |
| GC-MS热降解（远期） | J. Chromatography A | M20+ | 远期条件性 |
