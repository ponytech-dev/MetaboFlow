'use client';

import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Separator } from '@/components/ui/separator';
import { useAnalysisStore } from '@/stores/analysis-store';
import { cn } from '@/lib/utils';

interface StepAnnotationProps {
  onNext: () => void;
  onBack: () => void;
}

interface DatabaseOption {
  id: string;
  name: string;
  description: string;
  compounds: string;
  available: boolean;
}

const DATABASES: DatabaseOption[] = [
  {
    id: 'HMDB',
    name: 'HMDB',
    description: 'Human Metabolome Database — gold standard for human metabolites.',
    compounds: '220,000+',
    available: true,
  },
  {
    id: 'MoNA',
    name: 'MoNA',
    description: 'MassBank of North America — community-contributed MS/MS spectra.',
    compounds: '1M+ spectra',
    available: true,
  },
  {
    id: 'MassBank',
    name: 'MassBank',
    description: 'European MassBank — high-quality reference spectra.',
    compounds: '80,000+',
    available: true,
  },
  {
    id: 'LipidBlast',
    name: 'LipidBlast',
    description: 'In silico MS/MS lipid spectral library — comprehensive lipidome coverage.',
    compounds: '400,000+',
    available: true,
  },
];

const SIRIUS_TOOLS = [
  {
    id: 'SIRIUS',
    name: 'SIRIUS',
    description: 'Molecular formula prediction from MS/MS fragmentation trees.',
  },
  {
    id: 'DreaMS',
    name: 'DreaMS',
    description: 'Deep learning-based spectral embedding for annotation.',
  },
];

export function StepAnnotation({ onNext, onBack }: StepAnnotationProps) {
  const { databases, toggleDatabase, ms1Ppm, setMs1Ppm } = useAnalysisStore();

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-lg font-semibold">代谢物注释</h2>
        <p className="mt-1 text-sm text-muted-foreground">
          选择参考数据库并配置 MS1 质量精度。
        </p>
      </div>

      {/* Database selector */}
      <div>
        <h3 className="mb-3 text-sm font-medium">参考数据库</h3>
        <div className="grid grid-cols-2 gap-3">
          {DATABASES.map((db) => {
            const selected = databases.includes(db.id);
            return (
              <button
                key={db.id}
                type="button"
                onClick={() => toggleDatabase(db.id)}
                className={cn(
                  'relative rounded-xl border p-4 text-left transition-all focus:outline-none',
                  selected
                    ? 'border-blue-600 bg-blue-50/50 ring-1 ring-blue-600 dark:bg-blue-950/20'
                    : 'border-border hover:border-blue-400'
                )}
              >
                {/* Checkbox indicator */}
                <div
                  className={cn(
                    'absolute right-3 top-3 h-4 w-4 rounded border-2 flex items-center justify-center',
                    selected
                      ? 'border-blue-600 bg-blue-600'
                      : 'border-muted-foreground/30'
                  )}
                >
                  {selected && (
                    <svg
                      className="h-2.5 w-2.5 text-white"
                      viewBox="0 0 10 8"
                      fill="none"
                    >
                      <path
                        d="M1 4l3 3 5-6"
                        stroke="currentColor"
                        strokeWidth="1.5"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                      />
                    </svg>
                  )}
                </div>
                <p className="pr-6 font-semibold text-sm">{db.name}</p>
                <p className="mt-0.5 text-[11px] text-muted-foreground">
                  {db.compounds}
                </p>
                <p className="mt-1 text-xs text-muted-foreground leading-relaxed">
                  {db.description}
                </p>
              </button>
            );
          })}
        </div>
      </div>

      {/* MS1 ppm tolerance */}
      <Card>
        <CardHeader className="pb-3">
          <CardTitle className="text-sm">MS1 质量精度</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2">
          <div className="flex items-center justify-between">
            <label className="text-xs text-muted-foreground">
              Precursor m/z tolerance (ppm)
            </label>
            <span className="text-sm font-semibold tabular-nums">
              {ms1Ppm} ppm
            </span>
          </div>
          <input
            type="range"
            min={1}
            max={50}
            step={1}
            value={ms1Ppm}
            onChange={(e) => setMs1Ppm(Number(e.target.value))}
            className="w-full accent-blue-600"
          />
          <div className="flex justify-between text-[10px] text-muted-foreground">
            <span>1 ppm (高分辨)</span>
            <span>50 ppm (低分辨)</span>
          </div>
        </CardContent>
      </Card>

      {/* Advanced tools (coming soon) */}
      <div>
        <h3 className="mb-3 flex items-center gap-2 text-sm font-medium">
          高级注释工具
          <Badge variant="secondary" className="text-[10px]">Coming Soon</Badge>
        </h3>
        <div className="grid grid-cols-2 gap-3 opacity-50">
          {SIRIUS_TOOLS.map((tool) => (
            <div
              key={tool.id}
              className="cursor-not-allowed rounded-xl border border-border p-4"
            >
              <p className="font-semibold text-sm">{tool.name}</p>
              <p className="mt-1 text-xs text-muted-foreground leading-relaxed">
                {tool.description}
              </p>
            </div>
          ))}
        </div>
      </div>

      <Separator />

      <div className="flex justify-between">
        <Button variant="outline" onClick={onBack}>
          上一步
        </Button>
        <Button onClick={onNext} disabled={databases.length === 0} className="min-w-32">
          下一步
        </Button>
      </div>
    </div>
  );
}
