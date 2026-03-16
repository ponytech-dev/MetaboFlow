'use client';

import { useEffect, useState } from 'react';
import { CheckCircle, XCircle, Loader2, Circle, Clock } from 'lucide-react';
import { cn } from '@/lib/utils';
import { streamProgress } from '@/lib/api';
import type { PipelineStep } from '@/types/analysis';

const DEFAULT_STEPS: PipelineStep[] = [
  { name: 'import', label: 'Data Import', status: 'pending', duration_ms: null, message: null },
  { name: 'peak_detection', label: 'Peak Detection', status: 'pending', duration_ms: null, message: null },
  { name: 'alignment', label: 'Alignment & QC', status: 'pending', duration_ms: null, message: null },
  { name: 'normalization', label: 'Normalization', status: 'pending', duration_ms: null, message: null },
  { name: 'statistics', label: 'Statistical Analysis', status: 'pending', duration_ms: null, message: null },
  { name: 'annotation', label: 'Metabolite Annotation', status: 'pending', duration_ms: null, message: null },
  { name: 'report', label: 'Report Generation', status: 'pending', duration_ms: null, message: null },
];

interface ProgressTrackerProps {
  analysisId: string;
  onCompleted?: () => void;
  onFailed?: (message: string) => void;
}

export function ProgressTracker({
  analysisId,
  onCompleted,
  onFailed,
}: ProgressTrackerProps) {
  const [steps, setSteps] = useState<PipelineStep[]>(DEFAULT_STEPS);
  const [overallMessage, setOverallMessage] = useState<string>('Starting analysis…');
  const [connected, setConnected] = useState(false);

  useEffect(() => {
    const es = streamProgress(analysisId);

    es.onopen = () => setConnected(true);

    es.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data as string) as {
          steps?: PipelineStep[];
          message?: string;
          status?: string;
        };
        if (data.steps) {
          setSteps(data.steps);
        }
        if (data.message) {
          setOverallMessage(data.message);
        }
        if (data.status === 'completed') {
          es.close();
          onCompleted?.();
        }
        if (data.status === 'failed') {
          es.close();
          onFailed?.(data.message ?? 'Analysis failed');
        }
      } catch {
        // ignore parse errors
      }
    };

    es.onerror = () => {
      setConnected(false);
    };

    return () => es.close();
  }, [analysisId, onCompleted, onFailed]);

  const completedCount = steps.filter((s) => s.status === 'completed').length;
  const progressPercent = Math.round((completedCount / steps.length) * 100);

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h3 className="text-base font-semibold">Pipeline Progress</h3>
          <p className="text-sm text-muted-foreground mt-0.5">{overallMessage}</p>
        </div>
        <div className="flex items-center gap-2 text-sm text-muted-foreground">
          <div
            className={cn(
              'h-2 w-2 rounded-full',
              connected ? 'bg-green-500 animate-pulse' : 'bg-gray-400'
            )}
          />
          {connected ? 'Live' : 'Connecting…'}
        </div>
      </div>

      {/* Overall progress bar */}
      <div className="space-y-1.5">
        <div className="flex justify-between text-xs text-muted-foreground">
          <span>{completedCount} of {steps.length} steps</span>
          <span>{progressPercent}%</span>
        </div>
        <div className="h-2 w-full rounded-full bg-muted overflow-hidden">
          <div
            className="h-full rounded-full bg-blue-600 transition-all duration-500"
            style={{ width: `${progressPercent}%` }}
          />
        </div>
      </div>

      {/* Step list */}
      <ol className="space-y-3">
        {steps.map((step, idx) => (
          <li key={step.name} className="flex items-start gap-3">
            {/* Step icon */}
            <div className="mt-0.5 shrink-0">
              {step.status === 'completed' && (
                <CheckCircle className="h-5 w-5 text-green-500" />
              )}
              {step.status === 'failed' && (
                <XCircle className="h-5 w-5 text-destructive" />
              )}
              {step.status === 'running' && (
                <Loader2 className="h-5 w-5 text-blue-500 animate-spin" />
              )}
              {step.status === 'pending' && (
                <Circle className="h-5 w-5 text-muted-foreground/40" />
              )}
            </div>

            {/* Step details */}
            <div className="flex-1 min-w-0">
              <div className="flex items-center justify-between gap-2">
                <span
                  className={cn(
                    'text-sm font-medium',
                    step.status === 'completed' && 'text-foreground',
                    step.status === 'running' && 'text-blue-600 dark:text-blue-400',
                    step.status === 'failed' && 'text-destructive',
                    step.status === 'pending' && 'text-muted-foreground'
                  )}
                >
                  {idx + 1}. {step.label}
                </span>
                {step.duration_ms != null && (
                  <span className="flex items-center gap-1 text-xs text-muted-foreground shrink-0">
                    <Clock className="h-3 w-3" />
                    {formatDuration(step.duration_ms)}
                  </span>
                )}
              </div>
              {step.message && (
                <p
                  className={cn(
                    'mt-0.5 text-xs',
                    step.status === 'failed'
                      ? 'text-destructive'
                      : 'text-muted-foreground'
                  )}
                >
                  {step.message}
                </p>
              )}
              {/* Running animation bar */}
              {step.status === 'running' && (
                <div className="mt-1.5 h-0.5 w-full rounded-full bg-muted overflow-hidden">
                  <div className="h-full w-1/3 rounded-full bg-blue-500 animate-[slide_1.5s_ease-in-out_infinite]" />
                </div>
              )}
            </div>
          </li>
        ))}
      </ol>
    </div>
  );
}

function formatDuration(ms: number): string {
  if (ms < 1000) return `${ms}ms`;
  const s = ms / 1000;
  if (s < 60) return `${s.toFixed(1)}s`;
  const m = Math.floor(s / 60);
  const rem = Math.round(s % 60);
  return `${m}m ${rem}s`;
}
