import { formatPercent } from '../lib/format';
import { normaliseMix, TIERS, type TierMix } from '../lib/storage';

interface TierMixControlProps {
  mix: TierMix;
  onChange: (mix: TierMix) => void;
}

const TIER_COLOUR: Record<string, string> = {
  hot: 'bg-danger-500',
  cool: 'bg-signal-500',
  cold: 'bg-signal-600',
  archive: 'bg-ink-600',
};

export function TierMixControl({ mix, onChange }: TierMixControlProps) {
  const normalised = normaliseMix(mix);

  return (
    <div>
      <div
        className="mb-4 flex h-3 overflow-hidden rounded-full bg-ink-800"
        role="img"
        aria-label="Storage tier distribution"
      >
        {TIERS.map((tier) => (
          <div
            key={tier.id}
            className={TIER_COLOUR[tier.id]}
            style={{ width: `${normalised[tier.id as keyof TierMix] * 100}%` }}
          />
        ))}
      </div>

      {TIERS.map((tier) => {
        const key = tier.id as keyof TierMix;
        return (
          <div key={tier.id} className="mb-4 last:mb-0">
            <div className="flex items-baseline justify-between gap-3">
              <label htmlFor={`tier-${tier.id}`} className="text-sm font-medium text-ink-100">
                {tier.label}
                {!tier.onlineAccess ? (
                  <span className="ml-2 text-[10px] tracking-wider text-warn-500 uppercase">
                    offline
                  </span>
                ) : null}
              </label>
              <output htmlFor={`tier-${tier.id}`} className="font-mono text-sm text-ink-300">
                {formatPercent(normalised[key])}
              </output>
            </div>
            <input
              id={`tier-${tier.id}`}
              type="range"
              min={0}
              max={100}
              step={5}
              value={Math.round(mix[key] * 100)}
              onChange={(event) =>
                onChange({ ...mix, [key]: Number(event.target.value) / 100 })
              }
              className="mt-2 w-full cursor-pointer"
            />
            <p className="mt-1 text-xs text-ink-400">Retrieval: {tier.retrievalLatency}</p>
          </div>
        );
      })}
    </div>
  );
}
