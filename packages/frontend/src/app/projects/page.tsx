'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import {
  Plus,
  RefreshCw,
  FolderOpen,
  AlertCircle,
  FlaskConical,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
  CardFooter,
} from '@/components/ui/card';
import { listProjects, createProject } from '@/lib/api';
import type { ProjectSummary } from '@/types/project';
import { cn } from '@/lib/utils';

export default function ProjectsPage() {
  const router = useRouter();
  const [projects, setProjects] = useState<ProjectSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [creating, setCreating] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function fetchProjects() {
    setLoading(true);
    try {
      const data = await listProjects();
      setProjects(data.sort((a, b) => (a.created_at < b.created_at ? 1 : -1)));
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load projects');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    fetchProjects();
  }, []);

  async function handleNewProject() {
    const name = prompt('Project name:');
    if (!name?.trim()) return;
    setCreating(true);
    try {
      const project = await createProject({ name: name.trim() });
      router.push(`/projects/${project.id}/upload`);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to create project');
      setCreating(false);
    }
  }

  return (
    <div className="mx-auto max-w-5xl px-6 py-8 space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-semibold">Projects</h1>
          <p className="mt-0.5 text-sm text-muted-foreground">
            Manage your metabolomics projects.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button
            variant="outline"
            size="sm"
            onClick={fetchProjects}
            disabled={loading}
            className="gap-1.5"
          >
            <RefreshCw className={cn('h-3.5 w-3.5', loading && 'animate-spin')} />
            Refresh
          </Button>
          <Button
            size="sm"
            onClick={handleNewProject}
            disabled={creating}
            className="gap-1.5"
          >
            <Plus className="h-3.5 w-3.5" />
            New Project
          </Button>
        </div>
      </div>

      {/* Error */}
      {error && (
        <div className="flex items-start gap-3 rounded-lg border border-destructive/30 bg-destructive/5 px-4 py-3 text-sm text-destructive">
          <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
          <p>{error}</p>
        </div>
      )}

      {/* Loading skeletons */}
      {loading && !error && (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {[1, 2, 3].map((i) => (
            <div
              key={i}
              className="h-40 rounded-xl border border-border bg-card animate-pulse"
            />
          ))}
        </div>
      )}

      {/* Empty state */}
      {!loading && !error && projects.length === 0 && (
        <div className="flex flex-col items-center justify-center gap-4 rounded-xl border border-dashed border-border py-20 text-center">
          <FolderOpen className="h-12 w-12 text-muted-foreground/30" />
          <div>
            <p className="font-medium">No projects yet</p>
            <p className="mt-1 text-sm text-muted-foreground">
              Create a project to start organizing your analyses.
            </p>
          </div>
          <Button onClick={handleNewProject} disabled={creating} className="gap-1.5">
            <Plus className="h-4 w-4" />
            New Project
          </Button>
        </div>
      )}

      {/* Project cards */}
      {!loading && projects.length > 0 && (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {projects.map((p) => (
            <Link key={p.id} href={`/projects/${p.id}`} className="block group">
              <Card className="h-full transition-shadow hover:shadow-md">
                <CardHeader>
                  <div className="flex items-start justify-between gap-2">
                    <CardTitle className="line-clamp-2">{p.name}</CardTitle>
                    <StatusBadge status={p.status} />
                  </div>
                  {p.description && (
                    <CardDescription className="line-clamp-2">
                      {p.description}
                    </CardDescription>
                  )}
                </CardHeader>
                <CardContent>
                  <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
                    <FlaskConical className="h-3.5 w-3.5" />
                    <span>{p.analysis_count} analyses</span>
                  </div>
                </CardContent>
                <CardFooter className="text-xs text-muted-foreground">
                  {formatDate(p.updated_at)}
                </CardFooter>
              </Card>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}

function StatusBadge({ status }: { status: string }) {
  const map: Record<string, string> = {
    active:
      'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400',
    archived:
      'bg-gray-100 text-gray-600 dark:bg-gray-800/50 dark:text-gray-400',
  };
  return (
    <span
      className={cn(
        'inline-flex shrink-0 items-center rounded-full px-2 py-0.5 text-xs font-medium',
        map[status] ?? 'bg-muted text-muted-foreground'
      )}
    >
      {status}
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
