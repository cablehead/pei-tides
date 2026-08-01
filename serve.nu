# pei-tides: tide predictions for Prince Edward Island, served by http-nu.
#
# Run:
#   http-nu --dev --datastar :5199 ~/pei-tides/serve.nu
#
# Data comes from the Canadian Hydrographic Service IWLS API
# (api-iwls.dfo-mpo.gc.ca): wlp-hilo for high/low events, wlp for the tide
# curve. Predictions are static once published, so responses are cached
# in-memory per station per local day -- the API is hit a handful of times a
# day no matter how often the page is loaded.
#
# The station list is baked in (all PEI-area stations); regenerate it from
# GET /api/v1/stations?chs-region-code=ATL filtered to the island's bounding
# box if CHS ever adds one.

use http-nu/router *
use http-nu/http *
use http-nu/datastar *

const HERE = (path self | path dirname)
const TZ = "America/Halifax"
const API = "https://api-iwls.dfo-mpo.gc.ca/api/v1"
const DEFAULT = "01710" # Canoe Cove -- nearest station to the home shore

const STATIONS = [
  {code: "01795", name: "Abegweit Passage", id: "5dd3064ee0fdc4b9b4be67d6", lat: 46.166667, lon: -63.733333}
  {code: "01838", name: "Abrams Village", id: "5dd3064ce0fdc4b9b4be65f9", lat: 46.433333, lon: -64.116667}
  {code: "01778", name: "Aggermore Point", id: "5dd3064ce0fdc4b9b4be65ef", lat: 45.966667, lon: -63.883333}
  {code: "01885", name: "Alberton", id: "5cebf1e33d0f4a073c4bc256", lat: 46.7951034, lon: -64.0582548}
  {code: "01654", name: "Annandale", id: "5dd30650e0fdc4b9b4be6bf7", lat: 46.266667, lon: -62.433333}
  {code: "01675", name: "Beach Point", id: "5dd3064ce0fdc4b9b4be65ec", lat: 46.016667, lon: -62.483333}
  {code: "01842", name: "Brae Harbour", id: "5dd3064ce0fdc4b9b4be65fa", lat: 46.616667, lon: -64.2}
  {code: "01667", name: "Cahoon Wharf", id: "5dd3064fe0fdc4b9b4be6939", lat: 46.05, lon: -62.55}
  {code: "01710", name: "Canoe Cove", id: "5cebf1e33d0f4a073c4bc221", lat: 46.149224, lon: -63.303736}
  {code: "01800", name: "Cap Pelé", id: "5cebf1e33d0f4a073c4bc237", lat: 46.235841, lon: -64.26127}
  {code: "01835", name: "Cape Egmont", id: "5cebf1e33d0f4a073c4bc24c", lat: 46.408225, lon: -64.133638}
  {code: "01790", name: "Cape Tormentine", id: "5cebf1e33d0f4a073c4bc235", lat: 46.134676, lon: -63.776757}
  {code: "01658", name: "Cardigan", id: "5dd3064ce0fdc4b9b4be65e9", lat: 46.233333, lon: -62.616667}
  {code: "01700", name: "Charlottetown", id: "5cebf1e33d0f4a073c4bc21f", lat: 46.23012108, lon: -63.1221766}
  {code: "01918", name: "Covehead", id: "5dd3064ce0fdc4b9b4be6602", lat: 46.429035, lon: -63.146052}
  {code: "01925", name: "Crowbush Cove", id: "5cebf1e33d0f4a073c4bc25e", lat: 46.4269503, lon: -62.8399476}
  {code: "01907", name: "Darnley Bridge", id: "5dd3064ce0fdc4b9b4be65ff", lat: 46.533333, lon: -63.666667}
  {code: "01652", name: "Fortune Bay", id: "5dd3064ce0fdc4b9b4be65e7", lat: 46.333333, lon: -62.35}
  {code: "01909", name: "French River North", id: "5dd3064ce0fdc4b9b4be6600", lat: 46.516667, lon: -63.5}
  {code: "01660", name: "Georgetown", id: "5cebf1e33d0f4a073c4bc211", lat: 46.17951, lon: -62.531618}
  {code: "01896", name: "Goodwood River", id: "5cebf1e33d0f4a073c4bc258", lat: 46.616799, lon: -63.916607}
  {code: "01665", name: "Graham Pond", id: "5cebf1e33d0f4a073c4bc213", lat: 46.095961, lon: -62.453698}
  {code: "01801", name: "Harshmans Brook", id: "5dd3064ce0fdc4b9b4be65f1", lat: 46.233333, lon: -64.3}
  {code: "01850", name: "Howards Cove", id: "5dd3064ce0fdc4b9b4be65fb", lat: 46.733333, lon: -64.383333}
  {code: "01876", name: "Judes Point", id: "5dd30650e0fdc4b9b4be6d42", lat: 46.95, lon: -64.033333}
  {code: "01656", name: "Launching Pond", id: "5dd3064ce0fdc4b9b4be65e8", lat: 46.216667, lon: -62.416667}
  {code: "01669", name: "Machons Point", id: "5dd3064ce0fdc4b9b4be65eb", lat: 46.016667, lon: -62.516667}
  {code: "01905", name: "Malpeque", id: "5cebf1e33d0f4a073c4bc25a", lat: 46.523993, lon: -63.696637}
  {code: "01893", name: "Milligan's Wharf", id: "5dd3064ce0fdc4b9b4be65fe", lat: 46.65, lon: -63.916667}
  {code: "01855", name: "Miminegash", id: "5cebf1e33d0f4a073c4bc250", lat: 46.88011, lon: -64.234435}
  {code: "01662", name: "Montague", id: "5cebf1e13d0f4a073c4bbefd", lat: 46.164725, lon: -62.646332}
  {code: "01797", name: "Murray Corner", id: "5dd3064ce0fdc4b9b4be65f0", lat: 46.166667, lon: -63.933333}
  {code: "01670", name: "Murray Harbour", id: "5cebf1e33d0f4a073c4bc215", lat: 46.005478, lon: -62.523515}
  {code: "01668", name: "Murray River", id: "5dd3064ce0fdc4b9b4be65ea", lat: 46.016667, lon: -62.616667}
  {code: "01945", name: "Naufrage", id: "5cebf1e33d0f4a073c4bc262", lat: 46.468428, lon: -62.417173}
  {code: "01706", name: "Nine Mile Creek", id: "5dd3064fe0fdc4b9b4be6a14", lat: 46.15, lon: -63.216667}
  {code: "01955", name: "North Lake Harbour", id: "5cebf1e33d0f4a073c4bc264", lat: 46.4669804, lon: -62.06881902}
  {code: "01865", name: "North Point", id: "5cebf1e33d0f4a073c4bc252", lat: 47.0581997, lon: -63.9960403}
  {code: "01686", name: "Pinette", id: "5dd3064ce0fdc4b9b4be65ed", lat: 46.05, lon: -62.916667}
  {code: "01690", name: "Point Prim", id: "5cebf1e33d0f4a073c4bc219", lat: 46.056251, lon: -63.030217}
  {code: "01725", name: "Port Borden", id: "5cebf1e33d0f4a073c4bc225", lat: 46.246127, lon: -63.700721}
  {code: "01785", name: "Port Elgin", id: "5cebf1e33d0f4a073c4bc233", lat: 46.051875, lon: -64.082768}
  {code: "01930", name: "Red Head Harbour", id: "5dd3064ce0fdc4b9b4be6603", lat: 46.433333, lon: -62.716667}
  {code: "01802", name: "Robichaud Wharf", id: "5dd3064ce0fdc4b9b4be65f2", lat: 46.223, lon: -64.383333}
  {code: "01915", name: "Rustico", id: "5cebf1e33d0f4a073c4bc25c", lat: 46.4560018, lon: -63.2940585}
  {code: "01868", name: "Seacow Pond", id: "5dd3064ce0fdc4b9b4be65fc", lat: 47.0300766, lon: -63.9910272}
  {code: "01860", name: "Skinners Pond", id: "5cebf1e13d0f4a073c4bbf01", lat: 46.964224, lon: -64.122878}
  {code: "01650", name: "Souris", id: "5cebf1e33d0f4a073c4bc20f", lat: 46.349625, lon: -62.251762}
  {code: "01935", name: "St Peters Bay", id: "5cebf1e33d0f4a073c4bc260", lat: 46.43862, lon: -62.73313}
  {code: "01912", name: "Stanley Bridge", id: "5dd3064ce0fdc4b9b4be6601", lat: 46.466667, lon: -63.466667}
  {code: "01735", name: "Summerside", id: "5cebf1e33d0f4a073c4bc227", lat: 46.386486, lon: -63.789649}
  {code: "01780", name: "Tidnish", id: "5cebf1e33d0f4a073c4bc231", lat: 45.997582, lon: -64.007441}
  {code: "01875", name: "Tignish", id: "5cebf1e33d0f4a073c4bc254", lat: 46.950947, lon: -63.9938431}
  {code: "01922", name: "Tracadie", id: "5dd3064fe0fdc4b9b4be693a", lat: 46.35, lon: -62.966667}
  {code: "01715", name: "Victoria, PEI", id: "5cebf1e33d0f4a073c4bc223", lat: 46.212623, lon: -63.489466}
  {code: "01845", name: "West Point", id: "5cebf1e33d0f4a073c4bc24e", lat: 46.620079, lon: -64.371788}
  {code: "01680", name: "Wood Islands", id: "5cebf1e33d0f4a073c4bc217", lat: 45.952878, lon: -62.749395}
]
let TPL = .mj compile ($HERE | path join "templates" "tides.html")
let MAPTPL = .mj compile ($HERE | path join "templates" "map.html")
let LIVETPL = .mj compile ($HERE | path join "templates" "live.html")
let STAYTPL = .mj compile ($HERE | path join "templates" "stay.html")

# in-memory day cache; recreated on handler reload
try { stor create -t cache -c {k: str, v: str} } catch { }

def cached [k: string, fetch: closure] {
  let hit = try { stor open | query db $"select v from cache where k = '($k)'" } catch { [] }
  if ($hit | is-not-empty) {
    $hit.0.v | from json
  } else {
    let v = do $fetch
    try { stor insert -t cache -d {k: $k, v: ($v | to json -r)} } catch { }
    $v
  }
}

def api-data [station_id: string, series: string, from: string, to: string] {
  http get $"($API)/stations/($station_id)/data?time-series-code=($series)&from=($from)&to=($to)"
}

def to-utc-z []: datetime -> string {
  $in | date to-timezone UTC | format date "%Y-%m-%dT%H:%M:%SZ"
}

def fmt-time []: datetime -> string {
  $in | date to-timezone $TZ | format date "%-I:%M %P"
}

# compact form for the 7-day table, where columns are narrow
def fmt-time-short []: datetime -> string {
  $in | date to-timezone $TZ | format date "%-I:%M%P"
}

def fmt-height [v: float] {
  $"($v | math round --precision 1) m"
}

def fmt-dur [d: duration] {
  let mins = ($d / 1min | math floor)
  let h = ($mins // 60)
  let m = ($mins mod 60)
  if $h > 0 { $"($h)h ($m)m" } else { $"($m)m" }
}

# The stay: Friday July 31 for 8 nights, so rows run Jul 31 through the
# Aug 8 checkout morning. The snapshots in data/ are deliberately wider
# (context for photo annotation); the page shows just the trip.
const STAY = {from: "2026-07-31", nights: 8}

# svg path for the lit part of a moon disc: outer limb (right when waxing,
# left when waning) plus an elliptical terminator whose width follows the
# illuminated fraction
def phase-path [cx: float, cy: float, r: float, frac: float, waxing: bool] {
  let a = ((($frac * 2) - 1) | math abs) * $r
  let big = ($frac >= 0.5)
  let limb = if $waxing { 1 } else { 0 }
  let term = if $waxing { if $big { 1 } else { 0 } } else { if $big { 0 } else { 1 } }
  $"M ($cx),($cy - $r) A ($r),($r) 0 0,($limb) ($cx),($cy + $r) A ($a | math round --precision 2),($r) 0 0,($term) ($cx),($cy - $r) Z"
}

# The stay page: one row per trip day (curve averaged across the two
# home-beach stations), photo dots placed at their captured moment, and a
# card per photo. All data is static files in data/ and photos/.
def stay-context [] {
  let snaps = (glob ($HERE | path join "data" "*.json")
    | each {|f| open $f }
    | where {|d| ($d | describe -d | get type) == "record" and ($d | get -o station) != null })
  let a = $snaps.0
  let b = ($snaps | get -o 1 | default $snaps.0)
  let vals = ($a.curve | zip $b.curve | each {|p| ($p.0.v + $p.1.v) / 2 })
  let from = ($a.from | into datetime)
  let off = (date now | date to-timezone $TZ | format date "%:z")
  let start = ($"($STAY.from)T00:00:00($off)" | into datetime)
  let ndays = ($STAY.nights + 1)

  let photos = (if (($HERE | path join "data" "photos.json") | path exists) {
    open ($HERE | path join "data" "photos.json")
  } else { [] })

  # one continuous strip: DAY_W px per day, 1:1 svg units so text is crisp
  let day_w = 300
  let h = 160
  let base = ((($start - $from) / 5min) | math round)
  let n = ($vals | length)
  let window = ($vals | skip $base | take ($ndays * 288 + 1))
  let pad = 0.15
  let lo = (($window | math min) - $pad)
  let hi = (($window | math max) + $pad)
  # chart band inset top and bottom so event labels fit inside the svg
  let sy = {|v| (132 - (($v - $lo) / ($hi - $lo) * 104)) | math round --precision 1 }
  let today = (date now | date to-timezone $TZ | format date "%Y-%m-%d")
  let now = (date now)

  let points = (0..($ndays * 96) | each {|j|
    let idx = ([($base + $j * 3) ($n - 1)] | math min)
    $"(($j * $day_w / 96 | math round --precision 1)),(do $sy ($vals | get $idx))"
  } | str join " ")

  # hilo averaged across the two stations, trimmed to the trip
  let events = ($a.hilo | zip $b.hilo | each {|p|
      let t0 = ($p.0.t | into datetime)
      let t = ($t0 + ((($p.1.t | into datetime) - $t0) / 2))
      {kind: $p.0.kind, t: $t, v: (($p.0.v + $p.1.v) / 2)}
    }
    | where t >= $start and t < ($start + ($ndays * 1day))
    | each {|e|
      let y = (do $sy $e.v)
      {
        kind: $e.kind
        x: ((($e.t - $start) / 1day) * $day_w | math round --precision 1)
        y: $y
        ly: (if $e.kind == "high" { $y - 12 } else { $y + 22 })
        label: ($e.v | math round --precision 1)
      }
    })

  # moon band: one disc per day. The disc face is the phase; its height above
  # or below the equator line is the declination (see tools/moon.nu).
  let moon = (if (($HERE | path join "data" "moon.json") | path exists) {
    let m = (open ($HERE | path join "data" "moon.json"))
    let end = ($start + ($ndays * 1day))
    {
      discs: ($m.days
        | each {|d| $d | update t ($d.t | into datetime) }
        | where t >= $start and t < $end
        | each {|d|
          let cx = ((($d.t - $start) / 1day) * $day_w | math round --precision 1)
          # +-29 degrees of declination maps to +-17px around the y=28 line
          let cy = ((28 - $d.decl * 0.6) | math round --precision 1)
          {cx: $cx, cy: $cy, path: (phase-path $cx $cy 8 $d.frac $d.waxing)}
        })
    }
  } else { null })

  let strip = {
    w: ($ndays * $day_w)
    h: $h
    points: $points
    days: (0..($ndays - 1) | each {|i| {
      x: ($i * $day_w + 8)
      label: (($start + ($i * 1day)) | date to-timezone $TZ | format date "%a %-d")
      today: ((($start + ($i * 1day)) | date to-timezone $TZ | format date "%Y-%m-%d") == $today)
    }})
    events: $events
    dots: ($photos | each {|p| {
      stem: ($p.file | path parse | get stem)
      x: (((($p.taken | into datetime) - $start) / 1day) * $day_w | math round --precision 1)
      y: (do $sy $p.height)
    }})
    now_x: (if $now >= $start and $now < ($start + ($ndays * 1day)) {
      (($now - $start) / 1day) * $day_w | math round --precision 1
    } else { null })
  }

  {
    range_label: ($"($start | date to-timezone $TZ | format date '%b %-d') - (($start + (($ndays - 1) * 1day)) | date to-timezone $TZ | format date '%b %-d')")
    station_label: (if ($snaps | length) == 2 { "two-station midpoint" } else { $a.station.name })
    strip: $strip
    moon: $moon
    day_w: $day_w
    photos: ($photos | each {|p| {
      stem: ($p.file | path parse | get stem)
      file: $p.file
      w: ($p | get -o w | default 4)
      h: ($p | get -o h | default 3)
      day: ((($p.taken | into datetime) - $start) / 1day | math floor)
      height: $p.height
      phase: $p.phase
      when: ($p.taken | into datetime | date to-timezone $TZ | format date "%A %B %-d, %-I:%M %P")
      between: ($"($p.prev.kind) ($p.prev.t | into datetime | date to-timezone $TZ | format date '%-I:%M %P') \(($p.prev.v) m\) -> ($p.next.kind) ($p.next.t | into datetime | date to-timezone $TZ | format date '%-I:%M %P') \(($p.next.v) m\)")
    }})
  }
}

# Everything the template needs for one station, one page load.
def tides-context [code: string] {
  let station = ($STATIONS | where code == $code | first)
  let now = (date now | date to-timezone $TZ)
  let today = ($now | format date "%Y-%m-%d")
  # local midnight, as an absolute instant
  let midnight = ($"($today)T00:00:00($now | format date '%:z')" | into datetime)
  let from = ($midnight | to-utc-z)

  # a day of lookback so the strip can trail the most recent past tide
  let hilo_raw = cached $"hilo:($code):($today)" {
    api-data $station.id "wlp-hilo" (($midnight - 1day) | to-utc-z) (($midnight + 7day) | to-utc-z)
  }
  # wlp is 1-minute resolution; keep every 15th point for the curve
  let curve = cached $"curve:($code):($today)" {
    api-data $station.id "wlp" $from (($midnight + 1day) | to-utc-z)
    | enumerate
    | where {|r| $r.index mod 15 == 0 }
    | each {|r| {t: $r.item.eventDate, v: $r.item.value} }
  }

  # hilo events don't carry a high/low label: an event is a high when it is
  # taller than its neighbour (they alternate)
  let events = ($hilo_raw | each {|e| {t: ($e.eventDate | into datetime), v: $e.value} } | sort-by t)
  let events = ($events | enumerate | each {|r|
    let e = $r.item
    let ref = if $r.index > 0 {
      ($events | get ($r.index - 1) | get v)
    } else {
      ($events | get 1 | get v)
    }
    $e | insert kind (if $e.v > $ref { "high" } else { "low" })
  })

  let next = ($events | where t > $now | get -o 0)
  # between a low and a high the tide rises: the next event's kind is the trend
  let trend = if $next == null { null } else {
    if $next.kind == "high" { "rising" } else { "falling" }
  }

  # --- svg tide curve for today ------------------------------------------
  let w = 720
  let h = 240
  let vals = ($curve | get v)
  let span = (($vals | math max) - ($vals | math min))
  let pad = (if $span == 0 { 0.5 } else { $span * 0.18 })
  let lo = (($vals | math min) - $pad)
  let hi = (($vals | math max) + $pad)
  let n = ($curve | length)
  let scale_y = {|v| ($h - (($v - $lo) / ($hi - $lo) * $h)) | math round --precision 1 }
  let pts = ($curve | enumerate | each {|r|
    let x = ($r.index / ([($n - 1) 1] | math max) * $w | math round --precision 1)
    $"($x),(do $scale_y $r.item.v)"
  })
  let line = $"M ($pts | str join ' L ')"
  let day_mins = 1440
  let now_min = (($now - $midnight) / 1min | math floor)
  let now_idx = ([([($now_min // 15) 0] | math max) ($n - 1)] | math min)
  let today_events = ($events | where t >= $midnight and t < ($midnight + 1day))

  # the strip: the most recent past tide, then the next three -- a window
  # that slides left as time passes
  let fi = ($events | enumerate | where {|r| $r.item.t > $now } | get -o 0 | get -o index
    | default ($events | length))
  let strip = ($events | skip ([($fi - 1) 0] | math max) | take 4)

  # rate of change over the next hour (4 curve samples), for the trend line
  let ahead = ([($now_idx + 4) ($n - 1)] | math min)
  let rate = if $ahead > $now_idx {
    let dv = (($curve | get $ahead | get v) - ($curve | get $now_idx | get v))
    let per_h = ($dv / (($ahead - $now_idx) * 15) * 60 | math abs | math round --precision 1)
    if $per_h < 0.05 { null } else { $"($per_h) m/h" }
  } else { null }

  let ctx = {
    code: $code
    station: $station.name
    stations: $STATIONS
    date_label: ($now | format date "%A, %B %-d")
    now_time: ($now | fmt-time)
    updated: ($now | fmt-time)
    trend: $trend
    rate: $rate
    next: (if $next == null { null } else {
      {
        kind: $next.kind
        time: ($next.t | fmt-time)
        in: (fmt-dur ($next.t - $now))
        height: (fmt-height $next.v)
      }
    })
    strip: ($strip | each {|e| {
      kind: $e.kind
      time: ($e.t | fmt-time)
      height: (fmt-height $e.v)
      past: ($e.t < $now)
    }})
    days: ($events
      | where t >= $midnight
      | group-by {|e| $e.t | date to-timezone $TZ | format date "%Y-%m-%d" }
      | transpose d evs
      | sort-by d
      | each {|g| {
          label: ($g.evs.0.t | date to-timezone $TZ | format date "%a %b %-d")
          today: ($g.d == $today)
          events: ($g.evs | each {|e| {
            kind: $e.kind
            time: ($e.t | fmt-time-short)
            height: ($e.v | math round --precision 1)
          }})
        }})
    svg: {
      line: $line
      area: $"($line) L ($w),($h) L 0,($h) Z"
      now_x: ($now_min / $day_mins * $w | math round --precision 1)
      now_y: (do $scale_y ($curve | get $now_idx | get v))
      dots: ($today_events | each {|e| {
        kind: $e.kind
        x: ((($e.t - $midnight) / 1min) / $day_mins * $w | math round --precision 1)
        y: (do $scale_y $e.v)
      }})
    }
  }
  $ctx
}

{|req|
  dispatch $req [
    (route {method: "GET", path: "/"} {|req ctx|
      let q = ($req | get -o query | get -o s)
      let saved = ($req | cookie parse | get -o station)
      let code = ($q | default ($saved | default $DEFAULT))
      let code = if ($STATIONS | where code == $code | is-empty) { $DEFAULT } else { $code }

      let page = try {
        let c = tides-context $code
        $c
        | insert live ($c | .mj render $LIVETPL)
        | insert datastar $DATASTAR_JS_PATH
        | .mj render $TPL
      } catch {|err|
        $"<!doctype html><meta charset=utf-8><meta name=viewport content='width=device-width, initial-scale=1'>
<body style='background:#0d1b26;color:#eaf1f6;font:16px system-ui;padding:2rem'>
<h1 style='font-size:1.2rem'>tides are unreachable</h1>
<p style='color:#93a7b8'>could not fetch predictions from the CHS API. it happens; try again shortly.</p>
<p style='color:#5b6b7a;font-size:.8rem'>($err.msg)</p></body>"
      }

      if $q != null {
        $page | cookie set "station" $code --max-age 31536000
      } else {
        $page
      }
    })

    # Live updates: one SSE connection per open page. Every minute (the
    # granularity at which the countdown can change) re-render the live
    # fragments -- hero, chart, strip -- and push one patch event morphing all
    # three by id. Ticks read the day cache, so no IWLS traffic; datastar
    # closes the stream when the page is hidden and reattaches on show.
    (route {method: "GET", path: "/sse"} {|req ctx|
      let q = ($req | get -o query | get -o s)
      let saved = ($req | cookie parse | get -o station)
      let code = ($q | default ($saved | default $DEFAULT))
      let code = if ($STATIONS | where code == $code | is-empty) { $DEFAULT } else { $code }
      generate {|first|
        if not $first {
          # sleep to the next minute boundary, not a flat 60s: the countdown
          # and "now" flip exactly on the minute, so patches land in step
          # with the wall clock (and all clients tick together)
          let ns = (date now | into int)
          sleep ((60_000_000_000 - ($ns mod 60_000_000_000)) * 1ns)
        }
        let ev = try {
          tides-context $code | .mj render $LIVETPL | to datastar-patch-elements
        } catch {
          # a failed IWLS fetch mid-stream: skip this tick, heal on the next
          {data: []}
        }
        {out: $ev, next: false}
      } true
      | to sse
      | metadata set --content-type "text/event-stream"
    })

    # The explainer: markdown rendered by the built-in .md, in the shared shell.
    (route {method: "GET", path: "/moon"} {|req ctx|
      let body = (open ($HERE | path join "moon.md") | .md | get __html)
      $"<!doctype html><html lang=en><head><meta charset=utf-8>
<meta name=viewport content='width=device-width, initial-scale=1, viewport-fit=cover'>
<meta name=theme-color content='#0d1b26'><title>the moon and our tides</title>
<link rel=stylesheet href=/style.css></head><body><div class=wrap>
<header><p class=sub><small>for curious beach people</small><a href='/stay'>&larr; the stay</a></p></header>
<article>($body)</article>
</div></body></html>"
    })

    (route {method: "GET", path: "/style.css"} {|req ctx|
      .static ($HERE | path join "static") "/style.css"
    })

    (route {method: "GET", path: "/stay"} {|req ctx|
      stay-context | .mj render $STAYTPL
    })

    (route {method: "GET", path-matches: "/photos/:file"} {|req ctx|
      .static ($HERE | path join "photos") $"/($ctx.file)"
    })

    (route {method: "GET", path: "/map"} {|req ctx|
      let saved = ($req | cookie parse | get -o station | default $DEFAULT)
      {
        code: $saved
        stations_json: ($STATIONS | select code name lat lon | to json -r)
      } | .mj render $MAPTPL
    })

    (route {method: "GET", path: "/health"} {|req ctx| "ok" })

    (route true {|req ctx|
      "not found" | metadata set { merge {'http.response': {status: 404}} }
    })
  ]
}
