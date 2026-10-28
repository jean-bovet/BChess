# Sourced by snapshot-gallery.sh and snapshot-mac.sh (from the repo root): the languages a gallery run may render
# (the catalog's languages) and the region each is tested in, so the two platforms cannot drift.

# region <language>: en->US ja->JP he->IL ar->SA xx-YY->YY, else the language upper-cased
region() {
  case "$1" in
    en) echo US ;; ja) echo JP ;; he) echo IL ;; ar) echo SA ;;
    *-*) echo "${1##*-}" | tr '[:lower:]' '[:upper:]' ;;
    *) echo "$1" | tr '[:lower:]' '[:upper:]' ;;
  esac
}

# parse_languages <comma-separated list>: fills LANG_LIST, or exits 2 for an empty list or a language outside the whitelist
parse_languages() {
  LANG_LIST=()
  IFS=',' read -r -a LANG_LIST <<< "$1"
  [[ ${#LANG_LIST[@]} -gt 0 ]] || { echo "--lang needs a list of languages (en, fr, de, it, he, ar)" >&2; exit 2; }
  local lang
  for lang in "${LANG_LIST[@]}"; do
    case "$lang" in
      en|fr|de|it|he|ar) ;;
      *) echo "unknown language: $lang (en, fr, de, it, he, ar)" >&2; exit 2 ;;
    esac
  done
}
