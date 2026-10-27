// Shared stroke icons avoid platform-dependent symbol and emoji rendering.
const paths:Record<string,string>={
 '/dashboard':'M3 10 12 3l9 7M5 9v12h5v-7h4v7h5V9',
 '/relationship-tree':'M9 3h6v5H9zM2 16h6v5H2zM16 16h6v5h-6zM12 8v4M5 16v-4h14v4',
 '/feed':'M4 3h12a3 3 0 0 1 3 3v15H7a3 3 0 0 1-3-3V3ZM4 17h15M8 7h7M8 11h5',
 '/health':'M20 5a5 5 0 0 0-8 1 5 5 0 0 0-8-1c-3 3-1 7 8 15 9-8 11-12 8-15Z',
 '/finance':'M3 6h16v15H3V6Zm0 0 13-3v3M15 11h6v5h-6v-5Zm2 2.5h1',
 '/career':'M3 7h18v14H3V7Zm5 0V3h8v4M3 12h18M10 12v3h4v-3',
 '/interests':'m12 3 2.6 5.7 6.4.8-4.7 4.4 1.2 6.3-5.5-3-5.5 3 1.2-6.3L3 9.5l6.4-.8L12 3Z',
 '/messages':'M3 3h18v14H8l-5 4V3Zm4 5h10M7 12h7',
 '/online-feed':'M4 16v5h5M4 11a10 10 0 0 1 10 10M4 4a17 17 0 0 1 17 17',
 '/contacts':'M4 21v-3a6 6 0 0 1 12 0v3M10 3a4 4 0 1 0 0 8 4 4 0 0 0 0-8ZM18 4a4 4 0 0 1 0 7M19 15a5 5 0 0 1 3 5',
 '/help':'M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20ZM9 8a3 3 0 1 1 4 3c-1 .5-1 1-1 3M12 17h.01',
 '/settings':'M3 6h7M14 6h7M10 3v6M3 12h13M20 12h1M16 9v6M3 18h3M10 18h11M6 15v6',
 '/menu-comparison':'M3 7h18l-4-4M21 17H3l4 4',
 '/security-reports':'m12 2 9 4v6c0 5-5 8-9 10-4-2-9-5-9-10V6l9-4Zm0 5v6M12 16h.01',
 menu:'M4 6h16M4 12h16M4 18h16',
 search:'M10 17a7 7 0 1 0 0-14 7 7 0 0 0 0 14Zm5-2 6 6',
 logout:'M9 3H3v18h6M8 12h13l-5-5M21 12l-5 5',
};
export default function WorkspaceIcon({name}:{name:string}){
 const key=name.split('#')[0];
 return <svg className="workspace-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" focusable="false"><path d={paths[key]||paths['/settings']}/></svg>;
}
