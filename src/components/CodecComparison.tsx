import { CODECS } from '../lib/codecs';
import { estimate, paybackMonths, type EstimateInput } from '../lib/estimate';
import { formatEur, formatMonths, formatRatio, formatSize } from '../lib/format';

interface CodecComparisonProps {
  input: EstimateInput;
  selectedId: string;
  onSelect: (id: string) => void;
}

export function CodecComparison({ input, selectedId, onSelect }: CodecComparisonProps) {
  const rows = CODECS.map((codec) => {
    const result = estimate({ ...input, codecId: codec.id });
    return { codec, result, payback: paybackMonths(result) };
  });

  const best = Math.max(...rows.map((row) => row.result.annualCost.saved));

  return (
    <div className="overflow-x-auto">
      <table className="w-full min-w-[720px] border-collapse text-sm">
        <caption className="sr-only">
          Estimated annual storage savings by DICOM transfer syntax
        </caption>
        <thead>
          <tr className="text-left text-[11px] tracking-[0.12em] text-ink-400 uppercase">
            <th scope="col" className="py-2 pr-4 font-semibold">
              Transfer syntax
            </th>
            <th scope="col" className="py-2 pr-4 text-right font-semibold">
              Ratio
            </th>
            <th scope="col" className="py-2 pr-4 text-right font-semibold">
              Archive after
            </th>
            <th scope="col" className="py-2 pr-4 text-right font-semibold">
              Saved / year
            </th>
            <th scope="col" className="py-2 text-right font-semibold">
              Payback
            </th>
          </tr>
        </thead>
        <tbody>
          {rows.map(({ codec, result, payback }) => {
            const selected = codec.id === selectedId;
            const share = best > 0 ? result.annualCost.saved / best : 0;
            return (
              <tr
                key={codec.id}
                onClick={() => onSelect(codec.id)}
                className={`cursor-pointer border-t border-ink-700/60 transition ${
                  selected ? 'bg-signal-500/10' : 'hover:bg-ink-800/40'
                }`}
              >
                <th scope="row" className="py-3 pr-4 text-left font-normal">
                  <span
                    className={`block font-medium ${selected ? 'text-signal-500' : 'text-ink-100'}`}
                  >
                    {codec.label}
                  </span>
                  <span className="font-mono text-[11px] text-ink-400">{codec.uid}</span>
                  <span className="mt-1 block h-1 w-full max-w-48 rounded-full bg-ink-800">
                    <span
                      className="block h-1 rounded-full bg-signal-500"
                      style={{ width: `${Math.max(share, 0) * 100}%` }}
                    />
                  </span>
                </th>
                <td className="py-3 pr-4 text-right font-mono text-ink-300">
                  {formatRatio(result.ratio.expected)}
                </td>
                <td className="py-3 pr-4 text-right font-mono text-ink-300">
                  {formatSize(result.currentGb.after)}
                </td>
                <td
                  className={`py-3 pr-4 text-right font-mono ${
                    result.annualCost.saved > 0 ? 'text-good-500' : 'text-ink-400'
                  }`}
                >
                  {formatEur(result.annualCost.saved)}
                </td>
                <td className="py-3 text-right font-mono text-ink-300">
                  {formatMonths(payback)}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
