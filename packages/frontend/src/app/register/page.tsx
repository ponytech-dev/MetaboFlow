'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { register } from '@/lib/auth';

export default function RegisterPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [inviteCode, setInviteCode] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      await register({ email, password, invite_code: inviteCode });
      router.push('/projects');
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Registration failed');
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
            Join the Beta Program
          </h2>
          <p className="text-white/80 text-lg leading-relaxed mb-8">
            MetaboFlow is currently in invite-only beta.
            Enter your invite code to create an account and start analyzing your metabolomics data.
          </p>
          <div className="bg-white/10 backdrop-blur rounded-xl p-5 border border-white/20">
            <p className="text-white/90 text-sm font-medium mb-2">What you get with beta access:</p>
            <ul className="space-y-2 text-white/70 text-sm">
              <li className="flex items-start gap-2">
                <span className="text-[#91D1C2] mt-0.5">&#10003;</span>
                Full pipeline: upload mzML → peak detection → statistics → annotation → figures
              </li>
              <li className="flex items-start gap-2">
                <span className="text-[#91D1C2] mt-0.5">&#10003;</span>
                50 publication-grade chart templates (Nature/Science style)
              </li>
              <li className="flex items-start gap-2">
                <span className="text-[#91D1C2] mt-0.5">&#10003;</span>
                PDF &amp; Word report export with auto-generated Methods
              </li>
              <li className="flex items-start gap-2">
                <span className="text-[#91D1C2] mt-0.5">&#10003;</span>
                Priority support and feature requests
              </li>
            </ul>
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
            <h1 className="text-2xl font-bold text-gray-900 mb-1">Create account</h1>
            <p className="text-gray-500 mb-6">Enter your invite code to get started.</p>

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
                  autoComplete="new-password"
                  required
                  minLength={8}
                  placeholder="At least 8 characters"
                  className="h-11 bg-gray-50 border-gray-200 focus:bg-white"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                />
              </div>
              <div className="space-y-1.5">
                <label htmlFor="invite-code" className="text-sm font-medium text-gray-700">
                  Invite code
                </label>
                <Input
                  id="invite-code"
                  type="text"
                  required
                  placeholder="Paste your invite code here"
                  className="h-11 bg-gray-50 border-gray-200 focus:bg-white font-mono"
                  value={inviteCode}
                  onChange={(e) => setInviteCode(e.target.value)}
                />
                <p className="text-xs text-gray-400">
                  Contact your lab administrator for an invite code.
                </p>
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
                {loading ? 'Creating account...' : 'Create account'}
              </Button>
            </form>

            <div className="mt-6 text-center">
              <p className="text-sm text-gray-500">
                Already have an account?{' '}
                <a href="/login" className="text-[#3C5488] font-medium hover:underline">
                  Sign in
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
