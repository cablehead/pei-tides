# Moon data for the stay strip: declination (drives the strait's unequal
# lows) sampled every 3 hours, and phase (spring/neap context) at local noon
# each day. Low-precision lunar ephemeris (Astronomical Almanac truncation,
# good to ~1 degree -- plenty for a trend band).
#
#   nu tools/moon.nu 2026-07-31 2026-08-09 > data/moon.json

const TZ = "America/Halifax"

def dsin [x: float] { $x | math sin --degrees }
def dcos [x: float] { $x | math cos --degrees }

# days since J2000
def j2000 [t: datetime] { ($t - ("2000-01-01T12:00:00Z" | into datetime)) / 1day }

def moon-at [t: datetime] {
  let d = (j2000 $t)
  let mp = (134.963 + 13.064993 * $d)   # moon mean anomaly
  let dd = (297.850 + 12.190749 * $d)   # elongation
  let ms = (357.529 + 0.98560028 * $d)  # sun mean anomaly
  let f = (93.272 + 13.229350 * $d)     # argument of latitude
  let lam = (218.316 + 13.176396 * $d
    + 6.289 * (dsin $mp)
    + 1.274 * (dsin (2 * $dd - $mp))
    + 0.658 * (dsin (2 * $dd))
    - 0.186 * (dsin $ms)
    - 0.059 * (dsin (2 * $mp - 2 * $dd)))
  let beta = (5.128 * (dsin $f) + 0.281 * (dsin ($mp + $f)))
  let eps = (23.439 - 0.00000036 * $d)
  let decl = (((dsin $beta) * (dcos $eps) + (dcos $beta) * (dsin $eps) * (dsin $lam))
    | math arcsin --degrees)
  let lam_sun = (280.459 + 0.98564736 * $d + 1.915 * (dsin $ms))
  let elong = ($lam - $lam_sun)
  {
    decl: ($decl | math round --precision 1)
    frac: (((1 - (dcos $elong)) / 2) | math round --precision 3)
    waxing: ((dsin $elong) > 0)
  }
}

def main [from_day: string, to_day: string] {
  let off = (date now | date to-timezone $TZ | format date "%:z")
  let start = ($"($from_day)T00:00:00($off)" | into datetime)
  let end = ($"($to_day)T00:00:00($off)" | into datetime)
  let hours = ((($end - $start) / 1hr) | math round)
  let z = {|t| $t | date to-timezone UTC | format date "%Y-%m-%dT%H:%M:%SZ" }

  {
    from: (do $z $start)
    to: (do $z $end)
    decl: (0..($hours // 3) | each {|i|
      let t = ($start + ($i * 3hr))
      {t: (do $z $t), deg: (moon-at $t | get decl)}
    })
    days: (0..((($end - $start) / 1day | math round) - 1) | each {|i|
      let t = ($start + ($i * 1day) + 12hr)
      let m = (moon-at $t)
      {t: (do $z $t), frac: $m.frac, waxing: $m.waxing}
    })
  } | to json
}
