import type { ReactNode } from 'react';

interface PanelProps {
  title: string;
  subtitle?: string;
  children: ReactNode;
  className?: string;
}

export function Panel({ title, subtitle, children, className = '' }: PanelProps) {
  return (
    <section
      className={`rounded-2xl border border-ink-700/70 bg-ink-900/60 p-5 shadow-lg shadow-black/30 backdrop-blur ${className}`}
    >
      <header className="mb-4">
        <h2 className="text-sm font-semibold tracking-[0.14em] text-signal-500 uppercase">
          {title}
        </h2>
        {subtitle ? <p className="mt-1 text-sm text-ink-400">{subtitle}</p> : null}
      </header>
      {children}
    </section>
  );
}
