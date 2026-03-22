// Project and pipeline types for the multi-page architecture

export type ProjectStatus = 'active' | 'archived';

export interface Project {
  id: string;
  name: string;
  description: string | null;
  status: ProjectStatus;
  analysis_count: number;
  created_at: string;
  updated_at: string;
}

export interface ProjectSummary {
  id: string;
  name: string;
  description: string | null;
  status: ProjectStatus;
  analysis_count: number;
  created_at: string;
  updated_at: string;
}

export interface CreateProjectPayload {
  name: string;
  description?: string;
}

// Engine catalog types
export interface EngineInfo {
  name: string;
  label: string;
  description: string;
  version: string;
  step: PipelineStepKey;
}

export type PipelineStepKey =
  | 'peak_detection'
  | 'deconvolution'
  | 'stats'
  | 'annotation'
  | 'pathway';

export interface EngineParam {
  type: 'number' | 'string' | 'boolean' | 'select';
  title: string;
  description?: string;
  default?: unknown;
  minimum?: number;
  maximum?: number;
  enum?: string[];
}

export interface EngineParamSchema {
  title: string;
  properties: Record<string, EngineParam>;
  required?: string[];
}

// Pipeline configuration
export interface PipelineStepConfig {
  engine: string;
  params: Record<string, unknown>;
}

export interface PipelineConfig {
  peak_detection: PipelineStepConfig;
  deconvolution: PipelineStepConfig;
  stats: PipelineStepConfig;
  annotation: PipelineStepConfig;
  pathway: PipelineStepConfig;
}

// Upload / sample metadata
export interface SampleFileMeta {
  filename: string;
  size: number;
  group: string;
  sample_type: 'sample' | 'QC' | 'blank';
  batch: number;
}

// Analysis tied to a project
export interface ProjectAnalysis {
  id: string;
  project_id: string;
  name: string | null;
  status: 'pending' | 'running' | 'completed' | 'failed';
  engine: string | null;
  n_samples: number;
  n_features: number;
  created_at: string;
  updated_at: string;
}

// Results summary
export interface ResultSummary {
  analysis_id: string;
  n_features: number;
  n_significant: number;
  n_annotated: number;
  engine_versions: Record<string, string>;
  duration_ms: number | null;
}

// Feature row for the features table
export interface FeatureRow {
  feature_id: string;
  mz: number;
  rt: number;
  log2fc: number | null;
  p_value: number | null;
  adj_p: number | null;
  annotation: string | null;
}

// Annotation hit
export interface AnnotationHit {
  feature_id: string;
  compound_name: string;
  smiles: string | null;
  match_score: number;
  msi_level: number;
  source_library: string;
}

// Pathway enrichment row
export interface PathwayRow {
  pathway_id: string;
  pathway_name: string;
  p_value: number;
  n_hits: number;
  n_pathway: number;
}

// Chart from chart-r-worker
export interface Chart {
  id: string;
  type: string;
  label: string;
  svg_url: string;
  pdf_url: string | null;
  png_url: string | null;
}

// Progress event from SSE
export interface ProgressEvent {
  step: string;
  label: string;
  status: 'pending' | 'running' | 'completed' | 'failed';
  progress: number; // 0-100
  message: string | null;
  elapsed_ms: number | null;
}
