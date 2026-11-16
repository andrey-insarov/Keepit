<!-- source: GUIDE.md 5e4e05273c142ac7759f3c994f7665d09f9b8d3c -->
# Příručka Keepit

Keepit spravuje historii schránky a šablony v systému macOS. Sídlí v řádku nabídek, pamatuje si
vše, co zkopírujete, a kteroukoli položku vloží zpět klávesovou zkratkou. Všechny zkratky uvedené
níže jsou výchozí a každou lze změnit v *Nastavení → Zkratky*. Tato příručka popisuje Keepit 3;
příručka pro Keepit 2.x zůstává beze změny na adrese
[keep.it.com/v2/guide](https://keep.it.com/v2/guide) (anglicky).

![Nabídka historie](site/img/guide/menu.png)

**Obsah**

- [Část 1: Začínáme](#part-1-getting-started): [Instalace](#install) · [První spuštění](#first-launch)
- [Část 2: Každodenní používání](#part-2-everyday-use): [Nabídka historie](#the-history-menu) · [Hledání a náhled](#search-and-preview) · [Vkládání bez nabídky](#paste-without-the-menu) · [Fronta vkládání](#the-paste-queue) · [Rozšířená nabídka](#the-extended-menu)
- [Část 3: Šablony](#part-3-templates): [Vytváření a uspořádání](#creating-and-organising) · [Zástupné symboly](#placeholders) · [Šablony, které se ptají](#templates-that-ask-questions)
- [Část 4: Prohlížeč](#part-4-the-viewer)
- [Část 5: Nastavení](#part-5-settings)
- [Část 6: Zabezpečení](#part-6-security): [Heslo a šifrování](#password-and-encryption) · [Touch ID](#touch-id) · [Fráze pro obnovu](#recovery-phrase) · [Záloha](#backup)
- [Část 7: Pro pokročilé](#part-7-advanced): [Automatizace](#automation-the-keepit-url-scheme) · [Aktualizace](#updates) · [Odinstalace](#uninstalling)
- [Přehledy](#reference): [Řešení potíží](#troubleshooting) · [Tahák klávesových zkratek](#keyboard-cheat-sheet) · [Tahák zástupných symbolů](#placeholder-cheat-sheet)

---

## Část 1: Začínáme

### Instalace

**Homebrew.** Doporučujeme ho, protože `brew upgrade` udržuje aplikaci aktuální:

```bash
brew tap andrey-insarov/keepit https://github.com/andrey-insarov/Keepit
brew install --cask andrey-insarov/keepit/keepit
```

**DMG.** Stáhněte si `Keepit-<verze>.dmg` z
[nejnovějšího vydání](https://github.com/andrey-insarov/Keepit/releases/latest), otevřete ho a
přetáhněte Keepit do složky *Aplikace*.

![DMG: přetáhněte Keepit do složky Aplikace](site/img/guide/dmg.png)

Při prvním otevření aplikace macOS potvrdí, že byla stažena z internetu a že ji zkontroloval Apple.
Klikněte na *Otevřít*.

![Potvrzení Gatekeeperu v macOS](site/img/guide/gatekeeper.png)

Keepit je podepsaný a notarizovaný, aktualizuje se sám a běží nativně na Macích s Apple silicon
i s procesorem Intel a s macOS 13 Ventura nebo novějším.

### První spuštění

Keepit je aplikace pro řádek nabídek: nemá ikonu v Docku a žádné okno, dokud si ho neotevřete. Po
prvním spuštění se v řádku nabídek objeví ikona 📎 a Keepit se zeptá na tři věci.

**1. Obnovit ze zálohy?** Pokud jde o nový Mac a máte zálohu Keepit (automatickou na iCloud Drivu
nebo v jiné složce, případně exportovaný soubor `.keepit`), volba *Obnovit ze zálohy…* vrátí historii
a šablony dřív, než se stane cokoli dalšího. Soubor odemknete heslem Macu, ze kterého pochází, nebo
jeho frází pro obnovu. *Začít znovu* tento krok přeskočí. Stejné obnovení je později k dispozici
v *Nastavení → Záloha → Obnovit…* a soubor `.keepit` otevřete také dvojím kliknutím ve Finderu.
Podrobnosti najdete v oddílu [Záloha](#backup).

![První otázka na novém Macu: obnovit ze zálohy, nebo začít znovu](site/img/guide/restore-first-run.png)

**2. Heslo (nepovinné).** Keepit umí ukládat historii a šablony zašifrované a odemykat je pomocí
Touch ID. Rozhodnout se můžete hned, nebo později v *Nastavení → Zabezpečení*; jak to funguje,
vysvětluje [Část 6](#part-6-security). Při volbě *Teď ne* zůstane vše na disku nešifrované. Po obnovení zálohy jejím heslem Keepit nabídne, že toto heslo ponechá i pro tento Mac.

![Nabídka hesla při prvním spuštění](site/img/guide/password-offer.png)

![Volba Teď ne: jasné sdělení, co to znamená a kde to lze změnit](site/img/guide/no-password-notice.png)

**3. Oprávnění Zpřístupnění.** Aby mohl vkládat za vás, posílá Keepit ⌘V do aplikace, ve které pracujete. macOS to dovolí jen aplikacím uvedeným v *Nastavení systému → Soukromí a zabezpečení →
Zpřístupnění*. Klikněte na *Otevřít Nastavení systému* a Keepit zapněte. Bez tohoto oprávnění Keepit
dál zaznamenává a kopíruje, ale ⌘V je třeba stisknout ručně.

![Keepit žádá o oprávnění Zpřístupnění](site/img/guide/accessibility-prompt.png)

![Keepit zapnutý v Soukromí a zabezpečení → Zpřístupnění](site/img/guide/accessibility-settings.png)

Keepit se ve výchozím stavu spouští při přihlášení. Vypnout to lze v *Nastavení → Obecné*.

---

## Část 2: Každodenní používání

### Nabídka historie

Stiskněte **⌥M** v kterékoli aplikaci nebo klikněte na ikonu 📎. Nabídka se otevře u textového
kurzoru, pokud ho Keepit dokáže najít, jinak u ukazatele myši.

Každý řádek je jedna zkopírovaná položka, nejnovější je nahoře. Ta nejnovější je **tučně**, protože
právě ona je teď ve schránce. Ikona ukazuje zdrojovou aplikaci. Název zakončený `…`
má víc řádků, než nabídka zobrazuje. Obrázky mají miniaturu, seznamy souborů ukazují názvy souborů.

![Panel náhledu vedle nabídky ukazuje zvýrazněnou položku celou, se zdrojovou aplikací, časem a velikostí](site/img/guide/menu-preview.png)

![Obrázek v historii: miniatura v nabídce, celý obrázek v náhledu](site/img/guide/menu-image.png)

Položku vložíte tak, že na ni kliknete, nebo na ni přejdete šipkami ↑ ↓ a stisknete Return, nebo
stisknete její číslo s **⌃⌥**: `⌃⌥3` vloží položku 3. Stejná klávesa funguje odkudkoli, i bez
otevření nabídky.

Pod historií najdete podnabídku *Šablony*, Prohlížeč (⌥E), Nastavení (⌥S), *Vymazat historii* (⌥C),
*Pozastavit zaznamenávání na 10 minut* (⌥P, když píšete něco, co se zaznamenat nemá), *Zamknout
Keepit* (⌥L), pokud je nastavené heslo, a aktualizace. **⌥T** otevře samotnou nabídku šablon.
Všechny tyto klávesy fungují i bez nabídky.

### Hledání a náhled

**Hledání.** Když je nabídka otevřená, začněte psát: pole nahoře filtruje seznam podle názvu
i podle celého textu, takže najde i řádek uprostřed dlouhé položky. Return vloží první shodu,
Esc pole vymaže a druhé Esc nabídku zavře.

**Náhled.** Najeďte na položku myší (nebo na ni přejděte klávesnicí) a panel vedle nabídky ukáže
celý obrázek nebo první řádky dlouhého textu spolu se zdrojovou aplikací, datem a velikostí.
Krátké jednořádkové texty náhled nemají, řádek nabídky je už ukazuje celé.

![Psaní filtruje nabídku; panel náhledu ukazuje zvýrazněnou položku](site/img/guide/search-preview.png)

### Vkládání bez nabídky

Globální klávesové zkratky pracují s historií v jejím současném stavu (položka 1 je schránka),
a to z kterékoli aplikace:

| Klávesy | Co se stane |
|------|--------------|
| `⌃⌥1` … `⌃⌥9`, `⌃⌥0` | Vloží položku historie 1–10 |
| `⌥⇧V` | Vloží *předchozí* položku (položku 2); dalším stiskem je prohodíte zpět |
| `⌃⌥V` | Vloží schránku jako prostý text, bez formátování |
| `⌃⌥U` `⌃⌥L` `⌃⌥T` `⌃⌥S` | Vloží schránku VELKÝMI PÍSMENY / malými písmeny / Každé Slovo Velkým / jako věta |
| `⌃⌥W` | Vloží schránku bez mezer na začátku a na konci |
| `⌃⌥J` | Vloží schránku spojenou do jednoho řádku |
| `⌃⌥K` `⌃⌥D` `⌃⌥Y` | Vloží schránku přeškrtnutou / podtrženou / podtrženou vlnovkou, a to jako prostý text, který si vzhled zachová všude, i v chatech (viz níže) |
| `⌃⌥X` | Vloží schránku bez těchto zdobení |
| `⌃⌥A` | Přidá schránku do Šablon |
| `⌃⌥⌫` | Smaže nejnovější položku z historie |

Tato tři zdobení nejsou formátování: Keepit za každý znak přidá *kombinující znak* Unicode
(p̶ř̶e̶š̶k̶r̶t̶n̶u̶t̶í̶, p̲o̲d̲t̲r̲ž̲e̲n̲í̲, v̰l̰n̰o̰v̰k̰a̰), takže text vypadá stejně v messengeru, ve webovém
formuláři i v terminálu, kde by se skutečné formátování ztratilo. Má to svou cenu: takový text je
třikrát větší, hledání obyčejného slova ho nenajde, čtečky obrazovky se o něj zadrhávají a některá
písma kreslí linku nerovnoměrně. *Odstranit zdobení* (`⌃⌥X`) znaky zase odebere, a to i z textu
ozdobeného jinde. V obou směrech se znaky odstraňují podle kódového bodu bez ohledu na to, odkud
pocházejí: fonetický přepis, který tytéž znaky používá jako písmena (U+0330 je v IPA také značka
pro třepenou fonaci), o ně přijde a všechna tři zdobení je nejprve odstraní také. Při zapnutém
VoiceOveru slouží `⌃⌥` jako modifikátor samotného VoiceOveru: přiřaďte volbě *Akce s nejnovější
položkou* jiný v Nastavení → Zkratky.

Transformace se týkají textu; u obrázku nebo seznamu souborů klávesa jen pípne. Vše uvedené lze
změnit nebo vypnout v *Nastavení → Zkratky*.

### Fronta vkládání

Někdy potřebujete zkopírovat pět věcí z jednoho místa a ve stejném pořadí je vložit jinam: buňky
do formuláře, řádky ze stránky do dokumentu. Fronta vkládání to zvládne bez nabídky:

1. Stiskněte **⌥N** (nebo zvolte *Spustit frontu vkládání* v nabídce). Ikona v řádku nabídek ukáže
   červenou tečku a počítadlo: `📎 ● 0`.
2. Kopírujte jako obvykle pomocí ⌘C, kolikrát chcete. Počítadlo s každým kopírováním roste: 1, 2, 3…
   Vše se zaznamenává i do historie.

   ![Řádek nabídek při zapnuté frontě: červená tečka a počítadlo](site/img/guide/queue-menubar.png)

3. Přepněte se tam, kam text patří, a pro každou položku stiskněte **⌥V**. Jako první se vloží to,
   co bylo zkopírováno jako první, a počítadlo klesá. ⌘V dál vkládá schránku jako obvykle, takže
   obojí můžete kombinovat.
4. Fronta se sama vypne po vložení poslední položky nebo po dvou minutách bez kopírování a vkládání
   (dobu lze upravit). Dalším stiskem ⌥N ji ukončíte dřív.

**⌥⇧N** vloží najednou vše, co ve frontě ještě zbývá. Položky spojí zalomením řádku, tabulátorem,
mezerou nebo ničím; vyberete si na panelu *Fronta vkládání* v Nastavení, kde se nastavuje i doba
nečinnosti. Dokud je fronta zapnutá, nabídka historie její položky označuje: `▶` se vloží jako
další, `○` čeká ve frontě, `✓` už byla vložena.

![Nabídka historie se zapnutou frontou: ○ ve frontě, ▶ další, ✓ vloženo; řádek nabídky ukazuje, kolik položek zbývá](site/img/guide/queue-menu.png)

![Nastavení → Fronta vkládání](site/img/guide/prefs-queue.png)

### Rozšířená nabídka

Když je nabídka historie otevřená, podržte **⇧** a každá položka dostane podnabídku `▸` se všemi
akcemi pro danou položku: Vložit, Vložit jako prostý text, Jen zkopírovat (do schránky, bez
vložení), transformace *Vložit jako*, Přidat do Šablon, Zobrazit v Prohlížeči, Smazat. Podnabídku
otevřete najetím na položku nebo klávesou →; jakmile je otevřená, můžete ⇧ pustit.

![Podržte ⇧: každá položka dostane podnabídku; u nejnovější položky jsou v ní globální klávesové zkratky](site/img/guide/extended-menu.png)

U nejnovější položky podnabídka uvádí globální klávesové zkratky z tabulky výše. Jsou to stejné
akce se stejnými klávesami, takže se je tu můžete naučit. Ostatní položky ukazují akce bez kláves:
zkratka buď funguje všude, nebo se nezobrazuje.

![U ostatních položek: stejné akce, bez zkratek](site/img/guide/extended-menu-item2.png)

![U obrázku jsou textové akce zašedlé; použít lze jen Vložit, Jen zkopírovat, Přidat do Šablon, Zobrazit v Prohlížeči a Smazat](site/img/guide/extended-menu-image.png)

---

## Část 3: Šablony

Šablony jsou položky, které si necháváte natrvalo: podpisy, adresy, připravené odpovědi, úryvky
kódu, logo, které často vkládáte. Jsou uložené ve stromu se složkami a najdete je v podnabídce
*Šablony* v nabídce historie a pod **⌥T**. Čerstvá instalace obsahuje složku *Příklady* (pozdrav,
dnešní datum, citace schránky a podpis), aby bylo vidět, co šablony umějí, ještě než si napíšete vlastní. Můžete je libovolně mazat nebo upravovat. Ukázkové šablony vrátí *Nastavení → Pokročilé →
Obnovení a odinstalace → Obnovit…*; tato volba ale vrátí do výchozího stavu i ostatní data
a nastavení.

![Složka Příklady: po najetí na položku se zobrazí její text](site/img/guide/template-examples.png)

![Nabídka šablon: složky se otevírají jako podnabídky, písmena za & slouží jako zkratky](site/img/guide/template-menu-letters.png)

### Vytváření a uspořádání

**Přidání šablony**

- Z nabídky historie: `⌃⌥A` pro nejnovější položku, *Přidat schránku do šablon* dole, nebo
  ⇧ → podnabídka položky → *Přidat do Šablon* pro kteroukoli položku.
- V Prohlížeči: vyberte položku historie a klikněte na *Přidat do šablon*, nebo ji přetáhněte do
  stromu Šablony. *Nová položka* vytvoří prázdnou textovou šablonu; *Nová položka ze souboru*
  (kontextová nabídka) ji vytvoří z textového nebo obrazového souboru.

**Uspořádání**

- *Nová složka* vytvoří složku. Položky mezi složkami přetahujte, nebo použijte *Nahoru* / *Dolů*
  v kontextové nabídce.
- Šablona s názvem `-` se v nabídce změní v oddělovací čáru.
- Znak `&` před písmenem v názvu, například `&Podpis`, udělá z tohoto písmene zkratku položky
  v nabídce šablon: při otevřené nabídce stiskněte `P`.
- *Nastavit klávesovou zkratku* v kontextové nabídce dá šabloně vlastní globální zkratku.
- Šablona bez názvu ukazuje svůj první řádek. *Přejmenovat* a *Vymazat název* jsou v kontextové
  nabídce, nebo upravte pole *Název* nad textem.

### Zástupné symboly

Textové šablony mohou obsahovat zástupné symboly `{…}`, které se vyplní v okamžiku vložení. Vše
ostatní se vloží beze změny. V Prohlížeči nabízí **Vložit ▾** seznam všech zástupných symbolů
a vybraný umístí na pozici kurzoru, takže si nic nemusíte pamatovat.

![Příklad Dnešní datum: z `{date:EEEE, d MMMM yyyy}` se při vložení stane aktuální datum](site/img/guide/template-examples-date.png)

![Vložit ▾ v Prohlížeči nabízí všechny zástupné symboly](site/img/guide/insert-menu.png)

Ty nejužitečnější:

| Zástupný symbol | Výsledek |
|-------------|--------|
| `{date}` `{time}` `{datetime}` | Dnešní datum / aktuální čas, systémový formát |
| `{date:yyyy-MM-dd}` | Libovolný formát (`yyyy MM dd EEEE HH mm …`) |
| `{date:long}` `{time:short}` `{datetime:medium}` | Pojmenovaný styl: `short` `medium` `long` `full` |
| `{date+7d}` `{date-1m:MMMM}` `{time+1h}` `{date+1y-2d}` | Posun: `d` dny, `w` týdny, `m` měsíce, `y` roky, `h` hodiny; u `date`, `time`, `datetime`, i několik za sebou |
| `{clipboard}` `{clipboard:2}` | Schránka, nebo položka historie N |
| `{clipboard\|upper}` `{clipboard\|trim\|oneline}` | Filtry `upper` `lower` `title` `trim` `oneline` `url`, lze je řetězit |
| `{cursor}` | Místo, kde po vložení skončí textový kurzor |
| `{user}` `{username}` `{host}` | Celé jméno, název účtu, název počítače |
| `{uuid}` `{random:1-100}` | Nové UUID; náhodné číslo |
| `{{` `}}` | Doslovné složené závorky: šablona `{{"x":1}}` vloží `{"x":1}` |

Názvy zástupných symbolů se píšou malými písmeny: `{date}` je zástupný symbol, kdežto `{Date}`
a `{DATE}` jsou text a vloží se tak, jak jsou. Názvy stylů a filtry (`{date:LONG}`,
`{clipboard|UPPER}`) lze psát oběma způsoby.

Úplný seznam je v [taháku zástupných symbolů](#placeholder-cheat-sheet).

### Šablony, které se ptají

`{input:Jméno}` a `{choice:Popisek=A|B|C}` promění šablonu v malý formulář: když ji vkládáte,
Keepit se nejprve zeptá na hodnoty a potom vloží hotový text. Na stejný název se ptá jen jednou,
ať se v šabloně objevuje kolikrát chce; `{input:Jméno=Výchozí}` pole předvyplní.

![Vložení šablony s {input:Name} se nejprve zeptá na hodnotu](site/img/guide/input-dialog.png)

Například šablona odpovědi:

```
Dobrý den, {input:Jméno},

děkuji za Vaši zprávu z {date-1d}. Ozvu se Vám do {date+3d:d. MMMM}.
{cursor}
{user}
```

Při vložení se zeptá na *Jméno*, doplní data, podepíše vaším celým jménem a nechá kurzor na
prázdném řádku.

---

## Část 4: Prohlížeč

*Prohlížeč…* v nabídce nebo kliknutí pravým tlačítkem na ikonu 📎 otevře okno se třemi stromy:
**Schránka** (aktuální obsah schránky, jen ke čtení), **Historie** (*Text a soubory* a *Obrázky*)
a **Šablony**.

![Prohlížeč s vybranou šablonou](site/img/guide/viewer.png)

- Vyberte položku a uvidíte ji vpravo. Text lze upravovat přímo na místě a změny se použijí, když
  editor opustíte. Obrázek se zobrazí zmenšený na velikost panelu, nad ním jsou jeho rozměry
  v pixelech a velikost souboru. Seznamy souborů otevřou soubor dvojím kliknutím. *Zobrazit jako
  hex dump* v kontextové nabídce ukáže surové bajty.
- Panel nástrojů: *Odeslat do schránky*, *Vložit* (do aplikace, ze které byl Prohlížeč otevřen), *Přidat do
  šablon*, *Nová položka*, *Nová složka*, *Smazat*, *Vložit ▾* (zástupné symboly) a **?**, tedy
  tato příručka.
- **Hledat** (`⌘F`): pole vlevo filtruje historii a šablony podle názvu i obsahu a shodu zvýrazní.
- Položky historie si uchováte přetažením do stromu Šablony, šablony zkopírujete zpět přetažením
  do Historie. Pořadí měníte přetahováním nebo pomocí *Nahoru* / *Dolů*. ⌫ smaže vybranou položku.
- Stavový řádek ukazuje datum, zdrojovou aplikaci, formát a velikost.

![Hledání v Prohlížeči zvýrazňuje shody](site/img/guide/viewer-search.png)

---

## Část 5: Nastavení

`⌘,` v nabídce, *Nastavení…* nebo ⌥S z kterékoli aplikace. Okno funguje tak, jak je u oken
nastavení na Macu zvykem: vyberte panel na panelu nástrojů a každá změna platí okamžitě. Tlačítko
Uložit tu není; okno zavřete pomocí ⌘W nebo Esc. Každá volba, u které je **?**, má bublinu
s vysvětlením.

![Nastavení → Obecné](site/img/guide/prefs-general.png)

| Panel | Co na něm je |
|-----|---------------|
| **Obecné** | Spouštění při přihlášení · uložení historie při ukončení a její obnovení při startu · vložení po výběru (vypnuto = jen zkopírovat) · prodleva vložení, kterou zvyšte u aplikací, jež se do popředí dostávají pomalu · otevírání nabídky u textového kurzoru · Aktualizace: *Automaticky kontrolovat aktualizace* (edice ke stažení z webu; vypnuto = vůbec žádný síťový požadavek), viz [Aktualizace](#updates) |
| **Zkratky** | Všechny globální zkratky na jednom místě, viz níže |
| **Fronta vkládání** | Tři klávesy fronty, doba nečinnosti, po které se fronta vypne, a co vkládat mezi položky u volby *Vložit vše zbývající*, viz [Fronta vkládání](#the-paste-queue) |
| **Historie** | Kolik textových a souborových položek a kolik obrázků uchovávat (1000 / 30) · zapomínat položky starší než … · *Odstraňovat duplicity* (opětovné zkopírování téhož přesune položku nahoru) · *Ignorovat skrytá data schránky* · seznam ignorovaných aplikací (identifikátory balíčků; správci hesel jsou ignorováni vždy) |
| **Nabídka** | Pole hledání · číslování · panel náhledu · tipy · ikony zdrojových aplikací · miniatury obrázků · položky v nabídce (kolik nejnovějších záznamů nabídka vypíše, ve výchozím stavu 60; ostatní lze dál vyhledat) · délka názvu · výška miniatur |
| **Zabezpečení** | Heslo, Touch ID, zamykání, fráze pro obnovu, viz [Část 6](#part-6-security) |
| **Záloha** | Automatická záloha (stavový řádek vedle nadpisu): *Automaticky zálohovat do složky*, název Macu v souborech, složka, kolik kopií ponechat · Ruční záloha: *Zálohovat nyní*, *Uložit do archivu…* · Obnovení: *Obnovit…*, viz [Záloha](#backup) |
| **Pokročilé** | Interval dotazování schránky · Automatizace: *Povolit příkazy URL keepit://* (ve výchozím stavu vypnuto, viz [Automatizace](#automation-the-keepit-url-scheme)) · Data: *Otevřít složku* · Obnovení a odinstalace: *Obnovit…* (návrat do stavu čerstvé instalace, vrátí se ukázkové šablony) · *Odinstalovat…* (obnovení a poté odstranění aplikace, spouštění při přihlášení, záznamu v klíčence a oprávnění) |

![Nastavení → Historie: limity a seznam ignorovaných aplikací](site/img/guide/prefs-history.png)

![Nastavení → Zkratky](site/img/guide/prefs-hotkeys.png)

Na panelu **Zkratky** klikněte do pole a stiskněte kombinaci; ⌫ klávesu vypne. Kombinace, kterou už
používá jiný příkaz, je odmítnuta a důvod se zobrazí pod poli. *Obnovit výchozí* vrátí sadu ⌥ +
písmeno (⌥M historie, ⌥T šablony, ⌥E Prohlížeč, ⌥S Nastavení, ⌥C Vymazat historii, ⌥P pozastavení,
⌥L zámek, ⌥Q ukončení), ⌥⇧V a ⌃⌥. Volby *Vložit položku podle čísla* a *Akce s nejnovější položkou*
přijímají jen modifikátory, číslici nebo písmeno doplní Keepit. Pokud některou zkratku už vlastní
macOS nebo jiná aplikace, Keepit to oznámí při spuštění. *Prohlížeč* ⌥E, *Nastavení* ⌥S, *Vymazat
historii* ⌥C, *Pozastavit záznam* ⌥P, *Zamknout Keepit* ⌥L a *Ukončit Keepit* ⌥Q fungují
z kterékoli aplikace a v nabídce jsou uvedené vedle svých příkazů. Na americkém rozložení klávesnice
píše ⌥ + písmeno obvykle speciální znak (⌥S = ß, ⌥C = ç …); pokud některý z nich potřebujete,
přesuňte zkratku jinam. Keepit také čte vaše rozložení klávesnice: písmena zobrazená v Nastavení a v nabídkách jsou ta na klávesách rozložení, které právě používáte, a výchozí zkratku, která by zabrala znak potřebný ve vašem rozložení (⌥L píše @ v německém a ł v polském), Keepit při spuštění nechá volnou — říká to poznámka pod jejím polem; chcete-li ji přesto použít, klikněte do pole a stiskněte kombinaci. U nelatinkového rozložení, například ruského, pocházejí názvy z latinkového rozložení, které k němu macOS přiřazuje — stejně jako v nabídkách samotného systému.

---

## Část 6: Zabezpečení

### Heslo a šifrování

*Nastavení → Zabezpečení → Vyžadovat heslo při spuštění* zašifruje historii a šablony pomocí
AES-256-GCM. Klíč se odvozuje z vašeho hesla (PBKDF2, 200 000 iterací) a existuje jen v paměti.
Smaže se, když se Keepit zamkne: volbou *Zamknout Keepit* (`⌥L`), při ukončení a volitelně poté, co
byl Mac nějakou dobu zamčený nebo uspaný. *Automatický zámek Keepit* je u nové instalace nastaven na
**Nikdy** (aktualizace z verze 3.0.3 zachová původní volbu, tedy *Okamžitě*, pokud bylo zaškrtnuté
zamykání s obrazovkou): správce schránky, který chce heslo po každé přestávce na kávu, lidé
přestanou používat, a pro chvíle, kdy na tom záleží, je tu `⌥L`. *Okamžitě* zamyká spolu
s obrazovkou. Volby *Po 5 minutách*, *Po 15 minutách* a *Po 1 hodině* krátkou nepřítomnost
přecházejí (Keepit zůstane odemčený a dál zaznamenává) a zamknou až tehdy, když byl Mac po
celou nastavenou dobu zamčený nebo uspaný. Totéž platí, když se Keepit spustí ve chvíli, kdy je Mac už zamčený nebo je
v popředí relace jiného uživatele (třeba při opětovném spuštění po aktualizaci): nepřítomnost se
počítá od startu, pokud macOS tento stav Keepit hlásí (obvykle ano; když to nejde, odpočet začne
při příštím zamčení nebo uspání). Při zapnutém Touch ID požádá Keepit o dotyk v okamžiku, kdy Mac
odemknete, takže je připravený ještě před prvním `⌥M`.

![Nastavení hesla pomocí klávesnice na obrazovce. Je to fotografie obrazovky, ne snímek obrazovky: na autorově Macu ukazuje snímek této scény jen samotný dialog](site/img/guide/set-password-keyboard.jpg)

Dialogy pro heslo ukazují aktuální rozložení klávesnice a upozorňují na Caps Lock, takže odmítnuté
heslo bývá málokdy záhadou. Tlačítko s klávesnicí vedle pole otevře **klávesnici na obrazovce**, na
které heslo naklikáte myší: kliknutí nikdy neprocházejí systémem jako stisky kláves, klávesy se při
každém otevření zamíchají a klávesnice žádá macOS, aby ji vynechal ze snímků a záznamů obrazovky
(v některých konfiguracích vynechána je; zaručené to není). Hodí se pro Mac, kterému plně
nedůvěřujete, nebo pro Mac, jehož obrazovka je sdílená. Při spuštění a po zamčení se Keepit zeptá
na heslo (nebo na Touch ID); *Obnovit přístup…* místo něj přijme frázi o 24 slovech, viz
[Fráze pro obnovu](#recovery-phrase).

![Odemčení při spuštění: heslo, Ukončit nebo fráze pro obnovu; OK zůstává neaktivní, dokud něco nenapíšete. Vyfotografováno ze stejného důvodu jako výše](site/img/guide/unlock-keyboard.jpg)

![Nastavení → Zabezpečení](site/img/guide/prefs-security.png)

### Touch ID

Při zapnuté volbě *Odemykat pomocí Touch ID* je klíč uložen také v Secure Enclave za vaším otiskem
prstu: Keepit místo hesla požádá o dotyk. Heslo dál funguje jako záložní možnost, ve výzvě stačí
zvolit *Použít heslo*. Když je víko zavřené a máte externí Magic Keyboard s Touch ID, Keepit se ptá
na klávesnici. *Povolit změnu hesla pomocí Touch ID* dovolí, aby při změně hesla otisk prstu
zastoupil staré heslo.

![Odemčení pomocí Touch ID; heslo zůstává jako záložní možnost](site/img/guide/touch-id.png)

### Fráze pro obnovu

Když nastavíte heslo, Keepit jednou zobrazí frázi o 24 slovech. Vytiskněte si ji nebo ji uložte do
správce hesel. Pokud heslo zapomenete, *Obnovit přístup…* v dialogu pro odemčení otevře data
a umožní nastavit nové heslo. *Fráze pro obnovu → Vytvořit novou…* vydá novou frázi a starou
zneplatní; *Zobrazit…* vedle toho ukáže aktuální frázi znovu, po ověření pomocí Touch ID nebo hesla.

Bez hesla, Touch ID na stejném Macu nebo fráze data obnovit nelze: neexistuje žádný server a není
co resetovat.

![Fráze pro obnovu o 24 slovech (slova jsou zde skrytá)](site/img/guide/recovery-phrase.png)

### Záloha

Keepit umí uchovávat šifrovanou kopii historie a šablon ve složce, kterou si zvolíte (iCloud Drive,
Dropbox, Google Drive, externí disk, NAS), a zapsat novou, kdykoli se něco změní. Žádný server
Keepit neexistuje: složka je vaše. Poskytovatel, který za ní stojí, vidí šifrovaný soubor, jeho
velikost a malou nešifrovanou hlavičku (kdy a kterou verzí Keepit byl soubor zapsán, jak se
odvozuje klíč, náhodné identifikátory a název vašeho Macu jen tehdy, když to zapnete);
[stránka o zabezpečení](/security#backups) (anglicky) ji popisuje pole po poli.

![Nastavení → Záloha: automatická záloha, ruční záloha, obnovení](site/img/guide/prefs-backup.png)

**Zapnutí.** *Nastavení → Záloha → Automaticky zálohovat do složky* a potom *Vybrat…* složku
(výběr se otevře na iCloud Drivu). Automatická záloha vyžaduje ochranu heslem z *Nastavení →
Zabezpečení*: každá kopie je zapečetěna klíčem odvozeným z klíče vašeho trezoru, takže ji otevřete
svým heslem Keepit nebo frází pro obnovu na tomto Macu i na jakémkoli jiném a nic dalšího se pro to
nastavovat nemusí. Bez hesla je zaškrtávací pole neaktivní a uvádí důvod.

**Co se děje potom: plán.** Asi pět minut po poslední změně (a nejpozději jednou denně, dokud Keepit
běží) zapíše Keepit do složky soubor s názvem `Keepit-<datum a čas>-<instalace>-<id>.keepit`,
pro kontrolu ho přečte zpět a teprve potom smaže nejstarší ze svých vlastních kopií nad počet
*Ponechat posledních* (ve výchozím stavu 10, rozsah 1–100). Každá kopie je úplná sama o sobě, nejde
o přírůstek, takže vám vždy stačí jediný soubor. Kopií vytvořených jiným Macem ani souborů, které do složky přidáte, se Keepit nikdy nedotkne: dva Macy sdílející jednu složku zapisují dvě
nezávislé řady. Stavový řádek vedle nadpisu *Automatická záloha* ukazuje čas a velikost poslední
kopie, nebo důvod, proč poslední pokus selhal. Dokud je Keepit zamčený, neděje se nic; *Zálohovat
nyní* (v části *Ruční záloha*) na období klidu nečeká.

**Zahrnout název tohoto Macu** (ve výchozím stavu vypnuto) vloží název počítače do nešifrované
hlavičky každého souboru, takže se dvě řady v jedné složce ve Finderu snadno rozliší. Poskytovatel
úložiště tento název vidí, a proto je volba nepovinná.

**Obnovení.** *Obnovit…* otevře zálohu (z tohoto Macu, z jiného Macu nebo exportovaný soubor) poté,
co ji odemknete: heslem Macu, na kterém vznikla, nebo frází pro obnovu, kterou tento Mac zobrazil
při nastavení hesla (*Obnovit přístup…* v dialogu pro heslo). Náhled ukáže, kdy a kde soubor vznikl
a kolik položek obsahuje. Potom máte dvě možnosti:

![Náhled obnovení: kdy a kterou verzí Keepit byl soubor zapsán, co obsahuje, Sloučit nebo Nahradit](site/img/guide/restore-preview.png)

- *Sloučit* přidá to, co tu ještě není: položky historie podle obsahu a šablony ze zálohy jako jednu
  novou složku s názvem *Import <datum>*, bez jejich klávesových zkratek. Vidíte tak přesně, co ze
  zálohy přišlo, a můžete to přesunout nebo smazat. Nic z vašich dat se nepřepíše.
- *Nahradit* zahodí současnou historii a šablony a vezme místo nich ty ze zálohy. Předtím Keepit
  zapíše kopii toho, co máte teď (`Keepit-before-restore-…`), do složky se zálohami nebo do složky,
  kterou vyberete; pokud tuto kopii zapsat nelze, nahrazení se nespustí. Pokud Keepit ještě nemá
  heslo, požádá vás o heslo pro tuto kopii, stejně jako u volby *Uložit do archivu…*.

*Obnovit také předvolby* přenese ze zálohy klávesové zkratky, limity a volby. Nastavení, která
vyjadřují důvěru ke konkrétnímu Macu (Touch ID, automatizace přes URL a její důvěryhodné aplikace,
samotná složka se zálohami), vždy zůstávají taková, jaká jsou zde. Pokud je historie ze zálohy větší,
než dovolují limity tohoto Macu, Keepit před potvrzením řekne, kolik se toho vejde.

Obnovujete zálohu její frází pro obnovu na Macu, který ještě nemá heslo? Keepit vás požádá,
abyste ho nejprve nastavili, takže se obnovená data nikdy neuloží nešifrovaná, a nechá vás tuto
frázi pro tento Mac ponechat, nebo získat novou. Obnovujete ji heslem? Keepit nabídne, že ho
ponechá jako heslo tohoto Macu. V obou případech je samotná automatická záloha nastavením každého
Macu zvlášť: zapněte ji zde a vyberte složku (klidně tu stejnou) a tento Mac začne vedle souborů
starého Macu zapisovat vlastní řadu.

**Přechod na nový Mac** je hlavní smysl toho všeho: nainstalujte Keepit, při prvním spuštění zvolte
*Obnovit ze zálohy…*, vyberte ve své složce nejnovější soubor, zadejte heslo starého Macu a zvolte
*Nahradit*; potom na novém Macu zapněte automatickou zálohu. Dosavadní kopie se otevírají heslem
a frází, které platily v době jejich zápisu: po změně hesla potřebují ty staré stále staré heslo.

**Ruční záloha.** Jsou tu dvě tlačítka a každé dělá něco jiného. *Zálohovat nyní* vytvoří hned
kopii stejného typu jako automatická: stejný druh souboru, stejná složka i řada, otevírá se vaším
heslem Keepit nebo frází. *Uložit do archivu…* zapíše jeden *archiv* `.keepit` tam, kam určíte,
a zamkne ho heslem, které pro něj zvolíte. Nepotřebuje ochranu Keepit heslem a Keepit pak soubor
dál nesleduje. Hodí se pro předání dat nebo pro kopii mimo složku se zálohami. Navržený název říká,
o co jde: `Keepit-archive-<datum>-manual.keepit`, na rozdíl od automatických kopií
`Keepit-<datum a čas>-<instalace>-<id>.keepit`.

![Uložit do archivu…: název souboru obsahuje slova archive a manual](site/img/guide/save-to-archive.png)

![Vlastní heslo archivu s ukazatelem síly: nikam se neukládá](site/img/guide/archive-password.png)

*Obnovit…* otevře obojí. Archiv nahrazuje volby *Exportovat…* / *Importovat…* z verze 2.x. Soubor
přenáší data mezi edicí ke stažení z webu a edicí z App Storu i mezi Keepit 2.x a 3.x: soubor
zapsaný verzí 3.0 lze otevřít jen ve verzi 3.0 nebo novější; verze 3.0 přečte vše, co zapsala 2.x.

**Když se něco pokazí.** Neúspěšná kopie se ohlásí ve stavovém řádku a pokus se opakuje
s prodlužujícími se přestávkami; předchozí kopie zůstávají. Pokud byl Keepit ukončen nebo Mac
vypadl uprostřed obnovení, příští spuštění tiše vrátí vše do stavu před obnovením. Ve vzácném
případě, kdy to nejde (soubor, který nelze zapsat, plný disk), Keepit soubor jmenuje a ukončí se,
aniž cokoli změní: opravte soubor a spusťte Keepit znovu. Podrobnosti včetně vnitřní podoby formátu
souboru jsou na [stránce o zabezpečení](/security#backups) (anglicky).

---

## Část 7: Pro pokročilé

### Automatizace: schéma URL keepit://

Aplikace Zkratky (*Otevřít URL*), Raycast, Alfred, Keyboard Maestro nebo příkaz `open` v shellu
mohou Keepit ovládat, **jakmile to zapnete** v *Nastavení → Pokročilé → Automatizace → Povolit
příkazy URL keepit://*. Ve výchozím stavu je to vypnuté, protože URL může otevřít kterákoli aplikace
nebo webová stránka a příkazy `add` / `paste` mění schránku a píšou do aplikace v popředí; při
vypnuté volbě Keepit taková URL ignoruje a pípne. Při zapnuté volbě se Keepit dívá, kdo URL
otevřel: první příkaz z každé aplikace, který něco mění (`paste`, `copy`, `template`, `add`,
`add-template`, `pause`, `resume`), se zobrazí v dialogu. *Povolit* ho provede jednou, *Vždy
povolit* zařadí aplikaci na seznam důvěryhodných (vymažete ho volbou *Zapomenout důvěryhodné
aplikace* na stejném panelu). Webového prohlížeče nebo odesílatele, kterého macOS neumí
pojmenovat, se Keepit ptá pokaždé. Příkazy, které jen otevírají vlastní okna Keepit, se neptají
nikdy.

| URL | Účinek |
|-----|--------|
| `keepit://paste/2`<br>`keepit://paste/latest`<br>`keepit://paste/previous` | Vloží položku historie N (nebo nejnovější / předchozí) do aplikace v popředí |
| `keepit://copy/3` | Uloží položku N do schránky bez vložení |
| `keepit://template/Signature`<br>`keepit://template/Work/Reply?copy=1` | Vloží (nebo zkopíruje) šablonu podle názvu nebo cesty ke složce |
| `keepit://add?text=…` | Přidá text do historie a do schránky |
| `keepit://add-template?text=…&name=…` | Vytvoří šablonu |
| `keepit://history`<br>`keepit://templates`<br>`keepit://viewer`<br>`keepit://settings` | Otevře nabídku historie, nabídku šablon, Prohlížeč, Nastavení |
| `keepit://pause`<br>`keepit://resume` | Pozastaví záznam na 10 minut / obnoví ho |

Text kódujte procenty (`%20` místo mezery). Dokud je Keepit zamčený, URL se ignorují.

### Aktualizace

Keepit jednou denně kontroluje GitHub Releases a aktualizace nabízí v dialogu; *Zkontrolovat
aktualizace…* to udělá hned. Aktualizace jsou podepsané (EdDSA) a notarizované. S Homebrew udělá
totéž `brew upgrade --cask keepit`. Kontrolní součty všech stahovaných souborů jsou v `SHA256SUMS`
na stránce vydání.

Tato kontrola je jediný síťový požadavek, který Keepit posílá, a je volitelná: *Nastavení → Obecné →
Aktualizace → Automaticky kontrolovat aktualizace*. Když ji vypnete, Keepit už nic nekontaktuje, ani
na vaši žádost, a *Zkontrolovat aktualizace…* zmizí z nabídek. Aktualizujete pak stažením
z [keep.it.com](https://keep.it.com) nebo pomocí Homebrew. Edice z App Storu žádný aktualizátor ani
takovou volbu nemá; aktualizuje ji App Store.

### Odinstalace

*Nastavení → Pokročilé → Obnovení a odinstalace → Odinstalovat…* odstraní aplikaci, složku s daty,
záznamy v klíčence (včetně klíče pro Touch ID), položku spouštěnou při přihlášení a záznam ve
Zpřístupnění. Vyžádá si heslo nebo Touch ID, napsané slovo `DELETE` a potvrzení. Pokud byste data
ještě mohli chtít, nejprve si exportujte zálohu. S Homebrew potom spusťte
`brew uninstall --cask --force keepit`, aby Homebrew na cask zapomněl.

![Nastavení → Pokročilé](site/img/guide/prefs-advanced.png)

---

## Přehledy

### Řešení potíží

**Po výběru položky se nic nevloží.** Chybí oprávnění Zpřístupnění: *Nastavení systému → Soukromí
a zabezpečení → Zpřístupnění → Keepit*. Pokud Keepit v seznamu je, a přesto nevkládá, vypněte ho
a znovu zapněte. macOS udělené oprávnění zapomene, když se aplikace přeinstaluje.

**Klávesová zkratka nic nedělá.** Vlastní ji jiná aplikace nebo macOS; Keepit to hlásí při spuštění.
Vyberte jinou kombinaci na panelu *Zkratky*. Kombinace ⌃⌥ s číslicemi a písmeny je na Macu
v továrním stavu volná. Nebo je to výchozí zkratka, kterou Keepit nechal volnou, protože v některém z vašich rozložení klávesnice píše znak; říká to poznámka pod jejím polem na panelu *Zkratky*. Vyberte jinou kombinaci, nebo klikněte do pole a stiskněte tutéž, chcete-li ji přesto použít. ⌃⌥V nic nevloží, dokud je otevřená nabídka Keepitu: macOS používá ⌃V (a také ⌃N a ⌃P) k posouvání výběru v nabídkách. Nejprve nabídku zavřete, nebo podržte ⇧ a v podnabídce položky zvolte *Vložit jako prostý text*. Ze stejného důvodu nemůže být zkratkou pro *Zamknout Keepit* ⌃ s V, N nebo P.

**Nabídka se otevírá na špatném místě.** Aplikace, ve které jste, nezpřístupňuje svůj textový
kurzor, a nabídka se proto otevře u ukazatele myši. Volba *Otevírat nabídku u textového kurzoru,
pokud to jde* na panelu Obecné hledání kurzoru vypne, pokud chcete nabídku vždy u ukazatele.

**Něco, co jsem zkopíroval(a), chybí.** Nezaznamenává se nic, co kopírující aplikace označila jako
skryté, ani kopie pořízená ve chvíli, kdy byl v popředí správce hesel (vestavěný seznam) nebo
aplikace z vašeho seznamu ignorovaných, včetně aplikace, která byla v popředí těsně před přepnutím. Viz *Nastavení → Historie* a
[stránku o zabezpečení](/security#what-is-not-recorded) (anglicky).

**Touch ID se nenabízí.** V tuto chvíli není dostupný žádný snímač Touch ID (zavřené víko, žádná
klávesnice s Touch ID). Keepit si nastavení ponechá a o otisk prstu požádá, jakmile bude snímač
k dispozici.

**Stav zálohy hlásí, že složka není dostupná.** Složka byla přesunuta, přejmenována, odpojena nebo
(u iCloud Drivu) odstraněna z místního úložiště. Připojte ji nebo ji vraťte a příští kopie proběhne;
případně zvolte *Vybrat…* a určete novou složku. Nová složka začíná novou řadu, staré soubory
zůstanou tam, kde jsou.

**Soubor se zálohou nejde otevřít.** *Chybné heslo* znamená, že nesouhlasila autentizační značka
souboru: ujistěte se, že používáte heslo Macu, který soubor *zapsal* (po změně hesla se staré kopie
stále otevírají starým heslem), nebo jeho frázi pro obnovu. *Tato záloha vyžaduje Keepit 3.0 nebo
novější* znamená, že soubor zapsala novější verze, než která ho otevírá.

**Homebrew odmítá instalovat přes existující aplikaci.** Nejprve Keepit ukončete a přesuňte
`/Applications/Keepit.app` do Koše, nebo přidejte `--force`.

Stále si nevíte rady? [GitHub Issues](https://github.com/andrey-insarov/Keepit/issues) · admin@keep.it.com

### Tahák klávesových zkratek

| Klávesy | Akce |
|------|--------|
| `⌥M` | Nabídka historie, psaním hledáte |
| `⌥T` | Nabídka šablon |
| `⌃⌥1` … `⌃⌥0` | Vložit položku 1–10 (v nabídce i kdekoli jinde) |
| `⇧` v nabídce | Rozšířená nabídka: všechny akce pro každou položku |
| `⌥⇧V` | Vložit předchozí položku / prohodit |
| `⌃⌥V` | Vložit schránku jako prostý text |
| `⌃⌥U` `⌃⌥L` `⌃⌥T` `⌃⌥S` | VELKÁ PÍSMENA / malá písmena / Každé Slovo Velkým / jako věta |
| `⌃⌥W` `⌃⌥J` | Bez okrajových mezer / na jeden řádek |
| `⌃⌥K` `⌃⌥D` `⌃⌥Y` `⌃⌥X` | Přeškrtnutí / podtržení / vlnovka / odstranit zdobení |
| `⌃⌥A` | Přidat schránku do Šablon |
| `⌃⌥⌫` | Smazat nejnovější položku |
| `⌥N` · `⌥V` · `⌥⇧N` | Fronta vkládání: spustit / zastavit · vložit další · vložit vše zbývající |
| `⌥E` `⌥S` `⌥C` `⌥P` `⌥L` `⌥Q` | Prohlížeč · Nastavení · Vymazat historii · Pozastavit záznam · Zamknout · Ukončit |
| `⌘F` v Prohlížeči | Hledat |
| `⌘,` | Nastavení |

### Tahák zástupných symbolů

| Zástupný symbol | Výsledek |
|-------------|--------|
| `{date}` `{time}` `{datetime}` | Datum / čas / obojí, systémový formát |
| `{date:yyyy-MM-dd}` `{time:HH:mm}` | Vlastní formát (vzory data podle Unicode) |
| `{date:long}` `{time:short}` `{datetime:full}` | Pojmenovaný styl: `short` `medium` `long` `full` |
| `{date+7d}` `{date-1m:MMMM}` `{time+1h}` `{datetime-1d:long}` `{date+1y-2d}` | Posun (`d` `w` `m` `y` `h`; až čtyři posuny za sebou) |
| `{weekday}` `{month}` `{year}` | Název dne, název měsíce, rok |
| `{iso}` `{unix}` | Časové razítko ISO 8601, unixový čas |
| `{clipboard}` `{clipboard:2}` | Schránka (položka 1) nebo položka N |
| `{clipboard\|upper}` `\|lower` `\|title` `\|trim` `\|oneline` `\|url` | Filtry, lze je řetězit |
| `{input:Jméno}` `{input:Jméno=Výchozí}` | Zeptat se před vložením na hodnotu |
| `{choice:Popisek=A\|B\|C}` | Nechat vybrat jednu z možností |
| `{cursor}` | Pozice kurzoru po vložení |
| `{user}` `{username}` `{host}` | Celé jméno, název účtu, název počítače |
| `{uuid}` `{random:1-100}` | Nové UUID, náhodné číslo z rozsahu |
| `{{` `}}` | Doslovné složené závorky |
