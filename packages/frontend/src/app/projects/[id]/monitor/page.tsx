'use client';

import { use, useEffect, useRef, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { AlertCircle, CheckCircle2, Circle, Loader2, XCircle } from 'lucide-react';
import {
  Card,
  CardHeader,
  CardTitle,
  CardContent,
} from '@/components/ui/card';
import { Progress } from '@/components/ui/progress';
import { streamAnalysisProgress } from '@/lib/api';
import type { ProgressEvent } from '@/types/project';
import { cn } from '@/lib/utils';

export default function MonitorPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id: projectId } = use(params);
  const searchParams = useSearchParams();
  const analysisId = searchParams.get('analysisId') ?? '';
  const router = useRouter();

  const [steps, setSteps] = useState<ProgressEvent[]>([]);
  const [overallProgress, setOverallProgress] = useState(0);
  const [elapsedMs, setElapsedMs] = useState(0);
  const [finalStatus, setFinalStatus] = useState<
    'running' | 'completed' | 'failed' | null
  >('running');
  const [error, setError] = useState<string | null>(null);

  const startRef = useRef<number>(0);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // Elapsed timer
  useEffect(() => {
    startRef.current = Date.now();
    timerRef.current = setInterval(() => {
      setElapsedMs(Date.now() - startRef.current);
    }, 500);
    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
    };
  }, []);

  // SSE connection
  useEffect(() => {
    if (!analysisId) return;

    let es: EventSource;
    try {
      es = streamAnalysisProgress(analysisId);
    } catch {
      // Deferred to avoid setState-in-effect lint rule
      Promise.resolve().then(() =>
        setError('Cannot connect to analysis stream')
      );
      return;
    }

    es.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data as string) as ProgressEvent;
        setSteps((prev) => {
          const idx = prev.findIndex((s) => s.step === data.step);
          if (idx >= 0) {
            const copy = [...prev];
            copy[idx] = data;
            return copy;
          }
          return [...prev, data];
        });
        setOverallProgress(data.progress);

        if (data.status === 'completed' && data.progress >= 100) {
          setFinalStatus('completed');
          es.close();
          if (timerRef.current) clearInterval(timerRef.current);
          // Redirect after short delay
          setTimeout(() => {
            router.push(
              `/projects/${projectId}/results?analysisId=${analysisId}`
            );
          }, 2000);
        } else if (data.status === 'failed') {
          setFinalStatus('failed');
          es.close();
          if (timerRef.current) clearInterval(timerRef.current);
        }
      } catch {
        // ignore parse error
      }
    };

    es.onerror = () => {
      setError('Stream connection lost');
      es.close();
    };

    return () => {
      es.close();
    };
  }, [analysisId, projectId, router]);

  if (!analysisId) {
    return (
      <div className="flex items-start gap-3 rounded-lg border border-destructive/30 bg-destructive/5 px-4 py-3 text-sm text-destructive">
        <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
        <p>No analysis ID found. Please go back to the Pipeline step and start an analysis.</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-semibold">Real-time Monitor</h1>
        <p className="mt-0.5 text-sm text-muted-foreground">
          Analysis ID:{' '}
          <span className="font-mono text-xs">{analysisId}</span>
        </p>
      </div>

      {/* Error */}
      {error && (
        <div className="flex items-start gap-3 rounded-lg border border-destructive/30 bg-destructive/5 px-4 py-3 text-sm text-destructive">
          <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
          <p>{error}</p>
        </div>
      )}

      {/* Overall progress */}
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle>Overall Progress</CardTitle>
            <div className="flex items-center gap-3 text-sm text-muted-foreground">
              <span>{formatElapsed(elapsedMs)}</span>
              <StatusIcon status={finalStatus ?? 'running'} />
            </div>
          </div>
        </CardHeader>
        <CardContent>
          <Progress value={overallProgress} className="mb-2" />
          <p className="text-xs text-right text-muted-foreground">
            {overallProgress}%
          </p>
          {finalStatus === 'completed' && (
            <p className="mt-2 text-sm text-green-600 dark:text-green-400 font-medium">
              Analysis complete — redirecting to results…
            </p>
          )}
          {finalStatus === 'failed' && (
            <p className="mt-2 text-sm text-destructive font-medium">
              Analysis failed. Check logs for details.
            </p>
          )}
        </CardContent>
      </Card>

      {/* Step-by-step breakdown */}
      {steps.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle>Pipeline Steps</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {steps.map((step) => (
                <StepRow key={step.step} step={step} />
              ))}
            </div>
          </CardContent>
        </Card>
      )}

      {/* Waiting for first event */}
      {steps.length === 0 && !error && (
        <div className="flex items-center gap-3 text-sm text-muted-foreground">
          <Loader2 className="h-4 w-4 animate-spin" />
          <span>Waiting for pipeline to start…</span>
        </div>
      )}
    </div>
  );
}

function StepRow({ step }: { step: ProgressEvent }) {
  return (
    <div
      className={cn(
        'flex items-start gap-3 rounded-lg p-3',
        step.status === 'running' && 'bg-blue-50 dark:bg-blue-950/20',
        step.status === 'completed' && 'bg-green-50/50 dark:bg-green-950/10',
        step.status === 'failed' && 'bg-red-50 dark:bg-red-950/20'
      )}
    >
      <div className="mt-0.5 shrink-0">
        <StatusIcon status={step.status} />
      </div>
      <div className="flex-1 min-w-0 space-y-1">
        <div className="flex items-center justify-between gap-2">
          <span
            className={cn(
              'text-sm font-medium',
              step.status === 'running' && 'text-blue-700 dark:text-blue-400',
              step.status === 'completed' &&
                'text-green-700 dark:text-green-400',
              step.status === 'failed' && 'text-destructive'
            )}
          >
            {step.label || step.step}
          </span>
          {step.elapsed_ms !== null && step.elapsed_ms !== undefined && (
            <span className="text-xs text-muted-foreground shrink-0">
              {formatElapsed(step.elapsed_ms)}
            </span>
          )}
        </div>
        {step.message && (
          <p className="text-xs text-muted-foreground">{step.message}</p>
        )}
        {step.status === 'running' && (
          <Progress value={step.progress} className="mt-1" />
        )}
      </div>
    </div>
  );
}

function StatusIcon({
  status,
}: {
  status: 'pending' | 'running' | 'completed' | 'failed';
}) {
  switch (status) {
    case 'pending':
      return <Circle className="h-4 w-4 text-muted-foreground/40" />;
    case 'running':
      return <Loader2 className="h-4 w-4 animate-spin text-blue-500" />;
    case 'completed':
      return <CheckCircle2 className="h-4 w-4 text-green-500" />;
    case 'failed':
      return <XCircle className="h-4 w-4 text-destructive" />;
  }
}

function formatElapsed(ms: number): string {
  const s = Math.floor(ms / 1000);
  const m = Math.floor(s / 60);
  const h = Math.floor(m / 60);
  if (h > 0) return `${h}h ${m % 60}m`;
  if (m > 0) return `${m}m ${s % 60}s`;
  return `${s}s`;
}
