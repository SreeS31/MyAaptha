'use client';

import Link from 'next/link';
import { motion } from 'framer-motion';
import { GitBranch, Shield, Users, Zap } from 'lucide-react';

const features = [
  { icon: GitBranch, title: 'Unlimited Trees', desc: 'Family, office, community — any circle, any depth.' },
  { icon: Users, title: 'Smart Relationships', desc: 'Auto-inferred kinship paths and duplicate detection.' },
  { icon: Shield, title: 'Enterprise ACL', desc: 'Fine-grained permissions at tree, branch, and node level.' },
  { icon: Zap, title: 'Cross-Platform', desc: 'Web, PWA, Android, and iOS from one platform.' },
];

export default function HomePage() {
  return (
    <div className="relative min-h-screen overflow-hidden">
      <div className="pointer-events-none absolute inset-0 bg-gradient-to-br from-purple-50 via-white to-blue-50 dark:from-gray-950 dark:via-gray-900 dark:to-purple-950" />
      <div className="relative mx-auto max-w-6xl px-6 py-16">
        <motion.header
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          className="flex items-center justify-between"
        >
          <div className="flex items-center gap-2">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-purple-600 text-white font-bold">C</div>
            <span className="text-xl font-bold">MyAaptha</span>
          </div>
          <nav className="flex gap-4">
            <Link href="/login" className="text-sm font-medium text-gray-600 hover:text-purple-600 dark:text-gray-300">Sign in</Link>
            <Link href="/register" className="btn-primary">Get Started</Link>
          </nav>
        </motion.header>

        <motion.section
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1 }}
          className="mt-24 text-center"
        >
          <h1 className="text-5xl font-bold tracking-tight sm:text-6xl">
            Your relationships,
            <span className="bg-gradient-to-r from-purple-600 to-blue-600 bg-clip-text text-transparent"> visualized</span>
          </h1>
          <p className="mx-auto mt-6 max-w-2xl text-lg text-gray-600 dark:text-gray-400">
            Enterprise-grade network management for families, communities, and organizations.
            Unlimited circles, intelligent kinship engine, and beautiful interactive trees.
          </p>
          <div className="mt-10 flex justify-center gap-4">
            <Link href="/dashboard" className="btn-primary px-8 py-3 text-base">Open Dashboard</Link>
            <Link href="/login" className="inline-flex items-center rounded-xl border border-gray-200 px-8 py-3 text-base font-semibold hover:bg-gray-50 dark:border-gray-700 dark:hover:bg-gray-800">
              View Demo
            </Link>
          </div>
        </motion.section>

        <div className="mt-24 grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
          {features.map((f, i) => (
            <motion.div
              key={f.title}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.2 + i * 0.1 }}
              className="glass-card p-6"
            >
              <f.icon className="h-8 w-8 text-purple-600" />
              <h3 className="mt-4 font-semibold">{f.title}</h3>
              <p className="mt-2 text-sm text-gray-600 dark:text-gray-400">{f.desc}</p>
            </motion.div>
          ))}
        </div>
      </div>
    </div>
  );
}
