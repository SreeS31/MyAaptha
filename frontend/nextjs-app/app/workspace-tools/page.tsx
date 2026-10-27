import Link from 'next/link';
import type {Route} from 'next';
import {menuMoves} from '../lib/workspace-navigation';
export default function WorkspaceTools(){return <main className="navigation-review"><header><small>YOUR ACCOUNT</small><h1>Account & tools</h1></header><section className="navigation-overview">{menuMoves.filter(move=>move.destination.startsWith('Account & tools')).map(move=><Link key={move.href} href={move.href as Route}><strong>{move.old}</strong><small>Open {move.old.toLowerCase()}</small></Link>)}<Link href={'/menu-comparison' as Route}><strong>Menu comparison</strong><small>Review every old and new location</small></Link></section></main>}
