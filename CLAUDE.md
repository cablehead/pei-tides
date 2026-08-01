## Git Commit Style Preferences

**NEVER commit unless explicitly asked by the user.**

When committing: review `git diff`

- Use conventional commit format: `type: subject line`
- Keep subject line concise and descriptive
- **NEVER include marketing language, promotional text, or AI attribution**
- **NEVER add "Generated with Claude Code", "Co-Authored-By: Claude", or similar spam**
- Follow existing project patterns from git log
- Prefer just a subject and no body, unless the change is particularly complex

## Tone and Communication

- ASCII only. No em dashes, smart quotes, or other unicode punctuation. Use "--"
  only in code contexts, not as prose punctuation.
- No wasted words. No fluff. Each word should add value to the reader.
- Human readable and clear. Prefer short sentences, one idea each. Break a
  clause-stacked sentence into two or three. After drafting, re-read and cut every
  word that does not add information.
- Calm, matter-of-fact technical tone.
- Avoid the verbless appositive cadence: a fragment that drops the verb and stacks
  noun phrases for rhythm. Examples to NOT write: "Two streams, both
  newline-delimited JSON.", "one answer, two surfaces, both substantial.", "No
  TUI, no daemon.". It performs crispness instead of stating the fact. The tell is
  a comma or semicolon sitting where the verb belongs, often opening or closing a
  paragraph. Restore the verb: "Both streams are newline-delimited JSON."

## The project

An http-nu app: `serve.nu` is the handler, `templates/tides.html` the page
(minijinja). No build step. Run it with:

    http-nu --dev :5199 serve.nu

`--dev` is required locally so the station cookie works over plain http.

- Mobile foremost. The page is designed for a phone held in one hand: single
  column, 27rem max width, big tap targets, tabular numerals. Check changes at
  ~390px wide before calling them done.
- Data is the CHS IWLS API (api-iwls.dfo-mpo.gc.ca). Predictions are cached in
  `stor` per station per local day, but `stor` is in-memory: every server
  restart refetches. When iterating on the template, prefer editing while one
  server stays up so the cache absorbs the reloads.
- Times are America/Halifax everywhere; heights are meters above chart datum.
- The `wlp-hilo` series does not label highs and lows: an event is a high when
  it is taller than its neighbour. North-shore stations have mixed/diurnal
  tides -- days with 1 or 2 events are normal, never assume 4.
- The PEI station list is baked into `serve.nu` (see the header comment to
  regenerate). DEFAULT is Canoe Cove, the nearest station to the home
  shore; the cookie overrides it per browser.
