"""
Build unified Level 3 compound database from HMDB, KEGG, LipidMaps, and ChEBI.
Output: combined_compounds.csv with columns:
  name, formula, exact_mass, kegg_id, hmdb_id, chebi_id, lipidmaps_id, source
"""
import csv
import os
import gzip

BASE = os.path.expanduser("~/spectral_libraries/level3_compounds")
OUT_FILE = os.path.join(BASE, "combined", "level3_compounds.csv")

compounds = {}  # key = formula+mass -> compound record

def add_compound(name, formula, exact_mass, kegg_id="", hmdb_id="", chebi_id="", 
                 lipidmaps_id="", source=""):
    if not formula or not exact_mass:
        return
    try:
        mass = float(exact_mass)
    except (ValueError, TypeError):
        return
    if mass <= 0 or mass > 2000:
        return
    
    # Dedup key: formula + rounded mass (4 decimal places)
    key = f"{formula}_{mass:.4f}"
    
    if key in compounds:
        # Merge IDs into existing record
        rec = compounds[key]
        if kegg_id and not rec['kegg_id']:
            rec['kegg_id'] = kegg_id
        if hmdb_id and not rec['hmdb_id']:
            rec['hmdb_id'] = hmdb_id
        if chebi_id and not rec['chebi_id']:
            rec['chebi_id'] = chebi_id
        if lipidmaps_id and not rec['lipidmaps_id']:
            rec['lipidmaps_id'] = lipidmaps_id
        if not rec['name'] and name:
            rec['name'] = name
        rec['source'] += f",{source}" if source not in rec['source'] else ""
    else:
        compounds[key] = {
            'name': name,
            'formula': formula,
            'exact_mass': f"{mass:.5f}",
            'kegg_id': kegg_id,
            'hmdb_id': hmdb_id,
            'chebi_id': chebi_id,
            'lipidmaps_id': lipidmaps_id,
            'source': source
        }

# ===== 0. HMDB Compounds =====
hmdb_file = os.path.join(BASE, "hmdb", "hmdb_compounds.csv")
if os.path.exists(hmdb_file):
    with open(hmdb_file) as f:
        reader = csv.DictReader(f)
        n = 0
        for row in reader:
            if row.get('formula') and row.get('exact_mass'):
                add_compound(
                    name=row['name'], formula=row['formula'],
                    exact_mass=row['exact_mass'],
                    hmdb_id=row.get('hmdb_id', ''),
                    kegg_id=row.get('kegg_id', ''),
                    chebi_id=f"CHEBI:{row['chebi_id']}" if row.get('chebi_id') else '',
                    source="HMDB"
                )
                n += 1
    print(f"  HMDB: {n} compounds loaded")
else:
    print(f"  HMDB: file not found, skipping")

# ===== 0.5 Tox21 Compounds (EPA toxicology screening library) =====
tox21_file = os.path.join(BASE, "tox21", "tox21_compounds.csv")
if os.path.exists(tox21_file):
    with open(tox21_file) as f:
        reader = csv.DictReader(f)
        n = 0
        for row in reader:
            if row.get('formula') and row.get('exact_mass'):
                add_compound(
                    name=row.get('name', ''), formula=row['formula'],
                    exact_mass=row['exact_mass'],
                    source="Tox21"
                )
                n += 1
    print(f"  Tox21: {n} compounds loaded")
else:
    print(f"  Tox21: file not found, skipping")

# ===== 1. KEGG Compounds =====
kegg_file = os.path.join(BASE, "kegg", "kegg_compounds.csv")
if os.path.exists(kegg_file):
    with open(kegg_file) as f:
        reader = csv.DictReader(f)
        n = 0
        for row in reader:
            if row.get('formula') and row.get('exact_mass'):
                add_compound(
                    name=row['name'], formula=row['formula'],
                    exact_mass=row['exact_mass'], kegg_id=row['id'],
                    source="KEGG"
                )
                n += 1
    print(f"  KEGG: {n} compounds loaded")
else:
    print(f"  KEGG: file not found, skipping")

# ===== 2. LipidMaps =====
lm_file = os.path.join(BASE, "lipidmaps", "lipidmaps_compounds.csv")
if os.path.exists(lm_file):
    with open(lm_file) as f:
        reader = csv.DictReader(f)
        n = 0
        for row in reader:
            add_compound(
                name=row.get('NAME', ''), formula=row.get('FORMULA', ''),
                exact_mass=row.get('EXACT_MASS', ''),
                kegg_id=row.get('KEGG_ID', ''),
                hmdb_id=row.get('HMDBID', ''),
                chebi_id=row.get('CHEBI_ID', ''),
                lipidmaps_id=row.get('LM_ID', ''),
                source="LipidMaps"
            )
            n += 1
    print(f"  LipidMaps: {n} compounds loaded")

# ===== 3. ChEBI =====
chebi_dir = os.path.join(BASE, "chebi")
# Load compound names
chebi_names = {}
names_file = os.path.join(chebi_dir, "names.tsv")
if os.path.exists(names_file):
    with open(names_file) as f:
        reader = csv.DictReader(f, delimiter='\t')
        for row in reader:
            cid = row.get('compound_id', '')
            name = row.get('name', '')
            # Keep first name (usually the best one)
            if cid and name and cid not in chebi_names:
                chebi_names[cid] = name

# Load cross-references (HMDB, KEGG)
chebi_hmdb = {}
chebi_kegg = {}
acc_file = os.path.join(chebi_dir, "database_accession.tsv")
if os.path.exists(acc_file):
    with open(acc_file) as f:
        reader = csv.DictReader(f, delimiter='\t')
        for row in reader:
            cid = row.get('compound_id', '')
            acc = row.get('accession_number', '')
            if acc.startswith('HMDB'):
                chebi_hmdb[cid] = acc
            elif acc.startswith('C') and len(acc) == 6 and acc[1:].isdigit():
                chebi_kegg[cid] = acc

# Load chemical data (formula, mass)
chem_file = os.path.join(chebi_dir, "chemical_data.tsv")
if os.path.exists(chem_file):
    with open(chem_file) as f:
        reader = csv.DictReader(f, delimiter='\t')
        n = 0
        for row in reader:
            cid = row.get('compound_id', '')
            formula = row.get('formula', '')
            mass = row.get('monoisotopic_mass', '')
            if formula and mass:
                add_compound(
                    name=chebi_names.get(cid, ''),
                    formula=formula, exact_mass=mass,
                    chebi_id=f"CHEBI:{cid}",
                    hmdb_id=chebi_hmdb.get(cid, ''),
                    kegg_id=chebi_kegg.get(cid, ''),
                    source="ChEBI"
                )
                n += 1
    print(f"  ChEBI: {n} compounds loaded")

# ===== Write output =====
fields = ['name', 'formula', 'exact_mass', 'kegg_id', 'hmdb_id', 'chebi_id', 
          'lipidmaps_id', 'source']
with open(OUT_FILE, 'w', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=fields)
    writer.writeheader()
    for rec in sorted(compounds.values(), key=lambda x: float(x['exact_mass'])):
        writer.writerow(rec)

# Stats
total = len(compounds)
has_kegg = sum(1 for r in compounds.values() if r['kegg_id'])
has_hmdb = sum(1 for r in compounds.values() if r['hmdb_id'])
has_chebi = sum(1 for r in compounds.values() if r['chebi_id'])
has_lm = sum(1 for r in compounds.values() if r['lipidmaps_id'])
multi_src = sum(1 for r in compounds.values() if ',' in r['source'])

print(f"\n=== Level 3 Database Summary ===")
print(f"  Total unique compounds: {total}")
print(f"  With KEGG ID: {has_kegg}")
print(f"  With HMDB ID: {has_hmdb}")
print(f"  With ChEBI ID: {has_chebi}")
print(f"  With LipidMaps ID: {has_lm}")
print(f"  Cross-referenced (2+ sources): {multi_src}")
print(f"  Output: {OUT_FILE}")
