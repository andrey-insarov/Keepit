<!-- source: GUIDE.md 39bab8b4f2a3de5ce61f2427db3f17e669b6f280 -->
# Keepit-Handbuch

Keepit verwaltet den Verlauf der Zwischenablage und Vorlagen unter macOS. Es sitzt in der Menüleiste,
merkt sich alles, was du kopierst, und fügt jeden Eintrag per Tastenkürzel wieder ein. Alle Kürzel
unten sind die Standardbelegung, jedes lässt sich unter *Einstellungen → Kurzbefehle* ändern. Dieses
Handbuch beschreibt Keepit 3. Das Handbuch für Keepit 2.x bleibt unverändert unter
[keep.it.com/v2/guide](https://keep.it.com/v2/guide) (englisch) erhalten.

![Das Verlaufsmenü](site/img/guide/menu.png)

**Inhalt**

- [Teil 1: Erste Schritte](#part-1--getting-started): [Installation](#install) · [Erster Start](#first-launch)
- [Teil 2: Im Alltag](#part-2--everyday-use): [Das Verlaufsmenü](#the-history-menu) · [Suche und Vorschau](#search-and-preview) · [Einfügen ohne Menü](#paste-without-the-menu) · [Die Einfügewarteschlange](#the-paste-queue) · [Das erweiterte Menü](#the-extended-menu)
- [Teil 3: Vorlagen](#part-3--templates): [Anlegen und ordnen](#creating-and-organising) · [Platzhalter](#placeholders) · [Vorlagen, die Fragen stellen](#templates-that-ask-questions)
- [Teil 4: Der Viewer](#part-4--the-viewer)
- [Teil 5: Einstellungen](#part-5--settings)
- [Teil 6: Sicherheit](#part-6-security): [Passwort und Verschlüsselung](#password-and-encryption) · [Touch ID](#touch-id) · [Wiederherstellungsphrase](#recovery-phrase) · [Backup](#backup)
- [Teil 7: Für Fortgeschrittene](#part-7--advanced): [Automatisierung](#automation-the-keepit-url-scheme) · [Updates](#updates) · [Deinstallieren](#uninstalling)
- [Referenz](#reference): [Fehlerbehebung](#troubleshooting) · [Tastenkürzel im Überblick](#keyboard-cheat-sheet) · [Platzhalter im Überblick](#placeholder-cheat-sheet)

---

## Teil 1: Erste Schritte

### Installation

**Homebrew** ist der empfohlene Weg, weil `brew upgrade` die App aktuell hält:

```bash
brew tap andrey-insarov/keepit https://github.com/andrey-insarov/Keepit
brew install --cask andrey-insarov/keepit/keepit
```

**DMG:** Lade `Keepit-<version>.dmg` von der Seite der
[neuesten Version](https://github.com/andrey-insarov/Keepit/releases/latest), öffne die Datei und zieh Keepit
in den Ordner *Programme*.

![Das DMG: Keepit in den Ordner „Programme“ ziehen](site/img/guide/dmg.png)

Beim ersten Öffnen bestätigt macOS, dass die App aus dem Internet stammt und von Apple geprüft wurde.
Klicke auf *Öffnen*.

![Gatekeeper-Bestätigung von macOS](site/img/guide/gatekeeper.png)

Keepit ist signiert und notarisiert, aktualisiert sich selbst und läuft nativ auf Macs mit Apple
Silicon und Intel ab macOS 13 Ventura.

### Erster Start

Keepit ist eine Menüleisten-App: Es gibt kein Dock-Symbol und kein Fenster, solange du keins öffnest.
Nach dem ersten Start erscheint das Symbol 📎 in der Menüleiste, und Keepit stellt drei Fragen.

**1. Aus einem Backup wiederherstellen?** Wenn das ein neuer Mac ist und du ein Keepit-Backup hast
(ein automatisches in iCloud Drive oder einem anderen Ordner oder eine exportierte `.keepit`-Datei),
holt *Aus Backup wiederherstellen …* Verlauf und Vorlagen zurück, bevor irgendetwas anderes passiert.
Die Datei entsperrst du mit dem Passwort des Mac, von dem sie stammt, oder mit dessen
Wiederherstellungsphrase. *Neu beginnen* überspringt den Schritt. Dieselbe Wiederherstellung findest du
später unter *Einstellungen → Backup → Wiederherstellen …*, und auch ein Doppelklick auf eine
`.keepit`-Datei im Finder öffnet sie. Die Einzelheiten stehen unter [Backup](#backup).

![Die erste Frage auf einem neuen Mac: aus einem Backup wiederherstellen oder neu beginnen](site/img/guide/restore-first-run.png)

**2. Ein Passwort (optional).** Keepit kann Verlauf und Vorlagen verschlüsselt speichern und per
Touch ID entsperren. Entscheiden kannst du jetzt oder später unter *Einstellungen → Sicherheit*;
[Teil 6](#part-6-security) erklärt, wie das funktioniert. Mit *Nicht jetzt* bleibt alles
unverschlüsselt auf der Festplatte. Hast du gerade ein Backup mit seinem Passwort wiederhergestellt,
bietet Keepit an, dieses Passwort für diesen Mac zu übernehmen.

![Das Passwort-Angebot beim ersten Start](site/img/guide/password-offer.png)

![„Nicht jetzt“ gewählt: eine klare Aussage, was das bedeutet und wo es sich ändern lässt](site/img/guide/no-password-notice.png)

**3. Die Berechtigung für Bedienungshilfen.** Um für dich einzufügen, sendet Keepit ⌘V an die App, in
der du gearbeitet hast. macOS erlaubt das nur Apps, die unter *Systemeinstellungen → Datenschutz &
Sicherheit → Bedienungshilfen* aufgeführt sind. Klicke auf *Systemeinstellungen öffnen* und schalte
Keepit ein. Ohne die Berechtigung zeichnet Keepit weiter auf und kopiert, aber ⌘V drückst du selbst.

![Keepit bittet um die Berechtigung für Bedienungshilfen](site/img/guide/accessibility-prompt.png)

![Keepit ist unter Datenschutz & Sicherheit → Bedienungshilfen eingeschaltet](site/img/guide/accessibility-settings.png)

Keepit startet standardmäßig bei der Anmeldung. Unter *Einstellungen → Allgemein* lässt sich das
abschalten.

---

## Teil 2: Im Alltag

### Das Verlaufsmenü

Drücke **⌥M** in einer beliebigen App oder klicke auf das Symbol 📎. Das Menü öffnet sich am
Textcursor, wenn Keepit ihn findet, sonst am Mauszeiger.

Jede Zeile ist ein kopierter Eintrag, der neueste steht oben. Er ist **fett** dargestellt, denn er
liegt gerade in der Zwischenablage. Das Symbol zeigt die App, aus der du kopiert hast. Endet ein Titel
auf `…`, hat der Eintrag mehr Zeilen, als das Menü zeigt. Bilder erscheinen als Miniatur, Dateilisten
mit den Dateinamen.

![Das Vorschaufenster neben dem Menü zeigt den markierten Eintrag vollständig, mit Quell-App, Zeit und Größe](site/img/guide/menu-preview.png)

![Ein Bild im Verlauf: Miniatur im Menü, das ganze Bild in der Vorschau](site/img/guide/menu-image.png)

Um einen Eintrag einzufügen, klicke ihn an, oder gehe mit ↑ ↓ zu ihm und drücke den Zeilenschalter,
oder drücke seine Nummer zusammen mit **⌃⌥**: `⌃⌥3` fügt Eintrag 3 ein. Dieselbe Taste funktioniert
überall, auch ohne das Menü zu öffnen.

Unter dem Verlauf stehen das Untermenü *Vorlagen*, der Viewer (⌥E), die Einstellungen (⌥S), *Verlauf
löschen* (⌥C), *Aufzeichnung 10 Minuten pausieren* (⌥P, wenn du etwas tippst, das nicht aufgezeichnet
werden soll), *Keepit sperren* (⌥L), sofern ein Passwort gesetzt ist, und die Update-Funktion. **⌥T**
öffnet das Vorlagenmenü allein. Alle diese Tasten funktionieren auch ohne das Menü.

### Suche und Vorschau

**Suche.** Tippe einfach los, während das Menü offen ist: Das Feld oben filtert die Liste nach Titel
und nach dem vollen Text, also wird auch eine Zeile mitten in einem langen Eintrag gefunden. Der
Zeilenschalter fügt den ersten Treffer ein, Esc leert das Feld, ein zweites Esc schließt das Menü.

**Vorschau.** Zeig mit der Maus auf einen Eintrag (oder geh mit der Tastatur zu ihm), und ein Fenster
neben dem Menü zeigt das ganze Bild oder die ersten Zeilen eines langen Textes, dazu Quell-App, Datum
und Größe. Kurze einzeilige Texte haben keine Vorschau, weil die Menüzeile sie schon vollständig zeigt.

![Tippen filtert das Menü; das Vorschaufenster zeigt den markierten Eintrag](site/img/guide/search-preview.png)

### Einfügen ohne Menü

Systemweite Tastenkürzel arbeiten aus jeder App heraus mit dem Verlauf in seinem aktuellen Zustand.
Eintrag 1 ist dabei die Zwischenablage:

| Tasten | Was passiert |
|------|--------------|
| `⌃⌥1` … `⌃⌥9`, `⌃⌥0` | Verlaufseintrag 1–10 einfügen |
| `⌥⇧V` | Den *vorherigen* Eintrag (Eintrag 2) einfügen; noch einmal drücken, um zurückzutauschen |
| `⌃⌥V` | Zwischenablage als reinen Text einfügen, ohne Formatierung |
| `⌃⌥U` `⌃⌥L` `⌃⌥T` `⌃⌥S` | Zwischenablage in GROSSBUCHSTABEN / kleinbuchstaben / Mit Großen Wortanfängen / mit großem Satzanfang einfügen |
| `⌃⌥W` | Zwischenablage ohne Leerraum am Anfang und Ende einfügen |
| `⌃⌥J` | Zwischenablage zu einer Zeile zusammengefasst einfügen |
| `⌃⌥K` `⌃⌥D` `⌃⌥Y` | Zwischenablage durchgestrichen / unterstrichen / mit Wellenlinie einfügen, als reiner Text, der überall gleich aussieht, auch in Chats (siehe unten) |
| `⌃⌥X` | Zwischenablage ohne diese Verzierungen einfügen |
| `⌃⌥A` | Zwischenablage zu Vorlagen hinzufügen |
| `⌃⌥⌫` | Den neuesten Eintrag aus dem Verlauf löschen |

Die drei Verzierungen sind keine Formatierung: Keepit setzt hinter jedes Zeichen ein
*kombinierendes Zeichen* aus Unicode (d̶u̶r̶c̶h̶g̶e̶s̶t̶r̶i̶c̶h̶e̶n̶, u̲n̲t̲e̲r̲s̲t̲r̲i̲c̲h̲e̲n̲, W̰ḛl̰l̰ḛ), deshalb sieht der Text im Messenger,
im Webformular und im Terminal gleich aus, wo echte Formatierung verloren ginge. Der Preis dafür:
Solcher Text ist dreimal so groß, die Suche nach dem normalen Wort findet ihn nicht, Screenreader
stolpern darüber, und manche Schriften zeichnen die Linie ungleichmäßig. *Verzierungen entfernen*
(`⌃⌥X`) nimmt die Zeichen wieder heraus, auch aus Text, der anderswo verziert wurde. In beiden
Richtungen werden die Zeichen nach Codepunkt entfernt, egal woher sie stammen: Eine Lautschrift, die
dieselben Zeichen als Buchstaben verwendet (U+0330 ist auch das IPA-Zeichen für Knarrstimme), verliert
sie, und auch die drei Verzierungen entfernen sie zuerst. Bei eingeschaltetem VoiceOver ist `⌃⌥`
dessen eigene Sondertaste: Gib *Aktionen für den neuesten Eintrag* unter Einstellungen → Kurzbefehle
eine andere.

Umwandlungen gelten für Text. Bei einem Bild oder einer Dateiliste ertönt nur ein Signalton. Alles
lässt sich unter *Einstellungen → Kurzbefehle* ändern oder abschalten.

### Die Einfügewarteschlange

Manchmal willst du an einer Stelle fünf Dinge kopieren und sie woanders der Reihe nach einfügen:
Zellen in ein Formular, Zeilen von einer Seite in ein Dokument. Die Einfügewarteschlange erledigt das
ohne Menü:

1. Drücke **⌥N** (oder wähle *Einfügewarteschlange starten* im Menü). Das Symbol in der Menüleiste
   zeigt einen roten Punkt und einen Zähler: `📎 ● 0`.
2. Kopiere wie gewohnt mit ⌘C, so oft du willst. Der Zähler steigt mit jeder Kopie: 1, 2, 3… Alles
   landet auch im Verlauf.

   ![Die Menüleiste bei laufender Warteschlange: roter Punkt und Zähler](site/img/guide/queue-menubar.png)

3. Wechsle dorthin, wo der Text hin soll, und drücke für jeden Eintrag **⌥V**. Was du zuerst kopiert
   hast, wird zuerst eingefügt, der Zähler sinkt. ⌘V fügt weiterhin wie gewohnt die Zwischenablage
   ein, du kannst also beides mischen.
4. Die Warteschlange schaltet sich ab, wenn der letzte Eintrag eingefügt ist oder wenn zwei Minuten
   lang nichts kopiert oder eingefügt wurde (die Zeit ist einstellbar). Ein weiteres ⌥N beendet sie
   vorzeitig.

**⌥⇧N** fügt alles, was noch in der Warteschlange ist, auf einmal ein. Die Einträge werden mit einem
Zeilenumbruch, einem Tabulator, einem Leerzeichen oder gar nicht verbunden. Das wählst du im Bereich
*Einfügewarteschlange* der Einstellungen, wo auch die Wartezeit steht. Solange die Warteschlange
läuft, markiert das Verlaufsmenü ihre Einträge: `▶` ist als Nächstes dran, `○` wartet noch, `✓` ist
schon eingefügt.

![Das Verlaufsmenü bei laufender Warteschlange: ○ wartet, ▶ als Nächstes, ✓ eingefügt; die Menüzeile zeigt, wie viele übrig sind](site/img/guide/queue-menu.png)

![Einstellungen → Einfügewarteschlange](site/img/guide/prefs-queue.png)

### Das erweiterte Menü

Halte **⇧** gedrückt, während das Verlaufsmenü offen ist, und jeder Eintrag bekommt ein Untermenü `▸`
mit allen Aktionen für diesen Eintrag: Einfügen, Als reinen Text einfügen, Nur kopieren (in die
Zwischenablage, ohne Einfügen), die Umwandlungen unter *Einfügen als*, Zu Vorlagen hinzufügen, Im
Viewer anzeigen, Löschen. Zeig auf einen Eintrag oder drücke →, um es zu öffnen. Sobald es offen ist,
kannst du ⇧ loslassen.

![⇧ gedrückt halten: Jeder Eintrag bekommt ein Untermenü; beim neuesten Eintrag zeigt es die systemweiten Tastenkürzel](site/img/guide/extended-menu.png)

Beim neuesten Eintrag führt das Untermenü die systemweiten Tastenkürzel aus der Tabelle oben auf. Es
sind dieselben Aktionen mit denselben Tasten, du kannst sie also hier lernen. Andere Einträge zeigen
die Aktionen ohne Tasten: Ein Kürzel funktioniert entweder überall oder wird nicht angezeigt.

![Bei anderen Einträgen: dieselben Aktionen, keine Tastenkürzel](site/img/guide/extended-menu-item2.png)

![Bei einem Bild sind die Textaktionen ausgegraut; es gelten nur Einfügen, Nur kopieren, Zu Vorlagen hinzufügen, Im Viewer anzeigen und Löschen](site/img/guide/extended-menu-image.png)

---

## Teil 3: Vorlagen

Vorlagen sind Einträge, die du dauerhaft behältst: Signaturen, Adressen, Standardantworten,
Code-Schnipsel, ein Logo, das du oft einfügst. Sie liegen in einem Baum mit Ordnern und erscheinen im
Untermenü *Vorlagen* des Verlaufsmenüs und unter **⌥T**. Eine frische Installation bringt einen
Ordner *Beispiele* mit (eine Begrüßung, das heutige Datum, ein Zitat der Zwischenablage und eine
Signatur), damit du siehst, was Vorlagen können, bevor du eigene schreibst. Lösche oder bearbeite sie
nach Belieben (*Zurücksetzen …* in den Einstellungen bringt sie zurück).

![Der Ordner Beispiele: Beim Zeigen auf einen Eintrag erscheint sein Text](site/img/guide/template-examples.png)

![Das Vorlagenmenü: Ordner öffnen sich als Untermenüs, Buchstaben nach & werden zu Kurztasten](site/img/guide/template-menu-letters.png)

### Anlegen und ordnen

**Eine Vorlage hinzufügen**

- Aus dem Verlaufsmenü: `⌃⌥A` für den neuesten Eintrag, *Zwischenablage zu Vorlagen hinzufügen* ganz
  unten oder ⇧ → Untermenü des Eintrags → *Zu Vorlagen hinzufügen* für jeden beliebigen Eintrag.
- Im Viewer: Wähle einen Verlaufseintrag und klicke auf *Zu Vorlagen hinzufügen*, oder zieh ihn auf den
  Vorlagenbaum. *Neuer Eintrag* legt eine leere Textvorlage an; *Neuer Eintrag aus Datei …*
  (Kontextmenü) erstellt eine aus einer Text- oder Bilddatei.

**Ordnen**

- *Neuer Ordner* legt einen Ordner an. Zieh Einträge zwischen Ordnern hin und her oder nutze *Nach
  oben* / *Nach unten* im Kontextmenü.
- Eine Vorlage mit dem Namen `-` wird im Menü zur Trennlinie.
- Ein `&` vor einem Buchstaben im Namen (etwa `&Signatur`) macht diesen Buchstaben zur Kurztaste im
  Vorlagenmenü: Drücke `S`, während das Menü offen ist.
- *Tastenkürzel festlegen …* im Kontextmenü gibt einer Vorlage ein eigenes systemweites Kürzel.
- Eine Vorlage ohne Namen zeigt ihre erste Zeile. *Umbenennen* und *Namen löschen* stehen im
  Kontextmenü, oder du bearbeitest das Feld *Name* über dem Text.

### Platzhalter

Textvorlagen können Platzhalter der Form `{…}` enthalten, die beim Einfügen ausgefüllt werden. Alles
andere wird unverändert eingefügt. Im Viewer listet **Einfügen ▾** alle Platzhalter auf und setzt den
gewählten an die Cursorposition, du musst dir also nichts merken.

![Das Beispiel „Heutiges Datum“: `{date:EEEE, d MMMM yyyy}` wird beim Einfügen zum aktuellen Datum](site/img/guide/template-examples-date.png)

![Einfügen ▾ im Viewer listet alle Platzhalter auf](site/img/guide/insert-menu.png)

Die nützlichsten:

| Platzhalter | Ergebnis |
|-------------|--------|
| `{date}` `{time}` `{datetime}` | Heutiges Datum / aktuelle Uhrzeit im Systemformat |
| `{date:yyyy-MM-dd}` | Beliebiges Format (`yyyy MM dd EEEE HH mm …`) |
| `{date:long}` `{time:short}` `{datetime:medium}` | Ein benannter Stil: `short` `medium` `long` `full` |
| `{date+7d}` `{date-1m:MMMM}` `{time+1h}` `{date+1y-2d}` | Verschoben: `d` Tage, `w` Wochen, `m` Monate, `y` Jahre, `h` Stunden; für `date`, `time`, `datetime`, auch mehrere hintereinander |
| `{clipboard}` `{clipboard:2}` | Die Zwischenablage oder Verlaufseintrag N |
| `{clipboard\|upper}` `{clipboard\|trim\|oneline}` | Filter `upper` `lower` `title` `trim` `oneline` `url`, verkettbar |
| `{cursor}` | Wo der Textcursor nach dem Einfügen steht |
| `{user}` `{username}` `{host}` | Voller Name, Accountname, Computername |
| `{uuid}` `{random:1-100}` | Eine neue UUID; eine Zufallszahl |
| `{{` `}}` | Wörtliche geschweifte Klammern: Die Vorlage `{{"x":1}}` fügt `{"x":1}` ein |

Platzhalternamen werden kleingeschrieben: `{date}` ist ein Platzhalter, `{Date}` und `{DATE}` sind
Text und werden unverändert eingefügt. Stilnamen und Filter (`{date:LONG}`, `{clipboard|UPPER}`)
dürfen beliebig geschrieben werden.

Die vollständige Liste steht unter [Platzhalter im Überblick](#placeholder-cheat-sheet).

### Vorlagen, die Fragen stellen

`{input:Name}` und `{choice:Label=A|B|C}` machen aus einer Vorlage ein kleines Formular: Beim
Einfügen fragt Keepit zuerst die Werte ab und fügt dann den fertigen Text ein. Derselbe Name wird nur
einmal abgefragt, egal wie oft er vorkommt. `{input:Name=Default}` füllt das Feld vor.

![Beim Einfügen einer Vorlage mit {input:Name} wird zuerst der Wert abgefragt](site/img/guide/input-dialog.png)

Zum Beispiel eine Antwortvorlage:

```
Hallo {input:Name},

danke für deine Nachricht vom {date-1d}. Ich melde mich bis {date+3d:EEEE}.
{cursor}
{user}
```

Beim Einfügen fragt sie nach *Name*, setzt die Daten ein, unterschreibt mit deinem vollen Namen und
lässt den Cursor in der leeren Zeile stehen.

---

## Teil 4: Der Viewer

*Viewer …* im Menü oder ein Rechtsklick auf das Symbol 📎 öffnet ein Fenster mit drei Bäumen:
**Zwischenablage** (der aktuelle Inhalt, nur lesbar), **Verlauf** (*Text & Dateien* und *Bilder*) und
**Vorlagen**.

![Der Viewer mit einer ausgewählten Vorlage](site/img/guide/viewer.png)

- Wähle einen Eintrag, um ihn rechts zu sehen. Text lässt sich an Ort und Stelle bearbeiten, die
  Änderungen gelten, sobald du den Editor verlässt. Ein Bild wird an den Bereich angepasst angezeigt,
  darüber stehen Pixelmaße und Dateigröße. In Dateilisten öffnet ein Doppelklick die Datei. *Als
  Hexdump anzeigen* im Kontextmenü zeigt die rohen Bytes.
- Die Symbolleiste: *In die Zwischenablage legen*, *Einfügen* (in die App, aus der du kommst), *Zu
  Vorlagen hinzufügen*, *Neuer Eintrag*, *Neuer Ordner*, *Löschen*, *Einfügen ▾* (Platzhalter) und
  **?**, also dieses Handbuch.
- **Suchen** (`⌘F`): Das Feld links filtert Verlauf und Vorlagen nach Name und Inhalt und hebt den
  Treffer hervor.
- Zieh Verlaufseinträge in den Vorlagenbaum, um sie zu behalten, und Vorlagen in den Verlauf, um sie
  zurückzukopieren. Die Reihenfolge änderst du durch Ziehen oder mit *Nach oben* / *Nach unten*. ⌫
  löscht den ausgewählten Eintrag.
- Die Statusleiste zeigt Datum, Quell-App, Format und Größe.

![Die Suche im Viewer hebt Treffer hervor](site/img/guide/viewer-search.png)

---

## Teil 5: Einstellungen

`⌘,` im Menü, *Einstellungen …* oder ⌥S aus jeder App. Das Fenster funktioniert so, wie
Einstellungsfenster auf dem Mac funktionieren: Wähle einen Bereich in der Symbolleiste, und jede
Änderung gilt sofort. Einen Sichern-Knopf gibt es nicht. Schließen kannst du das Fenster mit ⌘W oder
Esc. Jede Option mit einem **?** daneben hat ein Popover mit einer Erklärung.

![Einstellungen → Allgemein](site/img/guide/prefs-general.png)

| Bereich | Was dort steht |
|-----|---------------|
| **Allgemein** | Beim Anmelden starten · Verlauf beim Beenden sichern, beim Start wiederherstellen · nach der Auswahl einfügen (aus = nur kopieren) · Einfügeverzögerung (erhöhe sie für Apps, die langsam in den Vordergrund kommen) · Menü am Textcursor öffnen · Updates: *Automatisch nach Updates suchen* (Version zum direkten Download; aus = überhaupt keine Netzwerkanfrage) — [Updates](#updates) |
| **Kurzbefehle** | Alle systemweiten Tastenkürzel an einem Ort, siehe unten |
| **Einfügewarteschlange** | Die drei Tasten der Warteschlange, die Wartezeit, nach der sie sich abschaltet, und was bei *Alle verbleibenden einfügen* zwischen die Einträge kommt — [Die Einfügewarteschlange](#the-paste-queue) |
| **Verlauf** | Wie viele Text-/Dateieinträge und Bilder behalten werden (1000 / 30) · Einträge vergessen, die älter sind als … · *Duplikate entfernen* (erneutes Kopieren derselben Sache holt sie nach oben) · *Vertrauliche Zwischenablage-Daten ignorieren* · die Liste ignorierter Apps (Bundle-IDs; Passwortmanager werden immer ignoriert) |
| **Menü** | Suchfeld · Nummerierung · Vorschaufenster · Tooltips · Symbole der Quell-Apps · Bildminiaturen · Einträge im Menü (wie viele der neuesten Einträge das Menü auflistet, standardmäßig 60; die übrigen bleiben durchsuchbar) · Titellänge · Höhe der Miniaturen |
| **Sicherheit** | Passwort, Touch ID, Sperren, Wiederherstellungsphrase — [Teil 6](#part-6-security) |
| **Backup** | Automatisches Backup (Statuszeile neben der Überschrift): *Automatisch in einen Ordner sichern*, der Name des Mac in den Dateien, der Ordner, wie viele Kopien behalten werden · Manuelles Backup: *Jetzt sichern*, *In Archiv sichern …* · Wiederherstellen: *Wiederherstellen …* — [Backup](#backup) |
| **Erweitert** | Abfrageintervall der Zwischenablage · Automatisierung: *keepit://-URL-Befehle erlauben* (standardmäßig aus — [Automatisierung](#automation-the-keepit-url-scheme)) · Daten: *Ordner öffnen* · Zurücksetzen und deinstallieren: *Zurücksetzen …* (zurück zum Zustand nach der Installation, die Beispielvorlagen kommen wieder) · *Deinstallieren …* (zurücksetzen, dann App, Anmeldeobjekt, Schlüsselbundeintrag und Berechtigungen entfernen) |

![Einstellungen → Verlauf: Limits und die Liste ignorierter Apps](site/img/guide/prefs-history.png)

![Einstellungen → Kurzbefehle](site/img/guide/prefs-hotkeys.png)

Im Bereich **Kurzbefehle** klickst du in ein Feld und drückst eine Kombination. ⌫ schaltet eine Taste
ab. Eine Kombination, die schon ein anderer Befehl verwendet, wird abgelehnt, der Grund steht unter
den Feldern. *Auf Standard zurücksetzen* stellt den Satz aus ⌥ und Buchstabe wieder her (⌥M Verlauf,
⌥T Vorlagen, ⌥E Viewer, ⌥S Einstellungen, ⌥C Verlauf löschen, ⌥P Pause, ⌥L Sperren, ⌥Q Beenden),
dazu ⌥⇧V und ⌃⌥. *Eintrag nach Nummer einfügen* und *Aktionen für den neuesten Eintrag* nehmen nur
Sondertasten an, die Ziffer oder den Buchstaben ergänzt Keepit. Gehört eine Kombination bereits macOS
oder einer anderen App, meldet Keepit das beim Start. *Viewer* ⌥E, *Einstellungen* ⌥S, *Verlauf
löschen* ⌥C, *Aufzeichnung pausieren* ⌥P, *Keepit sperren* ⌥L und *Keepit beenden* ⌥Q funktionieren
aus jeder App und stehen im Menü neben ihren Befehlen. Auf der Mac-Tastatur schreibt ⌥ mit einem
Buchstaben normalerweise ein Sonderzeichen (auf der deutschen Belegung etwa ⌥L = @, ⌥E = €). Wenn du
eines davon brauchst, leg den Befehl auf eine andere Taste.

---

## Teil 6: Sicherheit

### Passwort und Verschlüsselung

*Einstellungen → Sicherheit → Passwort beim Start verlangen* verschlüsselt Verlauf und Vorlagen mit
AES-256-GCM. Der Schlüssel wird aus deinem Passwort abgeleitet (PBKDF2, 200 000 Runden) und existiert
nur im Arbeitsspeicher. Er wird gelöscht, wenn Keepit sperrt: bei *Keepit sperren* (`⌥L`), beim
Beenden und auf Wunsch, nachdem der Mac eine Weile gesperrt oder im Ruhezustand war. *Keepit
automatisch sperren* steht bei einer neuen Installation auf **Nie** (ein Update von 3.0.3 behält die
alte Wahl, nämlich *Sofort*, wenn das Sperren zusammen mit dem Bildschirm eingeschaltet war). Ein
Clipboard-Manager, der nach jeder Kaffeepause sein Passwort verlangt, wird bald nicht mehr benutzt,
und für die Momente, in denen es darauf ankommt, gibt es `⌥L`. *Sofort* sperrt zusammen mit dem
Bildschirm. *Nach 5 Minuten*, *15 Minuten* oder *1 Stunde* lassen eine kurze Abwesenheit
unberücksichtigt: Keepit bleibt entsperrt und zeichnet weiter auf und sperrt erst, wenn der Mac die
ganze Zeit über weg war. Dasselbe gilt, wenn Keepit startet, während der Mac schon gesperrt ist oder
die Sitzung eines anderen Benutzers im Vordergrund läuft (etwa bei einem Neustart nach einem Update):
Die Abwesenheit zählt ab dem Start, soweit macOS diesen Zustand an Keepit meldet (normalerweise tut es
das; wenn nicht, beginnt die Zählung mit der nächsten Sperre oder dem nächsten Ruhezustand). Mit
Touch ID bittet Keepit in dem Moment um eine Berührung, in dem der Mac entsperrt wird, und ist so vor
dem ersten `⌥M` bereit.

![Passwort festlegen mit der Bildschirmtastatur. Ein Foto des Bildschirms, kein Bildschirmfoto: Auf dem Mac des Autors zeigt ein Bildschirmfoto dieser Szene nur den Dialog](site/img/guide/set-password-keyboard.jpg)

Die Passwortdialoge zeigen die aktuelle Tastaturbelegung und warnen bei aktiver Feststelltaste, ein
abgelehntes Passwort ist also selten ein Rätsel. Die Tastaturtaste neben dem Feld öffnet eine
**Bildschirmtastatur**, mit der du das Passwort per Maus eingibst: Die Klicks laufen nie als
Tastendrücke durch das System, die Tasten werden bei jedem Öffnen neu gemischt, und die Tastatur
bittet macOS, sie aus Bildschirmfotos und Bildschirmaufnahmen herauszuhalten (bei manchen
Konfigurationen wird sie ausgeschlossen, garantiert ist das nicht). Gedacht ist sie für einen Mac, dem
du nicht ganz traust, oder für einen, dessen Bildschirm gerade geteilt wird. Beim Start und nach
einer Sperre fragt Keepit nach dem Passwort (oder Touch ID). *Zugang wiederherstellen…* nimmt
stattdessen die Phrase aus 24 Wörtern entgegen, siehe [Wiederherstellungsphrase](#recovery-phrase).

![Entsperren beim Start: Passwort, Beenden oder die Wiederherstellungsphrase; OK bleibt deaktiviert, bis etwas eingegeben ist. Aus demselben Grund fotografiert](site/img/guide/unlock-keyboard.jpg)

![Einstellungen → Sicherheit](site/img/guide/prefs-security.png)

### Touch ID

Mit *Mit Touch ID entsperren* liegt der Schlüssel zusätzlich in der Secure Enclave, geschützt durch
deinen Fingerabdruck: Keepit bittet um eine Berührung statt um das Passwort. Das Passwort
funktioniert weiterhin als Ausweg (die Passwort-Taste im Dialog). Ist der Deckel geschlossen und ein
externes Magic Keyboard mit Touch ID angeschlossen, fragt Keepit dort. Mit *Passwortänderung per
Touch ID erlauben* kann ein Fingerabdruck beim Ändern des Passworts das alte Passwort ersetzen.

![Entsperren per Touch ID; das Passwort bleibt als Ausweg](site/img/guide/touch-id.png)

### Wiederherstellungsphrase

Wenn du ein Passwort festlegst, zeigt Keepit einmal eine Phrase aus 24 Wörtern. Druck sie aus oder
leg sie in einem Passwortmanager ab. Hast du das Passwort vergessen, öffnet *Zugang
wiederherstellen…* im Entsperrdialog die Daten und lässt dich ein neues festlegen.
*Wiederherstellungsphrase → Neu erstellen …* gibt eine neue Phrase aus und macht die alte ungültig.
*Anzeigen …* daneben zeigt die aktuelle Phrase nach Touch ID oder Passwort noch einmal.

Ohne das Passwort, Touch ID auf demselben Mac oder die Phrase lassen sich die Daten nicht
wiederherstellen: Es gibt keinen Server und nichts, was sich zurücksetzen ließe.

![Die Wiederherstellungsphrase aus 24 Wörtern (die Wörter sind hier verdeckt)](site/img/guide/recovery-phrase.png)

### Backup

Keepit kann eine verschlüsselte Kopie von Verlauf und Vorlagen in einem Ordner deiner Wahl ablegen
(iCloud Drive, Dropbox, Google Drive, eine externe Festplatte, ein NAS) und immer dann eine neue
schreiben, wenn sich etwas geändert hat. Einen Keepit-Server gibt es nicht, der Ordner gehört dir.
Der Anbieter dahinter sieht die verschlüsselte Datei, ihre Größe und einen kleinen unverschlüsselten
Header (wann und von welcher Keepit-Version sie geschrieben wurde, wie der Schlüssel abgeleitet wird,
zufällige Kennungen und den Namen deines Mac nur dann, wenn du das einschaltest). Die
[Sicherheitsseite](/security#backups) (englisch) führt ihn Feld für Feld auf.

![Einstellungen → Backup: automatisches Backup, manuelles Backup, Wiederherstellen](site/img/guide/prefs-backup.png)

**Einschalten.** *Einstellungen → Backup → Automatisch in einen Ordner sichern*, dann mit
*Auswählen …* einen Ordner bestimmen (der Dialog öffnet sich in iCloud Drive). Das automatische Backup
setzt den Passwortschutz aus *Einstellungen → Sicherheit* voraus: Jede Kopie wird mit einem Schlüssel
versiegelt, der aus dem Schlüssel deines Tresors abgeleitet ist. Sie lässt sich deshalb auf diesem
oder jedem anderen Mac mit deinem Keepit-Passwort oder deiner Wiederherstellungsphrase öffnen, und
dafür muss nichts eingerichtet werden. Ohne Passwort ist das Markierungsfeld deaktiviert und sagt das
auch.

**Was dann passiert: der Zeitplan.** Etwa fünf Minuten nach der letzten Änderung (und spätestens
einmal am Tag, solange Keepit läuft) schreibt Keepit eine Datei namens
`Keepit-<date and time>-<installation>-<id>.keepit` in den Ordner, liest sie zur Kontrolle wieder
ein und löscht erst dann die ältesten eigenen Kopien, die über *Behalten* hinausgehen (standardmäßig
10, möglich sind 1–100). Jede Kopie ist für sich vollständig und kein Inkrement, eine einzige Datei
reicht also immer. Kopien eines anderen Mac und Dateien, die du selbst dort ablegst, werden nie
angerührt: Zwei Macs, die sich einen Ordner teilen, schreiben zwei unabhängige Serien. Die Statuszeile
neben der Überschrift *Automatisches Backup* zeigt Zeit und Größe der letzten Kopie oder den Grund,
warum der letzte Versuch fehlschlug. Solange Keepit gesperrt ist, passiert nichts. *Jetzt sichern*
(unter *Manuelles Backup*) wartet die Ruhephase nicht ab.

**Namen dieses Mac in die Backup-Dateien aufnehmen** (standardmäßig aus) schreibt den Namen des
Computers in den unverschlüsselten Header jeder Datei, damit sich zwei Serien in einem Ordner im
Finder leicht unterscheiden lassen. Der Speicheranbieter kann diesen Namen sehen, deshalb ist die
Option freiwillig.

**Wiederherstellen.** *Wiederherstellen …* öffnet ein Backup (von diesem Mac, von einem anderen Mac
oder eine exportierte Datei), nachdem du es entsperrt hast: mit dem Passwort des Mac, auf dem es
entstanden ist, oder mit der Wiederherstellungsphrase, die jener Mac beim Festlegen seines Passworts
gezeigt hat (*Zugang wiederherstellen…* im Passwortdialog). Eine Vorschau zeigt, wann und wo die Datei
entstanden ist und wie viele Einträge sie enthält. Danach hast du die Wahl:

![Die Vorschau der Wiederherstellung: wann und von welcher Keepit-Version die Datei geschrieben wurde, was sie enthält, Zusammenführen oder Ersetzen](site/img/guide/restore-preview.png)

- *Zusammenführen* ergänzt, was noch nicht da ist: Verlaufseinträge nach Inhalt und die Vorlagen des
  Backups als einen neuen Ordner *Import <Datum>*, ohne ihre Tastenkürzel. So siehst du genau, was
  aus dem Backup stammt, und kannst es verschieben oder löschen. Von deinen Daten wird nichts
  überschrieben.
- *Ersetzen* verwirft den aktuellen Verlauf und die Vorlagen und übernimmt stattdessen die des
  Backups. Vorher schreibt Keepit eine Kopie deines jetzigen Stands (`Keepit-before-restore-…`) in den
  Backup-Ordner oder in einen Ordner, den du auswählst. Lässt sich diese Kopie nicht schreiben, startet
  das Ersetzen nicht. Hat Keepit noch kein Passwort, wirst du für diese Kopie nach einem gefragt, wie
  bei *In Archiv sichern …*.

*Auch Einstellungen wiederherstellen* übernimmt Tastenkürzel, Limits und Optionen aus dem Backup. Die
Einstellungen, die Vertrauen in einen bestimmten Mac ausdrücken (Touch ID, die URL-Automatisierung und
ihre vertrauenswürdigen Apps, der Backup-Ordner selbst), bleiben immer so, wie sie hier sind. Ist der
Verlauf des Backups größer, als die Limits dieses Mac erlauben, sagt Keepit vor dem Bestätigen, wie
viel hineinpasst.

Du hast ein Backup mit seiner Wiederherstellungsphrase auf einem Mac wiederhergestellt, der noch kein
Passwort hat? Keepit bittet dich, zuerst eines festzulegen, damit die wiederhergestellten Daten nie
unverschlüsselt auf der Platte landen, und lässt dich die Phrase für diesen Mac behalten oder eine
neue erzeugen. Mit dem Passwort wiederhergestellt? Keepit bietet an, es als Passwort dieses Mac zu
übernehmen. In beiden Fällen ist das automatische Backup eine Einstellung pro Mac: Schalte es hier
ein und wähle den Ordner (derselbe ist in Ordnung), und dieser Mac beginnt neben der Serie des alten
Mac seine eigene.

**Der Umzug auf einen neuen Mac** ist der eigentliche Zweck: Installiere Keepit, wähle beim ersten
Start *Aus Backup wiederherstellen …*, nimm die neueste Datei in deinem Ordner, gib das Passwort des
alten Mac ein und klicke auf *Ersetzen*. Schalte danach das automatische Backup für den neuen Mac ein.
Bisherige Kopien lassen sich mit dem Passwort und der Phrase öffnen, die beim Schreiben der jeweiligen
Kopie galten: Nach einer Passwortänderung brauchen die alten weiterhin das alte Passwort.

**Manuelles Backup.** Zwei Knöpfe, zwei verschiedene Dinge. *Jetzt sichern* erstellt sofort eine
Kopie wie die automatischen: dieselbe Art Datei, derselbe Ordner und dieselbe Serie, zu öffnen mit
deinem Keepit-Passwort oder der Phrase. *In Archiv sichern …* schreibt ein einzelnes
`.keepit`-*Archiv* an einen Ort deiner Wahl, gesperrt mit einem Passwort, das du dafür aussuchst. Es
braucht den Passwortschutz von Keepit nicht, und Keepit behält die Datei danach nicht im Blick. Das
eignet sich zum Weitergeben von Daten oder für eine Kopie außerhalb des Backup-Ordners. Der
vorgeschlagene Name sagt, was es ist: `Keepit-archive-<date>-manual.keepit`, im Unterschied zu den
automatischen Kopien `Keepit-<date and time>-<installation>-<id>.keepit`.

![In Archiv sichern …: Der Dateiname enthält archive und manual](site/img/guide/save-to-archive.png)

![Das eigene Passwort des Archivs mit einer Stärkeanzeige: Es wird nirgends gespeichert](site/img/guide/archive-password.png)

*Wiederherstellen …* öffnet beide Arten. Das Archiv ersetzt *Exportieren …* / *Importieren …* aus
2.x. Die Datei überträgt Daten zwischen der Version zum direkten Download und der App-Store-Version
sowie zwischen Keepit 2.x und 3.x. Eine von 3.0 geschriebene Datei braucht zum Öffnen 3.0 oder neuer;
3.0 liest alles, was 2.x geschrieben hat.

**Wenn etwas schiefgeht.** Eine fehlgeschlagene Kopie wird in der Statuszeile gemeldet und mit
wachsenden Pausen erneut versucht. Die bisherigen Kopien bleiben erhalten. Wurde Keepit mitten in
einer Wiederherstellung beendet oder ist der Mac abgestürzt, stellt der nächste Start stillschweigend
alles so wieder her, wie es vor der Wiederherstellung war. Im seltenen Fall, dass das nicht geht (eine
Datei, die sich nicht schreiben lässt, eine volle Festplatte), nennt Keepit die Datei und beendet
sich, ohne etwas zu ändern: Behebe das Problem mit der Datei und starte erneut. Einzelheiten, auch zum
inneren Aufbau des Dateiformats, stehen auf der [Sicherheitsseite](/security#backups) (englisch).

---

## Teil 7: Für Fortgeschrittene

### Automatisierung: das URL-Schema keepit://

Kurzbefehle (*URL öffnen*), Raycast, Alfred, Keyboard Maestro oder `open` in einer Shell können Keepit
steuern, **sobald du das einschaltest**, und zwar unter *Einstellungen → Erweitert → Automatisierung →
keepit://-URL-Befehle erlauben*. Standardmäßig ist es aus, weil jede App und jede Webseite eine URL
öffnen kann und `add` / `paste` die Zwischenablage ändern und in die vorderste App tippen. Ist es aus,
ignoriert Keepit solche URLs mit einem Signalton. Ist es an, prüft Keepit, wer die URL geöffnet hat:
Der erste Befehl jeder App, der etwas ändert (`paste`, `copy`, `template`, `add`, `add-template`,
`pause`, `resume`), wird in einem Dialog angezeigt. *Erlauben* führt ihn einmal aus, *Immer erlauben*
setzt die App auf die Liste der vertrauenswürdigen Apps (sie lässt sich mit *Vertrauenswürdige Apps
vergessen* im selben Bereich leeren). Bei einem Webbrowser oder einem Absender, den macOS nicht
benennen kann, wird jedes Mal gefragt. Befehle, die nur Keepits eigene Fenster öffnen, fragen nie.

| URL | Wirkung |
|-----|--------|
| `keepit://paste/2`<br>`keepit://paste/latest`<br>`keepit://paste/previous` | Verlaufseintrag N (oder den neuesten / den vorherigen) in die vorderste App einfügen |
| `keepit://copy/3` | Eintrag N in die Zwischenablage legen, ohne einzufügen |
| `keepit://template/Signature`<br>`keepit://template/Work/Reply?copy=1` | Eine Vorlage nach Name oder Ordnerpfad einfügen (oder kopieren) |
| `keepit://add?text=…` | Text zum Verlauf und zur Zwischenablage hinzufügen |
| `keepit://add-template?text=…&name=…` | Eine Vorlage anlegen |
| `keepit://history`<br>`keepit://templates`<br>`keepit://viewer`<br>`keepit://settings` | Verlaufsmenü, Vorlagenmenü, Viewer oder Einstellungen öffnen |
| `keepit://pause`<br>`keepit://resume` | Aufzeichnung 10 Minuten pausieren / fortsetzen |

Kodiere den Text mit Prozentkodierung (`%20` für ein Leerzeichen). Solange Keepit gesperrt ist, werden
URLs ignoriert.

### Updates

Keepit sieht einmal am Tag bei GitHub Releases nach und bietet Updates in einem Dialog an. *Nach
Updates suchen …* erledigt das sofort. Updates sind signiert (EdDSA) und notarisiert. Mit Homebrew
macht `brew upgrade --cask keepit` dasselbe. Die Prüfsummen aller Downloads stehen in `SHA256SUMS` auf
der Release-Seite.

Diese Suche ist die einzige Netzwerkanfrage, die Keepit stellt, und sie ist freiwillig: *Einstellungen
→ Allgemein → Updates → Automatisch nach Updates suchen*. Ist sie aus, nimmt Keepit zu nichts Kontakt
auf, auch nicht auf deinen Wunsch, und *Nach Updates suchen …* verschwindet aus den Menüs. Du
aktualisierst dann per Download von [keep.it.com](https://keep.it.com) oder mit Homebrew. Die
App-Store-Version hat weder eine Update-Funktion noch diese Option, sie wird vom App Store
aktualisiert.

### Deinstallieren

*Einstellungen → Erweitert → Zurücksetzen und deinstallieren → Deinstallieren …* entfernt die App, den
Datenordner, die Schlüsselbundeinträge (einschließlich des Touch-ID-Schlüssels), das Anmeldeobjekt und
den Eintrag unter Bedienungshilfen. Keepit verlangt dein Passwort oder Touch ID, das eingetippte Wort
`DELETE` und eine Bestätigung. Exportiere vorher ein Backup, falls du die Daten noch einmal brauchen
könntest. Mit Homebrew führst du anschließend `brew uninstall --cask --force keepit` aus, damit
Homebrew den Cask vergisst.

![Einstellungen → Erweitert](site/img/guide/prefs-advanced.png)

---

## Referenz

### Fehlerbehebung

**Nach der Auswahl eines Eintrags wird nichts eingefügt.** Die Berechtigung für Bedienungshilfen
fehlt: *Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen → Keepit*. Steht Keepit in
der Liste und fügt trotzdem nicht ein, schalte es aus und wieder ein: macOS vergisst die Freigabe,
wenn die App neu installiert wird.

**Ein Tastenkürzel tut nichts.** Es gehört einer anderen App oder macOS. Keepit meldet das beim
Start. Wähle im Bereich *Kurzbefehle* eine andere Kombination. ⌃⌥ mit Ziffern und Buchstaben ist auf
einem Mac im Auslieferungszustand frei.

**Das Menü öffnet sich an der falschen Stelle.** Die App, in der du arbeitest, gibt ihren Textcursor
nicht preis, deshalb weicht das Menü auf den Mauszeiger aus. *Menü nach Möglichkeit am Textcursor
öffnen* im Bereich Allgemein schaltet die Suche nach dem Cursor ab, falls dir der Mauszeiger immer
lieber ist.

**Etwas, das ich kopiert habe, fehlt.** Was die kopierende App als vertraulich markiert, wird nicht
aufgezeichnet. Dasselbe gilt für Kopien, die entstehen, während ein Passwortmanager (eingebaute Liste)
oder eine App von deiner Ignorierliste im Vordergrund war, auch die App, aus der du gerade erst
gewechselt hast. Siehe *Einstellungen → Verlauf* und die
[Sicherheitsseite](/security#what-is-not-recorded) (englisch).

**Touch ID wird nicht angeboten.** Im Moment ist kein Touch-ID-Sensor erreichbar (Deckel geschlossen,
keine Tastatur mit Touch ID). Keepit behält die Einstellung und fragt nach dem Fingerabdruck, sobald
ein Sensor verfügbar ist.

**Der Backup-Status meldet, dass der Ordner nicht verfügbar ist.** Der Ordner wurde verschoben,
umbenannt, ausgeworfen oder (iCloud Drive) vom Gerät entfernt. Aktiviere ihn oder stell ihn wieder
her, dann läuft die nächste Kopie durch. Oder bestimme mit *Auswählen …* einen neuen Ordner: Ein neuer
Ordner beginnt eine neue Serie, die alten Dateien bleiben, wo sie sind.

**Eine Backup-Datei lässt sich nicht öffnen.** *Falsches Passwort* bedeutet, dass das
Authentifizierungs-Tag der Datei nicht passte: Achte darauf, das Passwort des Mac zu verwenden, der
die Datei *geschrieben* hat (nach einer Passwortänderung öffnen sich alte Kopien weiterhin mit dem
alten Passwort), oder dessen Wiederherstellungsphrase. *Dieses Backup benötigt Keepit 3.0 oder neuer*
bedeutet, dass die Datei von einer neueren Version geschrieben wurde als der, die sie öffnet.

**Homebrew weigert sich, über eine vorhandene App zu installieren.** Beende Keepit und leg
`/Applications/Keepit.app` zuerst in den Papierkorb, oder ergänze `--force`.

Kommst du nicht weiter? [GitHub Issues](https://github.com/andrey-insarov/Keepit/issues) · admin@keep.it.com

### Tastenkürzel im Überblick

| Tasten | Aktion |
|------|--------|
| `⌥M` | Verlaufsmenü; tippen, um zu suchen |
| `⌥T` | Vorlagenmenü |
| `⌃⌥1` … `⌃⌥0` | Eintrag 1–10 einfügen (im Menü und überall) |
| `⇧` im Menü | Erweitertes Menü: alle Aktionen pro Eintrag |
| `⌥⇧V` | Vorherigen Eintrag einfügen / tauschen |
| `⌃⌥V` | Zwischenablage als reinen Text einfügen |
| `⌃⌥U` `⌃⌥L` `⌃⌥T` `⌃⌥S` | GROSSBUCHSTABEN / kleinbuchstaben / Große Wortanfänge / großer Satzanfang |
| `⌃⌥W` `⌃⌥J` | Ohne Leerraum am Rand / in einer Zeile |
| `⌃⌥K` `⌃⌥D` `⌃⌥Y` `⌃⌥X` | Durchgestrichen / unterstrichen / Wellenlinie / Verzierungen entfernen |
| `⌃⌥A` | Zwischenablage zu Vorlagen hinzufügen |
| `⌃⌥⌫` | Den neuesten Eintrag löschen |
| `⌥N` · `⌥V` · `⌥⇧N` | Einfügewarteschlange: starten / stoppen · nächsten einfügen · alle verbleibenden einfügen |
| `⌥E` `⌥S` `⌥C` `⌥P` `⌥L` `⌥Q` | Viewer · Einstellungen · Verlauf löschen · Aufzeichnung pausieren · Sperren · Beenden |
| `⌘F` im Viewer | Suchen |
| `⌘,` | Einstellungen |

### Platzhalter im Überblick

| Platzhalter | Ergebnis |
|-------------|--------|
| `{date}` `{time}` `{datetime}` | Datum / Uhrzeit / beides im Systemformat |
| `{date:yyyy-MM-dd}` `{time:HH:mm}` | Eigenes Format (Unicode-Datumsmuster) |
| `{date:long}` `{time:short}` `{datetime:full}` | Benannter Stil: `short` `medium` `long` `full` |
| `{date+7d}` `{date-1m:MMMM}` `{time+1h}` `{datetime-1d:long}` `{date+1y-2d}` | Verschoben (`d` `w` `m` `y` `h`; bis zu vier Verschiebungen hintereinander) |
| `{weekday}` `{month}` `{year}` | Wochentag, Monatsname, Jahr |
| `{iso}` `{unix}` | Zeitstempel nach ISO 8601, Unix-Zeit |
| `{clipboard}` `{clipboard:2}` | Die Zwischenablage (Eintrag 1) oder Eintrag N |
| `{clipboard\|upper}` `\|lower` `\|title` `\|trim` `\|oneline` `\|url` | Filter, verkettbar |
| `{input:Name}` `{input:Name=Default}` | Vor dem Einfügen einen Wert abfragen |
| `{choice:Label=A\|B\|C}` | Eine Option zur Auswahl anbieten |
| `{cursor}` | Cursorposition nach dem Einfügen |
| `{user}` `{username}` `{host}` | Voller Name, Accountname, Computername |
| `{uuid}` `{random:1-100}` | Neue UUID, Zufallszahl aus einem Bereich |
| `{{` `}}` | Wörtliche geschweifte Klammern |
