# Git Workflow — VoxStudio

Verbindlicher Workflow für dieses Repository.

## Commits

- **Conventional Commits**, Englisch, Imperativ, klein geschrieben, **kein** Punkt am Ende, Subject **≤ 72 Zeichen**.
- **Atomar:** ein Commit = eine logische Änderung.
- **Push sofort** nach jedem Commit — nicht am Sessionende sammeln.
- **Keine AI-Attribution:** niemals `Co-authored-by: Claude`, kein `--author="Claude"`, keine AI-Hinweise in Commits, Code-Kommentaren, PRs oder Tags. Commits erscheinen als Renes eigenständige Arbeit.

## Format

```
<type>(<scope>): <subject>

<optional body>
```

**Types:** `feat`, `fix`, `refactor`, `perf`, `test`, `docs`, `chore`, `build`, `ci`, `style`.

**Scopes (Beispiele):** `recording`, `library`, `editor`, `transcription`, `engine`, `persistence`, `design`, `app`, `deps`.

## Beispiele

```
feat(recording): add live waveform tap on audio engine
fix(editor): keep original file intact on trim export
refactor(transcription): extract SpeechTranscriptionService into actor
chore(deps): pin whisperkit to 0.9.0
```

## Releases

- **SemVer-Tags:** `vMAJOR.MINOR.PATCH` (z. B. `v0.1.0`).
- Tag erst nach abgeschlossener, getesteter Phase.

## Branching

- `main` ist immer baufähig.
- Feature-Arbeit kann direkt auf `main` erfolgen, solange Commits atomar und grün sind (Solo-Repo).
