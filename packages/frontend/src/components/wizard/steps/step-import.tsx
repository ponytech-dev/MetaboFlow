'use client';

import { useCallback, useRef } from 'react';
import { Upload, X, FileText, AlertCircle } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Separator } from '@/components/ui/separator';
import { useAnalysisStore } from '@/stores/analysis-store';
import { cn } from '@/lib/utils';

const ACCEPTED_EXTENSIONS = ['.mzML', '.mzXML', '.raw', '.d', '.wiff'];
const SAMPLE_TYPES = ['Sample', 'QC', 'Blank'] as const;

function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

interface StepImportProps {
  onNext: () => void;
}

export function StepImport({ onNext }: StepImportProps) {
  const { files, addFiles, removeFile, sampleMetadata, setSampleMetadata } =
    useAnalysisStore();
  const inputRef = useRef<HTMLInputElement>(null);

  const handleDrop = useCallback(
    (e: React.DragEvent<HTMLDivElement>) => {
      e.preventDefault();
      const dropped = Array.from(e.dataTransfer.files);
      addFiles(dropped);
      // Auto-generate metadata rows for new files
      const newMeta = dropped.map((f, i) => ({
        sample_id: f.name.replace(/\.[^.]+$/, ''),
        group: 'Group1',
        batch: 1,
        sample_type: 'Sample' as const,
      }));
      setSampleMetadata([...sampleMetadata, ...newMeta]);
    },
    [addFiles, sampleMetadata, setSampleMetadata]
  );

  const handleFileInput = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      if (!e.target.files) return;
      const selected = Array.from(e.target.files);
      addFiles(selected);
      const newMeta = selected.map((f) => ({
        sample_id: f.name.replace(/\.[^.]+$/, ''),
        group: 'Group1',
        batch: 1,
        sample_type: 'Sample' as const,
      }));
      setSampleMetadata([...sampleMetadata, ...newMeta]);
    },
    [addFiles, sampleMetadata, setSampleMetadata]
  );

  const updateMetadata = (
    index: number,
    field: keyof (typeof sampleMetadata)[0],
    value: string | number
  ) => {
    const updated = sampleMetadata.map((row, i) =>
      i === index ? { ...row, [field]: value } : row
    );
    setSampleMetadata(updated);
  };

  const handleRemove = (index: number) => {
    removeFile(index);
    setSampleMetadata(sampleMetadata.filter((_, i) => i !== index));
  };

  const canProceed = files.length > 0;

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-lg font-semibold">数据导入</h2>
        <p className="mt-1 text-sm text-muted-foreground">
          上传原始质谱数据文件，支持 mzML、mzXML、RAW 等格式。
        </p>
      </div>

      {/* Drop zone */}
      <div
        onDrop={handleDrop}
        onDragOver={(e) => e.preventDefault()}
        onClick={() => inputRef.current?.click()}
        className={cn(
          'flex flex-col items-center justify-center rounded-xl border-2 border-dashed p-12 text-center transition-colors cursor-pointer',
          files.length === 0
            ? 'border-border hover:border-blue-400 hover:bg-blue-50/50 dark:hover:bg-blue-950/20'
            : 'border-blue-300 bg-blue-50/30 dark:bg-blue-950/10'
        )}
      >
        <Upload className="mb-3 h-10 w-10 text-muted-foreground" />
        <p className="font-medium text-sm">
          拖放文件到此处，或点击选择文件
        </p>
        <p className="mt-1 text-xs text-muted-foreground">
          支持格式：{ACCEPTED_EXTENSIONS.join('、')}
        </p>
        <input
          ref={inputRef}
          type="file"
          className="hidden"
          multiple
          accept={ACCEPTED_EXTENSIONS.join(',')}
          onChange={handleFileInput}
        />
      </div>

      {/* File list */}
      {files.length > 0 && (
        <div>
          <div className="mb-2 flex items-center justify-between">
            <h3 className="text-sm font-medium">
              已选择文件{' '}
              <Badge variant="secondary">{files.length}</Badge>
            </h3>
          </div>
          <div className="rounded-lg border overflow-hidden">
            <table className="w-full text-sm">
              <thead className="bg-muted/50">
                <tr>
                  <th className="px-3 py-2 text-left font-medium text-muted-foreground">文件名</th>
                  <th className="px-3 py-2 text-left font-medium text-muted-foreground w-20">大小</th>
                  <th className="px-3 py-2 text-left font-medium text-muted-foreground w-28">Sample ID</th>
                  <th className="px-3 py-2 text-left font-medium text-muted-foreground w-24">Group</th>
                  <th className="px-3 py-2 text-left font-medium text-muted-foreground w-16">Batch</th>
                  <th className="px-3 py-2 text-left font-medium text-muted-foreground w-24">Type</th>
                  <th className="px-3 py-2 w-10" />
                </tr>
              </thead>
              <tbody>
                {files.map((file, index) => (
                  <tr key={index} className="border-t hover:bg-muted/20">
                    <td className="px-3 py-2 flex items-center gap-2">
                      <FileText className="h-3.5 w-3.5 shrink-0 text-blue-500" />
                      <span className="truncate max-w-[180px]" title={file.name}>
                        {file.name}
                      </span>
                    </td>
                    <td className="px-3 py-2 text-muted-foreground">
                      {formatBytes(file.size)}
                    </td>
                    <td className="px-3 py-2">
                      <input
                        className="w-full rounded border border-border bg-background px-2 py-0.5 text-xs focus:outline-none focus:ring-1 focus:ring-blue-500"
                        value={sampleMetadata[index]?.sample_id ?? ''}
                        onChange={(e) =>
                          updateMetadata(index, 'sample_id', e.target.value)
                        }
                      />
                    </td>
                    <td className="px-3 py-2">
                      <input
                        className="w-full rounded border border-border bg-background px-2 py-0.5 text-xs focus:outline-none focus:ring-1 focus:ring-blue-500"
                        value={sampleMetadata[index]?.group ?? ''}
                        onChange={(e) =>
                          updateMetadata(index, 'group', e.target.value)
                        }
                      />
                    </td>
                    <td className="px-3 py-2">
                      <input
                        type="number"
                        min={1}
                        className="w-full rounded border border-border bg-background px-2 py-0.5 text-xs focus:outline-none focus:ring-1 focus:ring-blue-500"
                        value={sampleMetadata[index]?.batch ?? 1}
                        onChange={(e) =>
                          updateMetadata(index, 'batch', Number(e.target.value))
                        }
                      />
                    </td>
                    <td className="px-3 py-2">
                      <select
                        className="w-full rounded border border-border bg-background px-1.5 py-0.5 text-xs focus:outline-none focus:ring-1 focus:ring-blue-500"
                        value={sampleMetadata[index]?.sample_type ?? 'Sample'}
                        onChange={(e) =>
                          updateMetadata(index, 'sample_type', e.target.value)
                        }
                      >
                        {SAMPLE_TYPES.map((t) => (
                          <option key={t} value={t}>
                            {t}
                          </option>
                        ))}
                      </select>
                    </td>
                    <td className="px-3 py-2">
                      <button
                        onClick={() => handleRemove(index)}
                        className="text-muted-foreground hover:text-destructive transition-colors"
                      >
                        <X className="h-3.5 w-3.5" />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Validation hint */}
      {files.length === 0 && (
        <div className="flex items-center gap-2 rounded-lg bg-amber-50 px-4 py-3 text-sm text-amber-700 dark:bg-amber-950/30 dark:text-amber-400">
          <AlertCircle className="h-4 w-4 shrink-0" />
          请至少上传一个数据文件才能继续。
        </div>
      )}

      <Separator />

      <div className="flex justify-end">
        <Button onClick={onNext} disabled={!canProceed} className="min-w-32">
          验证并继续
        </Button>
      </div>
    </div>
  );
}
