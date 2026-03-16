'use client';

import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Separator } from '@/components/ui/separator';
import { useAnalysisStore } from '@/stores/analysis-store';
import { cn } from '@/lib/utils';

interface StepPathwayProps {
  onNext: () => void;
  onBack: () => void;
}

interface WorkflowOption {
  id: string;
  name: string;
  fullName: string;
  description: string;
}

const WORKFLOWS: WorkflowOption[] = [
  {
    id: 'SMPDB',
    name: 'SMPDB ORA',
    fullName: 'Small Molecule Pathway Database — Over-Representation Analysis',
    description: 'Human-curated pathways from SMPDB. Best for human plasma/urine metabolomics.',
  },
  {
    id: 'MSEA',
    name: 'MSEA',
    fullName: 'Metabolite Set Enrichment Analysis',
    description: 'Quantitative enrichment analysis using metabolite concentrations.',
  },
  {
    id: 'KEGG_ORA',
    name: 'KEGG ORA',
    fullName: 'KEGG Pathway — Over-Representation Analysis',
    description: 'Fisher\'s exact test against KEGG pathway gene/compound sets.',
  },
  {
    id: 'QEA',
    name: 'QEA',
    fullName: 'Quantitative Enrichment Analysis',
    description: 'Uses all measured metabolites (not just significant) for more power.',
  },
];

const ORGANISMS = [
  'Homo sapiens',
  'Mus musculus',
  'Rattus norvegicus',
  'Arabidopsis thaliana',
  'Saccharomyces cerevisiae',
  'Escherichia coli',
];

export function StepPathway({ onNext, onBack }: StepPathwayProps) {
  const {
    pathwayWorkflows,
    togglePathwayWorkflow,
    organism,
    setOrganism,
    sigThreshold,
    setSigThreshold,
  } = useAnalysisStore();

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-lg font-semibold">通路分析</h2>
        <p className="mt-1 text-sm text-muted-foreground">
          选择通路分析工作流和物种。
        </p>
      </div>

      {/* Workflow selector */}
      <div>
        <h3 className="mb-3 text-sm font-medium">分析工作流</h3>
        <div className="grid grid-cols-2 gap-3">
          {WORKFLOWS.map((wf) => {
            const selected = pathwayWorkflows.includes(wf.id);
            return (
              <button
                key={wf.id}
                type="button"
                onClick={() => togglePathwayWorkflow(wf.id)}
                className={cn(
                  'relative rounded-xl border p-4 text-left transition-all focus:outline-none',
                  selected
                    ? 'border-blue-600 bg-blue-50/50 ring-1 ring-blue-600 dark:bg-blue-950/20'
                    : 'border-border hover:border-blue-400'
                )}
              >
                <div
                  className={cn(
                    'absolute right-3 top-3 h-4 w-4 rounded border-2 flex items-center justify-center',
                    selected ? 'border-blue-600 bg-blue-600' : 'border-muted-foreground/30'
                  )}
                >
                  {selected && (
                    <svg className="h-2.5 w-2.5 text-white" viewBox="0 0 10 8" fill="none">
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
                <p className="pr-6 font-semibold text-sm">{wf.name}</p>
                <p className="mt-0.5 text-[10px] text-muted-foreground">
                  {wf.fullName}
                </p>
                <p className="mt-1.5 text-xs text-muted-foreground leading-relaxed">
                  {wf.description}
                </p>
              </button>
            );
          })}
        </div>
      </div>

      {/* Organism + threshold */}
      <Card>
        <CardHeader className="pb-3">
          <CardTitle className="text-sm">通路参数</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          {/* Organism */}
          <div className="space-y-1.5">
            <label className="text-xs font-medium text-muted-foreground">
              物种 / Organism
            </label>
            <select
              value={organism}
              onChange={(e) => setOrganism(e.target.value)}
              className="w-full rounded-md border border-border bg-background px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              {ORGANISMS.map((org) => (
                <option key={org} value={org}>
                  {org}
                </option>
              ))}
            </select>
          </div>

          {/* Significance threshold */}
          <div className="space-y-1.5">
            <div className="flex items-center justify-between">
              <label className="text-xs font-medium text-muted-foreground">
                Significance threshold (FDR)
              </label>
              <span className="text-xs font-semibold tabular-nums">
                {sigThreshold}
              </span>
            </div>
            <div className="flex gap-2">
              {[0.001, 0.01, 0.05, 0.1].map((p) => (
                <button
                  key={p}
                  type="button"
                  onClick={() => setSigThreshold(p)}
                  className={cn(
                    'flex-1 rounded-md border py-1.5 text-xs font-medium transition-colors',
                    sigThreshold === p
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
        <Button
          onClick={onNext}
          disabled={pathwayWorkflows.length === 0}
          className="min-w-32"
        >
          下一步
        </Button>
      </div>
    </div>
  );
}
