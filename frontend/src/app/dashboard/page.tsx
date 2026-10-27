'use client';

import Link from 'next/link';
import { useMemo, useRef, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api, ApiResponse } from '@/lib/api';
import { useSelector } from 'react-redux';
import { RootState } from '@/store';
import { Activity, Bell, FileUp, GitBranch, Plus, Users } from 'lucide-react';
import { CartesianGrid, Line, LineChart, ReferenceArea, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';

interface DashboardStats { totalCircles: number; totalMembers: number; pendingInvitations: number; }
interface Circle { id: string; name: string; category: string; nodeCount: number; healthScore: number; }
interface Result { id: number; panelName?: string; testName: string; value: number; unit?: string; referenceLow?: number; referenceHigh?: number; status: 'LOW' | 'NORMAL' | 'HIGH' | 'UNKNOWN'; suggestion?: string; }
interface Report { id: string; reportDate: string; fileName: string; labName?: string; summary: string; results: Result[]; }
interface TrendPoint { date: string; value: number; referenceLow?: number; referenceHigh?: number; status: string; reportId: string; }
interface TestTrend { normalizedName: string; testName: string; unit?: string; points: TrendPoint[]; }
interface HealthHistory { reports: Report[]; trends: TestTrend[]; }

export default function DashboardPage() {
  const fullName = useSelector((s: RootState) => s.auth.fullName);
  const queryClient = useQueryClient();
  const fileRef = useRef<HTMLInputElement>(null);
  const [uploadError, setUploadError] = useState('');
  const [selectedTrend, setSelectedTrend] = useState('');
  const { data: stats } = useQuery({ queryKey: ['dashboard'], queryFn: async () => (await api.get<ApiResponse<DashboardStats>>('/api/v1/dashboard')).data.data });
  const { data: circles } = useQuery({ queryKey: ['circles'], queryFn: async () => (await api.get<ApiResponse<{ content: Circle[] }>>('/api/v1/circles')).data.data.content ?? [] });
  const { data: health } = useQuery({ queryKey: ['health-reports'], queryFn: async () => (await api.get<ApiResponse<HealthHistory>>('/api/v1/health-reports')).data.data });
  const upload = useMutation({
    mutationFn: async (file: File) => {
      const form = new FormData();
      form.append('file', file);
      return (await api.post<ApiResponse<Report>>('/api/v1/health-reports', form)).data.data;
    },
    onSuccess: async () => { setUploadError(''); await queryClient.invalidateQueries({ queryKey: ['health-reports'] }); },
    onError: (error: unknown) => {
      const message = (error as { response?: { data?: { error?: { message?: string } } } }).response?.data?.error?.message;
      setUploadError(message || 'The report could not be analyzed. Please try a clearer PDF or image.');
    },
  });
  const trends = health?.trends ?? [];
  const activeTrend = useMemo(() => trends.find(t => t.normalizedName === selectedTrend) ?? trends[0], [trends, selectedTrend]);
  const abnormal = health?.reports.flatMap(r => r.results.map(result => ({ ...result, reportDate: r.reportDate }))).filter(r => r.status === 'HIGH' || r.status === 'LOW').slice(0, 6) ?? [];
  const statCards = [
    { label: 'Circles', value: stats?.totalCircles ?? 0, icon: GitBranch, color: 'text-violet-600' },
    { label: 'Members', value: stats?.totalMembers ?? 0, icon: Users, color: 'text-sky-600' },
    { label: 'Reports', value: health?.reports.length ?? 0, icon: Activity, color: 'text-emerald-600' },
    { label: 'Invitations', value: stats?.pendingInvitations ?? 0, icon: Bell, color: 'text-amber-600' },
  ];

  return <div className="min-h-screen bg-gray-50 dark:bg-gray-950">
    <header className="border-b border-gray-200 bg-white dark:border-gray-800 dark:bg-gray-900">
      <div className="mx-auto flex max-w-7xl items-center justify-between px-4 py-4 sm:px-6">
        <div className="flex items-center gap-2"><div className="flex h-8 w-8 items-center justify-center rounded-md bg-emerald-600 text-sm font-bold text-white">M</div><span className="font-bold">MyAaptha</span></div>
        <span className="text-sm text-gray-600 dark:text-gray-400">Hello, {fullName ?? 'User'}</span>
      </div>
    </header>
    <main className="mx-auto max-w-7xl px-4 py-8 sm:px-6">
      <div className="flex flex-wrap items-center justify-between gap-3"><h1 className="text-2xl font-bold">Dashboard</h1><Link href="/circles/new" className="btn-primary"><Plus className="h-4 w-4" /> New Circle</Link></div>
      <div className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">{statCards.map(s => <div key={s.label} className="glass-card p-5"><div className="flex items-center justify-between"><div><p className="text-sm text-gray-500">{s.label}</p><p className="mt-1 text-2xl font-bold">{s.value}</p></div><s.icon className={`h-7 w-7 ${s.color}`} /></div></div>)}</div>
      <section className="mt-10 border-y border-gray-200 bg-white py-7 dark:border-gray-800 dark:bg-gray-900">
        <div className="flex flex-wrap items-start justify-between gap-4 px-5">
          <div><h2 className="text-lg font-semibold">Health report analysis</h2><p className="mt-1 max-w-2xl text-sm text-gray-500">Upload one complete laboratory report. MyAaptha extracts all numeric parameters and adds them to your dated health history.</p></div>
          <input ref={fileRef} className="hidden" type="file" accept="application/pdf,image/jpeg,image/png" onChange={e => { const file = e.target.files?.[0]; if (file) upload.mutate(file); e.target.value = ''; }} />
          <button className="btn-primary" disabled={upload.isPending} onClick={() => fileRef.current?.click()}><FileUp className="h-4 w-4" /> {upload.isPending ? 'Reading report...' : 'Upload report'}</button>
        </div>
        {uploadError && <p role="alert" className="mx-5 mt-4 rounded-md border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">{uploadError}</p>}
      </section>
      {activeTrend && <section className="mt-8 grid gap-5 lg:grid-cols-[240px_1fr]">
        <div><label htmlFor="trend" className="text-sm font-medium">Tracked parameter</label><select id="trend" className="input-field mt-2" value={activeTrend.normalizedName} onChange={e => setSelectedTrend(e.target.value)}>{trends.map(t => <option key={t.normalizedName} value={t.normalizedName}>{t.testName}</option>)}</select><p className="mt-4 text-xs leading-5 text-gray-500">Values use the reference range printed by the laboratory. Ranges can vary between labs.</p></div>
        <div className="glass-card p-4"><div className="mb-3 flex items-baseline justify-between"><h3 className="font-semibold">{activeTrend.testName}</h3><span className="text-xs text-gray-500">{activeTrend.unit}</span></div><div className="h-72"><ResponsiveContainer width="100%" height="100%"><LineChart data={activeTrend.points}><CartesianGrid strokeDasharray="3 3" stroke="#d1d5db" /><XAxis dataKey="date" tick={{ fontSize: 12 }} /><YAxis domain={['auto', 'auto']} tick={{ fontSize: 12 }} /><Tooltip />{activeTrend.points[0]?.referenceLow != null && activeTrend.points[0]?.referenceHigh != null && <ReferenceArea y1={activeTrend.points[0].referenceLow} y2={activeTrend.points[0].referenceHigh} fill="#10b981" fillOpacity={0.1} />}<Line type="monotone" dataKey="value" stroke="#0f766e" strokeWidth={2.5} dot={{ r: 4 }} /></LineChart></ResponsiveContainer></div></div>
      </section>}
      {abnormal.length > 0 && <section className="mt-9"><h2 className="text-lg font-semibold">Results to review</h2><div className="mt-3 grid gap-3 md:grid-cols-2">{abnormal.map((r, i) => <div className="glass-card p-4" key={`${r.id}-${i}`}><div className="flex items-center justify-between gap-3"><strong className="text-sm">{r.testName}</strong><span className={`rounded px-2 py-1 text-xs font-semibold ${r.status === 'HIGH' ? 'bg-red-100 text-red-700' : 'bg-amber-100 text-amber-800'}`}>{r.value} {r.unit} · {r.status}</span></div><p className="mt-2 text-sm text-gray-600 dark:text-gray-300">{r.suggestion || 'Discuss this result with a qualified healthcare professional.'}</p><p className="mt-2 text-xs text-gray-400">{r.reportDate}</p></div>)}</div><p className="mt-3 text-xs text-gray-500">Informational only. This analysis is not a diagnosis and does not replace professional medical advice.</p></section>}
      <section className="mt-10"><h2 className="text-lg font-semibold">Your Circles</h2><div className="mt-4 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">{(circles ?? []).map(circle => <Link key={circle.id} href={`/circles/${circle.id}/tree`}><div className="glass-card cursor-pointer p-5 transition hover:shadow-lg"><h3 className="font-semibold">{circle.name}</h3><p className="mt-1 text-sm text-gray-500">{circle.category}</p><div className="mt-4 flex gap-4 text-xs text-gray-500"><span>{circle.nodeCount} members</span><span>Health: {circle.healthScore}%</span></div></div></Link>)}{(!circles || circles.length === 0) && <div className="col-span-full border-y border-gray-200 py-8 text-center text-gray-500">No circles yet. Create your first circle to get started.</div>}</div></section>
    </main>
  </div>;
}
