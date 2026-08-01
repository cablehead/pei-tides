# Ingest photos for the stay: extract the EXIF capture time, resize a copy
# into photos/ (1600px long edge), annotate with the tide state at that
# moment -- interpolated as the average of the two stations bracketing the
# home beach -- and upsert data/photos.json.
#
#   nu tools/ingest.nu ~/IMG_1412.png ~/IMG_1424.png
#
# Needs exiftool and imagemagick convert on PATH, and station snapshots in
# data/ (see tools/snapshot.nu). Photos outside the snapshot window fail
# loudly rather than annotating with garbage.

const HERE = (path self | path dirname)
const ROOT = ($HERE | path dirname)

def snaps [] {
  glob ($ROOT | path join data "*.json")
  | each {|f| open $f }
  | where {|d| ($d | get -o station) != null }
}

# tide state in one snapshot at instant t: curve height by index (the curve
# is a uniform 5-minute grid), plus the bracketing hilo events
def lookup [snap: record, t: datetime] {
  let from = ($snap.from | into datetime)
  let to = ($snap.to | into datetime)
  if $t < $from or $t >= $to {
    error make {msg: $"($t) is outside snapshot window ($snap.from)..($snap.to) for ($snap.station.name)"}
  }
  let n = ($snap.curve | length)
  let idx = ([([((($t - $from) / 5min) | math round) 0] | math max) ($n - 1)] | math min)
  let hilo = ($snap.hilo | each {|e| $e | update t ($e.t | into datetime) })
  {
    v: ($snap.curve | get $idx | get v)
    prev: ($hilo | where t <= $t | last)
    next: ($hilo | where t > $t | first)
  }
}

def avg-ev [a: record, b: record] {
  {
    kind: $a.kind
    t: ($a.t + (($b.t - $a.t) / 2))
    v: ((($a.v + $b.v) / 2) | math round --precision 2)
  }
}

def fmt-ev [e: record] {
  {
    kind: $e.kind
    t: ($e.t | date to-timezone UTC | format date "%Y-%m-%dT%H:%M:%SZ")
    v: $e.v
  }
}

def main [...files: path] {
  let stations = snaps
  if ($stations | length) < 1 { error make {msg: "no station snapshots in data/"} }

  let entries = ($files | each {|f|
    let dto = (^exiftool -s3 -DateTimeOriginal $f | str trim)
    let off = (^exiftool -s3 -OffsetTimeOriginal $f | str trim | default "-03:00")
    if ($dto | is-empty) { error make {msg: $"($f): no DateTimeOriginal in EXIF"} }
    let parts = ($dto | split row " ")
    let taken = ($"($parts.0 | str replace --all ':' '-')T($parts.1)($off)" | into datetime)

    let out_name = ($f | path parse | get stem) + ".jpg"
    let out = ($ROOT | path join "photos" $out_name)
    mkdir ($ROOT | path join "photos")
    ^convert $f -auto-orient -resize "1600x1600>" -quality 82 $out

    let looks = ($stations | each {|s| lookup $s $taken })
    let height = (($looks | get v | math avg) | math round --precision 2)
    let prev = if ($looks | length) == 2 {
      avg-ev $looks.0.prev $looks.1.prev
    } else { $looks.0.prev }
    let next = if ($looks | length) == 2 {
      avg-ev $looks.0.next $looks.1.next
    } else { $looks.0.next }

    {
      file: $out_name
      taken: ($taken | date to-timezone UTC | format date "%Y-%m-%dT%H:%M:%SZ")
      taken_local: ($taken | date to-timezone America/Halifax | format date "%Y-%m-%d %-I:%M:%S %P")
      height: $height
      phase: (if $next.kind == "high" { "rising" } else { "falling" })
      prev: (fmt-ev $prev)
      next: (fmt-ev $next)
    }
  })

  # upsert by file name into the manifest
  let manifest_path = ($ROOT | path join "data" "photos.json")
  let existing = if ($manifest_path | path exists) { open $manifest_path } else { [] }
  let keep = ($existing | where {|e| $e.file not-in ($entries | get file) })
  $keep | append $entries | sort-by taken | save -f $manifest_path
  open $manifest_path | select file taken_local height phase | table
}
