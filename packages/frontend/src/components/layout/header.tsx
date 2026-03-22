'use client';

import Link from 'next/link';
import { Badge } from '@/components/ui/badge';

export function Header() {
  return (
    <header className="sticky top-0 z-50 w-full border-b border-border/40 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
      <div className="mx-auto flex h-14 max-w-screen-xl items-center px-6">
        {/* Logo */}
        <Link href="/" className="flex items-center gap-2 font-semibold">
          <div className="flex h-7 w-7 items-center justify-center rounded-md bg-blue-600 text-white text-xs font-bold">
            M
          </div>
          <span className="text-base font-bold tracking-tight">
            MetaboFlow
          </span>
          <Badge variant="secondary" className="ml-1 text-[10px] px-1.5 py-0">
            beta
          </Badge>
        </Link>

        {/* Nav */}
        <nav className="ml-8 flex items-center gap-6 text-sm text-muted-foreground">
          <Link
            href="/projects"
            className="transition-colors hover:text-foreground"
          >
            Projects
          </Link>
          <Link
            href="/analysis/new"
            className="transition-colors hover:text-foreground"
          >
            Quick Analysis
          </Link>
          <Link href="/analyses" className="transition-colors hover:text-foreground">
            History
          </Link>
          <Link href="#" className="transition-colors hover:text-foreground">
            Docs
          </Link>
        </nav>

        {/* Right side spacer */}
        <div className="ml-auto flex items-center gap-2">
          <span className="text-xs text-muted-foreground">
            v0.1.0
          </span>
        </div>
      </div>
    </header>
  );
}
