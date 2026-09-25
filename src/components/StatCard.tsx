interface StatCardProps {
  label: string;
  value: string;
  caption?: string;
  tone?: 'neutral' | 'good' | 'warn' | 'danger';
}

const TONE: Record<NonNullable<StatCardProps['tone']>, string> = {
  neutral: 'text-ink-100',
  good: 'text-good-500',
  warn: 'text-warn-500',
  danger: 'text-danger-500',
};

export function StatCard({ label, value, caption, tone = 'neutral' }: StatCardProps) {
  return (
    <div className="rounded-xl border border-ink-700/70 bg-ink-800/40 p-4">
      <p className="text-[11px] font-semibold tracking-[0.12em] text-ink-400 uppercase">
        {label}
      </p>
      <p className={`mt-2 font-mono text-2xl leading-none font-semibold ${TONE[tone]}`}>
        {value}
      </p>
      {caption ? <p className="mt-2 text-xs text-ink-400">{caption}</p> : null}
    </div>
  );
}
