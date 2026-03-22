'use client';

import { use, useEffect, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import {
  BarChart2,
  Image as ImageIcon,
  Table,
  Microscope,
  Network,
  AlertCircle,
  Download,
  RefreshCw,
  X,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
} from '@/components/ui/card';
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs';
import { Input } from '@/components/ui/input';
import {
  getResultSummary,
  getFeatures,
  getAnnotations,
  getPathways,
  getCharts,
  generateCharts,
} from '@/lib/api';
import type {
  ResultSummary,
  FeatureRow,
  AnnotationHit,
  PathwayRow,
  Chart,
} from '@/types/project';
import { cn } from '@/lib/utils';

export default function ResultsPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  use(params);
  const searchParams = useSearchParams();
  const analysisId = searchParams.get('analysisId') ?? '';

  if (!analysisId) {
    return (
      <div className="flex items-start gap-3 rounded-lg border border-destructive/30 bg-destructive/5 px-4 py-3 text-sm text-destructive">
        <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
        <p>
          No analysis ID found. Please run an analysis first from the Pipeline
          step.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-semibold">Results</h1>
        <p className="mt-0.5 text-sm text-muted-foreground font-mono text-xs">
          {analysisId}
        </p>
      </div>

      <Tabs defaultValue="overview">
        <TabsList className="w-full justify-start gap-1">
          <TabsTrigger value="overview" className="gap-1.5">
            <BarChart2 className="h-3.5 w-3.5" />
            Overview
          </TabsTrigger>
          <TabsTrigger value="charts" className="gap-1.5">
            <ImageIcon className="h-3.5 w-3.5" />
            Charts
          </TabsTrigger>
          <TabsTrigger value="features" className="gap-1.5">
            <Table className="h-3.5 w-3.5" />
            Features
          </TabsTrigger>
          <TabsTrigger value="annotation" className="gap-1.5">
            <Microscope className="h-3.5 w-3.5" />
            Annotation
          </TabsTrigger>
          <TabsTrigger value="pathway" className="gap-1.5">
            <Network className="h-3.5 w-3.5" />
            Pathway
          </TabsTrigger>
        </TabsList>

        <TabsContent value="overview" className="mt-4">
          <OverviewTab analysisId={analysisId} />
        </TabsContent>
        <TabsContent value="charts" className="mt-4">
          <ChartsTab analysisId={analysisId} />
        </TabsContent>
        <TabsContent value="features" className="mt-4">
          <FeaturesTab analysisId={analysisId} />
        </TabsContent>
        <TabsContent value="annotation" className="mt-4">
          <AnnotationTab analysisId={analysisId} />
        </TabsContent>
        <TabsContent value="pathway" className="mt-4">
          <PathwayTab analysisId={analysisId} />
        </TabsContent>
      </Tabs>
    </div>
  );
}

// ─── Overview Tab ─────────────────────────────────────────────────────────────

function OverviewTab({ analysisId }: { analysisId: string }) {
  const [summary, setSummary] = useState<ResultSummary | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    getResultSummary(analysisId)
      .then((data) => {
        setSummary(data);
        setError(null);
      })
      .catch((e) => setError(e instanceof Error ? e.message : 'Failed to load summary'))
      .finally(() => setLoading(false));
  }, [analysisId]);

  if (loading)
    return (
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {[1, 2, 3, 4].map((i) => (
          <div key={i} className="h-28 rounded-xl bg-muted animate-pulse" />
        ))}
      </div>
    );

  if (error)
    return <ErrorBanner message={error} />;

  if (!summary)
    return <PlaceholderBanner message="No summary data available yet." />;

  const stats = [
    { label: 'Total Features', value: summary.n_features.toLocaleString() },
    { label: 'Significant', value: summary.n_significant.toLocaleString() },
    { label: 'Annotated', value: summary.n_annotated.toLocaleString() },
    {
      label: 'Duration',
      value: summary.duration_ms
        ? formatDuration(summary.duration_ms)
        : '—',
    },
  ];

  return (
    <div className="space-y-6">
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {stats.map((s) => (
          <Card key={s.label}>
            <CardHeader>
              <CardDescription>{s.label}</CardDescription>
              <CardTitle className="text-2xl font-bold">{s.value}</CardTitle>
            </CardHeader>
          </Card>
        ))}
      </div>

      {Object.keys(summary.engine_versions).length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle>Engine Versions</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="flex flex-wrap gap-3">
              {Object.entries(summary.engine_versions).map(([name, ver]) => (
                <span
                  key={name}
                  className="inline-flex items-center gap-1.5 rounded-full border border-border px-3 py-1 text-xs font-mono"
                >
                  {name}
                  <span className="text-muted-foreground">{ver}</span>
                </span>
              ))}
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}

// ─── Charts Tab ───────────────────────────────────────────────────────────────

function ChartsTab({ analysisId }: { analysisId: string }) {
  const [charts, setCharts] = useState<Chart[]>([]);
  const [loading, setLoading] = useState(true);
  const [generating, setGenerating] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [expanded, setExpanded] = useState<Chart | null>(null);

  async function loadCharts() {
    setLoading(true);
    try {
      const data = await getCharts(analysisId);
      setCharts(data);
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load charts');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadCharts();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [analysisId]);

  async function handleGenerate() {
    setGenerating(true);
    try {
      await generateCharts(analysisId);
      // Poll — just reload after a delay
      setTimeout(loadCharts, 3000);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to generate charts');
    } finally {
      setGenerating(false);
    }
  }

  if (loading)
    return (
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {[1, 2, 3].map((i) => (
          <div key={i} className="h-48 rounded-xl bg-muted animate-pulse" />
        ))}
      </div>
    );

  return (
    <div className="space-y-4">
      {error && <ErrorBanner message={error} />}

      <div className="flex items-center justify-between">
        <p className="text-sm text-muted-foreground">
          {charts.length} chart{charts.length !== 1 ? 's' : ''} generated
        </p>
        <div className="flex items-center gap-2">
          <Button
            variant="outline"
            size="sm"
            onClick={loadCharts}
            disabled={loading}
            className="gap-1.5"
          >
            <RefreshCw className={cn('h-3.5 w-3.5', loading && 'animate-spin')} />
            Refresh
          </Button>
          <Button
            size="sm"
            onClick={handleGenerate}
            disabled={generating}
            className="gap-1.5"
          >
            {generating ? (
              <RefreshCw className="h-3.5 w-3.5 animate-spin" />
            ) : (
              <ImageIcon className="h-3.5 w-3.5" />
            )}
            Generate Charts
          </Button>
        </div>
      </div>

      {charts.length === 0 ? (
        <PlaceholderBanner message="No charts generated yet. Click 'Generate Charts' to create them." />
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {charts.map((chart) => (
            <Card
              key={chart.id}
              className="cursor-pointer hover:shadow-md transition-shadow"
              onClick={() => setExpanded(chart)}
            >
              <CardHeader>
                <CardTitle className="text-sm">{chart.label}</CardTitle>
              </CardHeader>
              <CardContent>
                {/* SVG thumbnail */}
                <div className="flex items-center justify-center h-32 bg-muted/50 rounded-lg overflow-hidden">
                  <img
                    src={chart.svg_url}
                    alt={chart.label}
                    className="max-h-full max-w-full object-contain"
                  />
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      {/* Chart modal */}
      {expanded && (
        <ChartModal chart={expanded} onClose={() => setExpanded(null)} />
      )}
    </div>
  );
}

function ChartModal({
  chart,
  onClose,
}: {
  chart: Chart;
  onClose: () => void;
}) {
  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm"
      onClick={onClose}
    >
      <div
        className="relative max-w-3xl w-full mx-4 bg-background rounded-xl shadow-2xl p-4"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between mb-3">
          <h2 className="font-medium">{chart.label}</h2>
          <div className="flex items-center gap-2">
            <a
              href={chart.svg_url}
              download
              className="inline-flex items-center gap-1 text-xs text-muted-foreground hover:text-foreground"
            >
              <Download className="h-3.5 w-3.5" /> SVG
            </a>
            {chart.pdf_url && (
              <a
                href={chart.pdf_url}
                download
                className="inline-flex items-center gap-1 text-xs text-muted-foreground hover:text-foreground"
              >
                <Download className="h-3.5 w-3.5" /> PDF
              </a>
            )}
            {chart.png_url && (
              <a
                href={chart.png_url}
                download
                className="inline-flex items-center gap-1 text-xs text-muted-foreground hover:text-foreground"
              >
                <Download className="h-3.5 w-3.5" /> PNG
              </a>
            )}
            <button
              onClick={onClose}
              className="rounded p-1 hover:bg-muted ml-2"
            >
              <X className="h-4 w-4" />
            </button>
          </div>
        </div>
        <div className="flex items-center justify-center bg-muted/30 rounded-lg p-4 max-h-[70vh] overflow-auto">
          <img src={chart.svg_url} alt={chart.label} className="max-w-full" />
        </div>
      </div>
    </div>
  );
}

// ─── Features Tab ─────────────────────────────────────────────────────────────

function FeaturesTab({ analysisId }: { analysisId: string }) {
  const [features, setFeatures] = useState<FeatureRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [pCutoff, setPCutoff] = useState(0.05);
  const [fcCutoff, setFcCutoff] = useState(1.5);
  const [search, setSearch] = useState('');

  useEffect(() => {
    let active = true;
    getFeatures(analysisId, { p_cutoff: pCutoff, fc_cutoff: fcCutoff })
      .then((data) => {
        if (!active) return;
        setFeatures(data);
        setLoading(false);
        setError(null);
      })
      .catch((e) => {
        if (!active) return;
        setError(e instanceof Error ? e.message : 'Failed to load features');
        setLoading(false);
      });
    return () => { active = false; };
  }, [analysisId, pCutoff, fcCutoff]);

  const filtered = features.filter(
    (f) =>
      !search ||
      f.feature_id.toLowerCase().includes(search.toLowerCase()) ||
      f.annotation?.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className="space-y-4">
      {error && <ErrorBanner message={error} />}

      {/* Filters */}
      <div className="flex flex-wrap items-center gap-4 rounded-lg border border-border bg-muted/30 px-4 py-3">
        <div className="flex items-center gap-2 text-sm">
          <label className="text-muted-foreground whitespace-nowrap">
            p-value ≤
          </label>
          <Input
            type="number"
            min={0}
            max={1}
            step={0.01}
            className="h-7 w-24 text-xs"
            value={pCutoff}
            onChange={(e) => setPCutoff(parseFloat(e.target.value))}
          />
        </div>
        <div className="flex items-center gap-2 text-sm">
          <label className="text-muted-foreground whitespace-nowrap">
            |log₂FC| ≥
          </label>
          <Input
            type="number"
            min={0}
            step={0.1}
            className="h-7 w-24 text-xs"
            value={fcCutoff}
            onChange={(e) => setFcCutoff(parseFloat(e.target.value))}
          />
        </div>
        <div className="flex items-center gap-2 ml-auto text-sm">
          <Input
            className="h-7 w-48 text-xs"
            placeholder="Search feature / compound…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
      </div>

      {loading ? (
        <div className="h-64 rounded-xl bg-muted animate-pulse" />
      ) : filtered.length === 0 ? (
        <PlaceholderBanner message="No features match the current filters." />
      ) : (
        <div className="overflow-x-auto rounded-xl border border-border">
          <table className="w-full text-sm">
            <thead className="bg-muted/50">
              <tr className="border-b border-border text-xs text-muted-foreground">
                {['Feature ID', 'm/z', 'RT (min)', 'log₂FC', 'p-value', 'adj.p', 'Annotation'].map(
                  (h) => (
                    <th
                      key={h}
                      className="px-4 py-2 text-left font-medium whitespace-nowrap"
                    >
                      {h}
                    </th>
                  )
                )}
              </tr>
            </thead>
            <tbody>
              {filtered.map((row) => (
                <tr
                  key={row.feature_id}
                  className="border-b border-border/50 last:border-0 hover:bg-muted/30"
                >
                  <td className="px-4 py-2 font-mono text-xs">
                    {row.feature_id}
                  </td>
                  <td className="px-4 py-2 tabular-nums">
                    {row.mz.toFixed(4)}
                  </td>
                  <td className="px-4 py-2 tabular-nums">
                    {row.rt.toFixed(2)}
                  </td>
                  <td
                    className={cn(
                      'px-4 py-2 tabular-nums font-medium',
                      row.log2fc !== null &&
                        row.log2fc > 0
                        ? 'text-rose-600 dark:text-rose-400'
                        : row.log2fc !== null && row.log2fc < 0
                          ? 'text-blue-600 dark:text-blue-400'
                          : ''
                    )}
                  >
                    {row.log2fc !== null ? row.log2fc.toFixed(2) : '—'}
                  </td>
                  <td className="px-4 py-2 tabular-nums">
                    {row.p_value !== null ? formatPVal(row.p_value) : '—'}
                  </td>
                  <td className="px-4 py-2 tabular-nums">
                    {row.adj_p !== null ? formatPVal(row.adj_p) : '—'}
                  </td>
                  <td className="px-4 py-2 text-xs text-muted-foreground">
                    {row.annotation ?? '—'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <div className="border-t border-border px-4 py-2 text-xs text-muted-foreground">
            {filtered.length} of {features.length} features
          </div>
        </div>
      )}
    </div>
  );
}

// ─── Annotation Tab ───────────────────────────────────────────────────────────

function AnnotationTab({ analysisId }: { analysisId: string }) {
  const [hits, setHits] = useState<AnnotationHit[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    getAnnotations(analysisId)
      .then((data) => {
        setHits(data);
        setError(null);
      })
      .catch((e) =>
        setError(e instanceof Error ? e.message : 'Failed to load annotations')
      )
      .finally(() => setLoading(false));
  }, [analysisId]);

  if (loading)
    return <div className="h-64 rounded-xl bg-muted animate-pulse" />;

  if (error) return <ErrorBanner message={error} />;

  if (hits.length === 0)
    return (
      <PlaceholderBanner message="Annotation results not available yet. They will appear here after the annotation step completes." />
    );

  return (
    <div className="overflow-x-auto rounded-xl border border-border">
      <table className="w-full text-sm">
        <thead className="bg-muted/50">
          <tr className="border-b border-border text-xs text-muted-foreground">
            {['Feature ID', 'Compound', 'SMILES', 'Score', 'MSI Level', 'Library'].map(
              (h) => (
                <th
                  key={h}
                  className="px-4 py-2 text-left font-medium whitespace-nowrap"
                >
                  {h}
                </th>
              )
            )}
          </tr>
        </thead>
        <tbody>
          {hits.map((hit, idx) => (
            <tr
              key={`${hit.feature_id}-${idx}`}
              className="border-b border-border/50 last:border-0 hover:bg-muted/30"
            >
              <td className="px-4 py-2 font-mono text-xs">{hit.feature_id}</td>
              <td className="px-4 py-2 font-medium">{hit.compound_name}</td>
              <td className="px-4 py-2 font-mono text-xs text-muted-foreground truncate max-w-[120px]">
                {hit.smiles ?? '—'}
              </td>
              <td className="px-4 py-2 tabular-nums">
                {hit.match_score.toFixed(3)}
              </td>
              <td className="px-4 py-2">
                <MSIBadge level={hit.msi_level} />
              </td>
              <td className="px-4 py-2 text-xs text-muted-foreground">
                {hit.source_library}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function MSIBadge({ level }: { level: number }) {
  const colorMap: Record<number, string> = {
    1: 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400',
    2: 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400',
    3: 'bg-yellow-100 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-400',
    4: 'bg-gray-100 text-gray-600 dark:bg-gray-800/50 dark:text-gray-400',
  };
  return (
    <span
      className={cn(
        'inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium',
        colorMap[level] ?? 'bg-muted text-muted-foreground'
      )}
    >
      MSI {level}
    </span>
  );
}

// ─── Pathway Tab ──────────────────────────────────────────────────────────────

function PathwayTab({ analysisId }: { analysisId: string }) {
  const [rows, setRows] = useState<PathwayRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    getPathways(analysisId)
      .then((data) => {
        setRows(data);
        setError(null);
      })
      .catch((e) =>
        setError(e instanceof Error ? e.message : 'Failed to load pathways')
      )
      .finally(() => setLoading(false));
  }, [analysisId]);

  if (loading)
    return <div className="h-64 rounded-xl bg-muted animate-pulse" />;

  if (error) return <ErrorBanner message={error} />;

  if (rows.length === 0)
    return (
      <PlaceholderBanner message="Pathway results not available yet. They will appear here after the pathway analysis step completes." />
    );

  return (
    <div className="overflow-x-auto rounded-xl border border-border">
      <table className="w-full text-sm">
        <thead className="bg-muted/50">
          <tr className="border-b border-border text-xs text-muted-foreground">
            {['Pathway', 'p-value', 'Hits', 'Pathway Size'].map((h) => (
              <th
                key={h}
                className="px-4 py-2 text-left font-medium whitespace-nowrap"
              >
                {h}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows
            .sort((a, b) => a.p_value - b.p_value)
            .map((row) => (
              <tr
                key={row.pathway_id}
                className="border-b border-border/50 last:border-0 hover:bg-muted/30"
              >
                <td className="px-4 py-2 font-medium">{row.pathway_name}</td>
                <td className="px-4 py-2 tabular-nums">
                  {formatPVal(row.p_value)}
                </td>
                <td className="px-4 py-2 tabular-nums">{row.n_hits}</td>
                <td className="px-4 py-2 tabular-nums">{row.n_pathway}</td>
              </tr>
            ))}
        </tbody>
      </table>
    </div>
  );
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

function ErrorBanner({ message }: { message: string }) {
  return (
    <div className="flex items-start gap-3 rounded-lg border border-destructive/30 bg-destructive/5 px-4 py-3 text-sm text-destructive">
      <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
      <p>{message}</p>
    </div>
  );
}

function PlaceholderBanner({ message }: { message: string }) {
  return (
    <div className="flex items-center justify-center rounded-xl border border-dashed border-border py-16 text-center">
      <p className="text-sm text-muted-foreground max-w-sm">{message}</p>
    </div>
  );
}

function formatPVal(v: number): string {
  if (v < 0.001) return v.toExponential(2);
  return v.toFixed(4);
}

function formatDuration(ms: number): string {
  const s = Math.floor(ms / 1000);
  const m = Math.floor(s / 60);
  if (m > 0) return `${m}m ${s % 60}s`;
  return `${s}s`;
}
