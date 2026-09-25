import { describe, expect, it } from 'vitest';

import { getCodec } from '../codecs';
import { effectiveRatio, estimate, paybackMonths, transcodeCost } from '../estimate';
import { MODALITIES } from '../modalities';
import { DEFAULT_TIER_MIX, GB_PER_PB } from '../storage';

const baseInput = {
  archivePb: 3,
  studiesPerYear: 250_000,
  codecId: 'jpeg-ls',
  tierMix: DEFAULT_TIER_MIX,
  retentionYears: 15,
};

describe('effectiveRatio', () => {
  it('keeps the uncompressed baseline at 1:1', () => {
    const ratio = effectiveRatio(getCodec('explicit-vr-le'));
    expect(ratio.min).toBe(1);
    expect(ratio.max).toBe(1);
    expect(ratio.expected).toBe(1);
  });

  it('places the expected ratio between min and max', () => {
    const ratio = effectiveRatio(getCodec('htj2k-lossless'));
    expect(ratio.expected).toBeGreaterThanOrEqual(ratio.min);
    expect(ratio.expected).toBeLessThanOrEqual(ratio.max);
  });

  it('stays close to the declared codec ratio for a balanced mix', () => {
    const codec = getCodec('jpeg-ls');
    const ratio = effectiveRatio(codec);
    expect(ratio.min).toBeGreaterThan(codec.minRatio * 0.85);
    expect(ratio.max).toBeLessThan(codec.maxRatio * 1.2);
  });

  it('rewards a highly compressible modality mix', () => {
    const codec = getCodec('jpeg-ls');
    const projection = MODALITIES.filter((m) => m.code === 'CR/DX');
    const crossSectional = MODALITIES.filter((m) => m.code === 'MR');
    expect(effectiveRatio(codec, projection).expected).toBeGreaterThan(
      effectiveRatio(codec, crossSectional).expected,
    );
  });

  it('falls back to the raw ratio for an empty modality list', () => {
    const codec = getCodec('jpeg-ls');
    const ratio = effectiveRatio(codec, []);
    expect(ratio.min).toBe(codec.minRatio);
    expect(ratio.max).toBe(codec.maxRatio);
  });
});

describe('estimate', () => {
  it('converts petabytes to gigabytes for the current archive', () => {
    const result = estimate(baseInput);
    expect(result.currentGb.before).toBe(3 * GB_PER_PB);
  });

  it('shrinks the archive by the effective ratio', () => {
    const result = estimate(baseInput);
    expect(result.currentGb.after).toBeCloseTo(
      result.currentGb.before / result.ratio.expected,
      6,
    );
    expect(result.currentGb.after).toBeLessThan(result.currentGb.before);
  });

  it('saves nothing when the baseline codec is selected', () => {
    const result = estimate({ ...baseInput, codecId: 'explicit-vr-le' });
    expect(result.currentGb.after).toBeCloseTo(result.currentGb.before, 6);
    expect(result.monthlyCost.saved).toBeCloseTo(0, 6);
    expect(result.reclaimedGb).toBeCloseTo(0, 6);
  });

  it('never reports a negative saving for a lossless codec', () => {
    for (const codecId of ['rle', 'jpeg-ls', 'jpeg2000-lossless', 'htj2k-lossless']) {
      expect(estimate({ ...baseInput, codecId }).monthlyCost.saved).toBeGreaterThan(0);
    }
  });

  it('keeps annual cost exactly twelve times the monthly cost', () => {
    const result = estimate(baseInput);
    expect(result.annualCost.before).toBeCloseTo(result.monthlyCost.before * 12, 6);
    expect(result.annualCost.saved).toBeCloseTo(result.monthlyCost.saved * 12, 6);
  });

  it('grows the projection with the retention horizon', () => {
    const short = estimate({ ...baseInput, retentionYears: 5 });
    const long = estimate({ ...baseInput, retentionYears: 30 });
    expect(long.projectedGb.before).toBeGreaterThan(short.projectedGb.before);
    expect(long.projectedAnnualSaved).toBeGreaterThan(short.projectedAnnualSaved);
  });

  it('leaves the projection equal to the current archive with no growth', () => {
    const result = estimate({ ...baseInput, studiesPerYear: 0 });
    expect(result.projectedGb.before).toBeCloseTo(result.currentGb.before, 6);
    expect(result.annualGrowthGb).toBe(0);
  });

  it('saves more with a stronger codec', () => {
    const rle = estimate({ ...baseInput, codecId: 'rle' });
    const htj2k = estimate({ ...baseInput, codecId: 'htj2k-lossless' });
    expect(htj2k.monthlyCost.saved).toBeGreaterThan(rle.monthlyCost.saved);
  });

  it('costs more on a hot-only tier mix than on the default mix', () => {
    const hot = estimate({
      ...baseInput,
      tierMix: { hot: 1, cool: 0, cold: 0, archive: 0 },
    });
    const mixed = estimate(baseInput);
    expect(hot.monthlyCost.before).toBeGreaterThan(mixed.monthlyCost.before);
  });

  it('handles an empty archive without dividing by zero', () => {
    const result = estimate({ ...baseInput, archivePb: 0, studiesPerYear: 0 });
    expect(result.currentGb.after).toBe(0);
    expect(result.monthlyCost.saved).toBe(0);
    expect(Number.isFinite(result.ratio.expected)).toBe(true);
  });

  it('rejects an unknown codec', () => {
    expect(() => estimate({ ...baseInput, codecId: 'zip' })).toThrow(/Unknown codec/);
  });
});

describe('transcodeCost and paybackMonths', () => {
  it('prices the transcode linearly and clamps negatives', () => {
    expect(transcodeCost(1000, 0.01)).toBeCloseTo(10, 6);
    expect(transcodeCost(-1000, 0.01)).toBe(0);
  });

  it('never pays back when the codec saves nothing', () => {
    const result = estimate({ ...baseInput, codecId: 'explicit-vr-le' });
    expect(paybackMonths(result)).toBe(Infinity);
  });

  it('pays back a lossless transcode within the retention horizon', () => {
    const result = estimate(baseInput);
    const months = paybackMonths(result);
    expect(months).toBeGreaterThan(0);
    expect(months).toBeLessThan(baseInput.retentionYears * 12);
  });
});
