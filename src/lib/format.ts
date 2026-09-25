/** Display helpers shared across the UI. */

const EUR = new Intl.NumberFormat('es-ES', {
  style: 'currency',
  currency: 'EUR',
  maximumFractionDigits: 0,
});

const EUR_PRECISE = new Intl.NumberFormat('es-ES', {
  style: 'currency',
  currency: 'EUR',
  maximumFractionDigits: 2,
});

const NUM = new Intl.NumberFormat('es-ES', { maximumFractionDigits: 1 });

export function formatEur(value: number): string {
  if (!Number.isFinite(value)) return '—';
  return Math.abs(value) < 100 ? EUR_PRECISE.format(value) : EUR.format(value);
}

export function formatNumber(value: number, digits = 1): string {
  if (!Number.isFinite(value)) return '—';
  return new Intl.NumberFormat('es-ES', { maximumFractionDigits: digits }).format(value);
}

/** Render a size given in gigabytes using the largest sensible unit. */
export function formatSize(gb: number): string {
  if (!Number.isFinite(gb)) return '—';
  if (gb >= 1024 * 1024) return `${NUM.format(gb / (1024 * 1024))} PB`;
  if (gb >= 1024) return `${NUM.format(gb / 1024)} TB`;
  if (gb >= 1) return `${NUM.format(gb)} GB`;
  return `${NUM.format(gb * 1024)} MB`;
}

export function formatRatio(ratio: number): string {
  if (!Number.isFinite(ratio)) return '—';
  return `${NUM.format(ratio)}:1`;
}

export function formatPercent(fraction: number): string {
  if (!Number.isFinite(fraction)) return '—';
  return `${NUM.format(fraction * 100)} %`;
}

export function formatMonths(months: number): string {
  if (!Number.isFinite(months)) return 'never';
  if (months < 1) return '< 1 month';
  if (months < 24) return `${NUM.format(months)} months`;
  return `${NUM.format(months / 12)} years`;
}
