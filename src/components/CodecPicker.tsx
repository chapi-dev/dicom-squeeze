import { CODECS, type Codec } from '../lib/codecs';
import { formatRatio } from '../lib/format';

interface CodecPickerProps {
  selectedId: string;
  onSelect: (id: string) => void;
}

function cpuBars(cost: number) {
  return '▮'.repeat(Math.max(cost, 0)).padEnd(4, '▯');
}

function badge(codec: Codec) {
  if (codec.kind === 'lossy') {
    return (
      <span className="rounded-full bg-danger-500/15 px-2 py-0.5 text-[10px] font-semibold tracking-wider text-danger-500 uppercase">
        Lossy
      </span>
    );
  }
  if (codec.kind === 'uncompressed') {
    return (
      <span className="rounded-full bg-ink-600/40 px-2 py-0.5 text-[10px] font-semibold tracking-wider text-ink-300 uppercase">
        Baseline
      </span>
    );
  }
  return (
    <span className="rounded-full bg-good-500/15 px-2 py-0.5 text-[10px] font-semibold tracking-wider text-good-500 uppercase">
      Lossless
    </span>
  );
}

export function CodecPicker({ selectedId, onSelect }: CodecPickerProps) {
  return (
    <ul className="flex flex-col gap-2" role="radiogroup" aria-label="Target transfer syntax">
      {CODECS.map((codec) => {
        const selected = codec.id === selectedId;
        return (
          <li key={codec.id}>
            <button
              type="button"
              role="radio"
              aria-checked={selected}
              onClick={() => onSelect(codec.id)}
              className={`w-full rounded-xl border px-4 py-3 text-left transition ${
                selected
                  ? 'border-signal-500 bg-signal-500/10'
                  : 'border-ink-700/70 bg-ink-800/40 hover:border-ink-600'
              }`}
            >
              <div className="flex items-center justify-between gap-3">
                <span className="text-sm font-semibold text-ink-100">{codec.label}</span>
                {badge(codec)}
              </div>
              <div className="mt-1 font-mono text-[11px] text-ink-400">{codec.uid}</div>
              <div className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-ink-300">
                <span>
                  Ratio {formatRatio(codec.minRatio)} – {formatRatio(codec.maxRatio)}
                </span>
                <span className="font-mono" title={`Relative CPU cost: ${codec.cpuCost}`}>
                  CPU {cpuBars(codec.cpuCost)}
                </span>
              </div>
              <p className="mt-2 text-xs leading-relaxed text-ink-400">{codec.notes}</p>
            </button>
          </li>
        );
      })}
    </ul>
  );
}
