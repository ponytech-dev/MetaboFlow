'use client';

import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Separator } from '@/components/ui/separator';
import { useAnalysisStore } from '@/stores/analysis-store';
import type { BatchCorrectionMethod } from '@/types/analysis';
import { cn } from '@/lib/utils';
import { CheckCircle2 } from 'lucide-react';

interface StepQcProps {
  onNext: () => void;
  onBack: () => void;
}

interface MethodOption {
  id: BatchCorrectionMethod;
  name: string;
  description: string;
  requiresQC: boolean;
}

const METHODS: MethodOption[] = [
  {
    id: 'SERRF',
    name: 'SERRF',
    description:
      'Systematic Error Removal using Random Forest. Uses QC samples to train a RF model for signal correction. Recommended for most experiments.',
    requiresQC: true,
  },
  {
    id: 'ComBat',
    name: 'ComBat',
    description:
      'Empirical Bayes-based batch effect removal. Works without QC samples; requires known batch labels.',
    requiresQC: false,
  },
  {
    id: 'QC-RLSC',
    name: 'QC-RLSC',
    description:
      'Quality Control-based Robust LOESS Signal Correction. Fits a LOESS curve on QC samples ordered by injection sequence.',
    requiresQC: true,
  },
];

const QC_PIPELINE_STEPS = [
  'Missing value imputation (kNN / half-minimum)',
  'RSD filtering (QC RSD < 30%)',
  'Blank subtraction',
  'Batch correction (selected method below)',
  'Post-correction QC metrics report',
];

export function StepQc({ onNext, onBack }: StepQcProps) {
  const { batchMethod, setBatchMethod } = useAnalysisStore();

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-lg font-semibold">质量控制 & 批次校正</h2>
        <p className="mt-1 text-sm text-muted-foreground">
          MetaboFlow 将自动执行 QC 流程，并应用所选批次校正方法。
        </p>
      </div>

      {/* Auto QC pipeline overview */}
      <Card className="border-blue-200 bg-blue-50/40 dark:bg-blue-950/10">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm text-blue-700 dark:text-blue-400">
            自动 QC 流程
          </CardTitle>
          <CardDescription className="text-xs">
            以下步骤将按顺序自动执行
          </CardDescription>
        </CardHeader>
        <CardContent>
          <ul className="space-y-1.5">
            {QC_PIPELINE_STEPS.map((step, i) => (
              <li key={i} className="flex items-start gap-2 text-sm">
                <CheckCircle2 className="mt-0.5 h-3.5 w-3.5 shrink-0 text-blue-500" />
                <span className="text-muted-foreground">{step}</span>
              </li>
            ))}
          </ul>
        </CardContent>
      </Card>

      {/* Batch correction method selector */}
      <div>
        <h3 className="mb-3 text-sm font-medium">批次校正方法</h3>
        <div className="space-y-2">
          {METHODS.map((method) => (
            <button
              key={method.id}
              type="button"
              onClick={() => setBatchMethod(method.id)}
              className={cn(
                'w-full rounded-xl border p-4 text-left transition-all focus:outline-none',
                batchMethod === method.id
                  ? 'border-blue-600 bg-blue-50/50 ring-1 ring-blue-600 dark:bg-blue-950/20'
                  : 'border-border hover:border-blue-400'
              )}
            >
              <div className="flex items-center justify-between">
                <span className="font-semibold text-sm">{method.name}</span>
                {method.requiresQC && (
                  <span className="rounded-full bg-amber-100 px-2 py-0.5 text-[10px] font-medium text-amber-700 dark:bg-amber-900/30 dark:text-amber-400">
                    需要 QC 样本
                  </span>
                )}
              </div>
              <p className="mt-1 text-xs text-muted-foreground leading-relaxed">
                {method.description}
              </p>
            </button>
          ))}
        </div>
      </div>

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
