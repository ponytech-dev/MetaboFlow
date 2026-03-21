'use client';

import { useRouter } from 'next/navigation';
import { StepIndicator } from './step-indicator';
import { StepImport } from './steps/step-import';
import { StepPeak } from './steps/step-peak';
import { StepQc } from './steps/step-qc';
import { StepStats } from './steps/step-stats';
import { StepAnnotation } from './steps/step-annotation';
import { StepPathway } from './steps/step-pathway';
import { StepExport } from './steps/step-export';
import { useAnalysisStore } from '@/stores/analysis-store';
import { Progress } from '@/components/ui/progress';
import { uploadFiles, startAnalysis } from '@/lib/api';

export function WizardShell() {
  const router = useRouter();
  const {
    currentStep, nextStep, prevStep, setStep,
    files, peakParams, selectedEngine, fcCutoff, pValueCutoff,
    databases, ms1Ppm, useSirius, pathwayWorkflows, organism,
    isRunning, setIsRunning, setAnalysisId, setRunError,
  } = useAnalysisStore();

  const progressPercent = Math.round(((currentStep - 1) / 6) * 100);

  return (
    <div className="mx-auto w-full max-w-4xl space-y-6">
      {/* Progress bar (thin, above step indicator) */}
      <Progress value={progressPercent} className="h-1" />

      {/* Step indicator */}
      <StepIndicator currentStep={currentStep} onStepClick={setStep} />

      {/* Step content card */}
      <div className="rounded-2xl border border-border bg-card p-8 shadow-sm">
        {currentStep === 1 && <StepImport onNext={nextStep} />}
        {currentStep === 2 && (
          <StepPeak onNext={nextStep} onBack={prevStep} />
        )}
        {currentStep === 3 && (
          <StepQc onNext={nextStep} onBack={prevStep} />
        )}
        {currentStep === 4 && (
          <StepStats onNext={nextStep} onBack={prevStep} />
        )}
        {currentStep === 5 && (
          <StepAnnotation onNext={nextStep} onBack={prevStep} />
        )}
        {currentStep === 6 && (
          <StepPathway onNext={nextStep} onBack={prevStep} />
        )}
        {currentStep === 7 && (
          <StepExport
            onBack={prevStep}
            onSubmit={async () => {
              try {
                setIsRunning(true);
                setRunError(null);

                // Step 1: Upload files
                const uploadedPaths = await uploadFiles(files);

                // Step 2: Start analysis with all wizard parameters
                const { id } = await startAnalysis({
                  files: uploadedPaths,
                  sampleMetadata: [],
                  selectedEngine: selectedEngine ?? 'xcms',
                  peakParams,
                  multiEngineMode: false,
                  batchMethod: 'SERRF',
                  analysisType: 'Differential',
                  groupComparison: null,
                  fcCutoff,
                  pValueCutoff,
                  databases,
                  ms1Ppm,
                  useSirius,
                  pathwayWorkflows,
                  organism,
                  sigThreshold: 0.05,
                  chartTypes: ['Volcano', 'PCA', 'Heatmap'],
                  exportFormat: 'PDF',
                });

                setAnalysisId(id);

                // Navigate to results page with SSE progress tracking
                router.push(`/analysis/${id}`);
              } catch (err) {
                setRunError(err instanceof Error ? err.message : 'Unknown error');
                setIsRunning(false);
              }
            }}
          />
        )}
      </div>

      {/* Step counter */}
      <p className="text-center text-xs text-muted-foreground">
        Step {currentStep} of 7
      </p>
    </div>
  );
}
