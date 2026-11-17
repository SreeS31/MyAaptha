import Link from 'next/link';
import type {Route} from 'next';
import {menuMoves} from '../lib/workspace-navigation';
export default function WorkspaceTools(){return <main className="navigation-review"><header><h1>Account & tools</h1></header><section className="navigation-overview">{menuMoves.filter(move=>move.destination.startsWith('Account & tools')).map(move=><Link key={move.href} href={move.href as Route}><strong>{move.old}</strong></Link>)}</section></main>}
