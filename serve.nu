# pei-tides: tide predictions for Prince Edward Island, served by http-nu.
#
# Run:
#   http-nu --dev :5199 ~/pei-tides/serve.nu
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

const HERE = (path self | path dirname)
const TZ = "America/Halifax"
const API = "https://api-iwls.dfo-mpo.gc.ca/api/v1"
const DEFAULT = "01700" # Charlottetown

const STATIONS = [
  {code: "01795", name: "Abegweit Passage", id: "5dd3064ee0fdc4b9b4be67d6"}
  {code: "01838", name: "Abrams Village", id: "5dd3064ce0fdc4b9b4be65f9"}
  {code: "01778", name: "Aggermore Point", id: "5dd3064ce0fdc4b9b4be65ef"}
  {code: "01885", name: "Alberton", id: "5cebf1e33d0f4a073c4bc256"}
  {code: "01654", name: "Annandale", id: "5dd30650e0fdc4b9b4be6bf7"}
  {code: "01675", name: "Beach Point", id: "5dd3064ce0fdc4b9b4be65ec"}
  {code: "01842", name: "Brae Harbour", id: "5dd3064ce0fdc4b9b4be65fa"}
  {code: "01667", name: "Cahoon Wharf", id: "5dd3064fe0fdc4b9b4be6939"}
  {code: "01710", name: "Canoe Cove", id: "5cebf1e33d0f4a073c4bc221"}
  {code: "01800", name: "Cap Pelé", id: "5cebf1e33d0f4a073c4bc237"}
  {code: "01835", name: "Cape Egmont", id: "5cebf1e33d0f4a073c4bc24c"}
  {code: "01790", name: "Cape Tormentine", id: "5cebf1e33d0f4a073c4bc235"}
  {code: "01658", name: "Cardigan", id: "5dd3064ce0fdc4b9b4be65e9"}
  {code: "01700", name: "Charlottetown", id: "5cebf1e33d0f4a073c4bc21f"}
  {code: "01918", name: "Covehead", id: "5dd3064ce0fdc4b9b4be6602"}
  {code: "01925", name: "Crowbush Cove", id: "5cebf1e33d0f4a073c4bc25e"}
  {code: "01907", name: "Darnley Bridge", id: "5dd3064ce0fdc4b9b4be65ff"}
  {code: "01652", name: "Fortune Bay", id: "5dd3064ce0fdc4b9b4be65e7"}
  {code: "01909", name: "French River North", id: "5dd3064ce0fdc4b9b4be6600"}
  {code: "01660", name: "Georgetown", id: "5cebf1e33d0f4a073c4bc211"}
  {code: "01896", name: "Goodwood River", id: "5cebf1e33d0f4a073c4bc258"}
  {code: "01665", name: "Graham Pond", id: "5cebf1e33d0f4a073c4bc213"}
  {code: "01801", name: "Harshmans Brook", id: "5dd3064ce0fdc4b9b4be65f1"}
  {code: "01850", name: "Howards Cove", id: "5dd3064ce0fdc4b9b4be65fb"}
  {code: "01876", name: "Judes Point", id: "5dd30650e0fdc4b9b4be6d42"}
  {code: "01656", name: "Launching Pond", id: "5dd3064ce0fdc4b9b4be65e8"}
  {code: "01669", name: "Machons Point", id: "5dd3064ce0fdc4b9b4be65eb"}
  {code: "01905", name: "Malpeque", id: "5cebf1e33d0f4a073c4bc25a"}
  {code: "01893", name: "Milligan's Wharf", id: "5dd3064ce0fdc4b9b4be65fe"}
  {code: "01855", name: "Miminegash", id: "5cebf1e33d0f4a073c4bc250"}
  {code: "01662", name: "Montague", id: "5cebf1e13d0f4a073c4bbefd"}
  {code: "01797", name: "Murray Corner", id: "5dd3064ce0fdc4b9b4be65f0"}
  {code: "01670", name: "Murray Harbour", id: "5cebf1e33d0f4a073c4bc215"}
  {code: "01668", name: "Murray River", id: "5dd3064ce0fdc4b9b4be65ea"}
  {code: "01945", name: "Naufrage", id: "5cebf1e33d0f4a073c4bc262"}
  {code: "01706", name: "Nine Mile Creek", id: "5dd3064fe0fdc4b9b4be6a14"}
  {code: "01955", name: "North Lake Harbour", id: "5cebf1e33d0f4a073c4bc264"}
  {code: "01865", name: "North Point", id: "5cebf1e33d0f4a073c4bc252"}
  {code: "01686", name: "Pinette", id: "5dd3064ce0fdc4b9b4be65ed"}
  {code: "01690", name: "Point Prim", id: "5cebf1e33d0f4a073c4bc219"}
  {code: "01725", name: "Port Borden", id: "5cebf1e33d0f4a073c4bc225"}
  {code: "01785", name: "Port Elgin", id: "5cebf1e33d0f4a073c4bc233"}
  {code: "01930", name: "Red Head Harbour", id: "5dd3064ce0fdc4b9b4be6603"}
  {code: "01802", name: "Robichaud Wharf", id: "5dd3064ce0fdc4b9b4be65f2"}
  {code: "01915", name: "Rustico", id: "5cebf1e33d0f4a073c4bc25c"}
  {code: "01868", name: "Seacow Pond", id: "5dd3064ce0fdc4b9b4be65fc"}
  {code: "01860", name: "Skinners Pond", id: "5cebf1e13d0f4a073c4bbf01"}
  {code: "01650", name: "Souris", id: "5cebf1e33d0f4a073c4bc20f"}
  {code: "01935", name: "St Peters Bay", id: "5cebf1e33d0f4a073c4bc260"}
  {code: "01912", name: "Stanley Bridge", id: "5dd3064ce0fdc4b9b4be6601"}
  {code: "01735", name: "Summerside", id: "5cebf1e33d0f4a073c4bc227"}
  {code: "01780", name: "Tidnish", id: "5cebf1e33d0f4a073c4bc231"}
  {code: "01875", name: "Tignish", id: "5cebf1e33d0f4a073c4bc254"}
  {code: "01922", name: "Tracadie", id: "5dd3064fe0fdc4b9b4be693a"}
  {code: "01715", name: "Victoria, PEI", id: "5cebf1e33d0f4a073c4bc223"}
  {code: "01845", name: "West Point", id: "5cebf1e33d0f4a073c4bc24e"}
  {code: "01680", name: "Wood Islands", id: "5cebf1e33d0f4a073c4bc217"}]

let TPL = .mj compile ($HERE | path join "templates" "tides.html")

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

def fmt-height [v: float] {
  $"($v | math round --precision 1) m"
}

def fmt-dur [d: duration] {
  let mins = ($d / 1min | math floor)
  let h = ($mins // 60)
  let m = ($mins mod 60)
  if $h > 0 { $"($h)h ($m)m" } else { $"($m)m" }
}

# Everything the template needs for one station, one page load.
def tides-context [code: string] {
  let station = ($STATIONS | where code == $code | first)
  let now = (date now | date to-timezone $TZ)
  let today = ($now | format date "%Y-%m-%d")
  # local midnight, as an absolute instant
  let midnight = ($"($today)T00:00:00($now | format date '%:z')" | into datetime)
  let from = ($midnight | to-utc-z)

  let hilo_raw = cached $"hilo:($code):($today)" {
    api-data $station.id "wlp-hilo" $from (($midnight + 7day) | to-utc-z)
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
  let today_events = ($events | where t < ($midnight + 1day))

  let ctx = {
    code: $code
    station: $station.name
    stations: $STATIONS
    date_label: ($now | format date "%A, %B %-d")
    updated: ($now | fmt-time)
    next: (if $next == null { null } else {
      {
        kind: $next.kind
        time: ($next.t | fmt-time)
        in: (fmt-dur ($next.t - $now))
        height: (fmt-height $next.v)
      }
    })
    today: ($today_events | each {|e| {
      kind: $e.kind
      time: ($e.t | fmt-time)
      height: (fmt-height $e.v)
      past: ($e.t < $now)
    }})
    days: ($events
      | group-by {|e| $e.t | date to-timezone $TZ | format date "%Y-%m-%d" }
      | transpose d evs
      | sort-by d
      | each {|g| {
          label: ($g.evs.0.t | date to-timezone $TZ | format date "%a %b %-d")
          today: ($g.d == $today)
          events: ($g.evs | each {|e| {
            kind: $e.kind
            time: ($e.t | fmt-time)
            height: (fmt-height $e.v)
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
        tides-context $code | .mj render $TPL
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

    (route {method: "GET", path: "/health"} {|req ctx| "ok" })

    (route true {|req ctx|
      "not found" | metadata set { merge {'http.response': {status: 404}} }
    })
  ]
}
