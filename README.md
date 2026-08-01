# pei-tides

Tide predictions for Prince Edward Island as a single mobile-first page,
served by [http-nu](https://github.com/cablehead/http-nu).

The page leads with the next tide (high/low, time, countdown, height), then
today's curve with a now marker, today's events, and a 7-day table. Pick any
PEI station from the selector; the choice is remembered in a cookie.

## Run

    http-nu --dev --datastar :5199 serve.nu

`--dev` lets the station cookie work over plain http; `--datastar` serves the
JS bundle the live updates need (the deployed site enables it via
`cross-stream.nuon`). An open page holds one SSE connection and receives a
patch each minute -- countdown, now marker, and the tide strip stay current
with no reloads and no client polling. The browser drops the connection while
the page is hidden and reattaches on return.

## How it works

- Data is the Canadian Hydrographic Service IWLS API
  (api-iwls.dfo-mpo.gc.ca): `wlp-hilo` for high/low events, `wlp` (1-minute
  resolution, downsampled to 15) for the curve. Heights are meters above
  chart datum, times in America/Halifax.
- Predictions are static once published, so responses are cached in-memory
  (nushell `stor`) per station per local day. The API is hit a few times a
  day per station regardless of traffic. The cache clears on restart.
- The hilo series does not label events; an event is a high when it is
  taller than its neighbour. This survives the north shore's mixed/diurnal
  days (1-2 events) as well as semidiurnal Charlottetown (4).
- All 57 PEI-area stations are baked into `serve.nu`; see the comment there
  to regenerate the list.
