import type {
  AnalysisConfig,
  AnalysisStatus,
  AnalysisResult,
  AnalysisSummary,
  VolcanoData,
  PCAData,
} from '@/types/analysis';

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
