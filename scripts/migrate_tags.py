#!/usr/bin/env python3
"""
migrate_tags.py — 将 registry.csv 标签从旧 compound_class/organism 体系
迁移到新 7 维正交体系（chemical_class / application / origin / source /
confidence / instrument / polarity）。

迁移规则来源：
  ponylabASMS/docs/spectral-library-tag-system.md（迁移对照表）
  ponylabASMS/docs/metaboflow-library-audit-and-fix-request.md（4 个错误修正）
"""

import csv
import os
import re
import shutil
import sys

REGISTRY = os.path.expanduser("~/spectral_libraries/registry.csv")
BACKUP   = REGISTRY + ".bak"

# ---------------------------------------------------------------------------
# Step 1: 通用迁移规则（compound_class / organism → 新维度）
# ---------------------------------------------------------------------------

# 旧 compound_class 值 → 新标签片段（key=value 字符串）
COMPOUND_CLASS_MAP = {
    "environmental":  "application=environmental_monitoring",
    "food":           "application=food_safety",
    "drug":           "application=pharmaceutical",
    "forensic":       "application=forensic",
    "natural_product": "origin=natural",
    "metabolite":     "chemical_class=metabolite",
    "lipid":          "chemical_class=lipid",
    "glycan":         "chemical_class=glycan",
    "amino_acid_peptide": "chemical_class=amino_acid_peptide",
}

# 旧 organism 值 → 新标签片段
ORGANISM_MAP = {
    "universal":    "origin=unknown",
    "human":        "origin=human",
    "plant":        "origin=plant",
    # environmental → 两个标签，特殊处理
    "environmental": None,  # handled separately
}

# ---------------------------------------------------------------------------
# Step 2: 每行 tags 字符串解析 & 重建
# ---------------------------------------------------------------------------

def parse_tags(tag_str: str) -> dict[str, list[str]]:
    """
    将 "compound_class=drug; compound_class=natural_product; confidence=high"
    解析为 {"compound_class": ["drug","natural_product"], "confidence": ["high"]}
    """
    result: dict[str, list[str]] = {}
    for part in tag_str.split(";"):
        part = part.strip()
        if not part:
            continue
        if "=" not in part:
            continue
        key, _, val = part.partition("=")
        key = key.strip()
        val = val.strip()
        result.setdefault(key, []).append(val)
    return result


def migrate_tags(file_path: str, old_tags: str) -> str:
    """
    给定 file_path（用于子库细分）和旧 tags 字符串，返回新格式 tags 字符串。
    """
    parsed = parse_tags(old_tags)

    # 收集新标签，用 list 保持顺序，用 set 去重
    new_parts_ordered: list[str] = []
    new_parts_seen: set[str] = set()

    def add(part: str):
        if part not in new_parts_seen:
            new_parts_seen.add(part)
            new_parts_ordered.append(part)

    # --- chemical_class（来自旧 compound_class 迁移） ---
    for old_cc in parsed.get("compound_class", []):
        mapped = COMPOUND_CLASS_MAP.get(old_cc)
        if mapped is not None:
            add(mapped)
        # organism=environmental 的 application 放后面统一处理

    # --- origin（来自旧 organism 迁移） ---
    for old_org in parsed.get("organism", []):
        if old_org == "environmental":
            add("origin=unknown")
            add("application=environmental_monitoring")
        else:
            mapped = ORGANISM_MAP.get(old_org)
            if mapped:
                add(mapped)

    # --- 原有 confidence / instrument 直接保留 ---
    for v in parsed.get("confidence", []):
        add(f"confidence={v}")
    for v in parsed.get("instrument", []):
        add(f"instrument={v}")

    # --- 保留其他已经是新格式的维度（如果有） ---
    for key in ("chemical_class", "application", "origin", "source"):
        for v in parsed.get(key, []):
            add(f"{key}={v}")

    # ---------------------------------------------------------------------------
    # Step 3: 子库细分 & 4 个错误修正
    # ---------------------------------------------------------------------------

    fname = os.path.basename(file_path)  # e.g. gnps_nih-clinical1_mixed.msp

    # 错误 1：gnps_nih-clinical1_mixed — chemical_class=metabolite → application=pharmaceutical
    if fname == "gnps_nih-clinical1_mixed.msp":
        new_parts_ordered = [p for p in new_parts_ordered if p != "chemical_class=metabolite"]
        new_parts_seen.discard("chemical_class=metabolite")
        add("application=pharmaceutical")

    # 错误 2：gnps_library_mixed — confidence=high → confidence=medium
    if fname == "gnps_library_mixed.msp":
        new_parts_ordered = [
            p.replace("confidence=high", "confidence=medium")
            for p in new_parts_ordered
        ]
        if "confidence=high" in new_parts_seen:
            new_parts_seen.discard("confidence=high")
            new_parts_seen.add("confidence=medium")

    # 错误 3：msnlib_nihnp_* — 移除 application=pharmaceutical，加 origin=natural; chemical_class=natural_product
    # 同时移除 origin=unknown（由 organism=universal 误生成，被 origin=natural 替代）
    if fname.startswith("msnlib_nihnp_"):
        new_parts_ordered = [p for p in new_parts_ordered
                             if p not in ("application=pharmaceutical", "origin=unknown")]
        new_parts_seen.discard("application=pharmaceutical")
        new_parts_seen.discard("origin=unknown")
        add("origin=natural")
        add("chemical_class=natural_product")

    # 错误 4：msnlib_otavapep_* — 移除 application=pharmaceutical 和 origin=natural（肽类非天然产物），
    # 加 chemical_class=amino_acid_peptide；同时移除 origin=unknown（organism=universal 误生成）
    if fname.startswith("msnlib_otavapep_"):
        new_parts_ordered = [p for p in new_parts_ordered
                             if p not in ("application=pharmaceutical",
                                          "origin=natural",
                                          "origin=unknown")]
        new_parts_seen.discard("application=pharmaceutical")
        new_parts_seen.discard("origin=natural")
        new_parts_seen.discard("origin=unknown")
        add("chemical_class=amino_acid_peptide")

    # MSnLib mce/enam 子库细分：这些库是合成药物库，compound_class=natural_product 的原始标签有误。
    # 移除由此生成的 origin=natural 和 origin=unknown（organism=universal 冗余标签）。
    mce_enam_prefixes = (
        "msnlib_mcedrug_", "msnlib_mcebio_", "msnlib_mcescaf_",
        "msnlib_enamdisc_", "msnlib_enammol_",
    )
    if any(fname.startswith(p) for p in mce_enam_prefixes):
        new_parts_ordered = [p for p in new_parts_ordered
                             if p not in ("origin=natural", "origin=unknown")]
        new_parts_seen.discard("origin=natural")
        new_parts_seen.discard("origin=unknown")

    # nihnp/otavapep 已在上面处理

    # 去冗余：如果同时有 origin=natural 和更具体的 origin=plant/human/microbial/marine/animal，
    # 则移除 origin=natural（更具体的值已涵盖 natural 含义）
    specific_origins = {"origin=plant", "origin=human", "origin=microbial",
                        "origin=marine", "origin=animal", "origin=synthetic"}
    if "origin=natural" in new_parts_seen and new_parts_seen & specific_origins:
        new_parts_ordered = [p for p in new_parts_ordered if p != "origin=natural"]
        new_parts_seen.discard("origin=natural")

    return "; ".join(new_parts_ordered)


# ---------------------------------------------------------------------------
# Step 4: 主流程
# ---------------------------------------------------------------------------

def main():
    print(f"读取: {REGISTRY}")
    with open(REGISTRY, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        rows = list(reader)

    print(f"共 {len(rows)} 条记录")

    # 备份
    shutil.copy2(REGISTRY, BACKUP)
    print(f"备份: {BACKUP}")

    # 迁移
    migrated = []
    for row in rows:
        new_row = dict(row)
        new_row["tags"] = migrate_tags(row["file_path"], row["tags"])
        migrated.append(new_row)

    # 写入
    with open(REGISTRY, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(migrated)

    print(f"已写入: {REGISTRY}")

    # ---------------------------------------------------------------------------
    # Step 5: 验证
    # ---------------------------------------------------------------------------
    errors = []
    for row in migrated:
        tags = row["tags"]
        if "compound_class=" in tags:
            errors.append(f"  [id={row['id']}] 仍含 compound_class=: {tags}")
        if "organism=" in tags:
            errors.append(f"  [id={row['id']}] 仍含 organism=: {tags}")

    if errors:
        print("\n[FAIL] 验证失败，发现旧维度残留：")
        for e in errors:
            print(e)
        sys.exit(1)
    else:
        print("\n[PASS] 验证通过：无 compound_class= 或 organism= 残留")

    # 打印前几条预览
    print("\n--- 迁移结果预览（前10条）---")
    for row in migrated[:10]:
        print(f"  id={row['id']:>3}  {os.path.basename(row['file_path']):<40}  {row['tags']}")

    print("\n--- 4 个错误修正验证 ---")
    for row in migrated:
        fname = os.path.basename(row["file_path"])
        if fname in (
            "gnps_nih-clinical1_mixed.msp",
            "gnps_library_mixed.msp",
            "msnlib_nihnp_negative.msp",
            "msnlib_nihnp_positive.msp",
            "msnlib_otavapep_negative.msp",
            "msnlib_otavapep_positive.msp",
        ):
            print(f"  id={row['id']:>3}  {fname:<40}  {row['tags']}")


if __name__ == "__main__":
    main()
