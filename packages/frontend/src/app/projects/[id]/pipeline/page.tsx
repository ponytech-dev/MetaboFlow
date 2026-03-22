'use client';

import { use, useEffect, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { ChevronDown, ChevronUp, AlertCircle, Play } from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
  Card,
  CardHeader,
  CardTitle,
  CardContent,
} from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { listEngines, getEngineParams, startProjectAnalysis } from '@/lib/api';
import type {
  EngineInfo,
  EngineParamSchema,
  PipelineStepKey,
} from '@/types/project';
const PIPELINE_STEPS: {
  key: PipelineStepKey;
  label: string;
  index: number;
}[] = [
  { key: 'peak_detection', label: 'Peak Detection', index: 1 },
  { key: 'deconvolution', label: 'Deconvolution', index: 2 },
  { key: 'stats', label: 'Statistical Analysis', index: 3 },
  { key: 'annotation', label: 'Annotation', index: 4 },
  { key: 'pathway', label: 'Pathway Analysis', index: 5 },
];

export default function PipelinePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id: projectId } = use(params);
  const searchParams = useSearchParams();
  const analysisId = searchParams.get('analysisId') ?? '';
  const router = useRouter();

  const [engines, setEngines] = useState<EngineInfo[]>([]);
  const [enginesLoading, setEnginesLoading] = useState(true);

  // Selected engine per step
  const [stepEngines, setStepEngines] = useState<
    Record<PipelineStepKey, string>
  >({
    peak_detection: '',
    deconvolution: '',
    stats: '',
    annotation: '',
    pathway: '',
  });

  // Params per step
  const [stepParams, setStepParams] = useState<
    Record<PipelineStepKey, Record<string, unknown>>
  >({
    peak_detection: {},
    deconvolution: {},
    stats: {},
    annotation: {},
    pathway: {},
  });

  // Collapsed state per step
  const [collapsed, setCollapsed] = useState<Record<PipelineStepKey, boolean>>(
    {
      peak_detection: false,
      deconvolution: true,
      stats: true,
      annotation: true,
      pathway: true,
    }
  );

  // Param schemas per engine
  const [schemas, setSchemas] = useState<Record<string, EngineParamSchema>>({});

  const [starting, setStarting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Load engines
  useEffect(() => {
    async function load() {
      try {
        const data = await listEngines();
        setEngines(data);

        // Auto-select first engine per step
        const autoSelect: Record<PipelineStepKey, string> = {
          peak_detection: '',
          deconvolution: '',
          stats: '',
          annotation: '',
          pathway: '',
        };
        for (const step of PIPELINE_STEPS) {
          const match = data.find((e) => e.step === step.key);
          if (match) autoSelect[step.key] = match.name;
        }
        setStepEngines(autoSelect);
      } catch {
        // Silently fail — engines might not be available yet
      } finally {
        setEnginesLoading(false);
      }
    }
    load();
  }, []);

  // Load schema when engine changes
  async function loadSchema(engineName: string) {
    if (!engineName || schemas[engineName]) return;
    try {
      const schema = await getEngineParams(engineName);
      setSchemas((prev) => ({ ...prev, [engineName]: schema }));

      // Seed default params
      const defaults: Record<string, unknown> = {};
      if (schema.properties) {
        for (const [k, v] of Object.entries(schema.properties)) {
          if (v.default !== undefined) defaults[k] = v.default;
        }
      }
      // Find which step this engine belongs to
      const stepEngine = engines.find((e) => e.name === engineName);
      if (stepEngine) {
        setStepParams((prev) => ({
          ...prev,
          [stepEngine.step]: { ...defaults, ...prev[stepEngine.step] },
        }));
      }
    } catch {
      // ignore schema load failure
    }
  }

  function handleEngineChange(step: PipelineStepKey, engineName: string) {
    setStepEngines((prev) => ({ ...prev, [step]: engineName }));
    loadSchema(engineName);
  }

  function handleParamChange(
    step: PipelineStepKey,
    key: string,
    value: unknown
  ) {
    setStepParams((prev) => ({
      ...prev,
      [step]: { ...prev[step], [key]: value },
    }));
  }

  function toggleCollapse(step: PipelineStepKey) {
    setCollapsed((prev) => ({ ...prev, [step]: !prev[step] }));
  }

  async function handleStartAnalysis() {
    if (!analysisId) {
      setError('No analysis ID found. Please go back to Upload step first.');
      return;
    }
    setStarting(true);
    setError(null);

    const config = Object.fromEntries(
      PIPELINE_STEPS.map((s) => [
        s.key,
        { engine: stepEngines[s.key], params: stepParams[s.key] },
      ])
    ) as Parameters<typeof startProjectAnalysis>[1];

    try {
      await startProjectAnalysis(analysisId, config);
      router.push(
        `/projects/${projectId}/monitor?analysisId=${analysisId}`
      );
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to start analysis');
      setStarting(false);
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-semibold">Pipeline Designer</h1>
        <p className="mt-0.5 text-sm text-muted-foreground">
          Configure engines and parameters for each analysis step.
        </p>
      </div>

      {/* Error */}
      {error && (
        <div className="flex items-start gap-3 rounded-lg border border-destructive/30 bg-destructive/5 px-4 py-3 text-sm text-destructive">
          <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
          <p>{error}</p>
        </div>
      )}

      {/* Pipeline steps */}
      <div className="space-y-3">
        {PIPELINE_STEPS.map((step) => {
          const stepEngineList = engines.filter((e) => e.step === step.key);
          const selectedEngine = stepEngines[step.key];
          const schema = selectedEngine ? schemas[selectedEngine] : null;
          const isCollapsed = collapsed[step.key];

          return (
            <Card key={step.key}>
              {/* Step header — clickable to toggle */}
              <button
                type="button"
                className="w-full text-left"
                onClick={() => toggleCollapse(step.key)}
              >
                <CardHeader className="flex flex-row items-center gap-3 cursor-pointer select-none">
                  <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-primary/10 text-xs font-semibold text-primary">
                    {step.index}
                  </span>
                  <CardTitle className="flex-1">{step.label}</CardTitle>
                  {selectedEngine && (
                    <span className="text-xs text-muted-foreground font-mono">
                      {selectedEngine}
                    </span>
                  )}
                  {isCollapsed ? (
                    <ChevronDown className="h-4 w-4 text-muted-foreground" />
                  ) : (
                    <ChevronUp className="h-4 w-4 text-muted-foreground" />
                  )}
                </CardHeader>
              </button>

              {!isCollapsed && (
                <CardContent className="space-y-4 pt-0">
                  {/* Engine selector */}
                  <div className="flex items-center gap-3">
                    <label className="text-sm font-medium w-20 shrink-0">
                      Engine
                    </label>
                    {enginesLoading ? (
                      <div className="h-8 w-40 rounded-lg bg-muted animate-pulse" />
                    ) : stepEngineList.length === 0 ? (
                      <span className="text-xs text-muted-foreground">
                        No engines available yet
                      </span>
                    ) : (
                      <Select
                        value={selectedEngine}
                        onValueChange={(v) => handleEngineChange(step.key, v ?? '')}
                      >
                        <SelectTrigger className="w-48">
                          <SelectValue placeholder="Select engine" />
                        </SelectTrigger>
                        <SelectContent>
                          {stepEngineList.map((e) => (
                            <SelectItem key={e.name} value={e.name}>
                              {e.label} {e.version && `(${e.version})`}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    )}
                  </div>

                  {/* Dynamic parameter form */}
                  {schema?.properties &&
                    Object.entries(schema.properties).length > 0 && (
                      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                        {Object.entries(schema.properties).map(
                          ([key, prop]) => (
                            <ParamField
                              key={key}
                              fieldKey={key}
                              prop={prop}
                              value={stepParams[step.key][key]}
                              onChange={(v) =>
                                handleParamChange(step.key, key, v)
                              }
                            />
                          )
                        )}
                      </div>
                    )}

                  {/* No schema yet — show placeholder */}
                  {!enginesLoading && selectedEngine && !schema && (
                    <p className="text-xs text-muted-foreground">
                      Loading parameters…
                    </p>
                  )}
                </CardContent>
              )}
            </Card>
          );
        })}
      </div>

      {/* Start Analysis */}
      <div className="flex justify-end">
        <Button
          onClick={handleStartAnalysis}
          disabled={starting || !analysisId}
          size="lg"
          className="gap-2"
        >
          <Play className="h-4 w-4" />
          {starting ? 'Starting…' : 'Start Analysis'}
        </Button>
      </div>
    </div>
  );
}

// ─── Parameter field ──────────────────────────────────────────────────────────

import type { EngineParam } from '@/types/project';

function ParamField({
  fieldKey,
  prop,
  value,
  onChange,
}: {
  fieldKey: string;
  prop: EngineParam;
  value: unknown;
  onChange: (v: unknown) => void;
}) {
  const display =
    prop.title || fieldKey.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());

  if (prop.type === 'boolean') {
    return (
      <label className="flex items-center gap-2 text-sm cursor-pointer">
        <input
          type="checkbox"
          checked={Boolean(value ?? prop.default)}
          onChange={(e) => onChange(e.target.checked)}
          className="h-4 w-4 rounded border-input"
        />
        <span>{display}</span>
      </label>
    );
  }

  if (prop.type === 'select' && prop.enum) {
    return (
      <div className="space-y-1">
        <label className="text-xs font-medium text-muted-foreground">
          {display}
        </label>
        <Select
          value={String(value ?? prop.default ?? '')}
          onValueChange={onChange}
        >
          <SelectTrigger className="h-8 text-xs">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {prop.enum.map((opt) => (
              <SelectItem key={opt} value={opt} className="text-xs">
                {opt}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>
    );
  }

  // number or string
  return (
    <div className="space-y-1">
      <label className="text-xs font-medium text-muted-foreground">
        {display}
        {prop.description && (
          <span className="ml-1 text-muted-foreground/60" title={prop.description}>
            ?
          </span>
        )}
      </label>
      <Input
        type={prop.type === 'number' ? 'number' : 'text'}
        className="h-8 text-xs"
        value={String(value ?? prop.default ?? '')}
        min={prop.minimum}
        max={prop.maximum}
        onChange={(e) =>
          onChange(
            prop.type === 'number'
              ? parseFloat(e.target.value)
              : e.target.value
          )
        }
      />
    </div>
  );
}
