#!/usr/bin/env bash
set -Eeuo pipefail
log(){ printf '[SUNO] %s\n' "$*"; }
die(){ printf '[SUNO] FEHLER: %s\n' "$*" >&2; exit 1; }
if ! command -v ffmpeg >/dev/null 2>&1 || ! command -v ffprobe >/dev/null 2>&1; then
  command -v pkg >/dev/null 2>&1 || die 'FFmpeg fehlt; bitte Termux installieren.'
  pkg install -y ffmpeg || die 'FFmpeg-Installation fehlgeschlagen.'
fi
for cmd in awk find stat mktemp df grep date cat rm; do
  command -v "$cmd" >/dev/null 2>&1 || die "Fehlendes Programm: $cmd"
done
DOWNLOADS=${SUNO_DOWNLOADS:-$HOME/storage/downloads}
MUSIC=${SUNO_MUSIC:-$HOME/storage/music}
if [[ ! -d "$DOWNLOADS" || ! -w "$DOWNLOADS" ]]; then
  if [[ -z ${SUNO_DOWNLOADS:-} ]] && command -v termux-setup-storage >/dev/null 2>&1; then termux-setup-storage || true; fi
  [[ -d "$DOWNLOADS" && -w "$DOWNLOADS" ]] || die "Downloads nicht zugänglich: $DOWNLOADS"
fi
(( $# <= 1 )) || die 'Aufruf: bash start_android_verified.sh [Audiodatei]'
INPUT=${1:-}
if [[ -z "$INPUT" ]]; then
  newest=-1
  for directory in "$DOWNLOADS" "$MUSIC"; do
    [[ -d "$directory" ]] || continue
    while IFS= read -r -d '' candidate; do
      modified=$(stat -c %Y -- "$candidate" 2>/dev/null) || continue
      if (( modified > newest )); then newest=$modified; INPUT=$candidate; fi
    done < <(find "$directory" -maxdepth 2 -type f \( -iname '*.mp3' -o -iname '*.m4a' -o -iname '*.wav' -o -iname '*.flac' -o -iname '*.ogg' \) -print0 2>/dev/null)
  done
fi
[[ -n "$INPUT" && -f "$INPUT" && -r "$INPUT" ]] || die 'Keine lesbare Audiodatei gefunden.'
ffprobe -v error -select_streams a:0 -show_entries stream=codec_type -of csv=p=0 "$INPUT" | grep -qx audio || die 'Kein Audiostream.'
duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INPUT") || die 'Audiodauer nicht lesbar.'
[[ "$duration" =~ ^[0-9]+([.][0-9]+)?$ ]] || die 'Ungültige Audiodauer.'
awk -v d="$duration" 'BEGIN {exit !(d>0 && d<=86400)}' || die 'Audiodauer außerhalb 0–24 Stunden.'
width=${VIDEO_WIDTH:-540}; height=${VIDEO_HEIGHT:-960}; fps=${VIDEO_FPS:-15}; crf=${VIDEO_CRF:-29}; threads=${VIDEO_THREADS:-2}
for value in "$width" "$height" "$fps" "$crf" "$threads"; do [[ "$value" =~ ^(0|[1-9][0-9]*)$ ]] || die 'Ungültige Videoeinstellungen.'; done
(( width>=160 && width<=1920 && width%2==0 && height>=160 && height<=1920 && height%2==0 && fps>=1 && fps<=60 && crf<=51 && threads>=1 && threads<=8 )) || die 'Videoeinstellungen außerhalb erlaubter Grenzen.'
grep -Eq '[[:space:]]libx264[[:space:]]' <<< "$(ffmpeg -hide_banner -encoders 2>/dev/null)" || die 'libx264 fehlt.'
grep -Eq '[[:space:]]mandelbrot[[:space:]]' <<< "$(ffmpeg -hide_banner -filters 2>/dev/null)" || die 'mandelbrot fehlt.'
grep -Eq '[[:space:]]drawgrid[[:space:]]' <<< "$(ffmpeg -hide_banner -filters 2>/dev/null)" || die 'drawgrid fehlt.'
available=$(df -Pk "$DOWNLOADS" | awk 'NR==2 {print $4}')
[[ "$available" =~ ^[0-9]+$ ]] || die 'Freier Speicher nicht bestimmbar.'
# Conservative minimum reserve; actual CRF file size is variable.
needed=$(awk -v d="$duration" 'BEGIN {printf "%.0f", 102400 + d*90}')
(( available > needed )) || die "Zu wenig Speicher: mindestens $((needed/1024)) MiB empfohlen."
stamp=$(date +%Y%m%d_%H%M%S)
OUT="$DOWNLOADS/SUNO_Snapchat_${stamp}_$$_${RANDOM}.mp4"
TMP=$(mktemp "$DOWNLOADS/.suno_render_XXXXXXXX.mp4") || die 'Temporäre Datei konnte nicht erstellt werden.'
cleanup(){ [[ -z ${TMP:-} ]] || rm -f -- "$TMP"; }
trap cleanup EXIT
trap 'die "Abbruch in Zeile $LINENO"' ERR
filter='[0:v]format=yuv420p,drawgrid=w=80:h=80:t=1:c=0x00ffff@0.20[v]'
log "Audio: $INPUT"
log "MP4-Ausgabe: $OUT"
ffmpeg -hide_banner -nostdin -loglevel warning -stats -y \
  -f lavfi -i "mandelbrot=size=${width}x${height}:rate=${fps}" -i "$INPUT" \
  -filter_complex "$filter" -map '[v]' -map '1:a:0' -t "$duration" \
  -c:v libx264 -preset ultrafast -threads:v "$threads" -crf "$crf" \
  -pix_fmt yuv420p -r "$fps" -c:a aac -b:a 160k -movflags +faststart "$TMP" || die 'Rendering fehlgeschlagen.'
[[ -s "$TMP" ]] || die 'Leere MP4-Ausgabe.'
[[ $(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$TMP") == h264 ]] || die 'H.264 fehlt.'
[[ $(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$TMP") == aac ]] || die 'AAC fehlt.'
output_duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$TMP") || die 'Ausgabedauer nicht lesbar.'
awk -v a="$duration" -v b="$output_duration" 'BEGIN {exit !(b>0 && b>=a-2 && b<=a+2)}' || die 'Ausgabedauer weicht ab.'
if [[ ${VERIFY_FULL:-0} == 1 ]]; then ffmpeg -v error -xerror -i "$TMP" -map 0:v:0 -map 0:a:0 -f null - || die 'Dekodierungstest fehlgeschlagen.'; fi
# Android shared storage may not support hard links. Use a unique name and rename.
# Reserve the destination atomically; avoid accidental replacement on name collision.
if ! ( set -C; : > "$OUT" ) 2>/dev/null; then die "Zieldatei existiert bereits: $OUT"; fi
if ! cat -- "$TMP" > "$OUT"; then rm -f -- "$OUT"; die 'Zieldatei konnte nicht geschrieben werden.'; fi
[[ -s "$OUT" ]] || die "Ausgabe nicht veröffentlicht."
rm -f -- "$TMP"
TMP=''
chmod 644 -- "$OUT" 2>/dev/null || log "Dateiberechtigungen unverändert."
if command -v termux-media-scan >/dev/null 2>&1; then termux-media-scan "$OUT" >/dev/null 2>&1 || log 'Medienscan nicht verfügbar.'; fi
log "FERTIG: $OUT"
if [[ ${OPEN_MP4:-0} == 1 ]] && command -v termux-open >/dev/null 2>&1; then termux-open --view "$OUT" || log 'Video bitte manuell öffnen.'; fi