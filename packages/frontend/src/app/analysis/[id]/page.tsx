'use client';

import { useEffect, useState, useCallback } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Link from 'next/link';
import {
  ArrowLeft,
  RefreshCw,
  AlertCircle,
  Clock,
  CheckCircle2,
} from 'lucide-react';
import { Button, buttonVariants } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { ProgressTracker } from '@/components/results/progress-tracker';
import { ResultsTabs } from '@/components/results/results-tabs';
import { getAnalysis, getAnalysisResult } from '@/lib/api';
import type { AnalysisStatus, AnalysisResult } from '@/types/analysis';
import { cn } from '@/lib/utils';

export default function AnalysisPage() {
  const params = useParams();
  const router = useRouter();
  const id = params.id as string;

  const [status, setStatus] = useState<AnalysisStatus | null>(null);
  const [result, setResult] = useState<AnalysisResult | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const fetchStatus = useCallback(async () => {
    try {
      const s = await getAnalysis(id);
      setStatus(s);
      setError(null);
      if (s.status === 'completed') {
        const r = await getAnalysisResult(id);
        setResult(r);
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load analysis');
    } finally {
      setLoading(false);
    }
  }, [id]);

  useEffect(() => {
    fetchStatus();
  }, [fetchStatus]);

  // Poll status while pending (before SSE kicks in)
  useEffect(() => {
    if (status?.status !== 'pending') return;
    const timer = setInterval(fetchStatus, 3000);
    return () => clearInterval(timer);
  }, [status?.status, fetchStatus]);

  const handleCompleted = useCallback(async () => {
    try {
      const [s, r] = await Promise.all([
        getAnalysis(id),
        getAnalysisResult(id),
      ]);
      setStatus(s);
      setResult(r);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load results');
    }
  }, [id]);

  const handleFailed = useCallback((msg: string) => {
    setError(msg);
    fetchStatus();
  }, [fetchStatus]);

  if (loading) {
    return (
      <div className="mx-auto max-w-4xl px-6 py-12">
        <div className="flex items-center gap-3 text-muted-foreground">
          <div className="h-5 w-5 animate-spin rounded-full border-2 border-muted-foreground border-t-transparent" />
          <span className="text-sm">Loading analysis…</span>
        </div>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-5xl px-6 py-8 space-y-6">
      {/* Back link + header */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <div className="space-y-1">
          <Link
            href="/analyses"
            className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground transition-colors"
          >
            <ArrowLeft className="h-3.5 w-3.5" />
            All analyses
          </Link>
          <h1 className="text-xl font-semibold">
            Analysis{' '}
            <span className="font-mono text-base text-muted-foreground">{id}</span>
          </h1>
          {status && (
            <div className="flex items-center gap-2 text-xs text-muted-foreground">
              <span>Created {formatDate(status.createdAt)}</span>
              <span>·</span>
              <span>Updated {formatDate(status.updatedAt)}</span>
            </div>
          )}
        </div>

        <div className="flex items-center gap-2">
          {status && <StatusBadge status={status.status} />}
          <Button
            variant="outline"
            size="sm"
            onClick={fetchStatus}
            className="gap-1.5"
          >
            <RefreshCw className="h-3.5 w-3.5" />
            Refresh
          </Button>
          <Link
            href="/analysis/new"
            className={cn(buttonVariants({ variant: 'outline', size: 'sm' }))}
          >
            New Analysis
          </Link>
        </div>
      </div>

      {/* Error banner */}
      {error && (
        <div className="flex items-start gap-3 rounded-lg border border-destructive/30 bg-destructive/5 px-4 py-3 text-sm text-destructive">
          <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
          <div>
            <p className="font-medium">Error</p>
            <p className="mt-0.5 text-xs opacity-80">{error}</p>
          </div>
        </div>
      )}

      {/* Content based on status */}
      {!status && !error && (
        <div className="rounded-lg border border-border p-8 text-center text-sm text-muted-foreground">
          Analysis not found.
        </div>
      )}

      {/* Pending */}
      {status?.status === 'pending' && (
        <div className="rounded-2xl border border-border bg-card p-8">
          <div className="flex items-center gap-3 text-muted-foreground">
            <Clock className="h-5 w-5 animate-pulse" />
            <div>
              <p className="text-sm font-medium text-foreground">Queued</p>
              <p className="text-xs">Your analysis is waiting to start. This page will update automatically.</p>
            </div>
          </div>
        </div>
      )}

      {/* Running */}
      {status?.status === 'running' && (
        <div className="rounded-2xl border border-border bg-card p-8">
          <ProgressTracker
            analysisId={id}
            onCompleted={handleCompleted}
            onFailed={handleFailed}
          />
        </div>
      )}

      {/* Failed */}
      {status?.status === 'failed' && (
        <div className="rounded-2xl border border-destructive/30 bg-card p-8">
          <div className="flex items-start gap-3">
            <AlertCircle className="mt-0.5 h-5 w-5 shrink-0 text-destructive" />
            <div className="space-y-1.5">
              <p className="font-semibold text-destructive">Analysis Failed</p>
              <p className="text-sm text-muted-foreground">
                {status.message || 'An unexpected error occurred during the analysis pipeline.'}
              </p>
              <Button
                size="sm"
                className="mt-3"
                onClick={() => router.push('/analysis/new')}
              >
                Try again
              </Button>
            </div>
          </div>
        </div>
      )}

      {/* Completed */}
      {status?.status === 'completed' && result && (
        <div className="space-y-4">
          <div className="flex items-center gap-2 text-sm text-green-600 dark:text-green-400">
            <CheckCircle2 className="h-4 w-4" />
            <span>Analysis completed successfully.</span>
          </div>
          <div className="rounded-2xl border border-border bg-card p-6">
            <ResultsTabs result={result} />
          </div>
        </div>
      )}

      {/* Completed but result still loading */}
      {status?.status === 'completed' && !result && !error && (
        <div className="flex items-center gap-3 text-sm text-muted-foreground">
          <div className="h-4 w-4 animate-spin rounded-full border-2 border-muted-foreground border-t-transparent" />
          Loading results…
        </div>
      )}
    </div>
  );
}

function StatusBadge({ status }: { status: string }) {
  const map: Record<string, { label: string; cls: string }> = {
    pending: { label: 'Pending', cls: 'bg-yellow-100 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-400' },
    running: { label: 'Running', cls: 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400' },
    completed: { label: 'Completed', cls: 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400' },
    failed: { label: 'Failed', cls: 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400' },
  };
  const { label, cls } = map[status] ?? { label: status, cls: '' };
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-xs font-medium',
        cls
      )}
    >
      {status === 'running' && (
        <span className="h-1.5 w-1.5 rounded-full bg-current animate-pulse" />
      )}
      {label}
    </span>
  );
}

function formatDate(iso: string): string {
  try {
    return new Date(iso).toLocaleString(undefined, {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  } catch {
    return iso;
  }
}
