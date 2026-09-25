/**
 * Modality profiles used to turn a study count into an estimated data volume.
 *
 * Average study sizes are planning figures for a general radiology department.
 * `compressibility` scales the codec ratio: noisy cross-sectional data compresses
 * worse than flat projection radiography.
 */

export interface Modality {
  /** DICOM modality code. */
  code: string;
  label: string;
  /** Average uncompressed study size in megabytes. */
  avgStudyMb: number;
  /** Multiplier applied to the codec ratio. 1 = codec performs as specified. */
  compressibility: number;
  /** Share of a typical general-radiology study mix, 0-1. */
  typicalMix: number;
}

export const MODALITIES: Modality[] = [
  {
    code: 'CR/DX',
    label: 'Radiography (CR / DX)',
    avgStudyMb: 20,
    compressibility: 1.15,
    typicalMix: 0.5,
  },
  {
    code: 'CT',
    label: 'Computed Tomography',
    avgStudyMb: 300,
    compressibility: 0.95,
    typicalMix: 0.22,
  },
  {
    code: 'MR',
    label: 'Magnetic Resonance',
    avgStudyMb: 150,
    compressibility: 0.9,
    typicalMix: 0.14,
  },
  {
    code: 'US',
    label: 'Ultrasound',
    avgStudyMb: 60,
    compressibility: 1.05,
    typicalMix: 0.08,
  },
  {
    code: 'MG',
    label: 'Mammography / Tomosynthesis',
    avgStudyMb: 2000,
    compressibility: 1.0,
    typicalMix: 0.05,
  },
  {
    code: 'NM/PT',
    label: 'Nuclear Medicine / PET',
    avgStudyMb: 120,
    compressibility: 1.1,
    typicalMix: 0.01,
  },
];

export function getModality(code: string): Modality {
  const modality = MODALITIES.find((m) => m.code === code);
  if (!modality) throw new Error(`Unknown modality: ${code}`);
  return modality;
}

/**
 * Weighted average study size across the default modality mix, in megabytes.
 */
export function blendedStudyMb(mix: readonly Modality[] = MODALITIES): number {
  const totalWeight = mix.reduce((sum, m) => sum + m.typicalMix, 0);
  if (totalWeight === 0) return 0;
  return mix.reduce((sum, m) => sum + m.avgStudyMb * m.typicalMix, 0) / totalWeight;
}
