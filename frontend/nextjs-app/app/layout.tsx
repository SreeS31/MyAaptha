import './globals.css';
import './design-system.css';
import './workspace-layout.css';
import './content-width.css';
import './messaging-workspace.css';
import './core-services.css';
import './professional.css';
import './navigation.css';
import './compact-workspace.css';
import './enterprise-workspace.css';
import './ui-foundation.css';
import type { Metadata } from 'next';
import WorkspaceShell from './components/WorkspaceShell';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: {
    default: 'MyAaptha',
    template: '%s | MyAaptha'
  },
  description: 'Your people, memories, personal records and conversations in one connected workspace.',
  icons: {
    icon: '/favicon.png',
    apple: '/myaaptha-logo.png'
  }
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body><WorkspaceShell>{children}</WorkspaceShell></body>
    </html>
  );
}
