import { describe, expect, it } from 'vitest';

import {
  blendedMonthlyCost,
  getTier,
  GB_PER_TB,
  monthlyCost,
  normaliseMix,
  TIERS,
} from '../storage';

describe('monthlyCost', () => {
  it('returns zero for an empty archive', () => {
    expect(monthlyCost(0, getTier('hot'))).toBe(0);
    expect(monthlyCost(-5, getTier('hot'))).toBe(0);
  });

  it('prices a single-band tier linearly', () => {
    const cold = getTier('cold');
    expect(monthlyCost(1000, cold)).toBeCloseTo(3.9, 6);
    expect(monthlyCost(2000, cold)).toBeCloseTo(7.8, 6);
  });

  it('stays inside the first band below the volume threshold', () => {
    const hot = getTier('hot');
    expect(monthlyCost(1000, hot)).toBeCloseTo(15.8, 6);
  });

  it('applies volume bands progressively, not retroactively', () => {
    const hot = getTier('hot');
    const gb = 100 * GB_PER_TB;
    const expected = 50 * GB_PER_TB * 0.0158 + 50 * GB_PER_TB * 0.0152;
    expect(monthlyCost(gb, hot)).toBeCloseTo(expected, 6);
    // A flat first-band price would be strictly more expensive.
    expect(monthlyCost(gb, hot)).toBeLessThan(gb * 0.0158);
  });

  it('reaches the third band at petabyte scale', () => {
    const hot = getTier('hot');
    const gb = 1000 * GB_PER_TB;
    const expected =
      50 * GB_PER_TB * 0.0158 + 450 * GB_PER_TB * 0.0152 + 500 * GB_PER_TB * 0.0145;
    expect(monthlyCost(gb, hot)).toBeCloseTo(expected, 6);
  });

  it('is monotonic in volume for every tier', () => {
    for (const tier of TIERS) {
      expect(monthlyCost(2 * GB_PER_TB, tier)).toBeGreaterThan(monthlyCost(GB_PER_TB, tier));
    }
  });
});

describe('normaliseMix', () => {
  it('scales an arbitrary mix to sum to one', () => {
    const mix = normaliseMix({ hot: 2, cool: 2, cold: 4, archive: 2 });
    expect(mix.hot + mix.cool + mix.cold + mix.archive).toBeCloseTo(1, 10);
    expect(mix.cold).toBeCloseTo(0.4, 10);
  });

  it('falls back to all-hot when the mix is empty', () => {
    expect(normaliseMix({ hot: 0, cool: 0, cold: 0, archive: 0 })).toEqual({
      hot: 1,
      cool: 0,
      cold: 0,
      archive: 0,
    });
  });
});

describe('blendedMonthlyCost', () => {
  it('matches the single-tier price when all data sits in one tier', () => {
    const gb = 10 * GB_PER_TB;
    const blended = blendedMonthlyCost(gb, { hot: 0, cool: 0, cold: 1, archive: 0 });
    expect(blended).toBeCloseTo(monthlyCost(gb, getTier('cold')), 6);
  });

  it('is cheaper when data moves to colder tiers', () => {
    const gb = 100 * GB_PER_TB;
    const allHot = blendedMonthlyCost(gb, { hot: 1, cool: 0, cold: 0, archive: 0 });
    const mostlyCold = blendedMonthlyCost(gb, { hot: 0.1, cool: 0.2, cold: 0.7, archive: 0 });
    expect(mostlyCold).toBeLessThan(allHot);
  });

  it('treats an unnormalised mix the same as its normalised form', () => {
    const gb = 5 * GB_PER_TB;
    const raw = blendedMonthlyCost(gb, { hot: 1, cool: 2, cold: 7, archive: 0 });
    const normalised = blendedMonthlyCost(gb, { hot: 0.1, cool: 0.2, cold: 0.7, archive: 0 });
    expect(raw).toBeCloseTo(normalised, 6);
  });
});
