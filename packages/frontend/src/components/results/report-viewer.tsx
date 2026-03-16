'use client';

import { useState } from 'react';
import { Download, Printer, ExternalLink, FileText } from 'lucide-react';
import { Button, buttonVariants } from '@/components/ui/button';

interface ReportViewerProps {
  reportUrl: string | null;
  analysisId: string;
}

export function ReportViewer({ reportUrl, analysisId }: ReportViewerProps) {
  const [iframeLoaded, setIframeLoaded] = useState(false);

  if (!reportUrl) {
    return (
      <div className="flex flex-col items-center justify-center gap-3 rounded-lg border border-dashed border-border py-16 text-muted-foreground">
        <FileText className="h-10 w-10 opacity-30" />
        <p className="text-sm">Report not yet available.</p>
      </div>
    );
  }

  function handleDownload() {
    const a = document.createElement('a');
    a.href = reportUrl!;
    a.download = `metaboflow_report_${analysisId}.html`;
    a.click();
  }

  function handlePrint() {
    const iframe = document.getElementById(
      'report-iframe'
    ) as HTMLIFrameElement | null;
    if (iframe?.contentWindow) {
      iframe.contentWindow.print();
    } else {
      window.open(reportUrl!, '_blank')?.print();
    }
  }

  return (
    <div className="space-y-3">
      {/* Toolbar */}
      <div className="flex items-center justify-between">
        <p className="text-sm text-muted-foreground">
          HTML report — rendered inline below.
        </p>
        <div className="flex items-center gap-2">
          <Button variant="outline" size="sm" onClick={handlePrint} className="gap-1.5">
            <Printer className="h-3.5 w-3.5" />
            Print
          </Button>
          <a
            href={reportUrl}
            target="_blank"
            rel="noopener noreferrer"
            className={buttonVariants({ variant: 'outline', size: 'sm' }) + ' gap-1.5'}
          >
            <ExternalLink className="h-3.5 w-3.5" />
            Open
          </a>
          <Button size="sm" onClick={handleDownload} className="gap-1.5">
            <Download className="h-3.5 w-3.5" />
            Download
          </Button>
        </div>
      </div>

      {/* Iframe wrapper */}
      <div className="relative overflow-hidden rounded-lg border border-border bg-white dark:bg-neutral-900">
        {!iframeLoaded && (
          <div className="absolute inset-0 flex items-center justify-center bg-muted/40">
            <div className="flex items-center gap-2 text-sm text-muted-foreground">
              <div className="h-4 w-4 animate-spin rounded-full border-2 border-muted-foreground border-t-transparent" />
              Loading report…
            </div>
          </div>
        )}
        <iframe
          id="report-iframe"
          src={reportUrl}
          className="w-full"
          style={{ height: '70vh', minHeight: '400px' }}
          onLoad={() => setIframeLoaded(true)}
          sandbox="allow-scripts allow-same-origin"
          title={`MetaboFlow Analysis Report ${analysisId}`}
        />
      </div>
    </div>
  );
}
