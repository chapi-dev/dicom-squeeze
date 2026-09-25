/**
 * DICOM transfer syntaxes and their compression characteristics.
 *
 * Ratios are indicative planning figures for radiology imaging, expressed
 * relative to uncompressed Explicit VR Little Endian. Real-world ratios vary
 * with modality, bit depth and anatomy, so the UI always presents a range.
 */

export type CodecKind = 'uncompressed' | 'lossless' | 'lossy';

export interface Codec {
  id: string;
  label: string;
  /** DICOM Transfer Syntax UID. */
  uid: string;
  kind: CodecKind;
  /** Conservative end of the observed compression ratio. */
  minRatio: number;
  /** Optimistic end of the observed compression ratio. */
  maxRatio: number;
  /** Relative CPU cost of transcoding, 1 = cheapest. */
  cpuCost: number;
  /** Whether the codec is broadly accepted for primary diagnostic reading. */
  diagnosticallyAccepted: boolean;
  notes: string;
}

export const CODECS: Codec[] = [
  {
    id: 'explicit-vr-le',
    label: 'Explicit VR Little Endian',
    uid: '1.2.840.10008.1.2.1',
    kind: 'uncompressed',
    minRatio: 1,
    maxRatio: 1,
    cpuCost: 0,
    diagnosticallyAccepted: true,
    notes: 'Baseline. Many modalities still emit uncompressed pixel data.',
  },
  {
    id: 'rle',
    label: 'RLE Lossless',
    uid: '1.2.840.10008.1.2.5',
    kind: 'lossless',
    minRatio: 1.2,
    maxRatio: 2.0,
    cpuCost: 1,
    diagnosticallyAccepted: true,
    notes: 'Cheap to compute but weak on noisy modalities such as CT and MR.',
  },
  {
    id: 'jpeg-ls',
    label: 'JPEG-LS Lossless',
    uid: '1.2.840.10008.1.2.4.80',
    kind: 'lossless',
    minRatio: 2.0,
    maxRatio: 3.0,
    cpuCost: 2,
    diagnosticallyAccepted: true,
    notes: 'Strong default for CT and MR. Bit-exact and widely supported by PACS.',
  },
  {
    id: 'jpeg2000-lossless',
    label: 'JPEG 2000 Lossless',
    uid: '1.2.840.10008.1.2.4.90',
    kind: 'lossless',
    minRatio: 2.2,
    maxRatio: 3.2,
    cpuCost: 4,
    diagnosticallyAccepted: true,
    notes: 'Slightly better ratios than JPEG-LS, noticeably heavier to encode.',
  },
  {
    id: 'htj2k-lossless',
    label: 'High-Throughput JPEG 2000 (HTJ2K)',
    uid: '1.2.840.10008.1.2.4.201',
    kind: 'lossless',
    minRatio: 2.2,
    maxRatio: 3.3,
    cpuCost: 2,
    diagnosticallyAccepted: true,
    notes: 'JPEG 2000 quality at far lower CPU cost. Best modern lossless choice.',
  },
  {
    id: 'jpeg2000-lossy',
    label: 'JPEG 2000 Lossy (20:1)',
    uid: '1.2.840.10008.1.2.4.91',
    kind: 'lossy',
    minRatio: 12,
    maxRatio: 25,
    cpuCost: 4,
    diagnosticallyAccepted: false,
    notes: 'Irreversible. Requires a documented clinical policy before use.',
  },
];

export function getCodec(id: string): Codec {
  const codec = CODECS.find((c) => c.id === id);
  if (!codec) throw new Error(`Unknown codec: ${id}`);
  return codec;
}
