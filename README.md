# Suno und Snapchat auf Android

Dieses Projekt hilft dir, aus einer **bereits heruntergeladenen Audiodatei** ein Musikvideo zu machen. Danach kannst du das Video selbst in Snapchat auswählen.

**Wichtig:** Das Projekt verbindet sich nicht automatisch mit deinem Suno- oder Snapchat-Konto. Es lädt keine Songs selbst von Suno herunter und veröffentlicht nichts ohne deine Entscheidung.

## Was du brauchst

- Android mit der App **Termux**.
- Die Programme `ffmpeg` und `ffprobe`. Das Startskript versucht, sie über Termux zu installieren, wenn sie fehlen.
- Zugriff auf den Downloads-Ordner. In Termux kannst du dafür `termux-setup-storage` ausführen und die Android-Abfrage bestätigen.
- Eine Audiodatei, die du verwenden darfst, zum Beispiel MP3, M4A, WAV, FLAC oder OGG.
- Genügend freien Speicherplatz.

## So startest du das Programm

Öffne Termux im Ordner mit diesen Dateien und gib ein:

```sh
bash suno_snapchat.sh
```

Das Programm sucht eine Audiodatei in Downloads oder Musik und fragt, wohin das fertige Video soll.

Du kannst auch eine Datei und ein Ziel direkt angeben:

```sh
bash suno_snapchat.sh "$HOME/storage/downloads/mein_song.mp3" private
```

Mögliche Ziele:

1. `memories`: Video speichern und später in Snapchat Memories importieren.
2. `private`: Video zum Teilen öffnen. Die private Story musst du in Snapchat selbst auswählen.
3. `public`: Video zum Teilen öffnen. Die öffentliche Story musst du in Snapchat selbst auswählen.

## Was passiert technisch?

`start_android_verified_v2.sh` erzeugt ein Hochkantvideo mit einem animierten Muster und deinem Ton. Das Video verwendet H.264 für das Bild und AAC für den Ton. Die fertige MP4-Datei liegt in Downloads.

Die Voreinstellung ist 540 × 960 Pixel mit 15 Bildern pro Sekunde. Das Skript prüft Dateiformat, Dauer, freien Speicher und die fertige Datei. Ein vollständiger Dekodierungstest ist mit `VERIFY_FULL=1` möglich.

## Häufige Probleme

- **Downloads nicht erreichbar:** In Termux `termux-setup-storage` ausführen und den Zugriff erlauben.
- **Keine Audiodatei gefunden:** Den genauen Dateipfad beim Start angeben.
- **FFmpeg fehlt:** In Termux `pkg install ffmpeg` ausführen.
- **Zu wenig Speicher:** Dateien sichern oder freien Platz schaffen.
- **Snapchat öffnet sich nicht:** Die fertige MP4-Datei manuell aus Downloads in Snapchat importieren.
- **Video wird nicht erstellt:** Die Fehlermeldung in Termux lesen. Die App veröffentlicht nichts automatisch.

## Sicherheit und Grenzen

Die Skripte benötigen keine Root-Rechte. Sie sollten nur mit Dateien verwendet werden, für die du die nötigen Rechte besitzt. Die Funktionsfähigkeit auf deinem konkreten Android-Gerät wurde hier noch nicht durch einen Gerätetest bestätigt.
