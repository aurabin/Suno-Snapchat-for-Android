#!/usr/bin/env bash
# SUNO → MP4 → Snapchat: three user-controlled destinations
set -Eeuo pipefail
say(){ printf '[SUNO-SNAP] %s\n' "$*"; }
die(){ say "FEHLER: $*" >&2; exit 1; }
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RENDERER="$ROOT/start_android_verified_v2.sh"
[[ -f "$RENDERER" ]] || die "Renderer fehlt: $RENDERER"
DOWNLOADS="${SUNO_DOWNLOADS:-$HOME/storage/downloads}"
[[ -d "$DOWNLOADS" ]] || die "Downloads nicht verfügbar. In Termux: termux-setup-storage"
if (( $# > 2 )); then die "Aufruf: bash suno_snapchat.sh [Audiodatei] [memories|private|public]"; fi
INPUT="${1:-}"
MODE="${2:-}"
if [[ -z "$MODE" ]]; then
  printf '\nWohin soll das SUNO-Musikvideo?\n'
  printf '  1) Snapchat Memories (über Kamera-Rolle importieren)\n'
  printf '  2) Private Snapchat Story (manuell auswählen)\n'
  printf '  3) Öffentliche Snapchat Story (manuell auswählen)\n'
  read -r -p 'Auswahl [1-3]: ' selection
  case "$selection" in 1) MODE=memories;; 2) MODE=private;; 3) MODE=public;; *) die "Ungültige Auswahl";; esac
fi
case "$MODE" in memories|private|public) ;; *) die "Unbekannter Modus: $MODE";; esac
# Preserve existing output files and identify the newest new file from this run.
MARKER="$(mktemp "$DOWNLOADS/.suno_start_XXXXXXXX")" || die "Marker nicht erstellbar"
trap 'rm -f -- "$MARKER"' EXIT
if [[ -n "$INPUT" ]]; then
  OPEN_MP4=0 bash "$RENDERER" "$INPUT"
else
  OPEN_MP4=0 bash "$RENDERER"
fi
OUT=""
while IFS= read -r -d '' candidate; do
  OUT="$candidate"
  break
done < <(find "$DOWNLOADS" -maxdepth 1 -type f -name 'SUNO_Snapchat_*.mp4' -newer "$MARKER" -print0)
[[ -n "$OUT" && -s "$OUT" ]] || die "Neu gerendertes MP4 nicht gefunden"
say "MP4 fertig: $OUT"
if command -v termux-media-scan >/dev/null 2>&1; then
  termux-media-scan "$OUT" >/dev/null 2>&1 || true
fi
case "$MODE" in
 memories)
  say "OPTION 1: Video in Downloads/Kamera-Rolle gespeichert."
  say "Snapchat öffnen → Memories → Kamera-Rolle → Video wählen → in Memories speichern."
  ;;
 private)
  say "OPTION 2: Snapchat auswählen und im Editor 'Private Story' auswählen."
  if command -v termux-open >/dev/null 2>&1; then
    termux-open --send "$OUT" || say "Teilen fehlgeschlagen; Video manuell in Snapchat importieren."
  else
    say "termux-open fehlt; Video manuell aus Downloads in Snapchat öffnen."
  fi
  ;;
 public)
  say "OPTION 3: Snapchat auswählen und im Editor 'Öffentliche Story' auswählen."
  say "Vor dem Veröffentlichen Publikum und Sichtbarkeit kontrollieren."
  if command -v termux-open >/dev/null 2>&1; then
    termux-open --send "$OUT" || say "Teilen fehlgeschlagen; Video manuell in Snapchat importieren."
  else
    say "termux-open fehlt; Video manuell aus Downloads in Snapchat öffnen."
  fi
  ;;
esac
say "Keine automatische Veröffentlichung oder Snapchat-Kontoanmeldung durchgeführt."
