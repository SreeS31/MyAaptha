import Link from 'next/link';

export default function NotFound() {
  return (
    <main className="container empty-state">
      <div className="card" style={{ maxWidth: '32rem' }}>
        <p className="eyebrow">ERROR 404</p>
        <h1 style={{ marginTop: '.5rem', fontSize: 'var(--text-size)' }}>This page drifted out of the circle.</h1>
        <p style={{ color: '#64748b' }}>The page you requested could not be found.</p>
        <Link href="/" className="btn btn-primary">
          Back home
        </Link>
      </div>
    </main>
  );
}
