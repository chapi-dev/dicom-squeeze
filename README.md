# DICOM Squeeze

[![CI](https://github.com/chapi-dev/dicom-squeeze/actions/workflows/ci.yml/badge.svg)](https://github.com/chapi-dev/dicom-squeeze/actions/workflows/ci.yml)
[![CodeQL](https://github.com/chapi-dev/dicom-squeeze/actions/workflows/codeql.yml/badge.svg)](https://github.com/chapi-dev/dicom-squeeze/actions/workflows/codeql.yml)
[![Pages](https://github.com/chapi-dev/dicom-squeeze/actions/workflows/deploy-pages.yml/badge.svg)](https://github.com/chapi-dev/dicom-squeeze/actions/workflows/deploy-pages.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**A mockup planner for squeezing a radiology imaging archive.**

Pick a target DICOM transfer syntax, describe the estate, and see what a lossless
recompression campaign would do to the footprint, the storage bill and the payback period.

**[Try it →](https://chapi-dev.github.io/dicom-squeeze/)**

> [!WARNING]
> This is a mockup. It is not a medical device, it processes no real imaging data, and its
> figures are planning estimates rather than a procurement commitment. Any change to a
> production imaging archive must be validated against the applicable medical device
> regulations and your organisation's own clinical governance.

## What it does

A 3 PB imaging archive is expensive to keep and it is getting bigger. Much of it is stored
uncompressed, because that is what the modality emitted and nobody went back. Transcoding to
a modern lossless transfer syntax typically recovers a factor of two to three — without
altering a single pixel value.

DICOM Squeeze puts numbers on that trade-off:

- **Six real transfer syntaxes**, from uncompressed Explicit VR Little Endian through JPEG-LS
  and HTJ2K to lossy JPEG 2000, each with its registered DICOM UID.
- **Modality-weighted ratios.** A chest radiograph and a CT volume do not compress alike, so
  the codec ratio is weighted by the study mix — by volume, not by study count.
- **Banded storage pricing.** Azure Blob Hot storage is cheaper above 50 TB and cheaper again
  above 500 TB. At petabyte scale that band is most of the bill, so it is modelled
  progressively rather than as a flat rate.
- **Payback.** Transcoding costs money once; storage costs money every month. The tool shows
  where those two lines cross.

## Quick start

```bash
git clone https://github.com/chapi-dev/dicom-squeeze.git
cd dicom-squeeze
npm ci
npm run dev
```

Node 24 is the development target. CI also tests Node 22. The minimum supported version is 22.12.

## Commands

| Command                 | What it does                             |
| ----------------------- | ---------------------------------------- |
| `npm run dev`           | Dev server with hot reload               |
| `npm run build`         | Typecheck and build to `dist/`           |
| `npm run preview`       | Serve the production build               |
| `npm run lint`          | oxlint                                   |
| `npm run typecheck`     | `tsc -b --noEmit`                        |
| `npm run test`          | Vitest, once                             |
| `npm run test:watch`    | Vitest in watch mode                     |
| `npm run test:coverage` | Vitest with enforced coverage thresholds |
| `npm run format`        | Prettier, write                          |
| `npm run format:check`  | Prettier, check only                     |

## Architecture

```
src/
  lib/            Pure TypeScript. The model. No React, no DOM, no I/O.
    codecs.ts       Transfer syntaxes, ratios, CPU cost, diagnostic acceptance
    modalities.ts   Study sizes and compressibility per modality
    storage.ts      Tiers, banded pricing, tier mixes
    estimate.ts     The engine that combines them
    format.ts       Display helpers, es-ES locale
  components/     Presentational React components
  App.tsx         State container
```

One rule holds the design together: **all arithmetic lives in `src/lib/`**. Components
format and display; they never calculate. Anything computed inline in JSX is untested by
construction, and in a tool whose entire output is numbers, that is not acceptable.

The engine is covered by unit tests that include relational assertions — "a colder tier mix
costs less than an all-hot one" — which catch the inverted comparisons and sign errors that
a fixed-value assertion sails straight past.

## Where the numbers come from

Every literal figure is a claim about the real world, and each one is traceable:

| Data                 | Source                                                        |
| -------------------- | ------------------------------------------------------------- |
| Transfer syntax UIDs | DICOM PS3.6, Registry of DICOM Unique Identifiers             |
| Compression ratios   | Published ranges for radiology imaging, modelled as ranges    |
| Storage prices       | Azure Retail Prices API, Spain Central, LRS, EUR per GB/month |
| Modality study sizes | Planning figures for a general radiology department           |

If you think one is wrong, that is a defect worth reporting — open a
[data accuracy issue](https://github.com/chapi-dev/dicom-squeeze/issues/new?template=data_accuracy.yml)
with the primary source.

## Using Copilot with this repository

The repository ships its agent configuration as committed files: repository and path-scoped
instructions, two custom agents, two skills, lifecycle hooks and an MCP server list. Clone
it, trust the folder, and `/env` will show all of it loaded.

**[docs/copilot-setup/](docs/copilot-setup/)** explains every piece, and is written to be
lifted into another project.

| Guide                                                          | Covers                                         |
| -------------------------------------------------------------- | ---------------------------------------------- |
| [Installing the CLI](docs/copilot-setup/01-install-cli.md)      | Install, auth, slash commands, troubleshooting |
| [Custom instructions](docs/copilot-setup/02-instructions.md)    | What makes an instruction file actually work   |
| [MCP servers](docs/copilot-setup/03-mcp-servers.md)             | Configuration, precedence, security            |
| [Agents and skills](docs/copilot-setup/04-agents-and-skills.md) | When to use which, and how to write both       |
| [Hooks and plugins](docs/copilot-setup/05-hooks-and-plugins.md) | Making a rule mechanical instead of advisory   |
| [GitHub automation](docs/copilot-setup/06-github-automation.md) | Code review, delegation, the CI/CD surface     |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The short version: run `lint`, `typecheck`, `test`
and `build` before opening a pull request, test anything you add to `src/lib/`, cite a
primary source for any number you change, and never commit imaging data.

## Licence

[MIT](LICENSE).

DICOM® is a registered trademark of the National Electrical Manufacturers Association. This
project is not affiliated with or endorsed by NEMA.
