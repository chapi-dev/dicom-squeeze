import { useMemo, useState } from 'react';

import { CodecComparison } from './components/CodecComparison';
import { CodecPicker } from './components/CodecPicker';
import { Panel } from './components/Panel';
import { SliderField } from './components/SliderField';
import { StatCard } from './components/StatCard';
import { TierMixControl } from './components/TierMixControl';
import { estimate, paybackMonths, type EstimateInput } from './lib/estimate';
import { formatEur, formatMonths, formatNumber, formatRatio, formatSize } from './lib/format';
import { DEFAULT_TIER_MIX, type TierMix } from './lib/storage';

export default function App() {
  const [archivePb, setArchivePb] = useState(3);
  const [studiesPerYear, setStudiesPerYear] = useState(250_000);
  const [retentionYears, setRetentionYears] = useState(15);
  const [codecId, setCodecId] = useState('htj2k-lossless');
  const [tierMix, setTierMix] = useState<TierMix>(DEFAULT_TIER_MIX);

  const input: EstimateInput = useMemo(
    () => ({ archivePb, studiesPerYear, retentionYears, codecId, tierMix }),
    [archivePb, studiesPerYear, retentionYears, codecId, tierMix],
  );

  const result = useMemo(() => estimate(input), [input]);
  const payback = paybackMonths(result);

  return (
    <div className="mx-auto min-h-svh w-full max-w-7xl px-5 py-10 sm:px-8">
      <header className="mb-10">
        <p className="font-mono text-xs tracking-[0.3em] text-signal-500 uppercase">
          Mockup · not a medical device
        </p>
        <h1 className="mt-3 text-4xl font-semibold tracking-tight text-ink-100 sm:text-5xl">
          DICOM Squeeze
        </h1>
        <p className="mt-3 max-w-3xl text-ink-300">
          Estimate what a lossless recompression campaign would do to a radiology archive. Pick
          a target DICOM transfer syntax, describe the estate, and watch the footprint, the
          storage bill and the payback period move.
        </p>
      </header>

      <div className="mb-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard
          label="Archive after transcode"
          value={formatSize(result.currentGb.after)}
          caption={`From ${formatSize(result.currentGb.before)} at ${formatRatio(result.ratio.expected)}`}
        />
        <StatCard
          label="Reclaimed capacity"
          value={formatSize(result.reclaimedGb)}
          caption={`Range ${formatRatio(result.ratio.min)} – ${formatRatio(result.ratio.max)}`}
          tone="good"
        />
        <StatCard
          label="Storage saved per year"
          value={formatEur(result.annualCost.saved)}
          caption={`Bill drops from ${formatEur(result.annualCost.before)} to ${formatEur(result.annualCost.after)}`}
          tone="good"
        />
        <StatCard
          label="Transcode payback"
          value={formatMonths(payback)}
          caption={`Reaching ${formatEur(result.projectedAnnualSaved)}/year by year ${retentionYears}`}
          tone={payback > 36 ? 'warn' : 'neutral'}
        />
      </div>

      <div className="grid gap-6 lg:grid-cols-[1fr_1.15fr]">
        <div className="flex flex-col gap-6">
          <Panel title="Estate" subtitle="Describe the archive you want to squeeze.">
            <SliderField
              id="archive-pb"
              label="Archive size today"
              value={archivePb}
              min={0.1}
              max={10}
              step={0.1}
              display={`${formatNumber(archivePb)} PB`}
              onChange={setArchivePb}
            />
            <SliderField
              id="studies-per-year"
              label="New studies per year"
              value={studiesPerYear}
              min={0}
              max={1_000_000}
              step={10_000}
              display={formatNumber(studiesPerYear, 0)}
              hint={`Blended study size ${formatNumber(result.avgStudyMb)} MB · ${formatSize(result.annualGrowthGb)} of growth per year`}
              onChange={setStudiesPerYear}
            />
            <SliderField
              id="retention-years"
              label="Retention horizon"
              value={retentionYears}
              min={1}
              max={30}
              step={1}
              display={`${retentionYears} years`}
              hint="Spanish regional rules commonly require 15 years, and up to 30 for nuclear medicine."
              onChange={setRetentionYears}
            />
          </Panel>

          <Panel
            title="Storage tiers"
            subtitle="Azure Blob list prices for Spain Central, in EUR per GB/month."
          >
            <TierMixControl mix={tierMix} onChange={setTierMix} />
          </Panel>
        </div>

        <div className="flex flex-col gap-6">
          <Panel
            title="Target transfer syntax"
            subtitle="Every option is a real DICOM transfer syntax UID."
          >
            <CodecPicker selectedId={codecId} onSelect={setCodecId} />
          </Panel>

          <Panel
            title="Side by side"
            subtitle="Same estate, every codec. Click a row to select it."
          >
            <CodecComparison input={input} selectedId={codecId} onSelect={setCodecId} />
          </Panel>
        </div>
      </div>

      <footer className="mt-10 border-t border-ink-700/60 pt-6 text-xs leading-relaxed text-ink-400">
        <p>
          Figures are planning estimates built from published compression ranges and Azure list
          prices. They are not a clinical, contractual or procurement commitment. Any change to
          a production imaging archive must be validated against the applicable medical device
          regulations and the organisation&rsquo;s own clinical governance.
        </p>
      </footer>
    </div>
  );
}
