interface SliderFieldProps {
  id: string;
  label: string;
  value: number;
  min: number;
  max: number;
  step: number;
  /** Rendered next to the label, e.g. "3 PB". */
  display: string;
  hint?: string;
  onChange: (value: number) => void;
}

export function SliderField({
  id,
  label,
  value,
  min,
  max,
  step,
  display,
  hint,
  onChange,
}: SliderFieldProps) {
  return (
    <div className="mb-5 last:mb-0">
      <div className="flex items-baseline justify-between gap-3">
        <label htmlFor={id} className="text-sm font-medium text-ink-100">
          {label}
        </label>
        <output htmlFor={id} className="font-mono text-sm text-signal-500">
          {display}
        </output>
      </div>
      <input
        id={id}
        type="range"
        min={min}
        max={max}
        step={step}
        value={value}
        onChange={(event) => onChange(Number(event.target.value))}
        className="mt-2 w-full cursor-pointer"
      />
      {hint ? <p className="mt-1 text-xs text-ink-400">{hint}</p> : null}
    </div>
  );
}
