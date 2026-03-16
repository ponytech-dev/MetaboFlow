'use client';

import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Separator } from '@/components/ui/separator';
import { useAnalysisStore } from '@/stores/analysis-store';
import type { EngineType } from '@/types/analysis';
import { cn } from '@/lib/utils';

interface StepPeakProps {
  onNext: () => void;
  onBack: () => void;
}

interface EngineCard {
  id: EngineType;
  name: string;
  description: string;
  tags: string[];
  available: boolean;
}

const ENGINES: EngineCard[] = [
  {
    id: 'xcms',
    name: 'XCMS',
    description: 'R-based chromatographic peak detection. Industry standard for untargeted metabolomics.',
    tags: ['CentWave', 'obiwarp', 'R'],
    available: true,
  },
  {
    id: 'mzmine',
    name: 'MZmine 3',
    description: 'Java-based modular pipeline with modern GUI-free batch mode support.',
    tags: ['ADAP', 'Java', 'Batch'],
    available: true,
  },
  {
    id: 'pyopenms',
    name: 'pyOpenMS',
    description: 'Python bindings for OpenMS — high-performance C++ backend.',
    tags: ['Python', 'C++', 'OpenMS'],
    available: false,
  },
  {
    id: 'msdial',
    name: 'MS-DIAL',
    description: 'Data-independent MS/MS deconvolution and identification.',
    tags: ['DIA', 'MS/MS', 'Deconvolution'],
    available: false,
  },
];

const PARAM_FIELDS = [
  { key: 'ppm' as const, label: 'Mass accuracy (ppm)', min: 1, max: 50, step: 1 },
  { key: 'peakwidthMin' as const, label: 'Min peak width (s)', min: 1, max: 60, step: 1 },
  { key: 'peakwidthMax' as const, label: 'Max peak width (s)', min: 10, max: 300, step: 5 },
  { key: 'snthresh' as const, label: 'S/N threshold', min: 1, max: 100, step: 1 },
  { key: 'noise' as const, label: 'Noise level', min: 0, max: 10000, step: 100 },
];

export function StepPeak({ onNext, onBack }: StepPeakProps) {
  const {
    selectedEngine,
    setSelectedEngine,
    peakParams,
    setPeakParams,
    multiEngineMode,
    setMultiEngineMode,
  } = useAnalysisStore();

  const canProceed = selectedEngine !== null || multiEngineMode;

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-lg font-semibold">峰检测</h2>
        <p className="mt-1 text-sm text-muted-foreground">
          选择峰检测引擎并配置核心参数。
        </p>
      </div>

      {/* Engine selector */}
      <div>
        <h3 className="mb-3 text-sm font-medium">选择引擎</h3>
        <div className="grid grid-cols-2 gap-3">
          {ENGINES.map((engine) => (
            <button
              key={engine.id}
              type="button"
              disabled={!engine.available}
              onClick={() => {
                if (engine.available) setSelectedEngine(engine.id);
              }}
              className={cn(
                'relative rounded-xl border p-4 text-left transition-all focus:outline-none',
                !engine.available && 'cursor-not-allowed opacity-50',
                engine.available &&
                  selectedEngine === engine.id &&
                  'border-blue-600 bg-blue-50/50 ring-1 ring-blue-600 dark:bg-blue-950/20',
                engine.available &&
                  selectedEngine !== engine.id &&
                  'border-border hover:border-blue-400'
              )}
            >
              {!engine.available && (
                <Badge
                  variant="secondary"
                  className="absolute right-3 top-3 text-[10px]"
                >
                  Coming Soon
                </Badge>
              )}
              <p className="font-semibold text-sm">{engine.name}</p>
              <p className="mt-1 text-xs text-muted-foreground leading-relaxed">
                {engine.description}
              </p>
              <div className="mt-2 flex flex-wrap gap-1">
                {engine.tags.map((tag) => (
                  <Badge key={tag} variant="outline" className="text-[10px] px-1.5 py-0">
                    {tag}
                  </Badge>
                ))}
              </div>
            </button>
          ))}
        </div>
      </div>

      {/* Multi-engine toggle */}
      <label className="flex cursor-pointer items-center gap-3 rounded-lg border border-border p-3 hover:bg-muted/30 transition-colors">
        <div className="relative">
          <input
            type="checkbox"
            className="sr-only"
            checked={multiEngineMode}
            onChange={(e) => setMultiEngineMode(e.target.checked)}
          />
          <div
            className={cn(
              'h-5 w-9 rounded-full transition-colors',
              multiEngineMode ? 'bg-blue-600' : 'bg-muted-foreground/30'
            )}
          />
          <div
            className={cn(
              'absolute top-0.5 h-4 w-4 rounded-full bg-white shadow transition-transform',
              multiEngineMode ? 'translate-x-4' : 'translate-x-0.5'
            )}
          />
        </div>
        <div>
          <p className="text-sm font-medium">Multi-engine comparison mode</p>
          <p className="text-xs text-muted-foreground">
            同时运行多引擎并对比结果（运行时间更长）
          </p>
        </div>
      </label>

      {/* Parameters */}
      {selectedEngine && (
        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="text-sm">
              {ENGINES.find((e) => e.id === selectedEngine)?.name} 参数配置
            </CardTitle>
            <CardDescription className="text-xs">
              调整核心峰检测参数，保持默认值适合大多数 LC-MS 数据。
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-2 gap-4">
              {PARAM_FIELDS.map((field) => (
                <div key={field.key} className="space-y-1">
                  <label className="text-xs font-medium text-muted-foreground">
                    {field.label}
                  </label>
                  <div className="flex items-center gap-2">
                    <input
                      type="range"
                      min={field.min}
                      max={field.max}
                      step={field.step}
                      value={peakParams[field.key] as number}
                      onChange={(e) =>
                        setPeakParams({ [field.key]: Number(e.target.value) })
                      }
                      className="flex-1 accent-blue-600"
                    />
                    <input
                      type="number"
                      min={field.min}
                      max={field.max}
                      step={field.step}
                      value={peakParams[field.key] as number}
                      onChange={(e) =>
                        setPeakParams({ [field.key]: Number(e.target.value) })
                      }
                      className="w-16 rounded border border-border bg-background px-2 py-0.5 text-xs text-right focus:outline-none focus:ring-1 focus:ring-blue-500"
                    />
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      )}

      <Separator />

      <div className="flex justify-between">
        <Button variant="outline" onClick={onBack}>
          上一步
        </Button>
        <Button onClick={onNext} disabled={!canProceed} className="min-w-32">
          下一步
        </Button>
      </div>
    </div>
  );
}
