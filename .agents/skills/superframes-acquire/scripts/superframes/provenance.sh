#!/usr/bin/env bash
# provenance.sh — the asset ledger. Every file that reaches a master has a row.
#
#   provenance.sh init
#   provenance.sh add --file path --url URL --licence CLASS [--use TEXT] [--credit TEXT] [--author TEXT]
#   provenance.sh check              verify every asset has a row and a licence class
#   provenance.sh list
#
# Ledger: assets/PROVENANCE.tsv (tab-separated, one row per asset).
#
# Licence classes:
#   own              the person's own recording or asset
#   licensed         a licence was supplied or purchased (record the terms)
#   cc-by            Creative Commons attribution — needs the credit string
#   cc0              public domain / no restrictions
#   reference-only   studied for style, never shipped as pixels
#   unknown          no basis established — blocks delivery until resolved

set -uo pipefail
die() { printf 'provenance: %s\n' "$*" >&2; exit 2; }
LEDGER="${LEDGER:-assets/PROVENANCE.tsv}"
VALID="own licensed cc-by cc0 reference-only unknown"

init() {
  mkdir -p "$(dirname "$LEDGER")"
  if [[ -f "$LEDGER" ]]; then printf 'ledger already exists: %s\n' "$LEDGER"; return 0; fi
  printf 'file\tlicence\tuse\turl\tauthor\tcredit\tadded\n' > "$LEDGER"
  printf 'created %s\n' "$LEDGER"
}

add() {
  local file="" url="" licence="" use="" credit="" author=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file) file="${2:-}"; shift 2 ;;
      --url) url="${2:-}"; shift 2 ;;
      --licence) licence="${2:-}"; shift 2 ;;
      --use) use="${2:-}"; shift 2 ;;
      --credit) credit="${2:-}"; shift 2 ;;
      --author) author="${2:-}"; shift 2 ;;
      *) die "unknown option: $1" ;;
    esac
  done
  [[ -n "$file" ]] || die "add needs --file"
  [[ -n "$licence" ]] || die "add needs --licence ($VALID)"
  case " $VALID " in *" $licence "*) ;; *) die "licence must be one of: $VALID" ;; esac
  [[ -f "$LEDGER" ]] || init >/dev/null
  [[ -f "$file" ]] || printf 'warning: %s does not exist yet\n' "$file" >&2
  # Replace an existing row for the same file rather than appending duplicates.
  local tmp; tmp=$(mktemp)
  awk -F'\t' -v f="$file" 'NR==1 || $1!=f' "$LEDGER" > "$tmp"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$file" "$licence" "${use:-}" "${url:-}" "${author:-}" "${credit:-}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$tmp"
  mv "$tmp" "$LEDGER"
  printf 'recorded %s as %s\n' "$file" "$licence"
}

check() {
  [[ -f "$LEDGER" ]] || die "no ledger at $LEDGER; run: provenance.sh init"
  local problems=0
  # Every media file under assets/ needs a row.
  while IFS= read -r f; do
    case "$f" in assets/PROVENANCE.tsv) continue ;; esac
    if ! awk -F'\t' -v f="$f" 'NR>1 && $1==f {found=1} END{exit !found}' "$LEDGER"; then
      printf 'FAIL  no provenance row: %s\n' "$f"; problems=$((problems+1))
    fi
  done < <(find assets -type f \( -name '*.mp4' -o -name '*.mov' -o -name '*.webm' -o -name '*.mkv' \
            -o -name '*.wav' -o -name '*.mp3' -o -name '*.m4a' -o -name '*.aac' -o -name '*.flac' \
            -o -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' -o -name '*.svg' \
            -o -name '*.woff2' -o -name '*.ttf' -o -name '*.otf' \) 2>/dev/null | sort)
  # Field-wise validation. Note: reading TSV with IFS=$'\\t' collapses runs of
  # tabs (tab is IFS *whitespace*), which silently shifts empty columns. awk with
  # -F'\\t' keeps empty fields, so the ledger survives missing values.
  local row_problems
  row_problems=$(awk -F'\t' '
    NR==1 { next }
    $1=="" { next }
    $2=="unknown" { printf "FAIL  unknown licence: %s (ask, then set a class)\n", $1 }
    $2=="cc-by" && $6=="" { printf "FAIL  cc-by without a credit string: %s\n", $1 }
    $2=="licensed" && $3=="" { printf "WARN  licensed but no use terms recorded: %s\n", $1 }
    { print "" }
  ' "$LEDGER" 2>/dev/null | grep -v '^$' || true)
  if [[ -n "$row_problems" ]]; then
    printf '%s\n' "$row_problems"
    problems=$((problems + $(printf '%s\n' "$row_problems" | grep -c '^FAIL')))
  fi
  # Ledger rows pointing at files that no longer exist.
  local missing_rows
  missing_rows=$(awk -F'\t' 'NR>1 && $1!="" {print $1}' "$LEDGER" | while read -r f; do
    [[ -f "$f" ]] || printf 'WARN  ledger row for a missing file: %s\n' "$f"
  done)
  [[ -n "$missing_rows" ]] && printf '%s\n' "$missing_rows"
  if [[ "$problems" -gt 0 ]]; then
    printf '\n%d problem(s). Delivery is blocked until every asset has a licence class.\n' "$problems"
    return 1
  fi
  printf 'PASS  every asset has a provenance row with a usable licence class\n'
}

list() {
  [[ -f "$LEDGER" ]] || die "no ledger at $LEDGER"
  column -t -s$'\t' "$LEDGER" 2>/dev/null || cat "$LEDGER"
}

case "${1:-}" in
  init) init ;;
  add) shift; add "$@" ;;
  check) check ;;
  list) list ;;
  *) printf 'usage: provenance.sh init|add|check|list  (see the header of this file)\n' >&2; exit 2 ;;
esac
