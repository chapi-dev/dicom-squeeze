import { describe, expect, it } from 'vitest';

import { blendedStudyMb, getModality, MODALITIES } from '../modalities';

describe('MODALITIES', () => {
  it('uses unique modality codes', () => {
    const codes = MODALITIES.map((m) => m.code);
    expect(new Set(codes).size).toBe(codes.length);
  });

  it('declares a study mix that sums to one', () => {
    const total = MODALITIES.reduce((sum, m) => sum + m.typicalMix, 0);
    expect(total).toBeCloseTo(1, 6);
  });

  it('keeps every average study size positive', () => {
    for (const modality of MODALITIES) {
      expect(modality.avgStudyMb).toBeGreaterThan(0);
      expect(modality.compressibility).toBeGreaterThan(0);
    }
  });

  it('throws on an unknown modality code', () => {
    expect(() => getModality('XA')).toThrow(/Unknown modality/);
  });

  it('resolves a known modality code', () => {
    expect(getModality('CT').label).toMatch(/computed tomography/i);
  });
});

describe('blendedStudyMb', () => {
  it('returns zero for an empty mix', () => {
    expect(blendedStudyMb([])).toBe(0);
  });

  it('returns the study size itself for a single modality', () => {
    const ct = getModality('CT');
    expect(blendedStudyMb([ct])).toBeCloseTo(ct.avgStudyMb, 6);
  });

  it('sits between the smallest and largest modality', () => {
    const blended = blendedStudyMb();
    const sizes = MODALITIES.map((m) => m.avgStudyMb);
    expect(blended).toBeGreaterThan(Math.min(...sizes));
    expect(blended).toBeLessThan(Math.max(...sizes));
  });

  it('ignores absolute weights and uses only their proportions', () => {
    const doubled = MODALITIES.map((m) => ({ ...m, typicalMix: m.typicalMix * 2 }));
    expect(blendedStudyMb(doubled)).toBeCloseTo(blendedStudyMb(), 6);
  });
});
