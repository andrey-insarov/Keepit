<!-- source: GUIDE.md 0be95178b3d79d4d8716766770440ce3a98d0dcf -->
# Keepit-handleiding

Keepit beheert je klembordgeschiedenis en sjablonen op macOS. Het woont in de menubalk, onthoudt
alles wat je kopieert en plakt elk item terug met een sneltoets. Alle sneltoetsen hieronder zijn
de standaardinstellingen en je kunt ze allemaal wijzigen in *Instellingen → Sneltoetsen*. Deze
handleiding beschrijft Keepit 3; de handleiding voor Keepit 2.x blijft ongewijzigd staan op
[keep.it.com/v2/guide](https://keep.it.com/v2/guide) (Engels).

![Het geschiedenismenu](site/img/guide/menu.png)

**Inhoud**

- [Deel 1. Aan de slag](#part-1-getting-started): [Installatie](#install) · [Eerste start](#first-launch)
- [Deel 2. Dagelijks gebruik](#part-2-everyday-use): [Het geschiedenismenu](#the-history-menu) · [Zoeken en voorvertoning](#search-and-preview) · [Plakken zonder menu](#paste-without-the-menu) · [De plakwachtrij](#the-paste-queue) · [Het uitgebreide menu](#the-extended-menu)
- [Deel 3. Sjablonen](#part-3-templates): [Maken en ordenen](#creating-and-organising) · [Plaatsaanduidingen](#placeholders) · [Sjablonen die vragen stellen](#templates-that-ask-questions)
- [Deel 4. De Weergave](#part-4-the-viewer)
- [Deel 5. Instellingen](#part-5-settings)
- [Deel 6. Beveiliging](#part-6-security): [Wachtwoord en versleuteling](#password-and-encryption) · [Touch ID](#touch-id) · [Herstelzin](#recovery-phrase) · [Reservekopie](#backup)
- [Deel 7. Geavanceerd](#part-7-advanced): [Automatisering](#automation-the-keepit-url-scheme) · [Updates](#updates) · [Verwijderen](#uninstalling)
- [Naslag](#reference): [Problemen oplossen](#troubleshooting) · [Spiekbriefje sneltoetsen](#keyboard-cheat-sheet) · [Spiekbriefje plaatsaanduidingen](#placeholder-cheat-sheet)

---

## Deel 1. Aan de slag

### Installatie

**Homebrew.** Dit raden we aan, omdat `brew upgrade` de app actueel houdt:

```bash
brew tap andrey-insarov/keepit https://github.com/andrey-insarov/Keepit
brew install --cask andrey-insarov/keepit/keepit
```

**DMG.** Download `Keepit-<versie>.dmg` van de
[nieuwste release](https://github.com/andrey-insarov/Keepit/releases/latest), open het bestand en
sleep Keepit naar *Apps*.

![De DMG: sleep Keepit naar Apps](site/img/guide/dmg.png)

De eerste keer dat je de app opent, bevestigt macOS dat de app van het internet komt en door Apple
is gecontroleerd. Klik op *Open*.

![De bevestiging van Gatekeeper in macOS](site/img/guide/gatekeeper.png)

Keepit is ondertekend en genotariseerd, werkt zichzelf bij en draait native op Macs met Apple
silicon en met een Intel-processor, met macOS 13 Ventura of nieuwer.

### Eerste start

Keepit is een menubalk-app: geen Dock-symbool en geen venster totdat je er een opent. Na de eerste
start verschijnt het symbool 📎 in de menubalk en vraagt Keepit drie dingen.

**1. Herstellen uit een back-up?** Als dit een nieuwe Mac is en je een Keepit-back-up hebt (een
automatische in iCloud Drive of een andere map, of een geëxporteerd `.keepit`-bestand), haalt
*Herstel uit back-up…* je geschiedenis en sjablonen terug voordat er iets anders gebeurt. Je
ontgrendelt het bestand met het wachtwoord van de Mac waar het vandaan komt, of met de herstelzin
van die Mac. *Opnieuw beginnen* slaat dit over. Hetzelfde herstel is later beschikbaar via
*Instellingen → Reservekopie → Herstel…*, en een `.keepit`-bestand open je ook door er in de
Finder dubbel op te klikken. De details staan onder [Reservekopie](#backup).

![De eerste vraag op een nieuwe Mac: herstellen uit een back-up of opnieuw beginnen](site/img/guide/restore-first-run.png)

**2. Een wachtwoord (optioneel).** Keepit kan de geschiedenis en de sjablonen versleuteld bewaren
en ontgrendelen met Touch ID. Je kunt nu beslissen of later in *Instellingen → Beveiliging*;
[Deel 6](#part-6-security) legt uit hoe het werkt. Met *Niet nu* blijft alles onversleuteld op de
schijf staan. Als je zojuist een back-up hebt hersteld met het wachtwoord ervan, biedt Keepit aan
om dat wachtwoord ook voor deze Mac te gebruiken.

![Het wachtwoordvoorstel bij de eerste start](site/img/guide/password-offer.png)

![Bij de keuze Niet nu: een duidelijke uitleg van wat dat betekent en waar je het kunt wijzigen](site/img/guide/no-password-notice.png)

**3. De toestemming voor Toegankelijkheid.** Om voor jou te plakken stuurt Keepit ⌘V naar de app
waarin je aan het werk was. macOS staat dat alleen toe aan apps die vermeld staan onder
*Systeeminstellingen → Privacy en beveiliging → Toegankelijkheid*. Klik op *Open
Systeeminstellingen* en zet Keepit aan. Zonder deze toestemming legt Keepit nog steeds vast en
kopieert het, maar druk je zelf op ⌘V.

![Keepit vraagt om toestemming voor Toegankelijkheid](site/img/guide/accessibility-prompt.png)

![Keepit ingeschakeld onder Privacy en beveiliging → Toegankelijkheid](site/img/guide/accessibility-settings.png)

Keepit start standaard bij het inloggen. Dat zet je uit in *Instellingen → Algemeen*.

---

## Deel 2. Dagelijks gebruik

### Het geschiedenismenu

Druk in een willekeurige app op **⌥M** of klik op het symbool 📎. Het menu opent bij je
tekstcursor als Keepit die kan vinden, en anders bij de muisaanwijzer.

Elke regel is één gekopieerd item, met het nieuwste bovenaan. Het nieuwste is **vet**, omdat dat
op dit moment op het klembord staat. Het symbool toont de app waaruit je hebt gekopieerd. Een
titel die eindigt op `…` heeft meer regels dan het menu laat zien. Afbeeldingen hebben een
miniatuur en lijsten met bestanden tonen de bestandsnamen.

![Het voorvertoningspaneel naast het menu toont het gemarkeerde item volledig, met de bron-app, het tijdstip en de grootte](site/img/guide/menu-preview.png)

![Een afbeelding in de geschiedenis: miniatuur in het menu, volledige afbeelding in de voorvertoning](site/img/guide/menu-image.png)

Een item plak je door erop te klikken, door er met ↑ ↓ naartoe te gaan en op Return te drukken, of
door het nummer ervan in te drukken met **⌃⌥**: `⌃⌥3` plakt item 3. Dezelfde toets werkt overal,
ook zonder het menu te openen.

Onder de geschiedenis staan het submenu *Sjablonen*, de Weergave (⌥E), de Instellingen (⌥S),
*Geschiedenis wissen* (⌥C), *Opnemen 10 minuten pauzeren* (⌥P, voor als je iets typt dat je niet
wilt laten vastleggen), *Keepit vergrendelen* (⌥L) als er een wachtwoord is ingesteld, en de
updates. **⌥T** opent het sjablonenmenu afzonderlijk. Al deze toetsen werken ook zonder het menu.

### Zoeken en voorvertoning

**Zoeken.** Begin te typen terwijl het menu open is: het veld bovenaan filtert de lijst op titel
en op volledige tekst, zodat ook een regel midden in een lang item wordt gevonden. Return plakt de
eerste treffer, Esc maakt het veld leeg en een tweede Esc sluit het menu.

**Voorvertoning.** Houd de aanwijzer boven een item (of ga er met het toetsenbord naartoe) en een
paneel naast het menu toont de volledige afbeelding of de eerste regels van een lange tekst, met
de bron-app, de datum en de grootte. Korte teksten van één regel hebben geen voorvertoning, omdat
de menuregel ze al volledig laat zien.

![Typen filtert het menu; het voorvertoningspaneel toont het gemarkeerde item](site/img/guide/search-preview.png)

### Plakken zonder menu

Globale sneltoetsen werken met de geschiedenis zoals die op dat moment is (item 1 is het
klembord), vanuit elke app:

| Toetsen | Wat er gebeurt |
|------|--------------|
| `⌃⌥1` … `⌃⌥9`, `⌃⌥0` | Plakt geschiedenisitem 1–10 |
| `⌥⇧V` | Plakt het *vorige* item (item 2); druk nog een keer om terug te wisselen |
| `⌃⌥V` | Plakt het klembord als platte tekst, zonder opmaak |
| `⌃⌥U` `⌃⌥L` `⌃⌥T` `⌃⌥S` | Plakt het klembord in HOOFDLETTERS / kleine letters / Elk Woord Met Hoofdletter / als een zin |
| `⌃⌥W` | Plakt het klembord zonder witruimte aan het begin en het einde |
| `⌃⌥J` | Plakt het klembord samengevoegd tot één regel |
| `⌃⌥K` `⌃⌥D` `⌃⌥Y` | Plakt het klembord doorgehaald / onderstreept / met een golvende onderstreping, als platte tekst die er overal hetzelfde uitziet, ook in chats (zie hieronder) |
| `⌃⌥X` | Plakt het klembord zonder die versieringen |
| `⌃⌥A` | Voegt het klembord toe aan Sjablonen |
| `⌃⌥⌫` | Verwijdert het nieuwste item uit de geschiedenis |

De drie versieringen zijn geen opmaak: Keepit voegt na elk teken een *combinerend teken* uit
Unicode toe (d̶o̶o̶r̶g̶e̶h̶a̶a̶l̶d̶, o̲n̲d̲e̲r̲s̲t̲r̲e̲e̲p̲t̲, g̰o̰l̰v̰ḛn̰d̰), zodat de tekst er hetzelfde uitziet in een
berichtenapp, een webformulier of een terminal, waar echte opmaak verloren zou gaan. Daar staat
iets tegenover: zulke tekst is drie keer zo groot, een zoekopdracht naar het gewone woord vindt
hem niet, schermlezers struikelen erover en sommige lettertypen tekenen de lijn ongelijkmatig.
*Versieringen verwijderen* (`⌃⌥X`) haalt de tekens er weer af, ook bij tekst die ergens anders is
versierd. In beide richtingen worden de tekens per codepunt verwijderd, waar ze ook vandaan komen:
een fonetische transcriptie die dezelfde tekens als letters gebruikt (U+0330 is ook het IPA-teken
voor kraakstem) raakt ze kwijt, en ook de drie versieringen verwijderen ze eerst. Als VoiceOver
aanstaat, is `⌃⌥` de eigen speciale toets van VoiceOver: geef *Acties op het nieuwste item* dan
een andere in Instellingen → Sneltoetsen.

Transformaties gelden voor tekst; bij een afbeelding of een lijst met bestanden geeft de toets
alleen een geluidssignaal. Dit alles kun je wijzigen of uitzetten in *Instellingen → Sneltoetsen*.

### De plakwachtrij

Soms wil je vijf dingen op één plek kopiëren en ze in dezelfde volgorde ergens anders plakken:
cellen in een formulier, regels van een pagina in een document. De plakwachtrij doet dat zonder
het menu:

1. Druk op **⌥N** (of kies *Plakwachtrij starten* in het menu). Het symbool in de menubalk toont
   een rode stip en een teller: `📎 ● 0`.
2. Kopieer zoals altijd met ⌘C, zo vaak als je wilt. De teller loopt bij elke kopie op: 1, 2, 3…
   Alles wordt ook in de geschiedenis vastgelegd.

   ![De menubalk terwijl de wachtrij aanstaat: rode stip en teller](site/img/guide/queue-menubar.png)

3. Ga naar de plek waar de tekst moet komen en druk voor elk item op **⌥V**. Wat je als eerste
   hebt gekopieerd, wordt als eerste geplakt, en de teller loopt terug. ⌘V plakt nog steeds
   gewoon het klembord, dus je kunt beide door elkaar gebruiken.
4. De wachtrij schakelt zichzelf uit nadat het laatste item is geplakt, of na twee minuten zonder
   kopiëren of plakken (de tijd is instelbaar). Met nog een keer ⌥N stop je de wachtrij eerder.

**⌥⇧N** plakt in één keer alles wat nog in de wachtrij staat. De items worden gescheiden door een
regeleinde, een tab, een spatie of niets; dat kies je in het paneel *Plakwachtrij* van de
Instellingen, waar je ook de wachttijd instelt. Zolang de wachtrij aanstaat, markeert het
geschiedenismenu de items ervan: `▶` wordt als volgende geplakt, `○` staat nog in de wachtrij,
`✓` is al geplakt.

![Het geschiedenismenu met de wachtrij aan: ○ in de wachtrij, ▶ volgende, ✓ geplakt; de menuregel toont hoeveel er nog over zijn](site/img/guide/queue-menu.png)

![Instellingen → Plakwachtrij](site/img/guide/prefs-queue.png)

### Het uitgebreide menu

Houd **⇧** ingedrukt terwijl het geschiedenismenu open is en elk item krijgt een submenu `▸` met
alle acties voor dat item: Plak, Als platte tekst plakken, Alleen kopiëren (naar het klembord,
zonder te plakken), de transformaties onder *Plakken als*, Aan Sjablonen toevoegen, Toon in
Weergave, Verwijder. Wijs een item aan of druk op → om het submenu te openen; zodra het open is,
kun je ⇧ loslaten.

![Houd ⇧ ingedrukt: elk item krijgt een submenu; bij het nieuwste item staan daarin de globale sneltoetsen](site/img/guide/extended-menu.png)

Bij het nieuwste item vermeldt het submenu de globale sneltoetsen uit de tabel hierboven. Het zijn
dezelfde acties met dezelfde toetsen, dus je kunt ze hier leren. Andere items tonen de acties
zonder toetsen: een sneltoets werkt overal of wordt niet getoond.

![Bij andere items: dezelfde acties, zonder sneltoetsen](site/img/guide/extended-menu-item2.png)

![Bij een afbeelding zijn de tekstacties grijs; alleen Plak, Alleen kopiëren, Aan Sjablonen toevoegen, Toon in Weergave en Verwijder zijn mogelijk](site/img/guide/extended-menu-image.png)

---

## Deel 3. Sjablonen

Sjablonen zijn items die je voorgoed bewaart: handtekeningen, adressen, standaardantwoorden,
stukjes code, een logo dat je vaak plakt. Ze staan in een boom met mappen en verschijnen in het
submenu *Sjablonen* van het geschiedenismenu en onder **⌥T**. Een nieuwe installatie bevat een map
*Voorbeelden* (een begroeting, de datum van vandaag, een citaat van het klembord en een
handtekening), zodat je kunt zien wat sjablonen kunnen voordat je er zelf een schrijft. Verwijder
of bewerk ze naar wens. De voorbeeldsjablonen zet je terug via *Instellingen → Geavanceerd →
Herstellen en verwijderen → Herstel…*; daarmee worden wel ook de overige gegevens en instellingen
gereset.

![De map Voorbeelden: als je een item aanwijst, zie je de tekst ervan](site/img/guide/template-examples.png)

![Het sjablonenmenu: mappen openen als submenu’s, letters na een & worden sneltoetsen](site/img/guide/template-menu-letters.png)

### Maken en ordenen

**Een sjabloon toevoegen**

- Vanuit het geschiedenismenu: `⌃⌥A` voor het nieuwste item, *Klembord toevoegen aan sjablonen*
  onderaan, of ⇧ → het submenu van het item → *Aan Sjablonen toevoegen* voor een willekeurig item.
- In de Weergave: selecteer een geschiedenisitem en klik op *Toevoegen aan sjablonen*, of sleep
  het naar de boom Sjablonen. *Nieuw item* maakt een leeg tekstsjabloon; *Nieuw item uit bestand*
  (contextmenu) maakt er een van een tekst- of afbeeldingsbestand.

**Ordenen**

- *Nieuwe map* maakt een map. Sleep items tussen mappen, of gebruik *Omhoog* / *Omlaag* in het
  contextmenu.
- Een sjabloon met de naam `-` wordt een scheidingslijn in het menu.
- Een `&` voor een letter in de naam, bijvoorbeeld `&Handtekening`, maakt van die letter de
  sneltoets van het item in het sjablonenmenu: druk op `H` terwijl het menu open is.
- *Stel sneltoets in* in het contextmenu geeft een sjabloon een eigen globale sneltoets.
- Een sjabloon zonder naam toont de eerste regel ervan. *Wijzig naam* en *Wis naam* staan in het
  contextmenu; je kunt ook het veld *Naam* boven de tekst bewerken.

### Plaatsaanduidingen

Tekstsjablonen kunnen plaatsaanduidingen `{…}` bevatten, die bij het plakken worden ingevuld. Al
het andere wordt ongewijzigd geplakt. In de Weergave toont **Invoegen ▾** alle plaatsaanduidingen
en zet de gekozen aanduiding bij de cursor, dus je hoeft niets te onthouden.

![Het voorbeeld Datum van vandaag: `{date:EEEE, d MMMM yyyy}` wordt bij het plakken de huidige datum](site/img/guide/template-examples-date.png)

![Invoegen ▾ in de Weergave toont alle plaatsaanduidingen](site/img/guide/insert-menu.png)

De nuttigste:

| Plaatsaanduiding | Resultaat |
|-------------|--------|
| `{date}` `{time}` `{datetime}` | Datum van vandaag / huidige tijd, systeemnotatie |
| `{date:yyyy-MM-dd}` | Een willekeurige notatie (`yyyy MM dd EEEE HH mm …`) |
| `{date:long}` `{time:short}` `{datetime:medium}` | Een benoemde stijl: `short` `medium` `long` `full` |
| `{date+7d}` `{date-1m:MMMM}` `{time+1h}` `{date+1y-2d}` | Verschoven: `d` dagen, `w` weken, `m` maanden, `y` jaren, `h` uren; bij `date`, `time`, `datetime`, ook meerdere achter elkaar |
| `{clipboard}` `{clipboard:2}` | Het klembord, of geschiedenisitem N |
| `{clipboard\|upper}` `{clipboard\|trim\|oneline}` | Filters `upper` `lower` `title` `trim` `oneline` `url`, te combineren |
| `{cursor}` | Waar de tekstcursor na het plakken terechtkomt |
| `{user}` `{username}` `{host}` | Volledige naam, accountnaam, computernaam |
| `{uuid}` `{random:1-100}` | Een nieuwe UUID; een willekeurig getal |
| `{{` `}}` | Letterlijke accolades: het sjabloon `{{"x":1}}` plakt `{"x":1}` |

Namen van plaatsaanduidingen schrijf je met kleine letters: `{date}` is een plaatsaanduiding,
terwijl `{Date}` en `{DATE}` gewone tekst zijn en worden geplakt zoals ze er staan. Stijlnamen en
filters (`{date:LONG}`, `{clipboard|UPPER}`) mag je op beide manieren schrijven.

De volledige lijst staat in het [spiekbriefje plaatsaanduidingen](#placeholder-cheat-sheet).

### Sjablonen die vragen stellen

`{input:Naam}` en `{choice:Label=A|B|C}` maken van een sjabloon een klein formulier: als je het
plakt, vraagt Keepit eerst om de waarden en plakt dan de voltooide tekst. Naar dezelfde naam wordt
maar één keer gevraagd, hoe vaak die ook voorkomt; `{input:Naam=Standaard}` vult het veld vooraf
in.

![Bij het plakken van een sjabloon met {input:Name} wordt eerst om de waarde gevraagd](site/img/guide/input-dialog.png)

Bijvoorbeeld een antwoordsjabloon:

```
Beste {input:Naam},

Bedankt voor je bericht van {date-1d}. Je hoort uiterlijk {date+3d:EEEE} van me.
{cursor}
{user}
```

Bij het plakken vraagt Keepit om *Naam*, vult de datums in, ondertekent met je volledige naam en
laat de cursor op de lege regel staan.

---

## Deel 4. De Weergave

*Weergave…* in het menu, of een klik met de rechtermuisknop op het symbool 📎, opent een venster
met drie bomen: **Klembord** (het klembord van dit moment, alleen-lezen), **Geschiedenis** (*Tekst
en bestanden* en *Afbeeldingen*) en **Sjablonen**.

![De Weergave met een geselecteerd sjabloon](site/img/guide/viewer.png)

- Selecteer een item om het rechts te zien. Tekst bewerk je ter plekke, en wijzigingen worden
  toegepast wanneer je de editor verlaat. Een afbeelding wordt passend in het paneel getoond, met
  erboven de afmetingen in pixels en de bestandsgrootte. Lijsten met bestanden openen het bestand
  met een dubbelklik. *Toon als hexdump* in het contextmenu toont de ruwe bytes.
- De knoppenbalk: *Stuur naar klembord*, *Plak* (in de app waar je vandaan kwam), *Toevoegen aan
  sjablonen*, *Nieuw item*, *Nieuwe map*, *Verwijder*, *Invoegen ▾* (plaatsaanduidingen) en **?**,
  dat deze handleiding opent.
- **Zoeken** (`⌘F`): het veld links filtert de geschiedenis en de sjablonen op naam en inhoud en
  markeert de treffer.
- Sleep geschiedenisitems naar de boom Sjablonen om ze te bewaren, en sjablonen naar Geschiedenis
  om ze terug te kopiëren; de volgorde wijzig je door te slepen of met *Omhoog* / *Omlaag*.
  ⌫ verwijdert het geselecteerde item.
- De statusbalk toont de datum, de bron-app, het formaat en de grootte.

![Zoeken in de Weergave markeert de treffers](site/img/guide/viewer-search.png)

---

## Deel 5. Instellingen

`⌘,` in het menu, *Instellingen…*, of ⌥S vanuit elke app. Het venster werkt zoals
instellingenvensters op de Mac werken: kies een paneel in de knoppenbalk, en elke wijziging gaat
meteen in. Er is geen knop Bewaar; sluit het venster met ⌘W of Esc. Elke optie met een **?**
ernaast heeft een popover met uitleg.

![Instellingen → Algemeen](site/img/guide/prefs-general.png)

| Paneel | Wat er staat |
|-----|---------------|
| **Algemeen** | Starten bij het inloggen · geschiedenis bewaren bij het stoppen en herstellen bij de start · plakken na het kiezen (uit = alleen kopiëren) · plakvertraging, die je verhoogt voor apps die traag naar voren komen · het menu openen bij de tekstcursor · Updates: *Automatisch controleren op updates* (de editie die je van de website downloadt; uit = helemaal geen netwerkverzoek), zie [Updates](#updates) |
| **Sneltoetsen** | Alle globale sneltoetsen op één plek, zie hieronder |
| **Plakwachtrij** | De drie toetsen van de wachtrij, de wachttijd waarna de wachtrij uitschakelt, en wat er tussen de items komt bij *Alle resterende plakken*, zie [De plakwachtrij](#the-paste-queue) |
| **Geschiedenis** | Hoeveel tekst- en bestandsitems en hoeveel afbeeldingen worden bewaard (1000 / 30) · items vergeten die ouder zijn dan … · *Duplicaten verwijderen* (hetzelfde opnieuw kopiëren zet het bovenaan) · *Verborgen klembordgegevens negeren* · de lijst met genegeerde apps (bundle-ID’s; wachtwoordmanagers worden altijd genegeerd) |
| **Menu** | Zoekveld · nummering · voorvertoningspaneel · tooltips · symbolen van bron-apps · miniaturen van afbeeldingen · items in het menu (hoeveel van de nieuwste items het menu toont, standaard 60; de rest blijft doorzoekbaar) · titellengte · hoogte van miniaturen |
| **Beveiliging** | Wachtwoord, Touch ID, vergrendelen, herstelzin, zie [Deel 6](#part-6-security) |
| **Reservekopie** | Automatische back-up (statusregel naast de kop): *Automatisch back-uppen naar een map*, de naam van de Mac in de bestanden, de map, hoeveel kopieën worden bewaard · Handmatige back-up: *Nu back-uppen*, *Bewaar als archief…* · Herstellen: *Herstel…*, zie [Reservekopie](#backup) |
| **Geavanceerd** | Interval voor het opvragen van het klembord · Automatisering: *keepit://-URL-opdrachten toestaan* (standaard uit, zie [Automatisering](#automation-the-keepit-url-scheme)) · Gegevens: *Open map* · Herstellen en verwijderen: *Herstel…* (terug naar een verse installatie, de voorbeeldsjablonen komen terug) · *Verwijder…* (herstellen, en daarna de app, het starten bij inloggen, het sleutelhangeronderdeel en de toestemmingen verwijderen) |

![Instellingen → Geschiedenis: limieten en de lijst met genegeerde apps](site/img/guide/prefs-history.png)

![Instellingen → Sneltoetsen](site/img/guide/prefs-hotkeys.png)

Klik in het paneel **Sneltoetsen** in een veld en druk op een combinatie; ⌫ schakelt een toets
uit. Een combinatie die al door een ander commando wordt gebruikt, wordt geweigerd, en de reden
staat onder de velden. *Standaardwaarden herstellen* brengt de set ⌥ + letter terug
(⌥M geschiedenis, ⌥T sjablonen, ⌥E Weergave, ⌥S Instellingen, ⌥C Geschiedenis wissen, ⌥P pauzeren,
⌥L vergrendelen, ⌥Q stoppen), plus ⌥⇧V en ⌃⌥. *Item op nummer plakken* en *Acties op het nieuwste
item* nemen alleen speciale toetsen aan; het cijfer of de letter voegt Keepit toe. Als macOS of
een andere app een combinatie al in gebruik heeft, meldt Keepit dat bij de start. *Weergave* ⌥E,
*Instellingen* ⌥S, *Geschiedenis wissen* ⌥C, *Opname pauzeren* ⌥P, *Keepit vergrendelen* ⌥L en
*Keepit stoppen* ⌥Q werken vanuit elke app en staan in het menu naast hun commando’s. Op een
Amerikaanse toetsenbordindeling typt ⌥ + letter normaal gesproken een speciaal teken (⌥S = ß,
⌥C = ç …); als je een daarvan nodig hebt, verplaats dan de sneltoets. Keepit leest ook je toetsenbordindelingen: de letters in Instellingen en in de menu’s zijn die op de toetsen van de indeling die je gebruikt, en een standaardsneltoets die een teken zou innemen dat je indeling nodig heeft (⌥L typt @ op de Duitse, ł op de Poolse) laat Keepit bij de start vrij — de notitie onder het veld zegt het; klik in het veld en druk op de combinatie om hem toch te gebruiken. Bij een niet-Latijnse indeling, zoals de Russische, komen de namen uit de Latijnse indeling die macOS eraan koppelt, net als in de menu’s van het systeem zelf.

---

## Deel 6. Beveiliging

### Wachtwoord en versleuteling

*Instellingen → Beveiliging → Wachtwoord vereisen bij starten* versleutelt de geschiedenis en de
sjablonen met AES-256-GCM. De sleutel wordt afgeleid van je wachtwoord (PBKDF2, 200 000 rondes) en
bestaat alleen in het geheugen. Hij wordt gewist wanneer Keepit vergrendelt: met *Keepit
vergrendelen* (`⌥L`), bij het stoppen en optioneel nadat de Mac een tijd vergrendeld is geweest of
in de sluimerstand heeft gestaan. *Keepit automatisch vergrendelen* staat bij een nieuwe
installatie op **Nooit** (een update vanaf 3.0.3 behoudt de oude keuze, dus *Onmiddellijk* als het
vakje voor vergrendelen samen met het scherm aanstond): een klembordmanager die na elke
koffiepauze om zijn wachtwoord vraagt, wordt niet meer gebruikt, en voor de momenten die ertoe
doen is er `⌥L`. *Onmiddellijk* vergrendelt samen met het scherm. *Na 5 minuten*, *Na 15 minuten*
en *Na 1 uur* laten een korte afwezigheid met rust (Keepit blijft ontgrendeld en legt verder vast)
en vergrendelen pas nadat de Mac de hele ingestelde tijd vergrendeld is geweest of in de
sluimerstand heeft gestaan. Hetzelfde geldt wanneer Keepit
start terwijl de Mac al vergrendeld is of de sessie van een andere gebruiker op de voorgrond staat
(een herstart na een update bijvoorbeeld): de afwezigheid telt vanaf de start, voor zover macOS
die toestand aan Keepit doorgeeft (normaal gesproken wel; als dat niet kan, begint het tellen bij
de volgende vergrendeling of sluimerstand). Als Touch ID aanstaat, vraagt Keepit om een aanraking
op het moment dat de Mac wordt ontgrendeld, zodat het klaarstaat vóór de eerste `⌥M`.

![Het wachtwoord instellen met het schermtoetsenbord. Dit is een foto van het scherm, geen schermafbeelding: op de Mac van de auteur toont een schermafbeelding van deze scène alleen het dialoogvenster](site/img/guide/set-password-keyboard.jpg)

De wachtwoordvensters tonen de huidige toetsenbordindeling en waarschuwen voor Caps Lock, dus een
geweigerd wachtwoord is zelden een raadsel. De toetsenbordknop naast het veld opent een
**schermtoetsenbord** waarmee je het wachtwoord met de muis typt: de klikken gaan nooit als
toetsaanslagen door het systeem, de toetsen worden bij elke opening geschud, en het toetsenbord
vraagt macOS om het buiten schermafbeeldingen en schermopnamen te houden (op sommige configuraties
wordt het uitgesloten; gegarandeerd is dat niet). Het is bedoeld voor een Mac die je niet helemaal
vertrouwt, of waarvan het scherm wordt gedeeld. Bij de start en na een vergrendeling vraagt Keepit
om het wachtwoord (of Touch ID); *Toegang herstellen…* neemt in plaats daarvan de zin van 24
woorden aan, zie [Herstelzin](#recovery-phrase).

![Ontgrendelen bij de start: wachtwoord, Stop of de herstelzin; OK blijft uitgeschakeld totdat je iets typt. Gefotografeerd om dezelfde reden als hierboven](site/img/guide/unlock-keyboard.jpg)

![Instellingen → Beveiliging](site/img/guide/prefs-security.png)

### Touch ID

Met *Ontgrendelen met Touch ID* wordt de sleutel ook bewaard in de Secure Enclave, achter je
vingerafdruk: Keepit vraagt om een aanraking in plaats van het wachtwoord. Het wachtwoord blijft
als reserve werken; kies daarvoor *Gebruik wachtwoord* in het venster. Met de klep dicht en een
extern Magic Keyboard met Touch ID vraagt Keepit het op het toetsenbord. Met *Wachtwoord wijzigen
met Touch ID toestaan* kan een vingerafdruk het oude wachtwoord vervangen wanneer je het wijzigt.

![Ontgrendelen met Touch ID; het wachtwoord blijft als reserve](site/img/guide/touch-id.png)

### Herstelzin

Wanneer je een wachtwoord instelt, toont Keepit één keer een zin van 24 woorden. Druk hem af of
bewaar hem in een wachtwoordmanager. Als je het wachtwoord vergeet, opent *Toegang herstellen…* in
het ontgrendelvenster je gegevens en kun je een nieuw wachtwoord instellen. *Herstelzin → Maak
nieuwe…* geeft een nieuwe zin uit en maakt de oude ongeldig; *Toon…* ernaast laat de huidige zin
opnieuw zien na Touch ID of het wachtwoord.

Zonder het wachtwoord, Touch ID op dezelfde Mac of de zin zijn de gegevens niet terug te halen: er
is geen server en er valt niets te resetten.

![De herstelzin van 24 woorden (de woorden zijn hier verborgen)](site/img/guide/recovery-phrase.png)

### Reservekopie

Keepit kan een versleutelde kopie van je geschiedenis en sjablonen bewaren in een map naar keuze
(iCloud Drive, Dropbox, Google Drive, een externe schijf, een NAS) en een nieuwe schrijven zodra
er iets is veranderd. Er is geen Keepit-server: de map is van jou. De aanbieder erachter ziet het
versleutelde bestand, de grootte ervan en een kleine onversleutelde header (wanneer en door welke
Keepit het bestand is geschreven, hoe de sleutel wordt afgeleid, willekeurige identificatoren, en
de naam van je Mac alleen als je dat aanzet); de [pagina over beveiliging](/security#backups)
(Engels) somt die veld voor veld op.

![Instellingen → Reservekopie: automatische back-up, handmatige back-up, herstellen](site/img/guide/prefs-backup.png)

**Aanzetten.** *Instellingen → Reservekopie → Automatisch back-uppen naar een map*, en daarna
*Kies…* een map (het keuzevenster opent in iCloud Drive). De automatische back-up heeft de
wachtwoordbeveiliging uit *Instellingen → Beveiliging* nodig: elke kopie wordt verzegeld met een
sleutel die is afgeleid van de sleutel van je kluis, dus je opent die met je Keepit-wachtwoord of
je herstelzin, op deze Mac of op elke andere, en daar hoeft niets voor te worden ingesteld. Zonder
wachtwoord is het aankruisvak uitgeschakeld en staat de reden erbij.

**Wat er daarna gebeurt: het schema.** Ongeveer vijf minuten na de laatste wijziging (en ten
minste één keer per dag zolang Keepit draait) schrijft Keepit een bestand met de naam
`Keepit-<datum en tijd>-<installatie>-<id>.keepit` naar de map, leest het terug ter controle en
verwijdert pas daarna de oudste van zijn eigen kopieën boven het aantal bij *Bewaar laatste*
(standaard 10, bereik 1–100). Elke kopie is op zichzelf compleet, geen increment, dus één bestand
is alles wat je ooit nodig hebt. Kopieën van een andere Mac, of bestanden die je er zelf neerzet,
worden nooit aangeraakt: twee Macs die een map delen, schrijven twee onafhankelijke reeksen. De
statusregel naast de kop *Automatische back-up* toont het tijdstip en de grootte van de laatste
kopie, of waarom de laatste poging is mislukt. Zolang Keepit vergrendeld is, gebeurt er niets; *Nu
back-uppen* (onder *Handmatige back-up*) wacht niet op de rustperiode.

**Naam van deze Mac opnemen** (standaard uit) zet de naam van de computer in de onversleutelde
header van elk bestand, zodat twee reeksen in één map in de Finder makkelijk uit elkaar te houden
zijn. De opslagaanbieder kan die naam zien; daarom is het optioneel.

**Herstellen.** *Herstel…* opent een back-up (van deze Mac, van een andere Mac of een
geëxporteerd bestand) nadat je die hebt ontgrendeld: met het wachtwoord van de Mac waarop hij is
gemaakt, of met de herstelzin die die Mac toonde toen het wachtwoord werd ingesteld (*Toegang
herstellen…* in het wachtwoordvenster). Een voorvertoning laat zien wanneer en waar het bestand is
gemaakt en hoeveel items het bevat. Daarna zijn er twee mogelijkheden:

![De voorvertoning bij herstellen: wanneer en door welke Keepit het bestand is geschreven, wat het bevat, Voeg samen of Vervang](site/img/guide/restore-preview.png)

- *Voeg samen* voegt toe wat er nog niet is: geschiedenisitems op inhoud, en de sjablonen uit de
  back-up als één nieuwe map met de naam *Geïmporteerd <datum>*, zonder hun sneltoetsen. Zo zie je
  precies wat er uit de back-up kwam en kun je het verplaatsen of verwijderen. Niets van jou wordt
  overschreven.
- *Vervang* gooit de huidige geschiedenis en sjablonen weg en neemt in plaats daarvan die uit de
  back-up. Voordat dat gebeurt, schrijft Keepit een kopie van wat je nu hebt
  (`Keepit-before-restore-…`) naar de back-upmap, of naar een map die je kiest; als die kopie niet
  kan worden geschreven, begint Vervang niet. Als Keepit nog geen wachtwoord heeft, wordt je voor
  die kopie om een wachtwoord gevraagd, net als bij *Bewaar als archief…*.

*Ook voorkeuren herstellen* haalt de sneltoetsen, limieten en opties uit de back-up. De
instellingen die vertrouwen in één bepaalde Mac uitdrukken (Touch ID, URL-automatisering en de
vertrouwde apps daarvan, de back-upmap zelf) blijven altijd zoals ze hier zijn. Als de
geschiedenis uit de back-up groter is dan de limieten van deze Mac toestaan, zegt Keepit hoeveel
er zou passen voordat je bevestigt.

Heb je een back-up hersteld met de herstelzin ervan op een Mac die nog geen wachtwoord heeft? Dan
vraagt Keepit je eerst een wachtwoord in te stellen, zodat de herstelde gegevens nooit
onversleuteld op de schijf belanden, en kun je die zin voor deze Mac houden of een nieuwe krijgen.
Hersteld met het wachtwoord? Dan biedt Keepit aan om het te houden als wachtwoord van deze Mac. In
beide gevallen is de automatische back-up zelf een instelling per Mac: zet die hier aan en kies
de map (dezelfde mag) en deze Mac begint een eigen reeks bestanden naast die van de oude Mac.

**Verhuizen naar een nieuwe Mac** is waar het allemaal om draait: installeer Keepit, kies bij de
eerste start *Herstel uit back-up…*, kies het nieuwste bestand in je map, voer het wachtwoord van
de oude Mac in en kies *Vervang*; zet daarna de automatische back-up aan op de nieuwe Mac. De
kopieën die tot dan toe zijn gemaakt, open je met het wachtwoord en de zin die golden toen ze
werden geschreven: na een wachtwoordwijziging hebben de oude nog steeds het oude wachtwoord nodig.

**Handmatige back-up.** Er zijn twee knoppen en ze doen twee verschillende dingen. *Nu back-uppen*
maakt meteen een kopie zoals de automatische: hetzelfde soort bestand, dezelfde map en reeks, te
openen met je Keepit-wachtwoord of je zin. *Bewaar als archief…* schrijft één *archief* `.keepit`
waar je maar wilt, vergrendeld met een wachtwoord dat je er speciaal voor kiest. Het heeft de
wachtwoordbeveiliging van Keepit niet nodig, en Keepit houdt het bestand daarna niet bij. Het is
bedoeld om gegevens over te dragen, of voor een kopie buiten de back-upmap. De voorgestelde naam
zegt wat het is: `Keepit-archive-<datum>-manual.keepit`, naast
`Keepit-<datum en tijd>-<installatie>-<id>.keepit` van de automatische kopieën.

![Bewaar als archief…: in de bestandsnaam staan archive en manual](site/img/guide/save-to-archive.png)

![Het eigen wachtwoord van het archief, met een sterktemeter: het wordt nergens bewaard](site/img/guide/archive-password.png)

*Herstel…* opent beide soorten. Het archief vervangt *Exporteer…* / *Importeer…* uit 2.x. Het
bestand zet gegevens over tussen de editie van de website en de App Store-editie, en tussen Keepit
2.x en 3.x: een bestand dat door 3.0 is geschreven, heeft 3.0 of nieuwer nodig om te openen; 3.0
leest alles wat 2.x heeft geschreven.

**Als er iets misgaat.** Een mislukte kopie wordt gemeld in de statusregel en opnieuw geprobeerd
met steeds langere pauzes; de eerdere kopieën blijven staan. Als Keepit is gestopt of de Mac is
uitgevallen midden in een herstelactie, zet de volgende start alles stilletjes terug zoals het was
vóór het herstel. In het zeldzame geval dat dat niet lukt (een bestand dat niet kan worden
geschreven, een volle schijf), noemt Keepit het bestand en stopt het zonder iets te wijzigen: los
het probleem met het bestand op en start Keepit opnieuw. Details, waaronder hoe het bestandsformaat
er vanbinnen uitziet, staan op de [pagina over beveiliging](/security#backups) (Engels).

---

## Deel 7. Geavanceerd

### Automatisering: het URL-schema keepit://

Opdrachten (*Open URL’s*), Raycast, Alfred, Keyboard Maestro of `open` in een shell kunnen Keepit
aansturen, **zodra je dat aanzet** in *Instellingen → Geavanceerd → Automatisering →
keepit://-URL-opdrachten toestaan*. Het staat standaard uit omdat elke app of webpagina een URL
kan openen, en `add` / `paste` het klembord wijzigen en in de voorste app typen; als het uitstaat,
negeert Keepit zulke URL’s met een geluidssignaal. Als het aanstaat, kijkt Keepit wie de URL heeft
geopend: het eerste commando van elke app dat iets verandert (`paste`, `copy`, `template`, `add`,
`add-template`, `pause`, `resume`) wordt in een dialoogvenster getoond. *Sta toe* voert het één
keer uit, *Altijd toestaan* zet de app op de lijst met vertrouwde apps (die maak je leeg met
*Vertrouwde apps vergeten* in hetzelfde paneel). Bij een webbrowser, of een afzender die macOS
niet kan benoemen, wordt het elke keer gevraagd. Commando’s die alleen de eigen vensters van
Keepit openen, vragen nooit iets.

| URL | Effect |
|-----|--------|
| `keepit://paste/2`<br>`keepit://paste/latest`<br>`keepit://paste/previous` | Plakt geschiedenisitem N (of het nieuwste / het vorige) in de voorste app |
| `keepit://copy/3` | Zet item N op het klembord zonder te plakken |
| `keepit://template/Signature`<br>`keepit://template/Work/Reply?copy=1` | Plakt (of kopieert) een sjabloon op naam of op mappad |
| `keepit://add?text=…` | Voegt tekst toe aan de geschiedenis en het klembord |
| `keepit://add-template?text=…&name=…` | Maakt een sjabloon |
| `keepit://history`<br>`keepit://templates`<br>`keepit://viewer`<br>`keepit://settings` | Opent het geschiedenismenu, het sjablonenmenu, de Weergave, de Instellingen |
| `keepit://pause`<br>`keepit://resume` | Pauzeert de opname 10 minuten / hervat die |

Codeer de tekst met procentcodering (`%20` voor een spatie). Zolang Keepit vergrendeld is, worden
URL’s genegeerd.

### Updates

Keepit controleert GitHub Releases één keer per dag en biedt updates aan in een dialoogvenster;
*Zoek naar updates…* doet dat meteen. Updates zijn ondertekend (EdDSA) en genotariseerd. Met
Homebrew doet `brew upgrade --cask keepit` hetzelfde. Controlesommen voor elke download staan in
`SHA256SUMS` op de releasepagina.

Deze controle is het enige netwerkverzoek dat Keepit doet, en ze is optioneel: *Instellingen →
Algemeen → Updates → Automatisch controleren op updates*. Als je dat uitzet, maakt Keepit nergens
meer verbinding mee, ook niet als je erom vraagt, en verdwijnt *Zoek naar updates…* uit de menu’s.
Je werkt dan bij door de app te downloaden van [keep.it.com](https://keep.it.com) of met Homebrew.
De App Store-editie heeft geen updater en geen dergelijke optie; de App Store werkt die bij.

### Verwijderen

*Instellingen → Geavanceerd → Herstellen en verwijderen → Verwijder…* verwijdert de app, de
gegevensmap, de sleutelhangeronderdelen (inclusief de Touch ID-sleutel), het inlogonderdeel en de
vermelding onder Toegankelijkheid. Keepit vraagt om je wachtwoord of Touch ID, een getypt `DELETE`
en een bevestiging. Exporteer eerst een back-up als je de gegevens misschien nog terug wilt. Voer
met Homebrew daarna `brew uninstall --cask --force keepit` uit, zodat Homebrew de cask vergeet.

![Instellingen → Geavanceerd](site/img/guide/prefs-advanced.png)

---

## Naslag

### Problemen oplossen

**Na het kiezen van een item wordt er niets geplakt.** De toestemming voor Toegankelijkheid
ontbreekt: *Systeeminstellingen → Privacy en beveiliging → Toegankelijkheid → Keepit*. Als Keepit
in de lijst staat maar toch niet plakt, zet het dan uit en weer aan. macOS vergeet de toestemming
wanneer de app opnieuw wordt geïnstalleerd.

**Een sneltoets doet niets.** Een andere app of macOS heeft hem in gebruik; Keepit meldt dat bij
de start. Kies een andere combinatie in het paneel *Sneltoetsen*. ⌃⌥ met cijfers en letters is vrij
op een Mac met standaardinstellingen. Of het is een standaardsneltoets die Keepit vrij heeft gelaten omdat hij op een van je toetsenbordindelingen een teken typt; de notitie onder het veld in het paneel *Sneltoetsen* zegt het. Kies een andere combinatie, of klik in het veld en druk op dezelfde om hem toch te gebruiken.

**Het menu opent op de verkeerde plek.** De app waarin je werkt, geeft zijn tekstcursor niet door,
en daarom valt het menu terug op de muisaanwijzer. *Menu bij de tekstcursor openen indien
mogelijk* in het paneel Algemeen zet het zoeken naar de cursor uit, als je altijd de aanwijzer
wilt.

**Iets wat ik heb gekopieerd, ontbreekt.** Alles wat de kopiërende app als verborgen heeft
gemarkeerd, wordt niet vastgelegd, en dat geldt ook voor een kopie die is gemaakt terwijl een
wachtwoordmanager (ingebouwde lijst) of een app op je negeerlijst op de voorgrond stond, inclusief
de app waaruit je een ogenblik eerder bent weggeschakeld. Zie *Instellingen → Geschiedenis* en de
[pagina over beveiliging](/security#what-is-not-recorded) (Engels).

**Touch ID wordt niet aangeboden.** Er is op dit moment geen Touch ID-sensor bereikbaar (klep
dicht, geen toetsenbord met Touch ID). Keepit behoudt de instelling en vraagt om de vingerafdruk
zodra er een sensor beschikbaar is.

**De back-upstatus zegt dat de map niet beschikbaar is.** De map is verplaatst, hernoemd,
ontkoppeld of (iCloud Drive) uit de lokale opslag verwijderd. Koppel of herstel de map en de
volgende kopie lukt weer; of gebruik *Kies…* om een nieuwe map aan te wijzen. Een nieuwe map begint
een nieuwe reeks, en de oude bestanden blijven waar ze zijn.

**Een back-upbestand wil niet openen.** *Verkeerd wachtwoord* betekent dat de authenticatietag van
het bestand niet klopte: controleer of je het wachtwoord gebruikt van de Mac die het bestand heeft
*geschreven* (na een wachtwoordwijziging openen oude kopieën nog steeds met het oude wachtwoord),
of de herstelzin van die Mac. *Deze back-up vereist Keepit 3.0 of nieuwer* betekent dat het bestand
is geschreven door een nieuwere versie dan de versie die het opent.

**Homebrew weigert over een bestaande app heen te installeren.** Stop Keepit eerst en verplaats
`/Applications/Keepit.app` naar de prullenmand, of voeg `--force` toe.

Kom je er niet uit? [GitHub Issues](https://github.com/andrey-insarov/Keepit/issues) · admin@keep.it.com

### Spiekbriefje sneltoetsen

| Toetsen | Actie |
|------|--------|
| `⌥M` | Geschiedenismenu, typ om te zoeken |
| `⌥T` | Sjablonenmenu |
| `⌃⌥1` … `⌃⌥0` | Item 1–10 plakken (in het menu en overal) |
| `⇧` in het menu | Uitgebreid menu: alle acties per item |
| `⌥⇧V` | Het vorige item plakken / wisselen |
| `⌃⌥V` | Het klembord als platte tekst plakken |
| `⌃⌥U` `⌃⌥L` `⌃⌥T` `⌃⌥S` | HOOFDLETTERS / kleine letters / Elk Woord Met Hoofdletter / als een zin |
| `⌃⌥W` `⌃⌥J` | Zonder witruimte aan de randen / op één regel |
| `⌃⌥K` `⌃⌥D` `⌃⌥Y` `⌃⌥X` | Doorhalen / onderstrepen / golvend onderstrepen / versieringen verwijderen |
| `⌃⌥A` | Het klembord toevoegen aan Sjablonen |
| `⌃⌥⌫` | Het nieuwste item verwijderen |
| `⌥N` · `⌥V` · `⌥⇧N` | Plakwachtrij: starten / stoppen · volgende plakken · alle resterende plakken |
| `⌥E` `⌥S` `⌥C` `⌥P` `⌥L` `⌥Q` | Weergave · Instellingen · Geschiedenis wissen · Opname pauzeren · Vergrendelen · Stoppen |
| `⌘F` in de Weergave | Zoeken |
| `⌘,` | Instellingen |

### Spiekbriefje plaatsaanduidingen

| Plaatsaanduiding | Resultaat |
|-------------|--------|
| `{date}` `{time}` `{datetime}` | Datum / tijd / beide, systeemnotatie |
| `{date:yyyy-MM-dd}` `{time:HH:mm}` | Eigen notatie (Unicode-datumpatronen) |
| `{date:long}` `{time:short}` `{datetime:full}` | Benoemde stijl: `short` `medium` `long` `full` |
| `{date+7d}` `{date-1m:MMMM}` `{time+1h}` `{datetime-1d:long}` `{date+1y-2d}` | Verschoven (`d` `w` `m` `y` `h`; maximaal vier verschuivingen achter elkaar) |
| `{weekday}` `{month}` `{year}` | Naam van de dag, naam van de maand, jaar |
| `{iso}` `{unix}` | ISO 8601-tijdstempel, Unix-tijd |
| `{clipboard}` `{clipboard:2}` | Het klembord (item 1) of item N |
| `{clipboard\|upper}` `\|lower` `\|title` `\|trim` `\|oneline` `\|url` | Filters, te combineren |
| `{input:Naam}` `{input:Naam=Standaard}` | Vraagt om een waarde voordat er wordt geplakt |
| `{choice:Label=A\|B\|C}` | Vraagt om een optie te kiezen |
| `{cursor}` | Positie van de cursor na het plakken |
| `{user}` `{username}` `{host}` | Volledige naam, accountnaam, computernaam |
| `{uuid}` `{random:1-100}` | Nieuwe UUID, willekeurig getal binnen een bereik |
| `{{` `}}` | Letterlijke accolades |
