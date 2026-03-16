'use client';

import { useEffect, useState } from 'react';
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs';
import { FeatureTable } from './feature-table';
import { VolcanoChart } from './volcano-chart';
import { PCAChart } from './pca-chart';
import { PathwayTable } from './pathway-table';
import { ReportViewer } from './report-viewer';
import { getVolcanoData, getPCAData } from '@/lib/api';
import type { AnalysisResult, VolcanoData, PCAData } from '@/types/analysis';
import {
  BarChart3,
  Table2,
  TrendingUp,
  Layers,
  FlaskConical,
  FileText,
} from 'lucide-react';

interface ResultsTabsProps {
  result: AnalysisResult;
}

export function ResultsTabs({ result }: ResultsTabsProps) {
  const [volcanoData, setVolcanoData] = useState<VolcanoData | null>(null);
  const [pcaData, setPcaData] = useState<PCAData | null>(null);

  // Derive volcano data from features if no dedicated endpoint data yet
  const features = result.features;
  useEffect(() => {
    getVolcanoData(result.id)
      .then(setVolcanoData)
      .catch(() => {
        // Fall back: build volcano data from feature results
        const points = features
          .filter((f) => f.fold_change != null && f.p_value != null)
          .map((f) => {
            const log2fc = Math.log2(f.fold_change!);
            const neg_log10_pval = -Math.log10(f.p_value!);
            const adjP = f.adjusted_p_value ?? f.p_value!;
            const significant: 'up' | 'down' | 'ns' =
              adjP < 0.05 && log2fc > 1
                ? 'up'
                : adjP < 0.05 && log2fc < -1
                ? 'down'
                : 'ns';
            return {
              feature_id: f.feature_id,
              compound_name: f.annotation,
              log2fc,
              neg_log10_pval,
              p_value: f.p_value!,
              adjusted_p_value: adjP,
              significant,
            };
          });
        setVolcanoData({ points, fc_cutoff: 2, pval_cutoff: 0.05 });
      });

    getPCAData(result.id)
      .then(setPcaData)
      .catch(() => {
        // No fallback for PCA — need backend data
        setPcaData(null);
      });
  }, [result.id, features]);

  // Summary statistics
  const totalFeatures = result.features.length;
  const annotated = result.features.filter((f) => f.annotation).length;
  const sigFeatures = result.features.filter(
    (f) =>
      f.adjusted_p_value != null &&
      f.adjusted_p_value < 0.05 &&
      f.fold_change != null &&
      Math.abs(Math.log2(f.fold_change)) > 1
  ).length;
  const sigPathways = result.pathwayResults.filter((p) => p.fdr < 0.05).length;

  return (
    <Tabs defaultValue="overview" className="space-y-4">
      <TabsList className="flex h-auto flex-wrap gap-0.5 w-full">
        <TabsTrigger value="overview" className="gap-1.5 text-xs sm:text-sm">
          <BarChart3 className="h-3.5 w-3.5" />
          Overview
        </TabsTrigger>
        <TabsTrigger value="features" className="gap-1.5 text-xs sm:text-sm">
          <Table2 className="h-3.5 w-3.5" />
          Features
          <span className="ml-0.5 rounded-full bg-muted px-1.5 py-0.5 text-[10px] font-mono leading-none">
            {totalFeatures}
          </span>
        </TabsTrigger>
        <TabsTrigger value="volcano" className="gap-1.5 text-xs sm:text-sm">
          <TrendingUp className="h-3.5 w-3.5" />
          Volcano
        </TabsTrigger>
        <TabsTrigger value="pca" className="gap-1.5 text-xs sm:text-sm">
          <Layers className="h-3.5 w-3.5" />
          PCA
        </TabsTrigger>
        <TabsTrigger value="pathways" className="gap-1.5 text-xs sm:text-sm">
          <FlaskConical className="h-3.5 w-3.5" />
          Pathways
          <span className="ml-0.5 rounded-full bg-muted px-1.5 py-0.5 text-[10px] font-mono leading-none">
            {result.pathwayResults.length}
          </span>
        </TabsTrigger>
        <TabsTrigger value="report" className="gap-1.5 text-xs sm:text-sm">
          <FileText className="h-3.5 w-3.5" />
          Report
        </TabsTrigger>
      </TabsList>

      {/* Overview */}
      <TabsContent value="overview" className="space-y-6">
        {/* Key metrics */}
        <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
          <MetricCard label="Total Features" value={totalFeatures.toLocaleString()} />
          <MetricCard
            label="Annotated"
            value={annotated.toLocaleString()}
            sub={`${((annotated / Math.max(totalFeatures, 1)) * 100).toFixed(0)}%`}
          />
          <MetricCard
            label="Significant"
            value={sigFeatures.toLocaleString()}
            sub="adj.p<0.05, |log₂FC|>1"
            highlight={sigFeatures > 0}
          />
          <MetricCard
            label="Enriched Pathways"
            value={sigPathways.toLocaleString()}
            sub="FDR < 0.05"
            highlight={sigPathways > 0}
          />
        </div>

        {/* QC Metrics */}
        {Object.keys(result.qcMetrics).length > 0 && (
          <div className="rounded-lg border border-border p-4">
            <h3 className="mb-3 text-sm font-semibold">QC Metrics</h3>
            <div className="grid grid-cols-2 gap-x-6 gap-y-2 sm:grid-cols-3">
              {Object.entries(result.qcMetrics).map(([k, v]) => (
                <div key={k} className="flex items-center justify-between text-sm">
                  <span className="text-muted-foreground">{k}</span>
                  <span className="font-mono font-medium">{formatMetricValue(v)}</span>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Quick preview of volcano + PCA side by side */}
        <div className="grid gap-4 lg:grid-cols-2">
          <div className="rounded-lg border border-border p-4">
            <h3 className="mb-3 text-sm font-semibold">Volcano Plot Preview</h3>
            <div className="overflow-x-auto">
              <VolcanoChart data={volcanoData} width={440} height={300} />
            </div>
          </div>
          <div className="rounded-lg border border-border p-4">
            <h3 className="mb-3 text-sm font-semibold">PCA Score Plot Preview</h3>
            <div className="overflow-x-auto">
              <PCAChart data={pcaData} width={440} height={300} />
            </div>
          </div>
        </div>
      </TabsContent>

      {/* Features table */}
      <TabsContent value="features">
        <FeatureTable features={result.features} analysisId={result.id} />
      </TabsContent>

      {/* Volcano */}
      <TabsContent value="volcano">
        <div className="space-y-4">
          <p className="text-sm text-muted-foreground">
            Hover over points to see feature details. Red = significantly up-regulated, Blue = down-regulated, Gray = not significant.
          </p>
          <div className="flex justify-center overflow-x-auto">
            <VolcanoChart data={volcanoData} width={620} height={460} />
          </div>
        </div>
      </TabsContent>

      {/* PCA */}
      <TabsContent value="pca">
        <div className="space-y-4">
          <p className="text-sm text-muted-foreground">
            PCA score plot. Each point represents a sample; colors indicate group membership.
          </p>
          <div className="flex justify-center overflow-x-auto">
            <PCAChart data={pcaData} width={620} height={460} />
          </div>
        </div>
      </TabsContent>

      {/* Pathways */}
      <TabsContent value="pathways">
        <PathwayTable pathways={result.pathwayResults} />
      </TabsContent>

      {/* Report */}
      <TabsContent value="report">
        <ReportViewer reportUrl={result.reportUrl} analysisId={result.id} />
      </TabsContent>
    </Tabs>
  );
}

function MetricCard({
  label,
  value,
  sub,
  highlight,
}: {
  label: string;
  value: string;
  sub?: string;
  highlight?: boolean;
}) {
  return (
    <div className="rounded-lg border border-border p-4">
      <p className="text-xs text-muted-foreground">{label}</p>
      <p
        className={`mt-1 text-2xl font-bold tabular-nums ${
          highlight ? 'text-blue-600 dark:text-blue-400' : ''
        }`}
      >
        {value}
      </p>
      {sub && <p className="mt-0.5 text-[11px] text-muted-foreground">{sub}</p>}
    </div>
  );
}

function formatMetricValue(v: number): string {
  if (Number.isInteger(v)) return v.toLocaleString();
  if (Math.abs(v) < 0.01) return v.toExponential(2);
  return v.toFixed(3);
}
