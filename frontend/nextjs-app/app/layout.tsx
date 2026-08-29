import './globals.css';
import type { Metadata } from 'next';
import WorkspaceShell from './components/WorkspaceShell';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: {
    default: 'MyAaptha Intelligence Cloud',
    template: '%s | MyAaptha'
  },
  description: 'Enterprise relationship intelligence, project delivery and team analytics in one connected workspace.',
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
