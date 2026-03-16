'use client';

import { Check } from 'lucide-react';
import { cn } from '@/lib/utils';

const STEPS = [
  { id: 1, label: '数据导入' },
  { id: 2, label: '峰检测' },
  { id: 3, label: '质量控制' },
  { id: 4, label: '统计分析' },
  { id: 5, label: '代谢物注释' },
  { id: 6, label: '通路分析' },
  { id: 7, label: '导出报告' },
];

interface StepIndicatorProps {
  currentStep: number;
  onStepClick?: (step: number) => void;
}

export function StepIndicator({ currentStep, onStepClick }: StepIndicatorProps) {
  return (
    <nav aria-label="Progress" className="w-full">
      <ol className="flex items-center justify-between">
        {STEPS.map((step, index) => {
          const isCompleted = step.id < currentStep;
          const isCurrent = step.id === currentStep;
          const isUpcoming = step.id > currentStep;

          return (
            <li key={step.id} className="flex flex-1 items-center">
              {/* Step circle + label */}
              <button
                type="button"
                className={cn(
                  'group flex flex-col items-center gap-1.5 focus:outline-none',
                  isUpcoming ? 'cursor-default' : 'cursor-pointer'
                )}
                onClick={() => {
                  if (!isUpcoming && onStepClick) onStepClick(step.id);
                }}
                disabled={isUpcoming}
              >
                <span
                  className={cn(
                    'flex h-8 w-8 items-center justify-center rounded-full border-2 text-xs font-semibold transition-all',
                    isCompleted &&
                      'border-blue-600 bg-blue-600 text-white',
                    isCurrent &&
                      'border-blue-600 bg-blue-50 text-blue-600 dark:bg-blue-950',
                    isUpcoming &&
                      'border-border bg-background text-muted-foreground'
                  )}
                >
                  {isCompleted ? (
                    <Check className="h-4 w-4 stroke-[3]" />
                  ) : (
                    step.id
                  )}
                </span>
                <span
                  className={cn(
                    'text-[11px] font-medium leading-tight',
                    isCurrent && 'text-blue-600',
                    isCompleted && 'text-foreground',
                    isUpcoming && 'text-muted-foreground'
                  )}
                >
                  {step.label}
                </span>
              </button>

              {/* Connector line (not after last step) */}
              {index < STEPS.length - 1 && (
                <div
                  className={cn(
                    'mx-1 mb-5 h-0.5 flex-1 transition-colors',
                    isCompleted ? 'bg-blue-600' : 'bg-border'
                  )}
                />
              )}
            </li>
          );
        })}
      </ol>
    </nav>
  );
}
