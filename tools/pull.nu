# Pull phone uploads from the site's inbox and run them through ingest:
#
#   nu tools/pull.nu                      # from the deployed site
#   nu tools/pull.nu http://127.0.0.1:5199
#
# Reads the bearer token from .upload-token at the repo root (gitignored).
# Downloads any inbox original we have not ingested yet, ingests it, and
# leaves the commit/push to you.

const HERE = (path self | path dirname)
const ROOT = ($HERE | path dirname)

def main [base: string = "https://tides.ndyg.cross.stream"] {
  let tok = (open --raw ($ROOT | path join ".upload-token") | str trim)
  let auth = [Authorization $"Bearer ($tok)"]
  let inbox = (http get --headers $auth $"($base)/inbox")
  if ($inbox | is-empty) { print "inbox is empty"; return }

  let have = (glob ($ROOT | path join "photos" "*.jpg")
    | each {|p| $p | path parse | get stem })
  let new = ($inbox | where {|f| ($f.name | path parse | get stem) not-in $have })
  if ($new | is-empty) { print "nothing new"; return }

  let dl = ($ROOT | path join "inbox")
  mkdir $dl
  let files = ($new | each {|f|
    let dest = ($dl | path join $f.name)
    http get --headers $auth $"($base)/inbox/($f.name)" | save -f $dest
    print $"pulled ($f.name) \(($f.size)\)"
    $dest
  })
  nu ($HERE | path join "ingest.nu") ...$files
  print "ingested -- review, then: git add -A && git commit && git push origin main && git push cross-stream main"
}
