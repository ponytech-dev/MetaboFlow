'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { login } from '@/lib/auth';

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      await login({ email, password });
      router.push('/projects');
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Login failed');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="flex min-h-screen">
      {/* Left brand panel */}
      <div className="hidden lg:flex lg:w-1/2 bg-gradient-to-br from-[#3C5488] via-[#4DBBD5] to-[#00A087] items-center justify-center p-12">
        <div className="max-w-md text-white">
          <div className="flex items-center gap-3 mb-8">
            <div className="w-12 h-12 rounded-xl bg-white/20 backdrop-blur flex items-center justify-center text-2xl font-bold">
              M
            </div>
            <span className="text-3xl font-bold tracking-tight">MetaboFlow</span>
          </div>
          <h2 className="text-2xl font-semibold mb-4">
            Multi-Engine Metabolomics Analysis Platform
          </h2>
          <p className="text-white/80 text-lg leading-relaxed mb-8">
            From raw mzML to publication-ready figures in one workflow.
            50 chart templates, automated reports, and multi-engine comparison.
          </p>
          <div className="space-y-3 text-white/70">
            <div className="flex items-center gap-3">
              <svg className="w-5 h-5 text-white/90" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <span>XCMS + MZmine + MS-DIAL engine support</span>
            </div>
            <div className="flex items-center gap-3">
              <svg className="w-5 h-5 text-white/90" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <span>Nature-grade figures with one click</span>
            </div>
            <div className="flex items-center gap-3">
              <svg className="w-5 h-5 text-white/90" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <span>MFSL spectral library: 960K compounds</span>
            </div>
            <div className="flex items-center gap-3">
              <svg className="w-5 h-5 text-white/90" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <span>PDF &amp; Word reports with auto Methods</span>
            </div>
          </div>
        </div>
      </div>

      {/* Right form panel */}
      <div className="flex w-full lg:w-1/2 items-center justify-center p-8 bg-gray-50">
        <div className="w-full max-w-md">
          {/* Mobile logo */}
          <div className="lg:hidden flex items-center gap-2 mb-8 justify-center">
            <div className="w-10 h-10 rounded-lg bg-[#3C5488] flex items-center justify-center text-white text-xl font-bold">
              M
            </div>
            <span className="text-2xl font-bold text-gray-900">MetaboFlow</span>
          </div>

          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-8">
            <h1 className="text-2xl font-bold text-gray-900 mb-1">Welcome back</h1>
            <p className="text-gray-500 mb-6">Sign in to your account to continue.</p>

            <form onSubmit={handleSubmit} className="space-y-5">
              <div className="space-y-1.5">
                <label htmlFor="email" className="text-sm font-medium text-gray-700">
                  Email
                </label>
                <Input
                  id="email"
                  type="email"
                  autoComplete="email"
                  required
                  placeholder="you@lab.edu"
                  className="h-11 bg-gray-50 border-gray-200 focus:bg-white"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                />
              </div>
              <div className="space-y-1.5">
                <label htmlFor="password" className="text-sm font-medium text-gray-700">
                  Password
                </label>
                <Input
                  id="password"
                  type="password"
                  autoComplete="current-password"
                  required
                  className="h-11 bg-gray-50 border-gray-200 focus:bg-white"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                />
              </div>
              {error && (
                <div className="bg-red-50 text-red-700 text-sm px-4 py-2.5 rounded-lg border border-red-100">
                  {error}
                </div>
              )}
              <Button
                type="submit"
                className="w-full h-11 bg-[#3C5488] hover:bg-[#2d3f66] text-white font-medium"
                disabled={loading}
              >
                {loading ? 'Signing in...' : 'Sign in'}
              </Button>
            </form>

            <div className="mt-6 text-center">
              <p className="text-sm text-gray-500">
                Don&apos;t have an account?{' '}
                <a href="/register" className="text-[#3C5488] font-medium hover:underline">
                  Request access
                </a>
              </p>
            </div>
          </div>

          <p className="mt-6 text-center text-xs text-gray-400">
            MetaboFlow v0.1.0 Beta — Invite-only access
          </p>
        </div>
      </div>
    </div>
  );
}
