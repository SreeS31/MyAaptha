import Image from 'next/image';
import Link from 'next/link';
import './home.css';

export default function HomePage() {
  return <main className="product-home">
    <header className="product-nav"><Link href="/" className="product-brand"><Image src="/myaaptha-logo-256.webp" unoptimized width={38} height={38} alt="" priority/>MyAaptha</Link><nav aria-label="Main navigation"><Link href="/auth">Sign in</Link><Link className="btn btn-primary" href="/dashboard">Open dashboard</Link></nav></header>
    <section className="product-intro"><div><p className="eyebrow">YOUR PEOPLE. YOUR MEMORIES.</p><h1>Stay connected to what matters.</h1><p>Bring your relationships, conversations and personal memories together in one place.</p><div className="product-actions"><Link className="btn btn-primary" href="/auth">Get started</Link><a className="btn" href="#explore">Explore MyAaptha</a></div><span className="product-free">Free for all users</span></div>
      <aside className="product-preview" aria-label="How MyAaptha connects your world"><div className="preview-person"><span>You</span></div><div className="preview-branches"><span>Family</span><span>Friends</span><span>Circles</span></div><div className="preview-memory"><span aria-hidden="true">♡</span><div><strong>A moment to remember</strong><p>Your diary. Your choice of audience.</p></div></div></aside>
    </section>
    <section id="explore" className="product-features" aria-label="Explore MyAaptha">
      <article><span className="feature-icon" aria-hidden="true">♧</span><h2>Your relationship tree</h2><p>See your connections and message a generation or a family branch.</p><Link href="/relationship-tree">Explore your tree <span aria-hidden="true">→</span></Link></article>
      <article><span className="feature-icon" aria-hidden="true">✎</span><h2>Diary &amp; memories</h2><p>Save thoughts, photos and documents. Choose who can view each entry.</p><Link href="/feed">Write a memory <span aria-hidden="true">→</span></Link></article>
      <article><span className="feature-icon" aria-hidden="true">✉</span><h2>Conversations &amp; circles</h2><p>Keep personal messages and circle conversations together.</p><Link href="/messages">Open messages <span aria-hidden="true">→</span></Link></article>
    </section>
    <footer className="product-footer"><span>MyAaptha · Your people &amp; memories</span><Link href="/auth">Join your community</Link></footer>
  </main>;
}
