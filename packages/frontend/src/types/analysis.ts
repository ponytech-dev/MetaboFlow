// TypeScript types matching backend Pydantic models

export type EngineType = 'xcms' | 'mzmine' | 'pyopenms' | 'msdial';
export type SampleType = 'QC' | 'Sample' | 'Blank';
export type BatchCorrectionMethod = 'SERRF' | 'ComBat' | 'QC-RLSC';
export type StatAnalysisType = 'PCA' | 'PLS-DA' | 'Differential';
export type ExportFormat = 'PDF' | 'SVG' | 'PNG';

export interface SampleMetadata {
  sample_id: string;
  group: string;
  batch: number;
  sample_type: SampleType;
}

export interface PeakDetectionParams {
  ppm: number;
  peakwidthMin: number;
  peakwidthMax: number;
  snthresh: number;
  noise: number;
  prefilter: [number, number];
}

export interface AnalysisConfig {
  // Step 1
  files: string[];
  sampleMetadata: SampleMetadata[];
  // Step 2
  selectedEngine: EngineType | null;
  peakParams: PeakDetectionParams;
  multiEngineMode: boolean;
  // Step 3
  batchMethod: BatchCorrectionMethod;
  // Step 4
  analysisType: StatAnalysisType;
  groupComparison: [string, string] | null;
  fcCutoff: number;
  pValueCutoff: number;
  // Step 5
  databases: string[];
  ms1Ppm: number;
  useSirius: boolean;
  // Step 6
  pathwayWorkflows: string[];
  organism: string;
  sigThreshold: number;
  // Step 7
  chartTypes: string[];
  exportFormat: ExportFormat;
}

export type AnalysisStatusState =
  | 'pending'
  | 'running'
  | 'completed'
  | 'failed';

export interface AnalysisStatus {
  id: string;
  status: AnalysisStatusState;
  currentStep: string;
  progress: number;
  message: string;
  createdAt: string;
  updatedAt: string;
}

export interface FeatureResult {
  feature_id: string;
  mz: number;
  rt: number;
  intensity: number;
  annotation: string | null;
  fold_change: number | null;
  p_value: number | null;
  adjusted_p_value: number | null;
}

export interface AnalysisResult {
  id: string;
  status: AnalysisStatusState;
  features: FeatureResult[];
  qcMetrics: Record<string, number>;
  pathwayResults: PathwayResult[];
  reportUrl: string | null;
}

export interface PathwayResult {
  pathway_id: string;
  pathway_name: string;
  p_value: number;
  fdr: number;
  coverage: number;
  hit_count: number;
  total_count: number;
}
