import type {
  AnalysisConfig,
  AnalysisStatus,
  AnalysisResult,
  AnalysisSummary,
  VolcanoData,
  PCAData,
} from '@/types/analysis';
import type {
  Project,
  ProjectSummary,
  CreateProjectPayload,
  ProjectAnalysis,
  EngineInfo,
  EngineParamSchema,
  PipelineConfig,
  ResultSummary,
  FeatureRow,
  AnnotationHit,
  PathwayRow,
  Chart,
} from '@/types/project';
import { authFetch } from '@/lib/auth';

const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:8000';

class ApiError extends Error {
  constructor(
    public status: number,
    message: string
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

async function fetchJSON<T>(
  path: string,
  options?: RequestInit
): Promise<T> {
  const res = await fetch(`${API_BASE_URL}${path}`, {
    headers: { 'Content-Type': 'application/json', ...options?.headers },
    ...options,
  });
  if (!res.ok) {
    const text = await res.text().catch(() => res.statusText);
    throw new ApiError(res.status, text);
  }
  return res.json() as Promise<T>;
}

/** Authenticated JSON fetch — auto-refreshes on 401, retries once. */
async function authJSON<T>(path: string, options?: RequestInit): Promise<T> {
  const res = await authFetch(`${API_BASE_URL}${path}`, options);
  if (!res.ok) {
    const text = await res.text().catch(() => res.statusText);
    throw new ApiError(res.status, text);
  }
  return res.json() as Promise<T>;
}

/**
 * Upload raw MS data files. Returns list of server-side file paths.
 */
export async function uploadFiles(files: File[]): Promise<string[]> {
  const formData = new FormData();
  files.forEach((f) => formData.append('files', f));

  const res = await fetch(`${API_BASE_URL}/api/v1/files/upload`, {
    method: 'POST',
    body: formData,
  });
  if (!res.ok) {
    const text = await res.text().catch(() => res.statusText);
    throw new ApiError(res.status, text);
  }
  const data = (await res.json()) as { paths: string[] };
  return data.paths;
}

/**
 * Start a new analysis run with the provided configuration.
 * Returns the analysis ID.
 */
export async function startAnalysis(
  config: Partial<AnalysisConfig>
): Promise<{ id: string }> {
  return fetchJSON<{ id: string }>('/api/v1/analysis', {
    method: 'POST',
    body: JSON.stringify(config),
  });
}

/**
 * Poll the status of an analysis run.
 */
export async function getAnalysisStatus(id: string): Promise<AnalysisStatus> {
  return fetchJSON<AnalysisStatus>(`/api/v1/analysis/${id}/status`);
}

/**
 * Fetch analysis results after completion.
 */
export async function getResults(id: string): Promise<AnalysisResult> {
  return fetchJSON<AnalysisResult>(`/api/v1/analysis/${id}/results`);
}

/**
 * Subscribe to real-time progress via Server-Sent Events.
 * Returns an EventSource; caller is responsible for closing it.
 */
export function subscribeToProgress(
  id: string,
  onProgress: (status: AnalysisStatus) => void,
  onError?: (err: Event) => void
): EventSource {
  const es = new EventSource(`${API_BASE_URL}/api/v1/analysis/${id}/stream`);
  es.onmessage = (event) => {
    try {
      const data = JSON.parse(event.data as string) as AnalysisStatus;
      onProgress(data);
    } catch {
      // ignore parse errors
    }
  };
  if (onError) {
    es.onerror = onError;
  }
  return es;
}

/**
 * Fetch a single analysis (status + metadata).
 */
export async function getAnalysis(id: string): Promise<AnalysisStatus> {
  return fetchJSON<AnalysisStatus>(`/api/v1/analyses/${id}`);
}

/**
 * Fetch full analysis results (features, pathways, etc.).
 */
export async function getAnalysisResult(id: string): Promise<AnalysisResult> {
  return fetchJSON<AnalysisResult>(`/api/v1/analyses/${id}/results`);
}

/**
 * Fetch the HTML report URL (returns a URL string).
 */
export async function getAnalysisReport(id: string): Promise<{ url: string }> {
  return fetchJSON<{ url: string }>(`/api/v1/analyses/${id}/report`);
}

/**
 * Fetch volcano plot data.
 */
export async function getVolcanoData(id: string): Promise<VolcanoData> {
  return fetchJSON<VolcanoData>(`/api/v1/analyses/${id}/results/volcano`);
}

/**
 * Fetch PCA plot data.
 */
export async function getPCAData(id: string): Promise<PCAData> {
  return fetchJSON<PCAData>(`/api/v1/analyses/${id}/results/pca`);
}

/**
 * List all analyses.
 */
export async function listAnalyses(): Promise<AnalysisSummary[]> {
  return fetchJSON<AnalysisSummary[]>('/api/v1/analyses');
}

/**
 * Subscribe to real-time pipeline progress via SSE.
 * Returns an EventSource; caller must close it.
 */
export function streamProgress(id: string): EventSource {
  return new EventSource(
    `${API_BASE_URL}/api/v1/analyses/${id}/progress/stream`
  );
}

export { ApiError };

// ─── Projects ────────────────────────────────────────────────────────────────

export async function listProjects(): Promise<ProjectSummary[]> {
  return authJSON<ProjectSummary[]>('/api/v1/projects');
}

export async function getProject(id: string): Promise<Project> {
  return authJSON<Project>(`/api/v1/projects/${id}`);
}

export async function createProject(
  payload: CreateProjectPayload
): Promise<Project> {
  return authJSON<Project>('/api/v1/projects', {
    method: 'POST',
    body: JSON.stringify(payload),
  });
}

export async function listProjectAnalyses(
  projectId: string
): Promise<ProjectAnalysis[]> {
  return authJSON<ProjectAnalysis[]>(`/api/v1/projects/${projectId}/analyses`);
}

// ─── Engines ─────────────────────────────────────────────────────────────────

export async function listEngines(): Promise<EngineInfo[]> {
  return authJSON<EngineInfo[]>('/api/v1/engines');
}

export async function getEngineParams(
  name: string
): Promise<EngineParamSchema> {
  return authJSON<EngineParamSchema>(`/api/v1/engines/${name}/params`);
}

// ─── Analysis (project-scoped) ────────────────────────────────────────────────

/** Create a new analysis under a project. Returns analysis id. */
export async function createAnalysis(
  projectId: string
): Promise<{ id: string }> {
  return authJSON<{ id: string }>('/api/v1/analyses', {
    method: 'POST',
    body: JSON.stringify({ project_id: projectId }),
  });
}

/** Upload files for an analysis (multipart). */
export async function uploadAnalysisFiles(
  analysisId: string,
  formData: FormData
): Promise<{ file_ids: string[] }> {
  const res = await authFetch(
    `${API_BASE_URL}/api/v1/analyses/${analysisId}/upload`,
    { method: 'POST', body: formData }
  );
  if (!res.ok) {
    const text = await res.text().catch(() => res.statusText);
    throw new ApiError(res.status, text);
  }
  return res.json() as Promise<{ file_ids: string[] }>;
}

/** Start analysis with pipeline config. */
export async function startProjectAnalysis(
  analysisId: string,
  config: Partial<PipelineConfig>
): Promise<{ id: string }> {
  return authJSON<{ id: string }>(`/api/v1/analyses/${analysisId}/start`, {
    method: 'POST',
    body: JSON.stringify(config),
  });
}

/** Fetch result summary (counts + engine versions). */
export async function getResultSummary(
  analysisId: string
): Promise<ResultSummary> {
  return authJSON<ResultSummary>(`/api/v1/analyses/${analysisId}/result`);
}

/** Fetch feature rows with optional filters. */
export async function getFeatures(
  analysisId: string,
  params?: { p_cutoff?: number; fc_cutoff?: number }
): Promise<FeatureRow[]> {
  const qs = params
    ? '?' +
      new URLSearchParams(
        Object.entries(params)
          .filter(([, v]) => v !== undefined)
          .map(([k, v]) => [k, String(v)])
      ).toString()
    : '';
  return authJSON<FeatureRow[]>(
    `/api/v1/analyses/${analysisId}/results/features${qs}`
  );
}

/** Fetch annotation hits. */
export async function getAnnotations(
  analysisId: string
): Promise<AnnotationHit[]> {
  return authJSON<AnnotationHit[]>(
    `/api/v1/analyses/${analysisId}/results/annotations`
  );
}

/** Fetch pathway enrichment rows. */
export async function getPathways(
  analysisId: string
): Promise<PathwayRow[]> {
  return authJSON<PathwayRow[]>(
    `/api/v1/analyses/${analysisId}/results/pathways`
  );
}

/** Fetch chart list. */
export async function getCharts(analysisId: string): Promise<Chart[]> {
  return authJSON<Chart[]>(`/api/v1/analyses/${analysisId}/charts`);
}

/** Trigger chart generation. */
export async function generateCharts(
  analysisId: string
): Promise<{ job_id: string }> {
  return authJSON<{ job_id: string }>(
    `/api/v1/analyses/${analysisId}/charts/generate`,
    { method: 'POST' }
  );
}

/** Trigger report generation. */
export async function generateReport(
  analysisId: string,
  payload: { charts: string[]; format: 'pdf' | 'docx' | 'both' }
): Promise<{ job_id: string }> {
  return authJSON<{ job_id: string }>(
    `/api/v1/analyses/${analysisId}/report/generate`,
    { method: 'POST', body: JSON.stringify(payload) }
  );
}

/** Open SSE stream for pipeline progress. */
export function streamAnalysisProgress(analysisId: string): EventSource {
  return new EventSource(
    `${API_BASE_URL}/api/v1/analyses/${analysisId}/progress/stream`
  );
}
