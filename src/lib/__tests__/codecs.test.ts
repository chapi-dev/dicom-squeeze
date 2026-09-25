import { describe, expect, it } from 'vitest';

import { CODECS, getCodec } from '../codecs';

describe('CODECS', () => {
  it('exposes a unique id for every codec', () => {
    const ids = CODECS.map((c) => c.id);
    expect(new Set(ids).size).toBe(ids.length);
  });

  it('uses unique DICOM transfer syntax UIDs', () => {
    const uids = CODECS.map((c) => c.uid);
    expect(new Set(uids).size).toBe(uids.length);
  });

  it('declares UIDs inside the DICOM root', () => {
    for (const codec of CODECS) {
      expect(codec.uid).toMatch(/^1\.2\.840\.10008\.1\.2(\.\d+)*$/);
    }
  });

  it('keeps minRatio below or equal to maxRatio', () => {
    for (const codec of CODECS) {
      expect(codec.minRatio).toBeLessThanOrEqual(codec.maxRatio);
      expect(codec.minRatio).toBeGreaterThanOrEqual(1);
    }
  });

  it('treats the uncompressed baseline as a 1:1 ratio', () => {
    const baseline = getCodec('explicit-vr-le');
    expect(baseline.kind).toBe('uncompressed');
    expect(baseline.minRatio).toBe(1);
    expect(baseline.maxRatio).toBe(1);
  });

  it('marks every lossy codec as not diagnostically accepted by default', () => {
    for (const codec of CODECS.filter((c) => c.kind === 'lossy')) {
      expect(codec.diagnosticallyAccepted).toBe(false);
    }
  });

  it('marks every lossless codec as diagnostically accepted', () => {
    for (const codec of CODECS.filter((c) => c.kind !== 'lossy')) {
      expect(codec.diagnosticallyAccepted).toBe(true);
    }
  });

  it('throws on an unknown codec id', () => {
    expect(() => getCodec('not-a-codec')).toThrow(/Unknown codec/);
  });
});
