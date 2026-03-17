# Plan 5: 新兴探索方向 — 完整执行方案

> 版本：v1.2 | 创建：2026-03-16 | 更新：v1.2 sub-AC方向清理（删除/降级/吸收）
> 覆盖方向：Y1 SC通量约束 + GC-MS自监督预训练 + Ensemble加权
> 已删除：嵌合谱图（永久删除）、MSI端元（永久删除）
> 已降级吸收：Y2→Plan 1 Discussion段落、TDA 1D删除/2D→Plan 2 POC、B8→Plan 1实验章节

---

## 竞争格局搜索结果汇总

### Y1 SC通量约束
- **scFEA**（转录组→通量，GNN，PubMed 2021）
- **METAFlux**（转录组→FBA，NC 2023）
- **MetroSCREEN**（转录组+细胞互作→通量，Genome Medicine 2025）
- 全部基于转录组。代谢物直接约束FBA（tFBA）理论存在（BMC Systems Biology 2007），但从未应用于单细胞代谢组学数据
- **HT SpaceM**（Cell 2025）：140,000+细胞，~100个代谢物，73个LC-MS/MS验证

### Y2 环境代谢物归因
- Zimmermann-Kogadeeva 2022 bioRxiv：肠道代谢物三分法（饮食/宿主/微生物组），非血浆/尿液二分类
- HMDB 5.0：endogenous/food-derived/drug-derived/toxin分类标注，但不完整
- UK Biobank 2025年11月：500,000人NMR代谢组数据全量发布（251个代谢物）

### GC-MS预训练
- **SpecTUS**（arXiv 2025.02）：354M参数Transformer，合成数据预训练，做EI-MS→SMILES结构预测，**不是通用表示学习**
- **DreaMS**（Nature Biotechnology 2025）：7亿LC-MS/MS谱图自监督预训练，**不覆盖GC-EI-MS**
- **MASSISTANT**（ChemRxiv 2025）：SELFIES编码做EI-MS结构预测
- NIST23 EI库：394,054张谱图

### 嵌合谱图
- 已有**6篇高质量论文**：msPurity(AC 2017), DecoMetDIA(AC 2019), CorrDec(AC 2020), DecoID(NatMethods 2021), DNMS2Purifier(AC 2023), Reverse Spectral Search(AC 2025.08)
- 主流场景（DDA嵌合→注释准确率）已被充分解决

---

## 1. 战略定位

四个方向是核心计划（Plan 1-4）之外的**高风险探索性卡位**：
- Y1和GC-MS预训练是真正的新领域开创，成功则AC 7.5+，失败代价为6-12个月
- Y2是方法论相对稳固、数据获取有摩擦的应用型方向
- 嵌合谱图是纯机会型，空间已被挤压

**资源分配顺序：GC-MS预训练 > Y2归因 > Y1通量 > 嵌合谱图**

---

## 2. 方向A：SC代谢物→通量约束（Y1，目标AC 7.0-7.5）

### 2.1 科学问题定义

**核心问题**：能否用单细胞代谢组学直接测量的代谢物浓度（而非转录组推断），通过热力学约束FBA，推断单细胞通量分布，并揭示转录组方法无法捕获的代谢异质性？

差异化：METAFlux、MetroSCREEN依赖基因表达→通量的间接推断，存在后转录调控盲区。代谢物浓度是通量的直接下游，提供更真实的约束信号。

### 2.2 方法设计

**框架一：tFBA约束（理想方案）**

热力学FBA要求通量方向与ΔG一致：
$$\Delta G_r' = \Delta G_r^0 + RT \ln \frac{\prod [P_j]^{\nu_j}}{\prod [S_i]^{\nu_i}} < 0 \text{ 当 } v_r > 0$$

HT SpaceM测量的代谢物浓度直接替换 [S_i]、[P_j]。

**压力测试发现的致命约束**：tFBA需要绝对浓度（mM），但MALDI-SCM产出的是相对离子强度。单细胞中标准曲线几乎无法构建。

**降级方案（实际可行）**：不做ΔG计算，改做**通量方向约束**（只需相对浓度比较）：如果细胞A的glucose:lactate比值高于细胞B，则可约束糖酵解通量方向。弱热力学假设但仍比转录组更直接。

### 2.3 数据需求

**HT SpaceM（Cell 2025）**：
- 140,000+细胞，132个样本，NCI-60肿瘤细胞系×9 + HeLa
- ~100个小分子，73个LC-MS/MS验证
- **关键限制**：73个代谢物覆盖Recon3D的4000+节点不足5%

**最小验证数据集**：HeLa糖酵解抑制实验，~10,000细胞，~50个代谢物，有bulk验证

### 2.4 六个月POC验证计划

**Go/No-Go门控**：
- Go：代谢物约束预测通量变化方向与bulk验证相关性 r > 0.5，且在≥3条通路上优于METAFlux
- No-Go：r < 0.3，或与METAFlux无显著差异
- 第3月检验点：绝对浓度问题是否可解，否则转为降级方案

### 2.5 执行时间线

| 月份 | 里程碑 |
|------|--------|
| M1-2 | 下载HT SpaceM数据，搭建tFBA框架，整合Recon3D |
| M3 | 门控评估：绝对浓度问题，决定完整版vs降级版 |
| M4-5 | HeLa验证实验，METAFlux对比分析 |
| M6 | Go/No-Go决策 |

### 2.6 风险矩阵

| 风险 | 概率 | 影响 | 应对 |
|------|------|------|------|
| 相对强度无法约束tFBA | 高(60%) | 高 | 降级为通量方向约束 |
| 代谢物覆盖率不足 | 中(40%) | 中 | 聚焦中央碳代谢子网络 |
| MetroSCREEN已部分解决 | 低(20%) | 中 | 代谢物直接测量仍是差异化 |

**总体评估**：POC成功率40-50%，成功后投稿成功率65%。

---

## ~~3. 方向B：环境代谢物归因（Y2）~~ — 降级为Plan 1 Discussion段落（v1.2）

> **降级理由**：UK Biobank NMR不含外源代谢物（核心验证路径失效）；Zeno MRMHR(AC 2025)实验方案已绕过计算归因需求；重新定义后评分6.5-7.0，独立价值不足。
>
> **保留方式**：作为Plan 1 MNAR-VAE论文的Discussion应用段落——"外源代谢物的缺失模式与内源不同，CP-MNAR-VAE的化学先验可区分"。不独立发表。

---

## 3. 方向B：GC-MS自监督预训练（目标AC 7.0）

### 4.1 科学问题定义

**核心问题**：为GC-EI-MS谱图训练通用自监督预训练表示模型，类似DreaMS对LC-MS/MS的作用。

**与SpecTUS/MASSISTANT的区分**：它们做**判别性下游任务**（谱图→结构预测）。我们做**通用表示学习**（谱图→低维嵌入空间），可迁移到任意下游任务。这个定位目前无人做。

### 4.2 GC-EI-MS的特有挑战

1. EI电离无precursor m/z（不能做masked spectrum modeling）
2. 整数质量（低分辨率）
3. 热降解ISF噪声
4. 不能直接复制DreaMS架构

### 4.3 自监督任务设计

- **任务1**：谱图增强一致性（对比学习）：同一化合物不同条件的谱图嵌入相近
- **任务2**：m/z分组预测（masked autoencoder变体）：掩蔽部分碎片峰预测强度
- **任务3**：分子特征预测（辅助弱监督）：元素组成预测

### 4.4 数据规模评估

| 数据集 | 谱图数量 | 用途 |
|--------|---------|------|
| NIST23 EI（需购买） | 394,054 | 主训练集 |
| MassBank GC-EI（公开） | ~13,000 | 外部验证 |
| NEIMS/RASSP合成 | 1000万+ | 预训练扩充 |

**关键问题**：40万真实谱图 vs DreaMS 7亿，差3个数量级。但合成数据扩增到数百万+小模型是可行路径。

### 4.5 与GC-MS Benchmark的系列关系

- Benchmark为预训练模型提供评估框架
- 预训练模型为benchmark提供深度学习基线
- 两篇论文同期投稿，互相引用

### 4.6 执行时间线

| 月份 | 里程碑 |
|------|--------|
| M1-2 | NIST23数据预处理，baseline实验 |
| M3 | 小规模自监督验证（1万谱图，确认训练信号） |
| M4-6 | 全量预训练+下游迁移 |
| M7-9 | 与SpecTUS/MASSISTANT系统比较，论文写作 |

### 4.7 风险矩阵

| 风险 | 概率 | 影响 | 应对 |
|------|------|------|------|
| 数据量不足 | 中(40%) | 高 | 合成扩增到1000万，降模型参数 |
| SpecTUS占据心智 | 中(35%) | 中 | 强调表示学习vs结构预测的区别 |
| GC-MS领域太小 | 中(30%) | 中 | 强调工业/食品安全/环境监测场景 |
| 低分辨率嵌入质量差 | 低(20%) | 高 | 强度归一化+峰簇聚合预处理 |

**总体评估**：技术可行性60%，AC 7.0可达。

---

## ~~5. 方向D：嵌合谱图~~ — 永久删除（v1.2）

> **删除理由**：6篇高质量论文（含AC 2025.08）覆盖DDA/DIA/去卷积/反向搜索全部角度。MALDI空间嵌合无公开数据，MNAR-VAE集成无法区分嵌合假缺失与真缺失。无可行拯救路径。

---

## ~~6. 方向E：TDA 1D峰检测~~ — 删除（v1.2）；2D场景已吸收进Plan 2

> **删除理由（1D）**：MassCube(NC 2025)声称100%信号覆盖，CentWave调参即可。TDA在1D无竞争力。
> **2D场景（GCxGC-MS）**：GC-IMS持久同调(ACA 2024)已证明技术可行，MassCube未覆盖2D。作为Plan 2 benchmark的1-2周POC保留，不独立推进。

---

## 5. 方向C：Ensemble/场景自适应加权（AC 7.0-7.5，组合C+系列第二篇）

### 7.1 定位

从Plan 2 benchmark数据中提取引擎特性知识库→场景自适应权重→ensemble特征表。

### 7.2 前置依赖

- Plan 2 benchmark Phase 1完成（有5引擎×4数据集的完整结果）
- 需要独立的生物学验证数据（证明ensemble比最佳单引擎更准确）

### 7.3 执行建议

在Plan 2投稿后启动（~M14），利用benchmark数据作为先验，6个月完成。

### 7.4 方法论要点

- 特征级投票（majority voting）→ 加权投票（引擎在该特征类型上的历史准确率）
- 场景检测：根据数据特征（代谢物类型、仪器、色谱条件）自动选择引擎权重
- 目标：在benchmark留出测试集上超越最佳单引擎

---

## 6. 压力测试结果汇总（v1.2更新）

| 方向 | 通过的假设 | 未通过的假设 | 最终处置 |
|------|-----------|-------------|---------|
| Y1 SC通量 | 代谢物直接测量理论优于转录组 | tFBA需绝对浓度；73代谢物覆盖率不足 | **保留**：降级为通量方向约束 |
| GC-MS预训练 | 领域空白真实；SpecTUS差异化成立 | 40万谱图可能不足 | **保留**：合成扩增+小模型 |
| Ensemble | 叙事逻辑清晰 | 依赖benchmark完成 | **保留**：M14后启动 |
| Y2 归因 | HMDB标注可用 | UK Biobank不适合；Zeno MRMHR绕过 | **降级**→Plan 1 Discussion段落 |
| 嵌合谱图 | — | 6篇论文饱和 | **永久删除** |
| MSI端元 | — | 3个致命问题不可解 | **永久删除** |
| TDA 1D | — | MassCube压缩空间 | **删除**；2D→Plan 2 POC |
| B8 ISF-MNAR | ISF污染MNAR存在 | 影响量仅3-7% | **降级**→Plan 1 实验章节 |

---

## 7. 整体优先级排序与资源分配（v1.2清理后）

### 排序

| 优先级 | 方向 | 理由 |
|--------|------|------|
| **1** | Y1 SC通量约束 | 科学价值最高，POC成功后可冲NatMethods |
| **2** | GC-MS自监督预训练 | 空白最真实，与Plan 2协同 |
| **3** | Ensemble加权 | 依赖Plan 2完成，M14后启动 |

### 时间线总览

```
月份:    1   2   3   4   5   6   7   8   9  10  11  12  13  14+
Y1通量:      [预研究评估][POC实验...    ][Go/No-Go][论文]
GC-MS:  [数据准备][小实验][全量预训练  ][比较分析][写作][投稿]
Ensemble:                                              [启动→M20]
```

### 方向间依赖关系

```
Plan 2 (benchmark) ──→ Ensemble加权（系列第二篇）
Plan 2 (benchmark) ──→ GC-MS预训练（互引+评估框架）
Plan 4 (ISF-GNN)   ──→ Plan 1 B8实验章节（ISF标记输出）
```

---

## 论文产出规划（v1.2）

| 论文 | 目标期刊 | 预计投稿 | 评分 | 前置条件 |
|------|----------|----------|------|---------|
| SC通量约束 | Analytical Chemistry / NatMethods条件 | M9（如POC通过） | 7.0-7.5 → POC后8.5-9.0 | M6 Go/No-Go |
| GC-MS自监督预训练 | Analytical Chemistry | M9 | 7.0-7.5 | NIST23数据获取 |
| Ensemble场景自适应 | AC → NC条件 | M20 | 7.0-7.5 → 8.0 | Plan 2完成 |

---

## 核心参考文献

- HT SpaceM (Cell 2025)
- DreaMS (Nature Biotechnology 2025)
- SpecTUS (arXiv 2502.05114, 2025)
- MASSISTANT (ChemRxiv 2025)
- METAFlux (Nature Communications 2023)
- MetroSCREEN (Genome Medicine 2025)
- scFEA (PubMed 2021)
- tFBA (BMC Systems Biology 2007)
- HMDB 5.0 (Nucleic Acids Research 2022)
- Zimmermann-Kogadeeva (bioRxiv 2022)
- UK Biobank NMR Atlas (Nature Communications 2023)
- DecoID (Nature Methods 2021)
- DNMS2Purifier (Analytical Chemistry 2023)
- Reverse Spectral Search Reimagined (AC 2025.08)
- Compass (Cell Systems 2021) — FBA+惩罚函数，Stanford
- GC-IMS Persistent Homology Peak Detection (Analytica Chimica Acta 2024)
- Hybrid DL EI-MS Prediction (IJMS 2025) — GNN编码器+ResNet解码器
- DeepEI (Analytical Chemistry 2021) — EI谱→分子指纹
- Zeno MRMHR (AC 2025) — 单次进样同时检测210种外源物+非靶向

---

## v1.1 更新：第二轮调研补充发现

### 评分修正（基于两轮独立调研交叉验证）

| 方向 | v1.0评分 | v1.1修正 | 修正理由 |
|------|---------|---------|---------|
| Y1 SC通量 | 7.0-7.5 | **7.0-7.5 → POC后8.5-9.0** | 新增Compass/scFBA竞争者但全部基于转录组；POC通过后可冲NatMethods |
| Y2 环境归因 | 7.0-7.5 | **↓降至6.0** | UK Biobank NMR 251代谢物几乎不含外源物，核心验证路径失效；Zeno MRMHR(AC 2025)实验方案已绕过计算归因 |
| GC-MS预训练 | 7.0 | **7.0 → NIST授权后7.5-8.0** | 确认DreaMS发表于Nat Biotech 2025（更高权威）；Hybrid DL EI-MS(IJMS 2025)存在但非自监督 |
| 嵌合谱图 | 6.5 | **↓降至5.5** | 6篇高质量论文（含2025.08最新），无killer case |
| TDA峰检测 | 6.5 | **1D维持6.5，2D升至7.0** | GC-IMS持久同调(ACA 2024)已做2D场景；MassCube(NC 2025)压缩1D空间 |
| Ensemble | 7.0-7.5 | **benchmark后升至8.0** | 叙事逻辑最清晰，MVFS-SHAP(2025)是特征选择不是峰检测集成，不直接竞争 |

### Y2 降级详细理由

1. **UK Biobank NMR不含外源代谢物**：251个Nightingale Health代谢物以脂蛋白亚类、氨基酸、酮体为主，外源性化合物几乎不在检测范围
2. **Zeno MRMHR (AC 2025)**：单次进样同时检测210种外源物+非靶向代谢组的实验方案已发表，绕过了计算归因的需求
3. **方向定义过宽**："外源/内源二分法"更像标注问题而非算法问题
4. **修正路径**：若坚持，需重新聚焦为"基于非靶向LC-MS/MS的外源代谢物自动鉴定与溯源"，用GNPS/MassBank数据

### TDA峰检测场景限定

**1D场景（传统LC-MS）**：MassCube(NC 2025)声称100%信号覆盖，"超越CentWave"门槛大幅提高。TDA在1D场景无竞争力。

**2D场景（GCxGC-MS/LC×LC-MS）**：
- GC-IMS持久同调(ACA 2024)已证明技术路线可行
- MassCube未覆盖2D场景
- 建议聚焦2D作为benchmark可选引擎

### Y1 SC通量升级潜力

第二轮调研新增竞争者全图：

| 工具 | 输入 | 核心差距 |
|------|------|---------|
| METAFlux (NC 2023) | scRNA-seq | 间接推断 |
| scFEA (Genome Res 2021) | scRNA-seq | GNN+因子图 |
| scFBA (PLoS CompBio 2019) | scRNA-seq | 仅针对癌症 |
| Compass (Cell Sys 2021) | scRNA-seq | 通量不可直接量化 |
| MetroSCREEN (Genome Med 2025) | scRNA-seq+细胞互作 | 仍基于转录组 |

**关键结论**：5个竞争者全部基于转录组。代谢物直接测量约束FBA的空白**完全确认**。若POC通过（r>0.6 vs METAFlux），这是整个Plan 5中最有潜力升级为NatMethods的方向。

### 修正后优先级排序（v1.2最终版）

1. **Y1 SC通量** → 立即启动POC（最高升级潜力8.5-9.0）
2. **GC-MS预训练** → 立即启动（空白确认，7.5-8.0）
3. **Ensemble加权** → benchmark后启动（8.0）
4. ~~TDA峰检测（2D限定）~~ → **已吸收进Plan 2 POC**
5. ~~Y2 归因~~ → **已降级为Plan 1 Discussion段落**
6. ~~嵌合谱图~~ → **永久删除**
7. ~~MSI端元~~ → **永久删除**
8. ~~B8 ISF-MNAR~~ → **已降级为Plan 1 实验章节**
