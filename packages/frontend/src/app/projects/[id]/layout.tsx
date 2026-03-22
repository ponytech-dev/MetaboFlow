import Link from 'next/link';
import { cn } from '@/lib/utils';

const STEPS = [
  { label: 'Upload', href: 'upload' },
  { label: 'Pipeline', href: 'pipeline' },
  { label: 'Monitor', href: 'monitor' },
  { label: 'Results', href: 'results' },
  { label: 'Report', href: 'report' },
] as const;

interface Props {
  children: React.ReactNode;
  params: Promise<{ id: string }>;
}

export default async function ProjectLayout({ children, params }: Props) {
  const { id } = await params;

  return (
    <div className="mx-auto max-w-6xl px-6 py-6 space-y-6">
      {/* Step navigation */}
      <nav className="flex items-center gap-1 overflow-x-auto pb-1">
        {STEPS.map((step, idx) => (
          <div key={step.href} className="flex items-center gap-1 shrink-0">
            {idx > 0 && (
              <span className="text-muted-foreground/50 select-none px-1">
                →
              </span>
            )}
            <StepLink id={id} step={step} index={idx + 1} />
          </div>
        ))}
      </nav>

      {children}
    </div>
  );
}

function StepLink({
  id,
  step,
  index,
}: {
  id: string;
  step: (typeof STEPS)[number];
  index: number;
}) {
  return (
    <Link
      href={`/projects/${id}/${step.href}`}
      className={cn(
        'inline-flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-sm font-medium transition-colors',
        'text-muted-foreground hover:text-foreground hover:bg-muted'
      )}
    >
      <span className="flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-muted text-xs font-semibold text-muted-foreground">
        {index}
      </span>
      {step.label}
    </Link>
  );
}
