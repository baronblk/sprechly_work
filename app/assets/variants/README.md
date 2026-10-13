# assets/variants — Testvarianten

**Niemals live schalten ohne ausgewerteten Test.** Was hier liegt, ist
ausdrücklich kein Store-Asset.

## test1-hero-a — Kontrolle

Das bisher live laufende Hero, aus dem Stand von `main` gesichert. Zeigt den
Transkriptbildschirm mit der KI-Zusammenfassung obenauf und trägt rund 24 %
leere Fläche.

## test1-hero-b — Treatment

Das neue Hero aus Lauf E (2026-10-10), gerätespezifisch: iPhone aus dem
Transkript-Blatt, iPad aus dem Detailbildschirm. Transkript beginnt bei 00:00,
Leerfläche 4,3 % (de) und 6,2 % (en).

Beide Arme sind damit vorbereitet; der Test selbst startet erst, wenn die
Traffic-Schwelle aus `docs/aso/PPO_TREATMENTS.md` erreicht ist.

## runC-reference — Zwischenkandidat

Lauf C, nur iPhone, nur zur Dokumentation. Füllte die Leinwand vollständig,
führte aber mit der KI-Zusammenfassung und hatte eine angeschnittene Kopfzeile.
**Kein Store-Asset, kein Testarm.** Nicht verändern.
