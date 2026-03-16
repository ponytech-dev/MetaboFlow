'use client';

import { useState, useMemo } from 'react';
import { ArrowUpDown, ArrowUp, ArrowDown, Download, Search } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import type { FeatureResult } from '@/types/analysis';

type SortKey = keyof FeatureResult;
type SortDir = 'asc' | 'desc';

const PAGE_SIZE_OPTIONS = [25, 50, 100] as const;

interface FeatureTableProps {
  features: FeatureResult[];
  analysisId: string;
}

export function FeatureTable({ features, analysisId }: FeatureTableProps) {
  const [search, setSearch] = useState('');
  const [sortKey, setSortKey] = useState<SortKey>('p_value');
  const [sortDir, setSortDir] = useState<SortDir>('asc');
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState<(typeof PAGE_SIZE_OPTIONS)[number]>(25);

  // Filter
  const filtered = useMemo(() => {
    const q = search.toLowerCase().trim();
    if (!q) return features;
    return features.filter(
      (f) =>
        f.feature_id.toLowerCase().includes(q) ||
        (f.annotation ?? '').toLowerCase().includes(q)
    );
  }, [features, search]);

  // Sort
  const sorted = useMemo(() => {
    return [...filtered].sort((a, b) => {
      const av = a[sortKey];
      const bv = b[sortKey];
      if (av == null && bv == null) return 0;
      if (av == null) return 1;
      if (bv == null) return -1;
      const cmp = av < bv ? -1 : av > bv ? 1 : 0;
      return sortDir === 'asc' ? cmp : -cmp;
    });
  }, [filtered, sortKey, sortDir]);

  // Paginate
  const totalPages = Math.max(1, Math.ceil(sorted.length / pageSize));
  const paginated = sorted.slice((page - 1) * pageSize, page * pageSize);

  function toggleSort(key: SortKey) {
    if (sortKey === key) {
      setSortDir((d) => (d === 'asc' ? 'desc' : 'asc'));
    } else {
      setSortKey(key);
      setSortDir('asc');
    }
    setPage(1);
  }

  function handleSearch(v: string) {
    setSearch(v);
    setPage(1);
  }

  function downloadCSV() {
    const header = [
      'feature_id', 'mz', 'rt', 'compound_name',
      'log2FC', 'p_value', 'adjusted_p_value',
    ].join(',');
    const rows = sorted.map((f) =>
      [
        f.feature_id,
        f.mz.toFixed(5),
        f.rt.toFixed(2),
        f.annotation ?? '',
        f.fold_change != null ? Math.log2(f.fold_change).toFixed(4) : '',
        f.p_value != null ? f.p_value.toExponential(4) : '',
        f.adjusted_p_value != null ? f.adjusted_p_value.toExponential(4) : '',
      ].join(',')
    );
    const blob = new Blob([[header, ...rows].join('\n')], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `metaboflow_features_${analysisId}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  }

  return (
    <div className="space-y-4">
      {/* Controls */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="relative w-full sm:w-72">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <input
            type="text"
            placeholder="Search feature ID or compound…"
            value={search}
            onChange={(e) => handleSearch(e.target.value)}
            className="w-full rounded-md border border-border bg-background pl-9 pr-3 py-1.5 text-sm placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring"
          />
        </div>

        <div className="flex items-center gap-3">
          <div className="flex items-center gap-1.5 text-sm text-muted-foreground">
            <span>Rows:</span>
            <select
              value={pageSize}
              onChange={(e) => {
                setPageSize(Number(e.target.value) as typeof pageSize);
                setPage(1);
              }}
              className="rounded border border-border bg-background px-2 py-1 text-sm focus:outline-none focus:ring-2 focus:ring-ring"
            >
              {PAGE_SIZE_OPTIONS.map((n) => (
                <option key={n} value={n}>{n}</option>
              ))}
            </select>
          </div>
          <Button variant="outline" size="sm" onClick={downloadCSV} className="gap-1.5">
            <Download className="h-3.5 w-3.5" />
            CSV
          </Button>
        </div>
      </div>

      {/* Table */}
      <div className="overflow-x-auto rounded-lg border border-border">
        <table className="w-full text-sm">
          <thead className="bg-muted/60">
            <tr>
              {([
                { key: 'feature_id', label: 'Feature ID' },
                { key: 'mz', label: 'm/z' },
                { key: 'rt', label: 'RT (s)' },
                { key: 'annotation', label: 'Compound' },
                { key: 'fold_change', label: 'log₂FC' },
                { key: 'p_value', label: 'p-value' },
                { key: 'adjusted_p_value', label: 'adj. p-value' },
              ] as Array<{ key: SortKey; label: string }>).map(({ key, label }) => (
                <th
                  key={key}
                  className="whitespace-nowrap px-3 py-2.5 text-left font-medium text-muted-foreground cursor-pointer select-none hover:text-foreground transition-colors"
                  onClick={() => toggleSort(key)}
                >
                  <span className="inline-flex items-center gap-1">
                    {label}
                    {sortKey === key ? (
                      sortDir === 'asc' ? (
                        <ArrowUp className="h-3.5 w-3.5" />
                      ) : (
                        <ArrowDown className="h-3.5 w-3.5" />
                      )
                    ) : (
                      <ArrowUpDown className="h-3.5 w-3.5 opacity-30" />
                    )}
                  </span>
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-border">
            {paginated.length === 0 ? (
              <tr>
                <td colSpan={7} className="px-3 py-8 text-center text-muted-foreground">
                  No features found.
                </td>
              </tr>
            ) : (
              paginated.map((f) => {
                const log2fc = f.fold_change != null ? Math.log2(f.fold_change) : null;
                const isSig =
                  f.adjusted_p_value != null &&
                  f.adjusted_p_value < 0.05 &&
                  log2fc != null &&
                  Math.abs(log2fc) > 1;
                return (
                  <tr
                    key={f.feature_id}
                    className="hover:bg-muted/40 transition-colors"
                  >
                    <td className="px-3 py-2 font-mono text-xs">{f.feature_id}</td>
                    <td className="px-3 py-2 tabular-nums">{f.mz.toFixed(4)}</td>
                    <td className="px-3 py-2 tabular-nums">{f.rt.toFixed(1)}</td>
                    <td className="px-3 py-2">
                      {f.annotation ? (
                        <span className="font-medium">{f.annotation}</span>
                      ) : (
                        <span className="text-muted-foreground/60">—</span>
                      )}
                    </td>
                    <td className={cn(
                      'px-3 py-2 tabular-nums font-medium',
                      log2fc != null && log2fc > 1 && 'text-red-600 dark:text-red-400',
                      log2fc != null && log2fc < -1 && 'text-blue-600 dark:text-blue-400',
                    )}>
                      {log2fc != null ? log2fc.toFixed(3) : '—'}
                    </td>
                    <td className="px-3 py-2 tabular-nums">
                      {f.p_value != null ? formatPVal(f.p_value) : '—'}
                    </td>
                    <td className="px-3 py-2 tabular-nums">
                      <span className={cn(
                        isSig && 'font-semibold text-orange-600 dark:text-orange-400'
                      )}>
                        {f.adjusted_p_value != null ? formatPVal(f.adjusted_p_value) : '—'}
                      </span>
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      <div className="flex items-center justify-between text-sm text-muted-foreground">
        <span>
          {sorted.length > 0
            ? `Showing ${(page - 1) * pageSize + 1}–${Math.min(page * pageSize, sorted.length)} of ${sorted.length} features`
            : 'No results'}
        </span>
        <div className="flex items-center gap-1">
          <button
            onClick={() => setPage((p) => Math.max(1, p - 1))}
            disabled={page === 1}
            className="rounded px-2 py-1 hover:bg-muted disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
          >
            ←
          </button>
          {Array.from({ length: Math.min(5, totalPages) }, (_, i) => {
            let p: number;
            if (totalPages <= 5) {
              p = i + 1;
            } else if (page <= 3) {
              p = i + 1;
            } else if (page >= totalPages - 2) {
              p = totalPages - 4 + i;
            } else {
              p = page - 2 + i;
            }
            return (
              <button
                key={p}
                onClick={() => setPage(p)}
                className={cn(
                  'rounded px-2.5 py-1 text-xs transition-colors',
                  p === page
                    ? 'bg-primary text-primary-foreground font-medium'
                    : 'hover:bg-muted'
                )}
              >
                {p}
              </button>
            );
          })}
          <button
            onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
            disabled={page === totalPages}
            className="rounded px-2 py-1 hover:bg-muted disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
          >
            →
          </button>
        </div>
      </div>
    </div>
  );
}

function formatPVal(v: number): string {
  if (v < 0.001) return v.toExponential(2);
  return v.toFixed(4);
}
