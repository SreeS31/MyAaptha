'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useDispatch } from 'react-redux';
import { api, ApiResponse } from '@/lib/api';
import { setCredentials } from '@/features/auth/authSlice';
import { motion } from 'framer-motion';

export default function RegisterPage() {
  const [fullName, setFullName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const dispatch = useDispatch();
  const router = useRouter();

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      const { data } = await api.post<ApiResponse<{ accessToken: string; userId: string; fullName: string }>>(
        '/api/v1/auth/register',
        { fullName, email, password }
      );
      if (data.success) {
        dispatch(setCredentials({
          token: data.data.accessToken,
          userId: data.data.userId,
          fullName: data.data.fullName,
        }));
        router.push('/dashboard');
      }
    } catch {
      setError('Registration failed. Email may already exist.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-purple-50 to-blue-50 px-4 dark:from-gray-950 dark:to-gray-900">
      <motion.div initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }} className="glass-card w-full max-w-md p-8">
        <h1 className="text-2xl font-bold">Create account</h1>
        <p className="mt-2 text-sm text-gray-600 dark:text-gray-400">Start building your relationship networks</p>
        <form onSubmit={handleSubmit} className="mt-8 space-y-4">
          <div>
            <label className="text-sm font-medium">Full name</label>
            <input className="input-field mt-1" value={fullName} onChange={(e) => setFullName(e.target.value)} required />
          </div>
          <div>
            <label className="text-sm font-medium">Email</label>
            <input type="email" className="input-field mt-1" value={email} onChange={(e) => setEmail(e.target.value)} required />
          </div>
          <div>
            <label className="text-sm font-medium">Password</label>
            <input type="password" className="input-field mt-1" value={password} onChange={(e) => setPassword(e.target.value)} minLength={8} required />
          </div>
          {error && <p className="text-sm text-red-600">{error}</p>}
          <button type="submit" className="btn-primary w-full" disabled={loading}>
            {loading ? 'Creating…' : 'Create account'}
          </button>
        </form>
        <p className="mt-6 text-center text-sm text-gray-600">
          Already have an account? <Link href="/login" className="font-medium text-purple-600 hover:underline">Sign in</Link>
        </p>
      </motion.div>
    </div>
  );
}
