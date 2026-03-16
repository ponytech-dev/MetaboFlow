'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { Plus, RefreshCw, FlaskConical, AlertCircle } from 'lucide-react';
import { Button, buttonVariants } from '@/components/ui/button';
import { listAnalyses } from '@/lib/api';
import type { AnalysisSummary } from '@/types/analysis';
import { cn } from '@/lib/utils';

export default function AnalysesPage() {
  const [analyses, setAnalyses] = useState<AnalysisSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  async function fetchList() {
    setLoading(true);
    try {
      const data = await listAnalyses();
      // Sort newest first
      setAnalyses(data.sort((a, b) => (a.created_at < b.created_at ? 1 : -1)));
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load analyses');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    fetchList();
  }, []);

  return (
    <div className="mx-auto max-w-5xl px-6 py-8 space-y-6">
      {/* Page header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-semibold">Analyses</h1>
          <p className="mt-0.5 text-sm text-muted-foreground">
            All your metabolomics analysis runs.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button
            variant="outline"
            size="sm"
            onClick={fetchList}
            disabled={loading}
            className="gap-1.5"
          >
            <RefreshCw className={cn('h-3.5 w-3.5', loading && 'animate-spin')} />
            Refresh
          </Button>
          <Link
            href="/analysis/new"
            className={cn(buttonVariants({ size: 'sm' }), 'gap-1.5')}
          >
            <Plus className="h-3.5 w-3.5" />
            New Analysis
          </Link>
        </div>
      </div>

      {/* Error */}
      {error && (
        <div className="flex items-start gap-3 rounded-lg border border-destructive/30 bg-destructive/5 px-4 py-3 text-sm text-destructive">
          <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
          <p>{error}</p>
        </div>
      )}

      {/* Loading skeleton */}
      {loading && !error && (
        <div className="space-y-3">
          {[1, 2, 3].map((i) => (
            <div
              key={i}
              className="h-[88px] rounded-xl border border-border bg-card animate-pulse"
            />
          ))}
        </div>
      )}

      {/* Empty state */}
      {!loading && !error && analyses.length === 0 && (
        <div className="flex flex-col items-center justify-center gap-4 rounded-xl border border-dashed border-border py-20 text-center">
          <FlaskConical className="h-12 w-12 text-muted-foreground/30" />
          <div>
            <p className="font-medium">No analyses yet</p>
            <p className="mt-1 text-sm text-muted-foreground">
              Start your first metabolomics analysis to see results here.
            </p>
          </div>
          <Link
            href="/analysis/new"
            className={cn(buttonVariants(), 'gap-1.5')}
          >
            <Plus className="h-4 w-4" />
            New Analysis
          </Link>
        </div>
      )}

      {/* Analysis cards */}
      {!loading && analyses.length > 0 && (
        <div className="space-y-3">
          {analyses.map((a) => (
            <Link
              key={a.id}
              href={`/analysis/${a.id}`}
              className="block rounded-xl border border-border bg-card px-5 py-4 transition-shadow hover:shadow-md hover:border-border/80 group"
            >
              <div className="flex items-start justify-between gap-4">
                <div className="min-w-0 space-y-1">
                  <div className="flex items-center gap-2">
                    <span className="font-mono text-xs text-muted-foreground truncate max-w-[200px] sm:max-w-xs">
                      {a.id}
                    </span>
                    {a.name && (
                      <span className="font-medium text-sm truncate">{a.name}</span>
                    )}
                  </div>
                  <div className="flex flex-wrap items-center gap-3 text-xs text-muted-foreground">
                    {a.engine && (
                      <span className="inline-flex items-center gap-1">
                        <span className="h-1.5 w-1.5 rounded-full bg-blue-500" />
                        {a.engine}
                      </span>
                    )}
                    {a.n_samples > 0 && (
                      <span>{a.n_samples} samples</span>
                    )}
                    {a.n_features > 0 && (
                      <span>{a.n_features.toLocaleString()} features</span>
                    )}
                    <span>{formatDate(a.created_at)}</span>
                  </div>
                </div>

                <div className="flex items-center gap-3 shrink-0">
                  <StatusPill status={a.status} />
                  <span className="text-muted-foreground text-sm opacity-0 group-hover:opacity-100 transition-opacity">
                    →
                  </span>
                </div>
              </div>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}

function StatusPill({ status }: { status: string }) {
  const map: Record<string, { label: string; cls: string; dot?: boolean }> = {
    pending: {
      label: 'Pending',
      cls: 'bg-yellow-100 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-400',
    },
    running: {
      label: 'Running',
      cls: 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400',
      dot: true,
    },
    completed: {
      label: 'Completed',
      cls: 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400',
    },
    failed: {
      label: 'Failed',
      cls: 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400',
    },
  };
  const { label, cls, dot } = map[status] ?? { label: status, cls: '' };
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-xs font-medium',
        cls
      )}
    >
      {dot && <span className="h-1.5 w-1.5 rounded-full bg-current animate-pulse" />}
      {label}
    </span>
  );
}

function formatDate(iso: string): string {
  try {
    return new Date(iso).toLocaleString(undefined, {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  } catch {
    return iso;
  }
}
