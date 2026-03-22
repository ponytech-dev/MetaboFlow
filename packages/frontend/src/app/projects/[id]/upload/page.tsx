'use client';

import { use, useCallback, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Upload, X, AlertCircle, FileText, ChevronRight } from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
} from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { createAnalysis, uploadAnalysisFiles } from '@/lib/api';
import type { SampleFileMeta } from '@/types/project';
import { cn } from '@/lib/utils';

const ACCEPTED = '.mzML,.mzXML,.mzml,.mzxml';

export default function UploadPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id: projectId } = use(params);
  const router = useRouter();

  const [files, setFiles] = useState<File[]>([]);
  const [meta, setMeta] = useState<SampleFileMeta[]>([]);
  const [dragging, setDragging] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // ── File selection ──────────────────────────────────────────────────────────
  const addFiles = useCallback((incoming: FileList | null) => {
    if (!incoming) return;
    const accepted = Array.from(incoming).filter((f) =>
      /\.(mzML|mzXML)$/i.test(f.name)
    );
    if (accepted.length === 0) return;

    setFiles((prev) => {
      const existing = new Set(prev.map((f) => f.name));
      const fresh = accepted.filter((f) => !existing.has(f.name));
      const newMeta: SampleFileMeta[] = fresh.map((f) => ({
        filename: f.name,
        size: f.size,
        group: 'Control',
        sample_type: 'sample',
        batch: 1,
      }));
      setMeta((m) => [...m, ...newMeta]);
      return [...prev, ...fresh];
    });
  }, []);

  function removeFile(index: number) {
    setFiles((prev) => prev.filter((_, i) => i !== index));
    setMeta((prev) => prev.filter((_, i) => i !== index));
  }

  function updateMeta(
    index: number,
    key: keyof SampleFileMeta,
    value: string | number
  ) {
    setMeta((prev) => {
      const copy = [...prev];
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      (copy[index] as any)[key] = value;
      return copy;
    });
  }

  // ── Drag and drop ───────────────────────────────────────────────────────────
  const onDragOver = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setDragging(true);
  }, []);

  const onDragLeave = useCallback(() => setDragging(false), []);

  const onDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setDragging(false);
    addFiles(e.dataTransfer.files);
  }, [addFiles]);

  // ── Upload & continue ───────────────────────────────────────────────────────
  async function handleContinue() {
    if (files.length === 0) return;
    setUploading(true);
    setError(null);
    try {
      const { id: analysisId } = await createAnalysis(projectId);

      const formData = new FormData();
      files.forEach((f) => formData.append('files', f));
      formData.append('metadata', JSON.stringify(meta));

      await uploadAnalysisFiles(analysisId, formData);

      router.push(
        `/projects/${projectId}/pipeline?analysisId=${analysisId}`
      );
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Upload failed');
      setUploading(false);
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-semibold">Upload Data</h1>
        <p className="mt-0.5 text-sm text-muted-foreground">
          Upload mzML or mzXML files and set sample metadata.
        </p>
      </div>

      {/* Error */}
      {error && (
        <div className="flex items-start gap-3 rounded-lg border border-destructive/30 bg-destructive/5 px-4 py-3 text-sm text-destructive">
          <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
          <p>{error}</p>
        </div>
      )}

      {/* Drop zone */}
      <div
        onDragOver={onDragOver}
        onDragLeave={onDragLeave}
        onDrop={onDrop}
        className={cn(
          'flex flex-col items-center justify-center gap-3 rounded-xl border-2 border-dashed py-16 text-center transition-colors cursor-pointer',
          dragging
            ? 'border-primary bg-primary/5'
            : 'border-border bg-card hover:border-border/80'
        )}
        onClick={() => document.getElementById('file-input')?.click()}
      >
        <Upload
          className={cn(
            'h-10 w-10 transition-colors',
            dragging ? 'text-primary' : 'text-muted-foreground/40'
          )}
        />
        <div>
          <p className="font-medium text-sm">Drop files here or click to browse</p>
          <p className="mt-1 text-xs text-muted-foreground">
            Supported: .mzML, .mzXML
          </p>
        </div>
        <input
          id="file-input"
          type="file"
          multiple
          accept={ACCEPTED}
          className="hidden"
          onChange={(e) => addFiles(e.target.files)}
        />
      </div>

      {/* File list + metadata table */}
      {files.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle>Files ({files.length})</CardTitle>
            <CardDescription>
              Set group name, sample type, and batch for each file.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border text-xs text-muted-foreground">
                    <th className="pb-2 pr-4 text-left font-medium">File</th>
                    <th className="pb-2 pr-4 text-left font-medium">Size</th>
                    <th className="pb-2 pr-4 text-left font-medium">Group</th>
                    <th className="pb-2 pr-4 text-left font-medium">Type</th>
                    <th className="pb-2 pr-4 text-left font-medium">Batch</th>
                    <th className="pb-2 text-left font-medium" />
                  </tr>
                </thead>
                <tbody>
                  {files.map((file, idx) => (
                    <tr key={file.name} className="border-b border-border/50 last:border-0">
                      <td className="py-2 pr-4">
                        <div className="flex items-center gap-2">
                          <FileText className="h-4 w-4 shrink-0 text-muted-foreground" />
                          <span className="truncate max-w-[200px] font-mono text-xs">
                            {file.name}
                          </span>
                        </div>
                      </td>
                      <td className="py-2 pr-4 text-xs text-muted-foreground whitespace-nowrap">
                        {formatBytes(file.size)}
                      </td>
                      <td className="py-2 pr-4">
                        <Input
                          className="h-7 w-28 text-xs"
                          value={meta[idx]?.group ?? ''}
                          onChange={(e) => updateMeta(idx, 'group', e.target.value)}
                        />
                      </td>
                      <td className="py-2 pr-4">
                        <select
                          className="h-7 rounded-md border border-input bg-transparent px-2 text-xs focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring"
                          value={meta[idx]?.sample_type ?? 'sample'}
                          onChange={(e) =>
                            updateMeta(idx, 'sample_type', e.target.value)
                          }
                        >
                          <option value="sample">Sample</option>
                          <option value="QC">QC</option>
                          <option value="blank">Blank</option>
                        </select>
                      </td>
                      <td className="py-2 pr-4">
                        <Input
                          type="number"
                          min={1}
                          className="h-7 w-16 text-xs"
                          value={meta[idx]?.batch ?? 1}
                          onChange={(e) =>
                            updateMeta(idx, 'batch', parseInt(e.target.value, 10) || 1)
                          }
                        />
                      </td>
                      <td className="py-2">
                        <button
                          onClick={() => removeFile(idx)}
                          className="rounded p-1 text-muted-foreground hover:text-destructive hover:bg-destructive/10 transition-colors"
                        >
                          <X className="h-3.5 w-3.5" />
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Continue button */}
      <div className="flex justify-end">
        <Button
          onClick={handleContinue}
          disabled={files.length === 0 || uploading}
          className="gap-1.5"
        >
          {uploading ? 'Uploading…' : 'Continue to Pipeline'}
          <ChevronRight className="h-4 w-4" />
        </Button>
      </div>
    </div>
  );
}

function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}
