'use client';

import { useState, useMemo } from 'react';
import { ArrowUp, ArrowDown, ArrowUpDown } from 'lucide-react';
import { cn } from '@/lib/utils';
import type { PathwayResult } from '@/types/analysis';

type SortKey = 'pathway_name' | 'p_value' | 'fdr' | 'fold_enrichment' | 'hit_count';
type SortDir = 'asc' | 'desc';

interface PathwayTableProps {
  pathways: PathwayResult[];
}

export function PathwayTable({ pathways }: PathwayTableProps) {
  const [sortKey, setSortKey] = useState<SortKey>('p_value');
  const [sortDir, setSortDir] = useState<SortDir>('asc');

  const sorted = useMemo(() => {
    return [...pathways].sort((a, b) => {
      const av = a[sortKey];
      const bv = b[sortKey];
      const cmp = av < bv ? -1 : av > bv ? 1 : 0;
      return sortDir === 'asc' ? cmp : -cmp;
    });
  }, [pathways, sortKey, sortDir]);

  function toggleSort(key: SortKey) {
    if (sortKey === key) {
      setSortDir((d) => (d === 'asc' ? 'desc' : 'asc'));
    } else {
      setSortKey(key);
      setSortDir('asc');
    }
  }

  function SortIcon({ k }: { k: SortKey }) {
    if (sortKey !== k) return <ArrowUpDown className="h-3.5 w-3.5 opacity-30" />;
    return sortDir === 'asc' ? (
      <ArrowUp className="h-3.5 w-3.5" />
    ) : (
      <ArrowDown className="h-3.5 w-3.5" />
    );
  }

  if (pathways.length === 0) {
    return (
      <div className="flex h-32 items-center justify-center rounded-lg border border-dashed border-border text-sm text-muted-foreground">
        No pathway enrichment results available.
      </div>
    );
  }

  return (
    <div className="overflow-x-auto rounded-lg border border-border">
      <table className="w-full text-sm">
        <thead className="bg-muted/60">
          <tr>
            {(
              [
                { key: 'pathway_name' as SortKey, label: 'Pathway' },
                { key: 'p_value' as SortKey, label: 'p-value' },
                { key: 'fdr' as SortKey, label: 'FDR' },
                { key: 'fold_enrichment' as SortKey, label: 'Fold Enrichment' },
                { key: 'hit_count' as SortKey, label: 'Hits / Total' },
              ]
            ).map(({ key, label }) => (
              <th
                key={key}
                className="whitespace-nowrap px-3 py-2.5 text-left font-medium text-muted-foreground cursor-pointer select-none hover:text-foreground transition-colors"
                onClick={() => toggleSort(key)}
              >
                <span className="inline-flex items-center gap-1">
                  {label}
                  <SortIcon k={key} />
                </span>
              </th>
            ))}
            <th className="px-3 py-2.5 text-left font-medium text-muted-foreground">
              Hit Compounds
            </th>
          </tr>
        </thead>
        <tbody className="divide-y divide-border">
          {sorted.map((pw) => {
            const isSig = pw.fdr < 0.05;
            const isNominal = pw.p_value < 0.05 && pw.fdr >= 0.05;
            return (
              <tr key={pw.pathway_id} className="hover:bg-muted/40 transition-colors">
                <td className="px-3 py-2.5 font-medium">
                  <div className="flex items-center gap-2">
                    {isSig && (
                      <span className="h-1.5 w-1.5 rounded-full bg-red-500 shrink-0" />
                    )}
                    {isNominal && !isSig && (
                      <span className="h-1.5 w-1.5 rounded-full bg-yellow-500 shrink-0" />
                    )}
                    {!isSig && !isNominal && (
                      <span className="h-1.5 w-1.5 rounded-full bg-gray-300 dark:bg-gray-600 shrink-0" />
                    )}
                    <span className={cn(isSig && 'text-foreground', !isSig && 'text-foreground/80')}>
                      {pw.pathway_name}
                    </span>
                  </div>
                </td>
                <td className={cn(
                  'px-3 py-2.5 tabular-nums',
                  pw.p_value < 0.05 ? 'font-medium text-orange-600 dark:text-orange-400' : 'text-muted-foreground'
                )}>
                  {formatPVal(pw.p_value)}
                </td>
                <td className={cn(
                  'px-3 py-2.5 tabular-nums',
                  isSig ? 'font-semibold text-red-600 dark:text-red-400' : 'text-muted-foreground'
                )}>
                  {formatPVal(pw.fdr)}
                </td>
                <td className="px-3 py-2.5 tabular-nums">
                  {pw.fold_enrichment.toFixed(2)}×
                </td>
                <td className="px-3 py-2.5 tabular-nums text-muted-foreground">
                  {pw.hit_count} / {pw.total_count}
                  <span className="ml-1.5 text-xs">
                    ({((pw.hit_count / pw.total_count) * 100).toFixed(0)}%)
                  </span>
                </td>
                <td className="px-3 py-2.5 max-w-xs">
                  <div className="flex flex-wrap gap-1">
                    {(pw.hit_compounds ?? []).slice(0, 5).map((c) => (
                      <span
                        key={c}
                        className="inline-block rounded-sm bg-muted px-1.5 py-0.5 text-xs font-mono"
                      >
                        {c}
                      </span>
                    ))}
                    {(pw.hit_compounds ?? []).length > 5 && (
                      <span className="text-xs text-muted-foreground">
                        +{pw.hit_compounds.length - 5} more
                      </span>
                    )}
                  </div>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>

      {/* Legend */}
      <div className="flex items-center gap-4 border-t border-border px-3 py-2 text-xs text-muted-foreground">
        <span className="flex items-center gap-1.5">
          <span className="h-1.5 w-1.5 rounded-full bg-red-500" /> FDR &lt; 0.05
        </span>
        <span className="flex items-center gap-1.5">
          <span className="h-1.5 w-1.5 rounded-full bg-yellow-500" /> p &lt; 0.05, FDR ≥ 0.05
        </span>
        <span className="flex items-center gap-1.5">
          <span className="h-1.5 w-1.5 rounded-full bg-gray-300 dark:bg-gray-600" /> Not significant
        </span>
      </div>
    </div>
  );
}

function formatPVal(v: number): string {
  if (v < 0.001) return v.toExponential(2);
  return v.toFixed(4);
}
