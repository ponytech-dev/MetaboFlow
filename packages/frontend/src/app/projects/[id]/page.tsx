'use client';

import { useEffect, useState } from 'react';
import { use } from 'react';
import Link from 'next/link';
import {
  Plus,
  AlertCircle,
  FlaskConical,
  Upload,
  Settings2,
  BarChart2,
} from 'lucide-react';
import { buttonVariants } from '@/components/ui/button';
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
} from '@/components/ui/card';
import { getProject, listProjectAnalyses } from '@/lib/api';
import type { Project, ProjectAnalysis } from '@/types/project';
import { cn } from '@/lib/utils';

export default function ProjectOverviewPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);
  const [project, setProject] = useState<Project | null>(null);
  const [analyses, setAnalyses] = useState<ProjectAnalysis[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function load() {
      setLoading(true);
      try {
        const [proj, ans] = await Promise.all([
          getProject(id),
          listProjectAnalyses(id),
        ]);
        setProject(proj);
        setAnalyses(ans.sort((a, b) => (a.created_at < b.created_at ? 1 : -1)));
        setError(null);
      } catch (e) {
        setError(e instanceof Error ? e.message : 'Failed to load project');
      } finally {
        setLoading(false);
      }
    }
    load();
  }, [id]);

  if (loading) {
    return (
      <div className="space-y-4">
        <div className="h-20 rounded-xl bg-card animate-pulse" />
        <div className="h-40 rounded-xl bg-card animate-pulse" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex items-start gap-3 rounded-lg border border-destructive/30 bg-destructive/5 px-4 py-3 text-sm text-destructive">
        <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
        <p>{error}</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Project header */}
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-xl font-semibold">{project?.name}</h1>
          {project?.description && (
            <p className="mt-1 text-sm text-muted-foreground">
              {project.description}
            </p>
          )}
        </div>
        <Link
          href={`/projects/${id}/upload`}
          className={cn(buttonVariants({ size: 'sm' }), 'gap-1.5 shrink-0')}
        >
          <Plus className="h-3.5 w-3.5" />
          New Analysis
        </Link>
      </div>

      {/* Quick nav cards */}
      <div className="grid gap-4 sm:grid-cols-3">
        <QuickNavCard
          href={`/projects/${id}/upload`}
          icon={<Upload className="h-5 w-5" />}
          title="Upload Data"
          description="Add mzML / mzXML files and set sample metadata."
        />
        <QuickNavCard
          href={`/projects/${id}/pipeline`}
          icon={<Settings2 className="h-5 w-5" />}
          title="Pipeline Designer"
          description="Configure engines and parameters for each step."
        />
        <QuickNavCard
          href={`/projects/${id}/results`}
          icon={<BarChart2 className="h-5 w-5" />}
          title="Results"
          description="View features, annotations, pathways and charts."
        />
      </div>

      {/* Analyses list */}
      <div>
        <h2 className="mb-3 text-sm font-medium text-muted-foreground uppercase tracking-wide">
          Analyses ({analyses.length})
        </h2>

        {analyses.length === 0 ? (
          <div className="flex flex-col items-center gap-3 rounded-xl border border-dashed border-border py-12 text-center">
            <FlaskConical className="h-10 w-10 text-muted-foreground/30" />
            <p className="text-sm text-muted-foreground">
              No analyses yet — start by uploading data.
            </p>
            <Link
              href={`/projects/${id}/upload`}
              className={cn(buttonVariants({ size: 'sm' }), 'gap-1.5')}
            >
              <Upload className="h-3.5 w-3.5" />
              Upload Data
            </Link>
          </div>
        ) : (
          <div className="space-y-2">
            {analyses.map((a) => (
              <AnalysisRow key={a.id} analysis={a} projectId={id} />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

function QuickNavCard({
  href,
  icon,
  title,
  description,
}: {
  href: string;
  icon: React.ReactNode;
  title: string;
  description: string;
}) {
  return (
    <Link href={href} className="block group">
      <Card className="h-full transition-shadow hover:shadow-md">
        <CardHeader>
          <div className="flex items-center gap-2 text-primary mb-1">{icon}</div>
          <CardTitle>{title}</CardTitle>
          <CardDescription>{description}</CardDescription>
        </CardHeader>
      </Card>
    </Link>
  );
}

function AnalysisRow({
  analysis,
  projectId,
}: {
  analysis: ProjectAnalysis;
  projectId: string;
}) {
  const href =
    analysis.status === 'completed'
      ? `/projects/${projectId}/results?analysisId=${analysis.id}`
      : analysis.status === 'running'
        ? `/projects/${projectId}/monitor?analysisId=${analysis.id}`
        : `/projects/${projectId}/pipeline?analysisId=${analysis.id}`;

  return (
    <Link
      href={href}
      className="block rounded-xl border border-border bg-card px-4 py-3 transition-shadow hover:shadow-sm group"
    >
      <div className="flex items-center justify-between gap-4">
        <div className="min-w-0 space-y-0.5">
          <div className="flex items-center gap-2">
            <span className="font-mono text-xs text-muted-foreground truncate max-w-[180px]">
              {analysis.id}
            </span>
            {analysis.name && (
              <span className="text-sm font-medium truncate">{analysis.name}</span>
            )}
          </div>
          <div className="flex flex-wrap items-center gap-3 text-xs text-muted-foreground">
            {analysis.engine && <span>{analysis.engine}</span>}
            {analysis.n_samples > 0 && <span>{analysis.n_samples} samples</span>}
            {analysis.n_features > 0 && (
              <span>{analysis.n_features.toLocaleString()} features</span>
            )}
            <span>{formatDate(analysis.created_at)}</span>
          </div>
        </div>
        <div className="flex items-center gap-3 shrink-0">
          <StatusPill status={analysis.status} />
        </div>
      </div>
    </Link>
  );
}

function StatusPill({ status }: { status: string }) {
  const map: Record<string, { label: string; cls: string; dot?: boolean }> = {
    pending: {
      label: 'Pending',
      cls: 'bg-yellow-100 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-400',
    },
    running: {
      label: 'Running',
      cls: 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400',
      dot: true,
    },
    completed: {
      label: 'Completed',
      cls: 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400',
    },
    failed: {
      label: 'Failed',
      cls: 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400',
    },
  };
  const { label, cls, dot } = map[status] ?? { label: status, cls: '' };
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-xs font-medium',
        cls
      )}
    >
      {dot && (
        <span className="h-1.5 w-1.5 rounded-full bg-current animate-pulse" />
      )}
      {label}
    </span>
  );
}

function formatDate(iso: string): string {
  try {
    return new Date(iso).toLocaleString(undefined, {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    });
  } catch {
    return iso;
  }
}
