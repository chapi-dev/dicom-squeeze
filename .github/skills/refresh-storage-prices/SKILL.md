---
name: refresh-storage-prices
description: Refreshes the Azure Blob Storage prices in the estimation engine from the official Retail Prices API. Use when asked to update, verify or re-check the storage prices in DICOM Squeeze.
---

# Refreshing the storage prices

The prices in `src/lib/storage.ts` are Azure Blob Storage LRS list prices for Spain Central
in EUR per GB per month. They go stale. Refresh them from the source, never from memory.

## 1. Query the Retail Prices API

The API is public and needs no authentication.

```bash
curl -s "https://prices.azure.com/api/retail/prices?currencyCode='EUR'&\$filter=serviceName eq 'Storage' and armRegionName eq 'spaincentral' and productName eq 'General Block Blob v2 Hierarchical Namespace'"
```

Narrow with `meterName` to isolate the tier you want, for example `Hot LRS Data Stored`,
`Cool LRS Data Stored`, `Cold LRS Data Stored`, `Archive LRS Data Stored`.

## 2. Watch the three traps

- **The unit.** `unitOfMeasure` must be `1 GB/Month`. Some meters are priced per GiB per
  **hour**, which is 730 times larger over a month. Azure NetApp Files is billed this way,
  and confusing the two produces an estimate that is wrong by more than an order of
  magnitude.
- **The bands.** Hot storage is priced in volume tiers, exposed as separate records with a
  `tierMinimumUnits` field. At petabyte scale the cheapest band dominates the bill, so all
  bands must be captured. Each band's price applies only to the volume inside that band —
  it is progressive, not retroactive.
- **The redundancy.** LRS, ZRS, GRS and RA-GRS are different meters at different prices.
  This tool models LRS. Do not mix them.

## 3. Update the code

Edit the `bands` arrays in `TIERS` in `src/lib/storage.ts`. Keep `fromGb` expressed in terms
of the `GB_PER_TB` constant so the thresholds stay readable.

Update the comment at the top of the file with the retrieval date.

## 4. Verify

```bash
npm run test
```

`storage.test.ts` asserts the banded arithmetic with explicit figures, so changing a price
will fail those tests. That is the point — update the expected values deliberately, one at a
time, and confirm each against the API response. Never bulk-replace them to make the suite
go green.

Then check the relational tests still hold: colder tiers must remain cheaper than warmer
ones. If that inverts, you have almost certainly pulled the wrong meter.

## 5. Write the pull request

List each price you changed, its old and new value, and the exact API query you ran with the
date. The pull request template has a "Source citations" section for this.
