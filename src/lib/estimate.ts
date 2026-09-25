/**
 * The estimation engine. Pure functions only, so the whole model is unit tested
 * without touching React.
 */

import { getCodec, type Codec } from './codecs';
import { blendedStudyMb, MODALITIES, type Modality } from './modalities';
import { blendedMonthlyCost, GB_PER_PB, type TierMix } from './storage';

export interface EstimateInput {
  /** Archive size today, in petabytes. */
  archivePb: number;
  /** New studies acquired per year. */
  studiesPerYear: number;
  /** Codec the archive is being transcoded to. */
  codecId: string;
  /** How the data is distributed across storage tiers. */
  tierMix: TierMix;
  /** Retention horizon in years, used to project growth. */
  retentionYears: number;
  /** Modality mix driving the average study size. */
  modalities?: readonly Modality[];
}

export interface RatioRange {
  min: number;
  max: number;
  expected: number;
}

export interface EstimateResult {
  codec: Codec;
  /** Effective compression ratio after modality weighting. */
  ratio: RatioRange;
  /** Current archive in GB, before and after transcoding. */
  currentGb: { before: number; after: number };
  /** Projected archive at the end of the retention horizon, in GB. */
  projectedGb: { before: number; after: number };
  /** Monthly storage cost in EUR for the current archive. */
  monthlyCost: { before: number; after: number; saved: number };
  /** Annual storage cost in EUR for the current archive. */
  annualCost: { before: number; after: number; saved: number };
  /** Annual saving in EUR once the archive reaches the retention horizon. */
  projectedAnnualSaved: number;
  /** Bytes reclaimed on the current archive. */
  reclaimedGb: number;
  /** Average uncompressed study size in MB for the configured mix. */
  avgStudyMb: number;
  /** Annual growth in GB before compression. */
  annualGrowthGb: number;
}

/**
 * Weighted compression ratio for a codec across a modality mix.
 *
 * Each modality scales the codec's raw ratio by its own compressibility, then
 * modalities are weighted by their share of the study mix by *volume*, not by
 * study count, because a single tomosynthesis study outweighs many radiographs.
 */
export function effectiveRatio(
  codec: Codec,
  modalities: readonly Modality[] = MODALITIES,
): RatioRange {
  const totalVolume = modalities.reduce((sum, m) => sum + m.avgStudyMb * m.typicalMix, 0);
  if (totalVolume === 0 || codec.minRatio === 1) {
    return { min: codec.minRatio, max: codec.maxRatio, expected: codec.minRatio };
  }

  const weighted = (pick: (m: Modality) => number) =>
    modalities.reduce(
      (sum, m) => sum + pick(m) * ((m.avgStudyMb * m.typicalMix) / totalVolume),
      0,
    );

  const min = weighted((m) => codec.minRatio * m.compressibility);
  const max = weighted((m) => codec.maxRatio * m.compressibility);
  return { min, max, expected: (min + max) / 2 };
}

export function estimate(input: EstimateInput): EstimateResult {
  const codec = getCodec(input.codecId);
  const modalities = input.modalities ?? MODALITIES;
  const ratio = effectiveRatio(codec, modalities);

  const avgStudyMb = blendedStudyMb(modalities);
  const annualGrowthGb = (input.studiesPerYear * avgStudyMb) / 1024;

  const currentBefore = input.archivePb * GB_PER_PB;
  const currentAfter = currentBefore / ratio.expected;

  const projectedBefore = currentBefore + annualGrowthGb * input.retentionYears;
  const projectedAfter = projectedBefore / ratio.expected;

  const monthlyBefore = blendedMonthlyCost(currentBefore, input.tierMix);
  const monthlyAfter = blendedMonthlyCost(currentAfter, input.tierMix);

  const projectedMonthlyBefore = blendedMonthlyCost(projectedBefore, input.tierMix);
  const projectedMonthlyAfter = blendedMonthlyCost(projectedAfter, input.tierMix);

  return {
    codec,
    ratio,
    currentGb: { before: currentBefore, after: currentAfter },
    projectedGb: { before: projectedBefore, after: projectedAfter },
    monthlyCost: {
      before: monthlyBefore,
      after: monthlyAfter,
      saved: monthlyBefore - monthlyAfter,
    },
    annualCost: {
      before: monthlyBefore * 12,
      after: monthlyAfter * 12,
      saved: (monthlyBefore - monthlyAfter) * 12,
    },
    projectedAnnualSaved: (projectedMonthlyBefore - projectedMonthlyAfter) * 12,
    reclaimedGb: currentBefore - currentAfter,
    avgStudyMb,
    annualGrowthGb,
  };
}

/**
 * One-off cost of transcoding an archive, priced per GB of source data.
 *
 * Default rate reflects a managed transcode meter; self-hosted transcoding trades
 * this for compute time on the PACS side.
 */
export function transcodeCost(gb: number, eurPerGb = 0.0034): number {
  return Math.max(0, gb) * eurPerGb;
}

/**
 * Months required to pay back the one-off transcode against monthly savings.
 * Returns `Infinity` when the codec saves nothing.
 */
export function paybackMonths(result: EstimateResult, eurPerGb = 0.0034): number {
  if (result.monthlyCost.saved <= 0) return Infinity;
  return transcodeCost(result.currentGb.before, eurPerGb) / result.monthlyCost.saved;
}
