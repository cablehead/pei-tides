# Snapshot a window of tide predictions to a JSON file, for offline use --
# e.g. associating photo timestamps with tide state after the fact.
#
#   nu tools/snapshot.nu 01710 2026-07-25 2026-08-09 > data/canoe-cove.json
#
# Args: station code, first local day, last local day (exclusive), all in
# America/Halifax. Output: {station, tz, from, to, hilo, curve} with times as
# UTC ISO strings; hilo events carry kind (high/low), the curve is 5-minute.

def main [code: string, from_day: string, to_day: string] {
  const TZ = "America/Halifax"
  const API = "https://api-iwls.dfo-mpo.gc.ca/api/v1"
  # station list lives in serve.nu; keep this tool standalone with a lookup
  let station = (http get $"($API)/stations?code=($code)" | get -o 0)
  if $station == null { error make {msg: $"no station with code ($code)"} }

  let off = (date now | date to-timezone $TZ | format date "%:z")
  let start = ($"($from_day)T00:00:00($off)" | into datetime)
  let end = ($"($to_day)T00:00:00($off)" | into datetime)
  let z = {|d| $d | date to-timezone UTC | format date "%Y-%m-%dT%H:%M:%SZ" }

  # per-day fetches: kind to the API and immune to span limits
  let days = (($end - $start) / 1day | math round)
  let curve = (0..($days - 1) | each {|i|
    let a = ($start + ($i * 1day))
    http get $"($API)/stations/($station.id)/data?time-series-code=wlp&from=(do $z $a)&to=(do $z ($a + 1day))"
    | enumerate | where {|r| $r.index mod 5 == 0 }
    | each {|r| {t: $r.item.eventDate, v: $r.item.value} }
  } | flatten | uniq-by t)

  let hilo_raw = (http get $"($API)/stations/($station.id)/data?time-series-code=wlp-hilo&from=(do $z $start)&to=(do $z $end)"
    | each {|e| {t: $e.eventDate, v: $e.value} } | sort-by t)
  let hilo = ($hilo_raw | enumerate | each {|r|
    let ref = if $r.index > 0 { $hilo_raw | get ($r.index - 1) | get v } else { $hilo_raw | get 1 | get v }
    $r.item | insert kind (if $r.item.v > $ref { "high" } else { "low" })
  })

  {
    station: {code: $code, name: $station.officialName, id: $station.id,
              lat: $station.latitude, lon: $station.longitude}
    tz: $TZ
    datum: "chart datum, meters"
    series: "wlp (CHS predictions)"
    from: (do $z $start)
    to: (do $z $end)
    hilo: $hilo
    curve: $curve
  } | to json
}
