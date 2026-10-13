#!/usr/bin/env bash
#
# Renders the benchmark corpus to fixed audio files.
#
# AVSpeechSynthesizer does not produce bit-identical audio across runs, which
# makes figures from different runs incomparable. These files freeze the input
# once so every future baseline measures the same thing. Regenerating them
# invalidates the recorded baseline — do it deliberately, then re-measure.
#
# An existing fixture is NEVER re-rendered: the script only fills in what is
# missing, so adding a language cannot disturb audio an earlier baseline was
# measured against. To regenerate one deliberately, delete the file and re-run,
# then re-measure — the manifest test will fail until the baseline is redone.
#
# Output: Tests/Fixtures/Transcription/<id>.m4a (+ SHA-256 manifest)
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="Tests/Fixtures/Transcription"
VOICE="${BENCH_VOICE:-Anna}"            # de_DE, present on macOS by default
VOICE_EN="${BENCH_VOICE_EN:-Samantha}"  # en_US, present on macOS by default
mkdir -p "$OUT"

# id|text — must match BenchmarkCorpus.german
CASES=$(cat <<'CORPUS'
names-01|René arbeitet bei der Chemnitzer Verkehrs-AG.
names-02|Jacqueline hat den Termin mit Hanning und Kahl bestätigt.
technical-01|Die Doku liegt in SharePoint, der Container läuft in Docker.
technical-02|Der Kauf läuft über StoreKit, die Synchronisierung über CloudKit.
technical-03|Die Oberfläche ist in SwiftUI geschrieben.
technical-04|SpeechAnalyzer bekommt die Begriffe über AnalysisContext.
abbrev-01|Der Zugriff läuft über VPN, die Geräte kommen aus dem MDM.
abbrev-02|Die API ist dokumentiert, die KI läuft auf dem Gerät.
numbers-01|Der Kauf kostet 9,99 Euro.
numbers-02|Das Treffen ist am 4. Oktober 2026 um 13:45 Uhr.
numbers-03|Der Server hat die Adresse 192.168.2.4.
numbers-04|Wir veröffentlichen Version 1.2.0 als Build 10.
mixed-01|René legt die CVAG-Unterlagen bis 13:45 Uhr in SharePoint ab.
mixed-02|Für Version 1.2.0 prüfen wir die API und den VPN-Zugang am 4. Oktober.
mixed-03|Die KI-Zusammenfassung läuft on-device, der Export geht nach Markdown.
CORPUS
)

# English corpus — same five categories, ids prefixed so one flat fixture
# directory stays unambiguous. Public product names and generic content only.
CASES_EN=$(cat <<'CORPUS_EN'
en-names-01|Rene works at the Chemnitz transport company.
en-names-02|Jacqueline confirmed the meeting with Hanning and Kahl.
en-technical-01|The docs are in SharePoint and the container runs in Docker.
en-technical-02|The purchase goes through StoreKit and syncing through CloudKit.
en-technical-03|The interface is written in SwiftUI.
en-technical-04|SpeechAnalyzer receives the terms through AnalysisContext.
en-abbrev-01|Access runs over VPN and the devices come from MDM.
en-abbrev-02|The API is documented and the AI runs on the device.
en-numbers-01|The purchase costs 9.99 dollars.
en-numbers-02|The meeting is on October 4th 2026 at 13:45 o'clock.
en-numbers-03|The server address is 192.168.2.4.
en-numbers-04|We are shipping version 1.2.0 as build 10.
en-mixed-01|Rene files the CVAG documents in SharePoint by 13:45 o'clock.
en-mixed-02|For version 1.2.0 we check the API and the VPN access on October 4th.
en-mixed-03|The AI summary runs on-device and the export goes to Markdown.
CORPUS_EN
)

render() {
  local voice="$1" cases="$2"
  echo "Voice: $voice"
  while IFS='|' read -r id text; do
    [ -z "$id" ] && continue
    if [ -f "$OUT/$id.m4a" ]; then
      printf '  %-17s %s\n' "$id" "kept (already frozen)"
      continue
    fi
    aiff="$(mktemp -t "$id").aiff"
    say -v "$voice" -o "$aiff" "$text"
    # 48 kHz mono AAC — the app's own recording format.
    afconvert -f m4af -d aac@48000 -c 1 -b 96000 "$aiff" "$OUT/$id.m4a" >/dev/null
    rm -f "$aiff"
    printf '  %-17s %s\n' "$id" "$(ls -lh "$OUT/$id.m4a" | awk '{print $5}')"
  done <<< "$cases"
}

render "$VOICE" "$CASES"
render "$VOICE_EN" "$CASES_EN"

# Manifest so a drifted fixture is noticed rather than silently measured.
{
  echo "# Benchmark fixture manifest"
  echo "# voice=$VOICE (de), $VOICE_EN (en) format=m4a/aac 48kHz mono 96kbps"
  echo "# Existing files are kept; deleting one and re-running regenerates it"
  echo "# and invalidates every baseline measured against it."
  echo
  (cd "$OUT" && shasum -a 256 *.m4a)
} > "$OUT/SHA256SUMS"

echo
echo "Total: $(du -sh "$OUT" | awk '{print $1}')"
