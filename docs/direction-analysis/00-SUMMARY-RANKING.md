# 代谢组学/质谱分析算法科研方向 深度调研汇总报告

**调研日期**: 2026-03-16（持续更新）
**调研方法**: 16个方向调研（12原始+4替代）+ 17个NC候选压力测试（5轮） + 5轮NC科学问题发现 + 4批Anal Chem压力测试 + 确认方向深度压力测试 + Pivot评估 + 全组合统一AC压力测试（解决方案导向）+ **全方向交叉头脑风暴（~30方向×3聚类，含淘汰方向复活评估）** + **sub-AC方向清理（删除/降级/吸收）**
**评分标准**: 可行性（技术+数据+时间）、发表潜力（期刊级别+创新性+竞争格局）、综合推荐
**核心前提**: 所有方向作为独立代谢组学/质谱算法科学问题评估，不绑定 MetaboFlow 平台

---

## 已淘汰方向（全部经压力测试后删除）

| 方向 | 淘汰原因 | 淘汰轮次 |
|------|---------|---------|
| M11.3 孟德尔随机化 | MetaboAnalyst 6.0 + mGWAS-Explorer 2.0 已占位，无算法创新空间 | 第1轮调研 |
| M11.5 微生物组-代谢组联合 | MicrobiomeAnalyst 已成熟，非质谱算法问题 | 第1轮调研 |
| M11.4 剂量-响应分析 | MetaboAnalyst 已做完整实现，用户群太窄 | 第1轮调研 |
| M10.5 DreaMS多平台预训练 | 2篇Nature Biotech 2025同期发表，创新性≈0 | 第1轮调研 |
| M10.1 最优传输谱图相似度 | FlashEntropy(AUC 0.958)主导，OT速度劣势50-200×，同分异构体场景太窄 | Anal Chem压力测试Batch1 |
| M10.3 图信号处理通路分析 | 与NetGSA数学等价，注释覆盖率10-30%致图断裂 | Anal Chem压力测试Batch1 |
| ALT3 批次效应校正benchmark | Groux et al. 2025竞争+空间过拥挤(~15篇) → 降级为内部基准工作 | Anal Chem压力测试Batch2 |
| M11.1 制药ADME/MIST | 方法论贡献不足+核心验证数据不可得 → 永久删除学术路径 | Anal Chem压力测试Batch2 |

---

## 最终方向排名（交叉头脑风暴后 v4 — 2026-03-16）

### v4 方法论：全方向交叉头脑风暴

在 v3 的"战略组合"基础上，对**全部~30个方向（含所有淘汰方向）**做四聚类交叉分析：
1. **不确定性与注释聚类**（11方向）：淘汰方向致命问题可解性逐一审查 → 组合矩阵 → 全局UQ链条空白识别
2. **引擎与数据处理聚类**（12方向）：淘汰方向复活路径 → ISF/批次效应/OT/TDA吸收进benchmark → "超级benchmark"可行性 → 新组合发现
3. **生物学·临床·通路聚类**（19方向）：淘汰方向重审 → "发现→验证"完整链条空白分析 → 新组合发现
4. **ML/AI方法 + 全局跨聚类**（5 ML组合 + 9跨聚类组合）：ML聚类内交叉 → 全局跨聚类协同 → 组合C叙事升级NatMethods

核心发现：**11个被吸收/复活方向 + 5个新方向(含B8 ISF-MNAR联合建模) + 3处链条空白 + 2个长期战略目标 + 组合C叙事升级NatMethods + ISF NC升级路径(B4)**

### 三大战略组合（v4 更新——交叉头脑风暴后升级）

| 组合 | 内容 | v3评分 | **v4评分** | 目标期刊 | v4新增内容 |
|------|------|--------|-----------|---------|-----------|
| **组合A** | CP + 异构体UQ传播 + **差异分析UQ传播** | 8.5 | **8.7-9.0** | **Nature Methods** | +差异分析UQ链条空白填补, +CCS可选先验, +暗代谢组叙事 |
| **组合B v2** | 功效+临床 + **因果效应量(MR)** + **Winner's Curse校正** | 8.0 | **8.5** | AC强 → NC条件(50%) | +MR因果效应量输入, +Winner's Curse校正, +通路级功效 |
| **组合C+** | benchmark + Multiverse + **批次效应模块** + **ISF维度** + **OT注释诊断** + **CP注释UQ** + **暗代谢组一致性** + **DreaMS嵌入** | 7.5→8.0 | **8.0-8.5 → NC / NatMethods条件** | **Nature Communications → NatMethods(if B3 significant)** | +吸收ALT3批次效应, +ISF, +OT, +CP注释UQ评估(B1), +跨引擎暗代谢组一致性(B3), +引擎-功效关系(B5), +DreaMS嵌入相似度(B7) → "代谢组学可重复性图谱" |

**组合A v4升级详解**：
- **关键新发现：差异分析UQ传播空白**——当前链条"CP→通路分析"跳过了差异分析层。当注释不确定时（亮氨酸0.6/异亮氨酸0.4），差异分析应做加权差异检验。填补此空白使组合A形成真正端到端链条：CP prediction sets → **注释感知差异分析** → 通路感知贝叶斯传播。现有任何工具都不覆盖这个完整路径。
- CCS可选先验（从IsoDistinguish救出）：有实验CCS且差异>1.5%时用贝叶斯更新，否则退化为纯MS2。"有则用，无则退化"的渐进框架。
- 暗代谢组叙事：零成本操作，用"双重不确定性危机"强化论文动机。

**组合B v2升级详解**：
- **Winner's Curse校正**：发现研究的效应量膨胀系统性纳入功效计算，提供更保守的样本量估计。
- **因果效应量输入**：用MR估计的因果效应量（非关联效应量）作为功效输入，区分"发现因果关联所需样本量"vs"统计关联所需样本量"。代谢组学特有MR问题（弱mQTL、通路内高相关导致IV重叠）是方法论贡献点。
- NC投稿可行性从30%提升至50%，工作量增加约20%。

**组合C+ 升级详解（v4.1 — ML/全局交叉后再升级）**：
- **吸收ALT3批次效应**：过度校正量化框架整合为benchmark的独立章节。MassCube benchmark完全没有批次效应评估，这是最显著的差异化点。
- **ISF影响维度**：用高源电压数据集对比各引擎ISF处理策略，量化ISF对引擎间重叠率的影响。
- **OT注释诊断**：OT不替代FlashEntropy，作为注释质量的双重检验——高余弦但高OT距离的注释标记为"边界注释"。
- **★B1 CP×benchmark注释UQ评估**：用保形预测给各引擎注释结果生成prediction sets，量化各引擎的"注释不确定性谱"。MassCube只比较注释数量，我们比较注释质量。
- **★B3 暗代谢组跨引擎一致性**：暗代谢组特征在不同引擎中是否稳定出现？如果某特征只在1/5引擎中检测到→可能是伪特征。这是对Giera/Siuzdak暗代谢组辩论（Nature Metabolism 2024-2025）的实证贡献。**若B3发现显著，叙事升级为"代谢组学可重复性图谱"，目标期刊从NC升至Nature Methods。**
- **B5 引擎-功效关系**：引擎选择如何影响统计功效？特征数与功效的非单调关系（更多特征≠更高功效，因FDR惩罚）。桥接组合C+与组合B。
- **B7 DreaMS嵌入注释相似度**：替代字符串匹配——用DreaMS预训练嵌入的余弦距离衡量注释一致性，解决"同一化合物不同数据库命名不同"的评估难题。
- Ensemble/场景自适应加权复活：benchmark数据→引擎特性知识库→场景自适应权重，作为系列第二篇（NC 7-7.5）。

### 第一梯队：确认推进（综合 ≥7.5）

| 排名 | 方向/组合 | v4评分 | v3→v4 | 推荐期刊 | 核心差异化 |
|------|----------|--------|--------|----------|-----------|
| **1** | **★组合A: CP+UQ传播+差异分析UQ** | **8.7-9.0** | ↑0.2-0.5 | **Nature Methods** | 端到端UQ链条（注释→差异→通路），现有工具零覆盖 |
| **2** | **★组合B v2: 功效+临床+因果MR+Winner's Curse** | **8.5** | ↑0.5 | AC强/NC(50%) | MNAR-aware bootstrap + ENIT + 因果效应量 + Winner's Curse |
| **3** | **★组合C+: benchmark+Multiverse+批次+ISF+OT+CP-UQ+暗代谢组+DreaMS** | **8.0-8.5 → NM条件** | ↑0.5-1.0 | NC → **NatMethods(if B3 significant)** | 全流程覆盖；批次/ISF/OT+注释UQ+暗代谢组一致性+DreaMS嵌入→"可重复性图谱" |
| **4** | **MNAR-VAE化学先验填补** | **7.5** | — | Analytical Chemistry | 化学先验(MW/logP/极性)实证链；"structure-informed"差异化 |
| **5** | **ISF-aware全流程框架** | **7.5** | — | AC → **NC条件(Phase 2 B4)** | GNN+峰检测阶段整合；**Phase 2: B4临床假阳性回顾性量化→NC升级路径** |

### 第二梯队：条件保留 + 探索方向（7.0-7.5）

| 排名 | 方向 | v5评分 | 状态 | 条件/说明 |
|------|------|--------|------|----------|
| **6** | **Ensemble/场景自适应加权** | **7.0-7.5 → 8.0** | ★复活 | 以benchmark数据为先验，需生物学验证数据合作；作为组合C+系列第二篇 |
| **7** | **SC代谢物→通量约束（Y1）** | **7.0-7.5 → POC后8.5-9.0** | ★新发现 | 替代scMetabo-Net：代谢物直接约束FBA；HT SpaceM数据可得；需6月POC门控 |
| **8** | **GC-MS自监督预训练** | **7.0-7.5** | ↑0.5 | 与GC-MS benchmark扩展互引；NIST23授权后7.5-8.0 |

### 吸收进组合的方向（不独立发表）

| 方向 | 原状态 | 吸收去向 | 吸收后价值 |
|------|--------|---------|-----------|
| 保形预测（独立） | 6.0 | 组合A核心 | — |
| 临床验证（独立） | 6.5 | 组合B核心 | — |
| consensus（独立） | 4.5 | 组合C+系列 | — |
| **批次效应benchmark** | 降级/淘汰 | **组合C+批次模块** | benchmark整体提分+0.5 |
| **OT谱图相似度** | 淘汰 | **组合C+注释诊断** | 低独立价值，有叙事增量 |
| **计算可重复性审计** | 6.5 | **组合C+ Multiverse扩展** | NC框架内比独立发GigaScience更有影响力 |
| **IsoDistinguish CCS维度** | 3.4→淘汰 | **组合A CCS可选先验** | 方法完整性提升，+1月工作量 |
| **暗代谢组叙事** | 2/10→淘汰 | **组合A引言动机** | 零成本叙事增强 |
| **GSP+代谢基因backbone** | 淘汰变体 | **组合A下游通路扩展** | 不独立发，作为组合A延伸应用 |
| **AbsoluteQuant对功效影响** | 3.5→淘汰 | **组合B分析节** | "绝对定量减少样本量X%"实用贡献 |
| **★CP×benchmark注释UQ(B1)** | 新交叉 | **组合C+注释评估** | 各引擎注释不确定性谱比较，超越MassCube只比数量 |
| **★暗代谢组跨引擎一致性(B3)** | 新交叉 | **组合C+暗代谢组模块** | 实证回应Giera/Siuzdak辩论；NatMethods叙事升级关键 |
| **引擎-功效关系(B5)** | 新交叉 | **组合B+C桥接** | 引擎选择→统计功效的非单调关系 |
| **DreaMS嵌入注释相似度(B7)** | 新交叉 | **组合C+注释一致性度量** | 替代字符串匹配，解决跨数据库命名差异问题 |
| **注释感知功效(B2)** | 新交叉 | **组合B v2扩展** | 不确定注释→功效折扣因子 |
| **★B8 ISF-MNAR联合建模** | 独立方向(7.0)→降级 | **Plan 1 MNAR-VAE可选实验章节** | ISF-aware vs unaware填补对比，3-7%特征改善 |
| **★Y2 环境代谢物归因** | 独立方向(6.0)→降级 | **Plan 1 MNAR-VAE Discussion段落** | 外源代谢物缺失模式与内源不同的应用讨论 |
| **★TDA 2D峰检测** | 独立方向(6.5)→降级 | **Plan 2 benchmark可选POC** | GCxGC-MS场景1-2周POC，不独立推进 |

### 长期战略目标（18-36个月）

| 方向 | 评分 | 时间线 | 前置依赖 |
|------|------|--------|---------|
| 代谢组学Meta分析方法论 | 7.0-7.5 | 组合B发表后18月 | 组合B建立方法论基础 |
| **MEWS代谢组学研究质量评分系统** | NC/NM级 | 24-36月 | 组合B+C全部完成 |
| GC-MS benchmark扩展（Phase 2） | NC级 | 组合C Phase 1后 | benchmark框架+GC-MS引擎适配 |

### 维持淘汰（交叉头脑风暴 + sub-AC清理后确认不可复活）

| 方向 | 确认淘汰原因 |
|------|-------------|
| **★嵌合谱图影响量化** | 6篇论文饱和（含AC 2025.08），无可行拯救路径（v1.2永久删除） |
| **★MSI端元解卷积** | 参考数据仅10种癌细胞系+离子抑制共线性+Moens 2025先发，3致命问题不可解（v1.2永久删除） |
| 暗代谢组（独立方向） | Li 2025已发+ground truth缺失+4/4致命问题不可解（叙事已吸收进组合A） |
| DIA In Silico Library | cosine 0.35数据质量限制不可改变 |
| 扩散模型正向MS2 | DiffMS(ICML)+FIORA(NC)双重占位 |
| IsoDistinguish（独立方向） | MassID占位+数据稀缺+精度重叠（CCS维度已吸收进组合A） |
| 孟德尔随机化 | MetaboAnalyst 6.0 + mGWAS-Explorer完全覆盖 |
| 微生物组-代谢组联合 | MicrobiomeAnalyst成熟；反向推断仅5.5-6.0 |
| 剂量-响应分析 | 工具链完备 |
| MIST制药 | 永久淘汰 |
| 智能工作流 | MetaboAnalyst标准，无绕过路径 |
| AdductPredict | MassCube内置 |
| 跨队列稳定性预测 | PMC11999569已解决 |
| 时序波动分解 | RM-ASCA+已覆盖 |
| 跨研究浓度标准化 | 工程性强、创新不足 |

---

## NC候选方向（5轮17个全部未通过）

### 第二轮NC压力测试结果

| 候选 | 初评 | 压力测试 | 致命原因 |
|------|------|---------|---------|
| MSI细胞类型解卷积 | 8.5 | **2.5/10** ❌ | 参考数据仅10种癌细胞系；离子抑制与细胞类型共线性；Moens et al. 2025先发 |
| DIA In Silico Library | 8.0 | **5.5/10** ⚠️→❌ | in silico预测cosine仅0.35；转型脂质组学DIA后被MS-DIAL 5+LipidIN占位 |
| 代谢物来源归因 | ★★★★★ | **3.5/10** ❌ | Zimmermann-Kogadeeva bioRxiv 2022已做定量分解 |
| 跨队列稳定性预测 | 7.5 | **3/10** ❌ | PMC11999569已解决核心问题 |
| 时序波动分解 | ★★★★★ | **4/10** ❌ | RM-ASCA+已覆盖；iHMP采样密度不足 |

### 第四轮NC压力测试结果

| 候选 | 初评 | 压力测试 | 致命原因 |
|------|------|---------|---------|
| scMetabo-Net | 7.5 | **3.0/10** ❌ | MGFEA(bioRxiv 2024)已用VGAE+代谢网络先验；无ground truth |
| AbsoluteQuant | 7.5 | **3.5/10** ❌ | Pyxis+IROA TruQuant(NC 2025)；响应因子天花板1.6-2.6× |
| IsoDistinguish | 7.0 | **3.4/10** ❌ | MassID(2026)已含MS2+RT贝叶斯融合+FDR |
| AdductPredict | 7.0 | **4.2/10** ❌ | MassCube(NC 2025)已内置；实验条件主导50-70%方差 |

### 第五轮NC压力测试结果（2026-03-16 最新）

| 候选 | 初评 | 压力测试 | 致命原因 |
|------|------|---------|---------|
| 碎片离子物理校正 | 7.0 | **4.0/10** ❌ | IRMPD数据需稀有FEL设施（物理屏障）；碎片结构正确性对下游注释影响≈0（m/z+intensity匹配不用3D结构）；van Tetering原作者团队最危险竞争者 |
| Multiverse分析框架 | 7.5 | **5.5/10** ⚠️ | 空白是"命名"非"实质"——8%特征重叠+85%显著代谢物是噪声已被分别发表；**建议作为benchmark论文的延伸章节发在Genome Biology** |

### 第五轮Pivot评估结果

| Pivot方向 | NC评分 | AC评分 | 建议 |
|-----------|--------|--------|------|
| SC→通量约束模型 | 5/10 | 7/10 | AC条件推荐（需METAFlux NC 2023差异化） |
| 跨研究浓度标准化 | 3/10 | 6/10 | 不推荐（工程性强、创新不足） |
| 同分异构体不确定性传播 | 5/10 | **8/10** | **AC强烈推荐**（不区分异构体，加权传播到下游） |

### 第五轮Pivot-NC衍生方向

| 候选 | 评分 | 致命原因 |
|------|------|---------|
| 计算可重复性审计框架 | 6.5/10 | 最佳但非NC级——更适合Genome Biology/GigaScience |
| 代谢组学结果不确定性传播 | 5.5/10 | Metchalchi 2023已做蛋白质组学版 |
| 通量平衡约束NMF | 5.0/10 | METAFlux(NC 2023)核心方法已占位 |
| 动态网络响应预测 | 4.5/10 | ReDU+MASST已做大规模谱图匹配 |

**关键洞察**：初评分数与压力测试结果几乎不相关（8.5→2.5, ★★★★★→3.5）。科学问题的重要性≠可解决性。

### Round 2 未测试NC→Anal Chem回退评估（Batch 3+4）

| 候选 | AC评分 | 结果 |
|------|--------|------|
| MNAR-VAE化学先验缺失值填补 | **8/10** | ★ 新增AC Top候选 |
| 嵌合谱图系统性影响量化 | **7.5/10** | ★ 新增AC候选 |
| MetaboODE神经ODE缺失值填补 | **7/10** | 新增AC候选 |
| 功效分析框架 | **7/10** | 新增AC候选 |
| 谱图预测UQ | 6.5/10 | 条件保留（arXiv 2026-03-11竞争） |
| 绝对浓度重建 | — | ❌ 冗余（与AbsoluteQuant >85%重叠） |
| 伪绝对量化 | — | ❌ 冗余（与AbsoluteQuant >90%重叠） |
| 因果网络图谱 | 4/10 | ❌ UK Biobank系列已覆盖 |
| 暴露组学对齐 | 4/10 | ❌ GromovMatcher已填核心空白 |
| OT轨迹 | 5/10 | 条件（需时序数据集先到位） |
| 扩散模型正向MS2 | 4/10 | ❌ DiffMS(ICML 2025)+FIORA(NC 2025)已占位 |

---

## 推荐执行路线图（v5 — sub-AC清理后最终版）

**v5核心变更：删除2个方向（嵌合谱图、MSI端元），降级吸收3个方向（Y2→Discussion、TDA→POC、B8→实验章节）。保留8个独立方向/组合 + 3个长期战略。**

```
优先级 A（立即并行推进——NC/NatMethods级）：
├── Month 1-8:   MNAR-VAE化学先验填补 → AC（7.5，最快产出，最高置信度）
│   └── 可选扩展：B8 ISF-aware实验章节（+1-2周）+ Y2 Discussion段落
├── Month 1-12:  组合A: CP+差异分析UQ+通路UQ → Nature Methods（8.7-9.0）
│   ├── Phase 1 (M1-4): CP框架+conformity score+calibration+CCS可选先验
│   ├── Phase 2 (M4-9): 注释感知加权差异分析（核心空白）
│   └── Phase 3 (M9-12): 通路感知贝叶斯传播+端到端案例
├── Month 1-14:  组合C+: benchmark+Multiverse+批次+ISF+OT → NC（8.0-8.5）
│   ├── Phase 1 (M1-6): 6+引擎运行+峰检测+ISF影响评估
│   ├── Phase 2 (M6-10): 批次效应模块+Multiverse+OT诊断+TDA 2D POC(1-2周)
│   └── Phase 3 (M10-14): 全流程综合+bioRxiv占位
└── Month 3-14:  组合B v2: 功效+临床+MR因果+Winner's Curse → AC强/NC(50%)（8.5）

优先级 B（Month 3 启动）：
├── Month 3-12:  ISF-aware全流程 → AC / NC条件（7.5）
├── Month 3-9:   SC代谢物→通量约束 Y1 POC → 门控决策（成功后8.5-9.0）
└── Month 6-15:  GC-MS自监督预训练 → AC（7.0-7.5，与GC-MS benchmark互引）

优先级 C（Month 14后按容量）：
├── Ensemble/场景自适应加权 → 组合C+系列第二篇（NC 7-7.5→8.0）
└── MNAR-VAE生成扩展(A3) → MNAR-VAE论文内optional章节

长期战略（18-36个月）：
├── Month 18-28: 代谢组学Meta分析方法论 → 组合B后续
├── Month 18-24: GC-MS benchmark扩展（组合C+ Phase 2）
└── Month 24-36: MEWS代谢组学研究质量评分系统 → 旗舰NC/NM
```

### 论文产出预期（v5 — 清理后最终版）

| 时间 | 论文 | 期刊 | 评分 | 置信度 |
|------|------|------|------|--------|
| Month 8 | MNAR-VAE化学先验填补（含B8实验章节+Y2 Discussion） | Analytical Chemistry | 7.5 | 高 |
| Month 12 | **组合A: CP+差异分析UQ+通路UQ** | **Nature Methods** | **8.7-9.0** | **高** |
| Month 12 | ISF-aware全流程 | Analytical Chemistry | 7.5 | 中高 |
| Month 9 | SC代谢物→通量约束 Y1（如POC通过） | AC → NatMethods条件 | 7.0-7.5 → 8.5-9.0 | 中（POC依赖） |
| Month 14 | **组合B v2: 功效+因果MR+Winner's Curse** | **AC强 / NC(50%)** | **8.5** | **中高** |
| Month 14 | **组合C+: "代谢组学可重复性图谱"** | **NC → NatMethods条件** | **8.0-8.5+** | **高** |
| Month 15 | GC-MS自监督预训练 | Analytical Chemistry | 7.0-7.5 | 中 |
| Month 20 | Ensemble/场景自适应加权(系列) | AC→NC条件 | 7.0-7.5 → 8.0 | 中 |

**2年内产出预期：2-3篇NC/NatMethods + 4-5篇AC（共6-8篇一作论文）**

**v5 sub-AC清理后的关键变化（vs v4）**：
- **永久删除2个方向**：嵌合谱图（5.5，6篇论文饱和）、MSI端元（5.5，3致命问题）
- **降级吸收3个方向**：Y2→Plan 1 Discussion段落、TDA→Plan 2 POC、B8→Plan 1实验章节
- **净效果**：从12个排名方向精简为8个独立方向/组合 + 3个长期战略，所有有用组件保留但不再占独立位
- **产出预期**：2年内6-8篇一作论文（2-3篇NC/NM + 4-5篇AC），聚焦度更高

---

## NC战略总结

### 代谢组学NC赛道竞争格局（2023-2025）
6篇密集发表：tidyMass、asari、MetaboAnalystR 4.0、MS-DIAL 5、MassCube、Pan-ReDU
2025-2026持续涌入：FIORA(NC 2025)、DreaMS(NatBiotech 2025)、MassID(bioRxiv 2026-02)、DiffMS(ICML 2025)、MassCube(NC 2025)

### 全局统计：5轮17个NC候选全部未通过压力测试

| 轮次 | 候选数 | 最高分 | 通过数 |
|------|--------|--------|--------|
| Round 1 (工具框架) | 5 | 6/10 | 0 |
| Round 2 (科学问题→方案) | 5 | 5.5/10 | 0 |
| Round 3 (DIA脂质组学) | 1 | 3.5/10 | 0 |
| Round 4 (算法+领域问题) | 4 | 4.2/10 | 0 |
| Round 5 (碎片物理+Multiverse+Pivot衍生) | 2+4 | 6.5/10 | 0 |
| **合计** | **17+4pivot** | **6.5/10** | **0** |

### 根本原因分析
1. **代谢组学NC赛道2023-2026极度拥挤**——几乎所有算法空白都在12-18个月内被占
2. **初评基于问题重要性，压力测试检验可做性**——这两者在成熟领域高度脱节
3. **dry lab约束严格**——需要公开数据+单人12-18月可完成
4. **"命名掩盖同质性"模式**——不同名称的候选实质上是同一问题（Round 2 Fundamentals C ≈ IndustryPain P2 ≈ AbsoluteQuant）

### 深度压力测试对确认方向的影响（2026-03-16）
用2025-2026最新竞争者重新搜索已确认的6个方向，3个需要降分：
- **benchmark 8.0→7.0**: MassCube(NC 2025)内置了自己的benchmark，削弱了独立benchmark的独占叙事
- **ISF 7.5→6.5**: MS1FA(Bioinformatics 2025)已做ML+ISF分类器
- **conformal 7.5→6.5**: arXiv 2026-03-10 "When should we trust the annotation?" 6天前发布
- **GC-MS 7.0不变**: 最干净的空白，无直接竞争者
- **consensus 7.0→5.5**: MassCube论证"一个好引擎够用"，严重削弱多引擎共识的科学叙事
- **clinical 7.0不变**: FDA draft guidance反而强化了需求

### 战略结论（v4 — 交叉头脑风暴后）

**v4的认知突破：淘汰方向的核心组件可以系统性吸收进存活组合，形成"组件级复活"。**

1. **组合A增强版（8.7-9.0）是整个组合中最强的NatMethods候选**——差异分析UQ传播空白的发现使其形成真正端到端链条（注释→差异→通路），现有工具零覆盖。CCS可选先验和暗代谢组叙事是零/低成本增强。
2. **组合B v2（8.5）通过加入MR因果效应量和Winner's Curse校正，NC可行性从30%提升至50%**——代谢组学特有MR方法论问题（弱mQTL、IV重叠）是真实空白，增加约20%工作量。
3. **组合C+（8.0-8.5→NatMethods条件）通过吸收批次效应+ISF+OT+CP注释UQ+暗代谢组一致性+DreaMS嵌入六个维度**——从"峰检测比较"升级为"代谢组学可重复性图谱"。若B3暗代谢组跨引擎一致性发现显著，叙事直接对标Nature Methods。
4. **Ensemble/场景自适应加权复活（NC 7-7.5）**——以benchmark数据为先验的场景自适应引擎权重，是组合C+的自然系列第二篇。需要生物学验证数据合作，这是执行层面最需尽早锁定的资源。
5. **两个新发现方向**：SC代谢物→通量约束（Y1，替代scMetabo-Net，热力学差异化METAFlux）和环境代谢物归因（Y2，外源/内源二分法，UK Biobank验证）。
6. **MEWS长期战略目标**——代谢组学研究质量评分系统（对标Cochrane偏倚风险工具），需要组合B+C全部完成后才能启动，但领域影响力潜力最大。
7. **"发现→验证"链条的6个空白已被系统识别**——ISF→注释质量传播、注释UQ→差异分析传播（已纳入组合A）、通路级功效分析（纳入组合B）、验证失败诊断、Meta分析方法论、Winner's Curse校正（纳入组合B）。
8. **2年产出预期：2-3篇NC/NM + 4-5篇AC（共6-8篇一作论文）**——聚焦度更高，组合A冲击NatMethods的置信度最高。
9. **v5 sub-AC清理**——永久删除嵌合谱图+MSI端元（不可救），降级吸收Y2/TDA/B8（有用组件保留但不占独立位）。从12个方向精简为8个独立方向/组合。
10. **ISF方向有明确NC升级路径（B4）**——Phase 1发AC，Phase 2做回顾性临床假阳性量化（"ISF导致的临床标志物X%假阳性率"），可升级至NC。

---

## 全部报告索引

### ★★ 最终研究计划书（无迭代历史的干净版）

| 文件 | 说明 |
|------|------|
| **[FINAL-RESEARCH-PLAN.md](FINAL-RESEARCH-PLAN.md)** | 8个方向完整计划 + 时间线 + 门控 + 论文产出规划（无迭代过程） |

### ★ 完整执行方案（含压力测试过程，2026-03-16）

| 文件 | 覆盖方向 | 核心发现 |
|------|---------|---------|
| [plans/Plan1-UQ-Chain.md](plans/Plan1-UQ-Chain.md) | MNAR-VAE(AC 7.5) + 组合A端到端UQ(NatMethods 8.7-9.0) | 差异分析层注释感知加权是真实空白；arXiv 2026-03-10仅覆盖Phase 1；MassID不做加权差异分析 |
| [plans/Plan2-ReproducibilityAtlas.md](plans/Plan2-ReproducibilityAtlas.md) | 组合C+可重复性图谱(NC→NatMethods条件) + Ensemble系列 | MassCube NC仅4引擎+峰检测；DreaMS公开可用；5引擎×4数据集×6维度；14月详细时间线 |
| [plans/Plan3-ClinicalPower.md](plans/Plan3-ClinicalPower.md) | 组合B v2功效(AC→NC 50%) + B2注释感知功效 + B5引擎-功效 | MetSizeR/MultiPower均不处理MNAR/WC/MR；UK Biobank NMR可作MR验证；WC代谢组学证据有限需原创量化 |
| [plans/Plan4-ISF-Series.md](plans/Plan4-ISF-Series.md) | ISF-GNN全流程(AC) + B4临床假阳性(NC升级) + B8 ISF-MNAR + GC-MS热降解 | 无GNN做ISF检测（真实空白）；MS1FA是规则引擎非ML；GNN vs RF需M6消融实验；B8影响量3-7%需验证 |
| [plans/Plan5-EmergingDirections.md](plans/Plan5-EmergingDirections.md) | Y1 SC通量 + GC-MS预训练 + Ensemble（v1.2清理后3方向） | 嵌合谱图/MSI端元永久删除；Y2→Plan1 Discussion；TDA→Plan2 POC；B8→Plan1实验章节 |

### 确认存活方向（v5更新——sub-AC清理后）
| 文件 | 方向 | 综合分 | 状态 |
|------|------|--------|------|
| [NC-Benchmark-Platform.md](NC-Benchmark-Platform.md) | 跨引擎基准测试 | 7.0 | 组合C+核心 |
| [ALT4-GCMS-Pretraining.md](ALT4-GCMS-Pretraining.md) | GC-MS预训练 | 7.0-7.5 | 独立方向 |
| [M11.2-Clinical-Targeted.md](M11.2-Clinical-Targeted.md) | 临床验证框架 | 7.0 | 组合B核心 |
| [ALT1-ISF-Detection.md](ALT1-ISF-Detection.md) | ISF自动检测 | 7.5 | 独立方向+NC升级路径 |
| [M10.4-Conformal-Annotation.md](M10.4-Conformal-Annotation.md) | 保形预测 | 6.5 | 组合A核心（不独立） |
| [ALT2-Consensus-Features.md](ALT2-Consensus-Features.md) | 共识特征提取 | 5.5 | 组合C+吸收（不独立） |
| ~~[M10.2-TDA-PeakDetect.md](M10.2-TDA-PeakDetect.md)~~ | ~~TDA峰检测~~ | ~~6.5~~ | **1D删除；2D→Plan 2 POC** |
| ~~[M10.6-Endmember-MSI.md](M10.6-Endmember-MSI.md)~~ | ~~MSI端元~~ | ~~5.5~~ | **永久删除** |

### NC第二轮压力测试报告（已完成）
| 文件 | 方向 | 结果 |
|------|------|------|
| [NC-PressureTest-MSI-Deconvolution.md](NC-PressureTest-MSI-Deconvolution.md) | MSI细胞类型解卷积 | ❌ 2.5/10 |
| [NC-PressureTest-DIA-InSilico.md](NC-PressureTest-DIA-InSilico.md) | DIA In Silico Library | ⚠️ 5.5/10→转型脂质组学 |
| [NC-PressureTest-MetaboliteOrigin.md](NC-PressureTest-MetaboliteOrigin.md) | 代谢物来源归因 | ❌ 3.5/10 |
| [NC-PressureTest-Stability-Temporal.md](NC-PressureTest-Stability-Temporal.md) | 稳定性预测+时序分解 | ❌ 3/10 + 4/10 |

### NC第三轮压力测试报告（已完成）
| 文件 | 方向 | 结果 |
|------|------|------|
| [NC-PressureTest-DIA-Lipidomics.md](NC-PressureTest-DIA-Lipidomics.md) | 脂质组学DIA Library-Free | ❌ 3.5/10 |

### NC第四轮压力测试报告（已完成）
| 文件 | 方向 | 结果 |
|------|------|------|
| [NC-PressureTest-scMetaboNet.md](NC-PressureTest-scMetaboNet.md) | 单细胞代谢网络imputation | ❌ 3.0/10 |
| [NC-PressureTest-IsoDistinguish.md](NC-PressureTest-IsoDistinguish.md) | 同分异构体贝叶斯区分 | ❌ 3.4/10 |
| [NC-PressureTest-AbsoluteQuant.md](NC-PressureTest-AbsoluteQuant.md) | 非靶向绝对定量 | ❌ 3.5/10 |
| [NC-PressureTest-AdductPredict.md](NC-PressureTest-AdductPredict.md) | 离子形态ML预测 | ❌ 4.2/10 |

### NC第五轮发现+压力测试+Pivot报告（已完成）
| 文件 | 内容 | 结果 |
|------|------|------|
| [NC-Discovery-Round5.md](NC-Discovery-Round5.md) | 6新搜索角度（NeurIPS/ICML workshops、蛋白组反向机会、NatMethods视角、FDA法规、暴露组学、多模态）| 碎片物理7.0、负离子6.5、暴露组学6.5 |
| [NC-Discovery-Round5-Pivots.md](NC-Discovery-Round5-Pivots.md) | 4个Pivot衍生NC方向 | 计算可重复性6.5（最佳）|
| [NC-PressureTest-FragmentPhysics.md](NC-PressureTest-FragmentPhysics.md) | 碎片离子物理校正 | ❌ 4.0/10 |
| [NC-PressureTest-MultiverseAnalysis.md](NC-PressureTest-MultiverseAnalysis.md) | Multiverse分析框架 | ⚠️ 5.5/10（建议作benchmark延伸） |
| [NC-PressureTest-Pivots.md](NC-PressureTest-Pivots.md) | 3个Pivot方向双评（NC+AC） | 异构体UQ传播AC 8/10★ |

### 全方向交叉头脑风暴（v4核心依据，~30方向×4聚类）
| 文件 | 覆盖聚类 | 关键发现 |
|------|---------|---------|
| [CrossBrainstorm-UncertaintyAnnotation.md](CrossBrainstorm-UncertaintyAnnotation.md) | 不确定性+注释（11方向） | **★差异分析UQ传播空白**→组合A升级8.7-9.0；CCS可选先验；暗代谢组叙事 |
| [CrossBrainstorm-EngineProcessing.md](CrossBrainstorm-EngineProcessing.md) | 引擎+数据处理（12方向） | 批次效应吸收进benchmark→8.0；Ensemble复活→NC 7-7.5；GC-MS热降解新方向；超级benchmark分阶段策略 |
| [CrossBrainstorm-BioClinicalPathway.md](CrossBrainstorm-BioClinicalPathway.md) | 生物学+临床+通路（19方向） | 组合B v2升级（MR+WC）；SC→通量约束Y1；环境代谢物归因Y2；MEWS长期战略 |
| [CrossBrainstorm-ML-GlobalCross.md](CrossBrainstorm-ML-GlobalCross.md) | ML/AI方法+全局跨聚类（5+9组合） | **★组合C+叙事升级NatMethods**（B1 CP注释UQ+B3暗代谢组一致性+B5引擎功效+B7 DreaMS嵌入）；**★B8 ISF-MNAR联合建模**（全新方向7.0）；B4 ISF临床NC升级路径；ML聚类仅A3值得保留 |

### 全组合统一AC压力测试（解决方案导向，v3核心依据）
| 文件 | 覆盖方向 | 关键发现 |
|------|---------|---------|
| [AC-PressureTest-MNAR-Chimeric.md](AC-PressureTest-MNAR-Chimeric.md) | MNAR-VAE (8→7.5) + 嵌合谱图 (7.5→6.5) | MNAR化学先验实证链是贡献；嵌合谱图4篇AC已饱和 |
| [AC-PressureTest-IsomerUQ-Conformal.md](AC-PressureTest-IsomerUQ-Conformal.md) | 异构体UQ (8→7.5) + 保形预测 (6.5→6.0) | **★★合并升级到NatMethods/NC 8.5** |
| [AC-PressureTest-Benchmark-GCMS-Consensus.md](AC-PressureTest-Benchmark-GCMS-Consensus.md) | benchmark (7.0→7.5) + GC-MS (7.0→6.5) + consensus (5.5→4.5/6.5) | benchmark提升；SpecTUS威胁GC-MS；consensus必须系列 |
| [AC-PressureTest-ISF-Clinical-Power.md](AC-PressureTest-ISF-Clinical-Power.md) | ISF (6.5→7.5) + clinical (7.0→6.5/8.0) + 功效分析 (7.0→7.5/8.5) | ISF意外升级；**★clinical+power合并8.0-8.5** |

### 深度压力测试+Anal Chem回退评估（已完成）
| 文件 | 内容 |
|------|------|
| [DeepStressTest-ConfirmedDirections.md](DeepStressTest-ConfirmedDirections.md) | 6个确认方向用2025-2026竞争者重新评估，3个降分 |
| [AnalChem-PressureTest-Batch3-Untested-NC.md](AnalChem-PressureTest-Batch3-Untested-NC.md) | 8个Round 4未测试方向AC评估，MNAR-VAE 8/10★ |
| [AnalChem-PressureTest-Batch4-Round2-Untested.md](AnalChem-PressureTest-Batch4-Round2-Untested.md) | 5个Round 2未测试方向AC评估，2个冗余删除 |

### NC第四轮发现报告
| 文件 | 维度 |
|------|------|
| [NC-Discovery-Round4-Algorithms.md](NC-Discovery-Round4-Algorithms.md) | 新算法范式（Flow Matching、Neural ODE、CP、GNN、Mamba、RAG、Foundation Model） |
| [NC-Discovery-Round4-FieldProblems.md](NC-Discovery-Round4-FieldProblems.md) | 领域内科学问题（绝对定量、嵌合谱图、离子抑制、FDR控制、功效分析） |

### NC发现报告（第2-3轮）
| 文件 | 维度 |
|------|------|
| [NC-Discovery-Fundamentals.md](NC-Discovery-Fundamentals.md) | 根本性科学矛盾 |
| [NC-Discovery-CrossDiscipline.md](NC-Discovery-CrossDiscipline.md) | 跨学科方法移植 |
| [NC-Discovery-IndustryPain.md](NC-Discovery-IndustryPain.md) | 临床/产业瓶颈 |

### NC第一轮压力测试报告（已关闭）
| 文件 | 方向 | NC可行性 |
|------|------|---------|
| [01-NC-STRATEGY-FINAL.md](01-NC-STRATEGY-FINAL.md) | 总结报告 | — |
| [NC-Candidate1-AnnotConfidence.md](NC-Candidate1-AnnotConfidence.md) | 统一注释框架 ❌ | 5/10 |
| [NC-Candidate2-DarkMetabolome.md](NC-Candidate2-DarkMetabolome.md) | 暗代谢组 ❌ | 2/10 |
| [NC-Candidate3-ReliabilityAtlas.md](NC-Candidate3-ReliabilityAtlas.md) | 可靠性图谱 ❌ | 4/10 |
| [NC-Candidate4-EnsembleMetabolomics.md](NC-Candidate4-EnsembleMetabolomics.md) | 集成代谢组学 ⚠️ | 6/10 |
| [NC-Candidate5-IntelligentWorkflow.md](NC-Candidate5-IntelligentWorkflow.md) | 智能工作流 ❌ | 4/10 |

### Anal Chem压力测试报告
| 文件 | 覆盖方向 |
|------|---------|
| [AnalChem-PressureTest-Batch1.md](AnalChem-PressureTest-Batch1.md) | M10.1 ❌, M10.2 ⚠️, M10.3 ❌ |
| [AnalChem-PressureTest-Batch2.md](AnalChem-PressureTest-Batch2.md) | ALT3 ❌, M10.6 ⚠️, M11.1 ❌ |
| [AnalChem-PressureTest-Batch4-Round2-Untested.md](AnalChem-PressureTest-Batch4-Round2-Untested.md) | 绝对浓度重建 ❌(冗余), 因果网络图谱 ❌, OT轨迹 ⚠️(条件), 伪绝对量化 ❌(冗余), 暴露组学对齐 ❌ |

### 已淘汰方向（存档参考）
| 文件 | 方向 |
|------|------|
| [M10.1-OT-Similarity.md](M10.1-OT-Similarity.md) | 最优传输（已淘汰） |
| — | 绝对浓度重建 Fundamentals C（冗余删除，与AbsoluteQuant>85%重叠） |
| — | 伪绝对量化 IndustryPain P2（冗余删除，与AbsoluteQuant>90%重叠） |
| — | 因果网络图谱 Fundamentals D（删除，UK Biobank 2024-2025系列已系统覆盖） |
| — | 暴露组学对齐 IndustryPain P3（删除，GromovMatcher+RT预测已填补核心空白） |
| [M10.3-GSP-Pathway.md](M10.3-GSP-Pathway.md) | GSP通路（已淘汰） |
| [M10.5-DreaMS-Pretraining.md](M10.5-DreaMS-Pretraining.md) | DreaMS预训练（已淘汰） |
| [ALT3-BatchCorrection-Benchmark.md](ALT3-BatchCorrection-Benchmark.md) | 批次效应（降级） |
| [M11.1-Pharma-MIST.md](M11.1-Pharma-MIST.md) | MIST自动化（已淘汰） |
| [M11.3-MR-Analysis.md](M11.3-MR-Analysis.md) | 孟德尔随机化（已淘汰） |
| [M11.4-Dose-Response.md](M11.4-Dose-Response.md) | 剂量响应（已淘汰） |
| [M11.5-Microbiome-Metabolome.md](M11.5-Microbiome-Metabolome.md) | 微生物组（已淘汰） |
