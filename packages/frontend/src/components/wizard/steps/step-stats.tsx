'use client';

import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Separator } from '@/components/ui/separator';
import { useAnalysisStore } from '@/stores/analysis-store';
import type { StatAnalysisType } from '@/types/analysis';
import { cn } from '@/lib/utils';
import { BarChart2, Layers, TrendingUp } from 'lucide-react';

interface StepStatsProps {
  onNext: () => void;
  onBack: () => void;
}

interface AnalysisTypeOption {
  id: StatAnalysisType;
  name: string;
  description: string;
  icon: React.ReactNode;
}

const ANALYSIS_TYPES: AnalysisTypeOption[] = [
  {
    id: 'PCA',
    name: 'PCA',
    description: 'Principal Component Analysis — unsupervised overview of sample clustering and outlier detection.',
    icon: <Layers className="h-5 w-5" />,
  },
  {
    id: 'PLS-DA',
    name: 'PLS-DA',
    description: 'Partial Least Squares Discriminant Analysis — supervised classification with VIP score ranking.',
    icon: <TrendingUp className="h-5 w-5" />,
  },
  {
    id: 'Differential',
    name: '差异分析',
    description: 'Fold change + t-test / Wilcoxon between two groups. Volcano plot output.',
    icon: <BarChart2 className="h-5 w-5" />,
  },
];

export function StepStats({ onNext, onBack }: StepStatsProps) {
  const {
    analysisType,
    setAnalysisType,
    fcCutoff,
    setFcCutoff,
    pValueCutoff,
    setPValueCutoff,
  } = useAnalysisStore();

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-lg font-semibold">统计分析</h2>
        <p className="mt-1 text-sm text-muted-foreground">
          选择统计分析类型并设置筛选阈值。
        </p>
      </div>

      {/* Analysis type selector */}
      <div>
        <h3 className="mb-3 text-sm font-medium">分析类型</h3>
        <div className="grid grid-cols-3 gap-3">
          {ANALYSIS_TYPES.map((type) => (
            <button
              key={type.id}
              type="button"
              onClick={() => setAnalysisType(type.id)}
              className={cn(
                'rounded-xl border p-4 text-left transition-all focus:outline-none',
                analysisType === type.id
                  ? 'border-blue-600 bg-blue-50/50 ring-1 ring-blue-600 dark:bg-blue-950/20'
                  : 'border-border hover:border-blue-400'
              )}
            >
              <div
                className={cn(
                  'mb-2 flex h-9 w-9 items-center justify-center rounded-lg',
                  analysisType === type.id
                    ? 'bg-blue-600 text-white'
                    : 'bg-muted text-muted-foreground'
                )}
              >
                {type.icon}
              </div>
              <p className="font-semibold text-sm">{type.name}</p>
              <p className="mt-1 text-xs text-muted-foreground leading-relaxed">
                {type.description}
              </p>
            </button>
          ))}
        </div>
      </div>

      {/* Thresholds */}
      <Card>
        <CardHeader className="pb-3">
          <CardTitle className="text-sm">筛选阈值</CardTitle>
        </CardHeader>
        <CardContent className="space-y-5">
          {/* FC cutoff */}
          <div className="space-y-1.5">
            <div className="flex items-center justify-between">
              <label className="text-xs font-medium text-muted-foreground">
                Fold Change cutoff
              </label>
              <span className="text-xs font-semibold tabular-nums">
                ±{fcCutoff.toFixed(1)}
              </span>
            </div>
            <input
              type="range"
              min={1.0}
              max={10.0}
              step={0.5}
              value={fcCutoff}
              onChange={(e) => setFcCutoff(Number(e.target.value))}
              className="w-full accent-blue-600"
            />
            <div className="flex justify-between text-[10px] text-muted-foreground">
              <span>1.0×</span>
              <span>10.0×</span>
            </div>
          </div>

          {/* p-value cutoff */}
          <div className="space-y-1.5">
            <div className="flex items-center justify-between">
              <label className="text-xs font-medium text-muted-foreground">
                Adjusted p-value cutoff (FDR)
              </label>
              <span className="text-xs font-semibold tabular-nums">
                {pValueCutoff}
              </span>
            </div>
            <div className="flex gap-2">
              {[0.001, 0.01, 0.05, 0.1].map((p) => (
                <button
                  key={p}
                  type="button"
                  onClick={() => setPValueCutoff(p)}
                  className={cn(
                    'flex-1 rounded-md border py-1.5 text-xs font-medium transition-colors',
                    pValueCutoff === p
                      ? 'border-blue-600 bg-blue-600 text-white'
                      : 'border-border hover:border-blue-400'
                  )}
                >
                  {p}
                </button>
              ))}
            </div>
          </div>
        </CardContent>
      </Card>

      <Separator />

      <div className="flex justify-between">
        <Button variant="outline" onClick={onBack}>
          上一步
        </Button>
        <Button onClick={onNext} className="min-w-32">
          下一步
        </Button>
      </div>
    </div>
  );
}
