import { describe, expect, it } from 'vitest';

import {
  formatEur,
  formatMonths,
  formatNumber,
  formatPercent,
  formatRatio,
  formatSize,
} from '../format';

describe('formatSize', () => {
  it('picks the largest sensible unit', () => {
    expect(formatSize(0.5)).toBe('512 MB');
    expect(formatSize(12)).toBe('12 GB');
    expect(formatSize(2048)).toBe('2 TB');
    expect(formatSize(3 * 1024 * 1024)).toBe('3 PB');
  });

  it('renders a dash for non-finite input', () => {
    expect(formatSize(Number.NaN)).toBe('—');
    expect(formatSize(Infinity)).toBe('—');
  });
});

describe('formatEur', () => {
  it('drops decimals on large amounts and keeps them on small ones', () => {
    expect(formatEur(125_000)).not.toMatch(/,\d\d/);
    expect(formatEur(4.5)).toMatch(/4,50/);
  });

  it('renders a dash for non-finite input', () => {
    expect(formatEur(Number.NaN)).toBe('—');
  });
});

describe('formatMonths', () => {
  it('describes the payback horizon in human terms', () => {
    expect(formatMonths(0.4)).toBe('< 1 month');
    expect(formatMonths(6)).toBe('6 months');
    expect(formatMonths(36)).toBe('3 years');
    expect(formatMonths(Infinity)).toBe('never');
  });
});

describe('formatRatio, formatPercent and formatNumber', () => {
  it('suffixes ratios with :1', () => {
    expect(formatRatio(2.75)).toBe('2,8:1');
    expect(formatRatio(Number.NaN)).toBe('—');
  });

  it('scales fractions to percentages', () => {
    expect(formatPercent(0.25)).toBe('25 %');
    expect(formatPercent(Number.NaN)).toBe('—');
  });

  it('honours the requested precision', () => {
    expect(formatNumber(1234.567, 0)).toBe('1235');
    expect(formatNumber(Number.NaN)).toBe('—');
  });
});
