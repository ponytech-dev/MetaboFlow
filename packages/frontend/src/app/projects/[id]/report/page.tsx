'use client';

import { use, useEffect, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import {
  AlertCircle,
  Download,
  FileText,
  Loader2,
  CheckCircle2,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
} from '@/components/ui/card';
import { getCharts, generateReport } from '@/lib/api';
import type { Chart } from '@/types/project';
import { cn } from '@/lib/utils';

type ReportFormat = 'pdf' | 'docx' | 'both';

export default function ReportPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  use(params);
  const searchParams = useSearchParams();
  const analysisId = searchParams.get('analysisId') ?? '';

  const [charts, setCharts] = useState<Chart[]>([]);
  const [selectedCharts, setSelectedCharts] = useState<Set<string>>(new Set());
  const [format, setFormat] = useState<ReportFormat>('pdf');
  const [loading, setLoading] = useState(true);
  const [generating, setGenerating] = useState(false);
  const [jobId, setJobId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!analysisId) {
      setLoading(false);
      return;
    }
    getCharts(analysisId)
      .then((data) => {
        setCharts(data);
        setSelectedCharts(new Set(data.map((c) => c.id)));
        setError(null);
      })
      .catch(() => {
        // Charts might not exist yet — that's ok
      })
      .finally(() => setLoading(false));
  }, [analysisId]);

  function toggleChart(id: string) {
    setSelectedCharts((prev) => {
      const copy = new Set(prev);
      if (copy.has(id)) copy.delete(id);
      else copy.add(id);
      return copy;
    });
  }

  async function handleGenerate() {
    if (!analysisId) return;
    setGenerating(true);
    setError(null);
    try {
      const { job_id } = await generateReport(analysisId, {
        charts: Array.from(selectedCharts),
        format,
      });
      setJobId(job_id);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to generate report');
    } finally {
      setGenerating(false);
    }
  }

  if (!analysisId) {
    return (
      <div className="flex items-start gap-3 rounded-lg border border-destructive/30 bg-destructive/5 px-4 py-3 text-sm text-destructive">
        <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
        <p>
          No analysis ID found. Please run an analysis first.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-semibold">Report Generation</h1>
        <p className="mt-0.5 text-sm text-muted-foreground">
          Select charts to include and choose output format.
        </p>
      </div>

      {/* Error */}
      {error && (
        <div className="flex items-start gap-3 rounded-lg border border-destructive/30 bg-destructive/5 px-4 py-3 text-sm text-destructive">
          <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
          <p>{error}</p>
        </div>
      )}

      {/* Chart selection */}
      <Card>
        <CardHeader>
          <CardTitle>Charts to Include</CardTitle>
          <CardDescription>
            Select which charts to embed in the report.
          </CardDescription>
        </CardHeader>
        <CardContent>
          {loading ? (
            <div className="h-24 rounded-lg bg-muted animate-pulse" />
          ) : charts.length === 0 ? (
            <p className="text-sm text-muted-foreground">
              No charts available. Generate charts in the Results tab first.
            </p>
          ) : (
            <div className="grid gap-2 sm:grid-cols-2">
              {charts.map((chart) => (
                <label
                  key={chart.id}
                  className="flex items-center gap-3 rounded-lg border border-border px-3 py-2 cursor-pointer hover:bg-muted/50 transition-colors"
                >
                  <input
                    type="checkbox"
                    checked={selectedCharts.has(chart.id)}
                    onChange={() => toggleChart(chart.id)}
                    className="h-4 w-4 rounded border-input"
                  />
                  <span className="text-sm">{chart.label}</span>
                </label>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Format selector */}
      <Card>
        <CardHeader>
          <CardTitle>Output Format</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="flex gap-3">
            {(['pdf', 'docx', 'both'] as ReportFormat[]).map((f) => (
              <label
                key={f}
                className={cn(
                  'flex items-center gap-2 rounded-lg border px-4 py-2.5 cursor-pointer transition-colors text-sm font-medium',
                  format === f
                    ? 'border-primary bg-primary/5 text-primary'
                    : 'border-border hover:bg-muted/50'
                )}
              >
                <input
                  type="radio"
                  name="format"
                  value={f}
                  checked={format === f}
                  onChange={() => setFormat(f)}
                  className="sr-only"
                />
                <FileText className="h-4 w-4" />
                {f === 'both' ? 'PDF + Word' : f.toUpperCase()}
              </label>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* Generation status */}
      {jobId && !error && (
        <div className="flex items-start gap-3 rounded-lg border border-border bg-muted/30 px-4 py-3">
          <div className="mt-0.5">
            {generating ? (
              <Loader2 className="h-4 w-4 animate-spin text-primary" />
            ) : (
              <CheckCircle2 className="h-4 w-4 text-green-500" />
            )}
          </div>
          <div className="space-y-1">
            <p className="text-sm font-medium">
              {generating ? 'Generating report…' : 'Report job submitted'}
            </p>
            <p className="text-xs text-muted-foreground font-mono">
              Job ID: {jobId}
            </p>
            <p className="text-xs text-muted-foreground">
              Report generation runs in the background. Download links will
              appear here when ready (report-worker coming soon).
            </p>
          </div>
        </div>
      )}

      {/* Placeholder notice */}
      {!jobId && (
        <div className="rounded-lg border border-border bg-muted/20 px-4 py-3 text-xs text-muted-foreground">
          Note: The report-worker backend is not yet built. Clicking Generate will
          submit the job, but no download will be available until it is deployed.
        </div>
      )}

      {/* Generate button */}
      <div className="flex justify-end">
        <Button
          onClick={handleGenerate}
          disabled={generating || !analysisId}
          className="gap-2"
        >
          {generating ? (
            <Loader2 className="h-4 w-4 animate-spin" />
          ) : (
            <Download className="h-4 w-4" />
          )}
          {generating ? 'Generating…' : 'Generate Report'}
        </Button>
      </div>
    </div>
  );
}
