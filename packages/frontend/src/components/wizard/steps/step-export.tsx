'use client';

import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Separator } from '@/components/ui/separator';
import { useAnalysisStore } from '@/stores/analysis-store';
import type { ExportFormat } from '@/types/analysis';
import { cn } from '@/lib/utils';
import {
  BarChart2,
  TrendingUp,
  Grid3X3,
  Box,
  GitBranch,
  FileText,
  Rocket,
} from 'lucide-react';

interface StepExportProps {
  onBack: () => void;
  onSubmit?: () => void;
}

interface ChartOption {
  id: string;
  name: string;
  description: string;
  icon: React.ReactNode;
}

const CHART_OPTIONS: ChartOption[] = [
  {
    id: 'Volcano',
    name: 'Volcano Plot',
    description: 'FC vs -log10(p) scatter plot for differential metabolites.',
    icon: <TrendingUp className="h-4 w-4" />,
  },
  {
    id: 'PCA',
    name: 'PCA Biplot',
    description: 'Score + loading plot from principal component analysis.',
    icon: <GitBranch className="h-4 w-4" />,
  },
  {
    id: 'Heatmap',
    name: 'Heatmap',
    description: 'Clustered heatmap of top differential metabolites.',
    icon: <Grid3X3 className="h-4 w-4" />,
  },
  {
    id: 'Boxplot',
    name: 'Boxplot',
    description: 'Per-metabolite group comparison box plots.',
    icon: <Box className="h-4 w-4" />,
  },
  {
    id: 'Pathway',
    name: 'Pathway Bubble',
    description: 'Bubble chart summarizing enriched pathways.',
    icon: <BarChart2 className="h-4 w-4" />,
  },
];

const FORMAT_OPTIONS: ExportFormat[] = ['PDF', 'SVG', 'PNG'];

export function StepExport({ onBack, onSubmit }: StepExportProps) {
  const {
    chartTypes,
    toggleChartType,
    exportFormat,
    setExportFormat,
  } = useAnalysisStore();

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-lg font-semibold">图表 & 报告导出</h2>
        <p className="mt-1 text-sm text-muted-foreground">
          选择输出图表类型和导出格式。
        </p>
      </div>

      {/* Chart type selector */}
      <div>
        <h3 className="mb-3 text-sm font-medium">输出图表</h3>
        <div className="grid grid-cols-3 gap-3 sm:grid-cols-5">
          {CHART_OPTIONS.map((chart) => {
            const selected = chartTypes.includes(chart.id);
            return (
              <button
                key={chart.id}
                type="button"
                onClick={() => toggleChartType(chart.id)}
                className={cn(
                  'group relative flex flex-col items-center gap-2 rounded-xl border p-4 text-center transition-all focus:outline-none',
                  selected
                    ? 'border-blue-600 bg-blue-50/50 ring-1 ring-blue-600 dark:bg-blue-950/20'
                    : 'border-border hover:border-blue-400'
                )}
              >
                <div
                  className={cn(
                    'flex h-9 w-9 items-center justify-center rounded-lg transition-colors',
                    selected
                      ? 'bg-blue-600 text-white'
                      : 'bg-muted text-muted-foreground'
                  )}
                >
                  {chart.icon}
                </div>
                <span className="text-xs font-medium leading-tight">{chart.name}</span>
                {/* Tooltip on hover */}
                <div className="absolute -top-12 left-1/2 z-10 hidden w-48 -translate-x-1/2 rounded-lg bg-popover px-3 py-2 text-[11px] text-muted-foreground shadow-md ring-1 ring-border group-hover:block">
                  {chart.description}
                </div>
              </button>
            );
          })}
        </div>
      </div>

      {/* Export format */}
      <Card>
        <CardHeader className="pb-3">
          <CardTitle className="text-sm">导出格式</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="flex gap-3">
            {FORMAT_OPTIONS.map((fmt) => (
              <button
                key={fmt}
                type="button"
                onClick={() => setExportFormat(fmt)}
                className={cn(
                  'flex-1 rounded-lg border py-3 text-sm font-medium transition-colors focus:outline-none',
                  exportFormat === fmt
                    ? 'border-blue-600 bg-blue-600 text-white'
                    : 'border-border hover:border-blue-400'
                )}
              >
                {fmt}
              </button>
            ))}
          </div>
          <p className="mt-2 text-xs text-muted-foreground">
            {exportFormat === 'PDF' && 'Multi-page PDF report with all charts and statistics tables.'}
            {exportFormat === 'SVG' && 'Vector graphics — ideal for publication-quality figures.'}
            {exportFormat === 'PNG' && 'Raster PNG at 300 DPI — suitable for presentations.'}
          </p>
        </CardContent>
      </Card>

      {/* Summary */}
      <Card className="border-green-200 bg-green-50/40 dark:bg-green-950/10">
        <CardHeader className="pb-2">
          <CardTitle className="flex items-center gap-2 text-sm text-green-700 dark:text-green-400">
            <FileText className="h-4 w-4" />
            报告内容预览
          </CardTitle>
        </CardHeader>
        <CardContent>
          <ul className="space-y-1 text-xs text-muted-foreground">
            <li>• 样本质量控制报告（RSD、PCA、缺失率）</li>
            <li>• 峰检测摘要（feature 数量、重复率）</li>
            <li>• 差异代谢物列表（含 m/z、RT、FC、p 值）</li>
            <li>• 代谢物注释结果（含数据库来源、Level）</li>
            <li>• 通路富集分析结果（bubble chart + 表格）</li>
            {chartTypes.length > 0 && (
              <li>• 图表：{chartTypes.join('、')}</li>
            )}
          </ul>
        </CardContent>
      </Card>

      <Separator />

      <div className="flex justify-between">
        <Button variant="outline" onClick={onBack}>
          上一步
        </Button>
        <Button
          onClick={onSubmit}
          disabled={chartTypes.length === 0}
          className="min-w-40 gap-2 bg-green-600 hover:bg-green-700 text-white"
        >
          <Rocket className="h-4 w-4" />
          生成报告
        </Button>
      </div>
    </div>
  );
}
