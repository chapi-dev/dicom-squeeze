/**
 * Storage tier economics.
 *
 * Prices are Azure Blob Storage LRS list prices for the Spain Central region in
 * EUR per GB/month, retrieved from the Azure Retail Prices API. Hot storage is
 * billed in volume bands, which matters at petabyte scale.
 *
 * These are list prices for planning only. Enterprise agreements, reservations
 * and regional differences will move the real figure.
 */

export const GB_PER_TB = 1024;
export const GB_PER_PB = 1024 * 1024;

export interface PriceBand {
  /** Inclusive lower bound of the band, in GB. */
  fromGb: number;
  /** EUR per GB per month within this band. */
  eurPerGbMonth: number;
}

export interface StorageTier {
  id: string;
  label: string;
  bands: PriceBand[];
  /** Typical time to first byte, shown to explain the clinical trade-off. */
  retrievalLatency: string;
  /** Whether a PACS can read directly from this tier without rehydration. */
  onlineAccess: boolean;
}

export const TIERS: StorageTier[] = [
  {
    id: 'hot',
    label: 'Hot',
    bands: [
      { fromGb: 0, eurPerGbMonth: 0.0158 },
      { fromGb: 50 * GB_PER_TB, eurPerGbMonth: 0.0152 },
      { fromGb: 500 * GB_PER_TB, eurPerGbMonth: 0.0145 },
    ],
    retrievalLatency: 'milliseconds',
    onlineAccess: true,
  },
  {
    id: 'cool',
    label: 'Cool',
    bands: [{ fromGb: 0, eurPerGbMonth: 0.0086 }],
    retrievalLatency: 'milliseconds',
    onlineAccess: true,
  },
  {
    id: 'cold',
    label: 'Cold',
    bands: [{ fromGb: 0, eurPerGbMonth: 0.0039 }],
    retrievalLatency: 'milliseconds',
    onlineAccess: true,
  },
  {
    id: 'archive',
    label: 'Archive',
    bands: [{ fromGb: 0, eurPerGbMonth: 0.0015 }],
    retrievalLatency: 'hours (rehydration required)',
    onlineAccess: false,
  },
];

export function getTier(id: string): StorageTier {
  const tier = TIERS.find((t) => t.id === id);
  if (!tier) throw new Error(`Unknown storage tier: ${id}`);
  return tier;
}

/**
 * Monthly cost in EUR of holding `gb` gigabytes in a tier, honouring volume bands.
 */
export function monthlyCost(gb: number, tier: StorageTier): number {
  if (gb <= 0) return 0;
  const bands = [...tier.bands].sort((a, b) => a.fromGb - b.fromGb);

  let cost = 0;
  for (let i = 0; i < bands.length; i++) {
    const band = bands[i];
    if (gb <= band.fromGb) break;
    const next = bands[i + 1];
    const upper = next ? Math.min(gb, next.fromGb) : gb;
    cost += (upper - band.fromGb) * band.eurPerGbMonth;
  }
  return cost;
}

/** Distribution of data across tiers. Values are fractions that must sum to 1. */
export interface TierMix {
  hot: number;
  cool: number;
  cold: number;
  archive: number;
}

export const DEFAULT_TIER_MIX: TierMix = {
  hot: 0.1,
  cool: 0.2,
  cold: 0.7,
  archive: 0,
};

export function normaliseMix(mix: TierMix): TierMix {
  const total = mix.hot + mix.cool + mix.cold + mix.archive;
  if (total <= 0) return { hot: 1, cool: 0, cold: 0, archive: 0 };
  return {
    hot: mix.hot / total,
    cool: mix.cool / total,
    cold: mix.cold / total,
    archive: mix.archive / total,
  };
}

/**
 * Monthly cost in EUR of `gb` gigabytes spread across a tier mix.
 */
export function blendedMonthlyCost(gb: number, mix: TierMix): number {
  const m = normaliseMix(mix);
  return (
    monthlyCost(gb * m.hot, getTier('hot')) +
    monthlyCost(gb * m.cool, getTier('cool')) +
    monthlyCost(gb * m.cold, getTier('cold')) +
    monthlyCost(gb * m.archive, getTier('archive'))
  );
}
