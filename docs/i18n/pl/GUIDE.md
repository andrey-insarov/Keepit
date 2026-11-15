<!-- source: GUIDE.md 02a558b209b5788bd20956d5be4d5997d024d7d3 -->
# Podręcznik Keepit

Keepit zarządza historią schowka i szablonami w systemie macOS. Mieszka na pasku menu, pamięta
wszystko, co kopiujesz, i wkleja dowolny element z powrotem po naciśnięciu skrótu klawiszowego.
Wszystkie skróty podane niżej są domyślne i każdy można zmienić w *Ustawienia → Skróty*. Ten
podręcznik opisuje Keepit 3; podręcznik do Keepit 2.x pozostaje bez zmian pod adresem
[keep.it.com/v2/guide](https://keep.it.com/v2/guide) (po angielsku).

![Menu historii](site/img/guide/menu.png)

**Spis treści**

- [Część 1. Pierwsze kroki](#part-1--getting-started): [Instalacja](#install) · [Pierwsze uruchomienie](#first-launch)
- [Część 2. Codzienna praca](#part-2--everyday-use): [Menu historii](#the-history-menu) · [Wyszukiwanie i podgląd](#search-and-preview) · [Wklejanie bez menu](#paste-without-the-menu) · [Kolejka wklejania](#the-paste-queue) · [Menu rozszerzone](#the-extended-menu)
- [Część 3. Szablony](#part-3--templates): [Tworzenie i porządkowanie](#creating-and-organising) · [Symbole zastępcze](#placeholders) · [Szablony, które zadają pytania](#templates-that-ask-questions)
- [Część 4. Przeglądarka](#part-4--the-viewer)
- [Część 5. Ustawienia](#part-5--settings)
- [Część 6. Ochrona](#part-6-security): [Hasło i szyfrowanie](#password-and-encryption) · [Touch ID](#touch-id) · [Fraza odzyskiwania](#recovery-phrase) · [Kopia zapasowa](#backup)
- [Część 7. Dla zaawansowanych](#part-7--advanced): [Automatyzacja](#automation-the-keepit-url-scheme) · [Aktualizacje](#updates) · [Odinstalowanie](#uninstalling)
- [Informacje pomocnicze](#reference): [Rozwiązywanie problemów](#troubleshooting) · [Ściąga ze skrótów klawiszowych](#keyboard-cheat-sheet) · [Ściąga z symboli zastępczych](#placeholder-cheat-sheet)

---

## Część 1. Pierwsze kroki

### Instalacja

**Homebrew.** Polecamy ten sposób, bo `brew upgrade` dba o aktualność aplikacji:

```bash
brew tap andrey-insarov/keepit https://github.com/andrey-insarov/Keepit
brew install --cask andrey-insarov/keepit/keepit
```

**DMG.** Pobierz `Keepit-<wersja>.dmg` z
[najnowszego wydania](https://github.com/andrey-insarov/Keepit/releases/latest), otwórz go
i przeciągnij Keepit do folderu *Aplikacje*.

![DMG: przeciągnij Keepit do folderu Aplikacje](site/img/guide/dmg.png)

Przy pierwszym otwarciu aplikacji macOS potwierdza, że pochodzi ona z Internetu i została
sprawdzona przez Apple. Kliknij *Otwórz*.

![Potwierdzenie Gatekeepera w macOS](site/img/guide/gatekeeper.png)

Keepit jest podpisany i poświadczony przez Apple, aktualizuje się sam i działa natywnie na Macach
z Apple silicon oraz z procesorem Intel, z systemem macOS 13 Ventura lub nowszym.

### Pierwsze uruchomienie

Keepit jest aplikacją paska menu: nie ma ikony w Docku ani okna, dopóki go nie otworzysz. Po
pierwszym uruchomieniu na pasku menu pojawia się ikona 📎, a Keepit pyta o trzy rzeczy.

**1. Przywrócić dane z kopii zapasowej?** Jeśli to nowy Mac i masz kopię zapasową Keepit
(automatyczną w iCloud Drive lub innym folderze albo wyeksportowany plik `.keepit`), polecenie
*Przywróć z kopii…* odtworzy historię i szablony, zanim wydarzy się cokolwiek innego. Plik
odblokujesz hasłem Maca, z którego pochodzi, albo jego frazą odzyskiwania. *Zacznij od nowa*
pomija ten krok. To samo przywracanie jest później dostępne w *Ustawienia → Kopia zapasowa →
Przywróć…*, a plik `.keepit` otworzysz też dwukrotnym kliknięciem w Finderze. Szczegóły znajdziesz
w rozdziale [Kopia zapasowa](#backup).

![Pierwsze pytanie na nowym Macu: przywrócić z kopii czy zacząć od nowa](site/img/guide/restore-first-run.png)

**2. Hasło (opcjonalnie).** Keepit może przechowywać historię i szablony w postaci zaszyfrowanej
i odblokowywać je przez Touch ID. Możesz zdecydować teraz albo później w *Ustawienia → Ochrona*;
[Część 6](#part-6-security) wyjaśnia, jak to działa. Po wybraniu *Nie teraz* wszystko pozostaje na
dysku niezaszyfrowane. Jeśli przed chwilą przywrócono kopię zapasową jej hasłem, Keepit zaproponuje
zachowanie tego hasła na tym Macu.

![Propozycja ustawienia hasła przy pierwszym uruchomieniu](site/img/guide/password-offer.png)

![Wybór Nie teraz: jasna informacja, co to oznacza i gdzie można to zmienić](site/img/guide/no-password-notice.png)

**3. Uprawnienie Dostępność.** Żeby wklejać za Ciebie, Keepit wysyła ⌘V do aplikacji, w której
pracujesz. macOS pozwala na to tylko aplikacjom wymienionym w *Ustawienia systemowe → Prywatność
i ochrona → Dostępność*. Kliknij *Otwórz Ustawienia systemowe* i włącz Keepit. Bez tego uprawnienia
Keepit nadal zapisuje i kopiuje, ale ⌘V naciskasz samodzielnie.

![Keepit prosi o uprawnienie Dostępność](site/img/guide/accessibility-prompt.png)

![Keepit włączony w Prywatność i ochrona → Dostępność](site/img/guide/accessibility-settings.png)

Keepit domyślnie uruchamia się przy logowaniu. Wyłączysz to w *Ustawienia → Ogólne*.

---

## Część 2. Codzienna praca

### Menu historii

Naciśnij **⌥M** w dowolnej aplikacji albo kliknij ikonę 📎. Menu otwiera się przy kursorze
tekstowym, jeśli Keepit potrafi go znaleźć, a w przeciwnym razie przy wskaźniku myszy.

Każdy wiersz to jeden skopiowany element, najnowsze są na górze. Najnowszy jest **pogrubiony**, bo
to on znajduje się teraz w schowku. Ikona pokazuje aplikację, z której kopiowano. Tytuł zakończony
znakiem `…` ma więcej wierszy, niż pokazuje menu. Obrazy mają miniaturę, a listy plików pokazują
nazwy plików.

![Panel podglądu obok menu pokazuje zaznaczony element w całości, z aplikacją źródłową, godziną i rozmiarem](site/img/guide/menu-preview.png)

![Obraz w historii: miniatura w menu, cały obraz w podglądzie](site/img/guide/menu-image.png)

Element wkleisz, klikając go, przechodząc do niego strzałkami ↑ ↓ i naciskając Return albo
naciskając jego numer z **⌃⌥**: `⌃⌥3` wkleja element 3. Ten sam klawisz działa wszędzie, bez
otwierania menu.

Pod historią znajdziesz podmenu *Szablony*, Przeglądarkę (⌥E), Ustawienia (⌥S), *Wyczyść historię*
(⌥C), *Wstrzymaj zapisywanie na 10 minut* (⌥P, gdy wpisujesz coś, czego nie chcesz zapisywać),
*Zablokuj Keepit* (⌥L), jeśli ustawiono hasło, oraz aktualizacje. **⌥T** otwiera samo menu
szablonów. Każdy z tych klawiszy działa też bez menu.

### Wyszukiwanie i podgląd

**Wyszukiwanie.** Gdy menu jest otwarte, zacznij pisać: pole u góry filtruje listę po tytule i po
pełnym tekście, więc znajdzie też wiersz ze środka długiego elementu. Return wkleja pierwsze
dopasowanie, Esc czyści pole, a drugie Esc zamyka menu.

**Podgląd.** Najedź na element (albo przejdź do niego klawiaturą), a panel obok menu pokaże cały
obraz albo pierwsze wiersze długiego tekstu razem z aplikacją źródłową, datą i rozmiarem. Krótkie
jednowierszowe teksty nie mają podglądu, bo wiersz menu pokazuje je już w całości.

![Pisanie filtruje menu; panel podglądu pokazuje zaznaczony element](site/img/guide/search-preview.png)

### Wklejanie bez menu

Globalne skróty klawiszowe działają na historii w jej bieżącym stanie (element 1 to schowek)
z dowolnej aplikacji:

| Klawisze | Co się dzieje |
|------|--------------|
| `⌃⌥1` … `⌃⌥9`, `⌃⌥0` | Wkleja element historii 1–10 |
| `⌥⇧V` | Wkleja *poprzedni* element (element 2); kolejne naciśnięcie zamienia je z powrotem |
| `⌃⌥V` | Wkleja schowek jako zwykły tekst, bez formatowania |
| `⌃⌥U` `⌃⌥L` `⌃⌥T` `⌃⌥S` | Wkleja schowek WIELKIMI LITERAMI / małymi literami / Każde Słowo Wielką / jak w zdaniu |
| `⌃⌥W` | Wkleja schowek bez białych znaków na początku i na końcu |
| `⌃⌥J` | Wkleja schowek połączony w jeden wiersz |
| `⌃⌥K` `⌃⌥D` `⌃⌥Y` | Wkleja schowek przekreślony / podkreślony / podkreślony wężykiem, jako zwykły tekst, który zachowuje wygląd wszędzie, także w czatach (zobacz niżej) |
| `⌃⌥X` | Wkleja schowek po usunięciu tych ozdobników |
| `⌃⌥A` | Dodaje schowek do Szablonów |
| `⌃⌥⌫` | Usuwa najnowszy element z historii |

Te trzy ozdobniki nie są formatowaniem: Keepit dodaje po każdym znaku *znak łączący* Unicode
(p̶r̶z̶e̶k̶r̶e̶ś̶l̶e̶n̶i̶e̶, p̲o̲d̲k̲r̲e̲ś̲l̲e̲n̲i̲e̲, w̰ę̰ż̰y̰k̰), więc tekst wygląda tak samo w komunikatorze,
w formularzu na stronie i w terminalu, gdzie prawdziwe formatowanie by przepadło. Ma to swoją cenę:
taki tekst jest trzy razy większy, wyszukiwanie zwykłego słowa go nie znajdzie, czytniki ekranu się
na nim potykają, a niektóre czcionki rysują linię nierówno. *Usuń ozdobniki* (`⌃⌥X`) zdejmuje te
znaki, także z tekstu ozdobionego gdzie indziej. W obu kierunkach znaki są usuwane według punktu
kodowego, niezależnie od ich pochodzenia: transkrypcja fonetyczna, która używa tych samych znaków
jako liter (U+0330 jest w IPA także oznaczeniem fonacji skrzypiącej), straci je, a trzy ozdobniki
również najpierw je usuwają. Przy włączonym VoiceOver `⌃⌥` jest modyfikatorem samego VoiceOver:
przypisz opcji *Działania na najnowszym elemencie* inny w Ustawienia → Skróty.

Przekształcenia dotyczą tekstu; przy obrazie albo liście plików klawisz wydaje tylko sygnał
dźwiękowy. Wszystko to można zmienić albo wyłączyć w *Ustawienia → Skróty*.

### Kolejka wklejania

Czasem trzeba skopiować pięć rzeczy z jednego miejsca i wkleić je po kolei w innym: komórki do
formularza, wiersze ze strony do dokumentu. Kolejka wklejania robi to bez menu:

1. Naciśnij **⌥N** (albo wybierz *Włącz kolejkę wklejania* w menu). Ikona na pasku menu pokazuje
   czerwoną kropkę i licznik: `📎 ● 0`.
2. Kopiuj jak zwykle przez ⌘C, ile razy chcesz. Licznik rośnie z każdym kopiowaniem: 1, 2, 3…
   Wszystko trafia również do historii.

   ![Pasek menu przy włączonej kolejce: czerwona kropka i licznik](site/img/guide/queue-menubar.png)

3. Przejdź tam, gdzie ma trafić tekst, i dla każdego elementu naciśnij **⌥V**. Jako pierwsze
   wkleja się to, co skopiowano jako pierwsze, a licznik maleje. ⌘V nadal wkleja schowek jak
   zwykle, więc można łączyć oba sposoby.
4. Kolejka wyłącza się sama po wklejeniu ostatniego elementu albo po dwóch minutach bez kopiowania
   i wklejania (czas można zmienić). Ponowne ⌥N kończy ją wcześniej.

**⌥⇧N** wkleja naraz wszystko, co jeszcze zostało w kolejce. Elementy są łączone znakiem nowego
wiersza, tabulatorem, spacją albo niczym; wybierzesz to w panelu *Kolejka wklejania* w Ustawieniach,
gdzie ustawia się także czas bezczynności. Dopóki kolejka jest włączona, menu historii oznacza jej
elementy: `▶` wklei się jako następny, `○` czeka w kolejce, `✓` został już wklejony.

![Menu historii przy włączonej kolejce: ○ w kolejce, ▶ następny, ✓ wklejony; wiersz menu pokazuje, ile zostało](site/img/guide/queue-menu.png)

![Ustawienia → Kolejka wklejania](site/img/guide/prefs-queue.png)

### Menu rozszerzone

Gdy menu historii jest otwarte, przytrzymaj **⇧**, a każdy element dostanie podmenu `▸` ze
wszystkimi działaniami dla tego elementu: Wklej, Wklej jako zwykły tekst, Tylko kopiuj (do schowka,
bez wklejania), przekształcenia *Wklej jako*, Dodaj do Szablonów, Pokaż w Przeglądarce, Usuń.
Podmenu otworzysz, wskazując element albo naciskając →; gdy jest już otwarte, możesz puścić ⇧.

![Przytrzymaj ⇧: każdy element dostaje podmenu; przy najnowszym widać w nim globalne skróty klawiszowe](site/img/guide/extended-menu.png)

Przy najnowszym elemencie podmenu wymienia globalne skróty klawiszowe z tabeli powyżej. To te same
działania z tymi samymi klawiszami, więc można się ich tu nauczyć. Pozostałe elementy pokazują
działania bez klawiszy: skrót albo działa wszędzie, albo nie jest pokazywany.

![Przy pozostałych elementach: te same działania, bez skrótów](site/img/guide/extended-menu-item2.png)

![Przy obrazie działania tekstowe są wyszarzone; dostępne są tylko Wklej, Tylko kopiuj, Dodaj do Szablonów, Pokaż w Przeglądarce i Usuń](site/img/guide/extended-menu-image.png)

---

## Część 3. Szablony

Szablony to elementy, które zostają na stałe: podpisy, adresy, gotowe odpowiedzi, fragmenty kodu,
logo, które często wklejasz. Leżą w drzewie z folderami i pojawiają się w podmenu *Szablony* menu
historii oraz pod **⌥T**. Świeża instalacja zawiera folder *Przykłady* (powitanie, dzisiejszą datę,
cytat ze schowka i podpis), żeby pokazać, co potrafią szablony, zanim napiszesz własne. Możesz je
dowolnie usuwać i edytować. Przykładowe szablony przywraca *Ustawienia → Zaawansowane → Reset
i odinstalowanie → Resetuj…*; to polecenie resetuje jednak także pozostałe dane i ustawienia.

![Folder Przykłady: po najechaniu na element widać jego tekst](site/img/guide/template-examples.png)

![Menu szablonów: foldery otwierają się jako podmenu, litery po znaku & stają się skrótami](site/img/guide/template-menu-letters.png)

### Tworzenie i porządkowanie

**Dodawanie szablonu**

- Z menu historii: `⌃⌥A` dla najnowszego elementu, *Dodaj schowek do szablonów* na dole albo
  ⇧ → podmenu elementu → *Dodaj do Szablonów* dla dowolnego elementu.
- W Przeglądarce: zaznacz element historii i kliknij *Dodaj do szablonów* albo przeciągnij go do
  drzewa Szablony. *Nowy element* tworzy pusty szablon tekstowy; *Nowy element z pliku* (menu
  kontekstowe) tworzy go z pliku tekstowego lub obrazu.

**Porządkowanie**

- *Nowy folder* tworzy folder. Elementy przeciągaj między folderami albo użyj *W górę* / *W dół*
  z menu kontekstowego.
- Szablon o nazwie `-` staje się w menu linią oddzielającą.
- Znak `&` przed literą w nazwie, na przykład `&Podpis`, robi z tej litery skrót elementu w menu
  szablonów: przy otwartym menu naciśnij `P`.
- *Ustaw skrót klawiszowy* z menu kontekstowego nadaje szablonowi własny globalny skrót.
- Szablon bez nazwy pokazuje swój pierwszy wiersz. *Zmień nazwę* i *Wyczyść nazwę* są w menu
  kontekstowym; możesz też edytować pole *Nazwa* nad tekstem.

### Symbole zastępcze

Szablony tekstowe mogą zawierać symbole zastępcze `{…}`, które są wypełniane w chwili wklejania.
Cała reszta wkleja się bez zmian. W Przeglądarce **Wstaw ▾** pokazuje listę wszystkich symboli
i umieszcza wybrany w miejscu kursora, więc niczego nie trzeba pamiętać.

![Przykład Dzisiejsza data: `{date:EEEE, d MMMM yyyy}` przy wklejaniu zamienia się w bieżącą datę](site/img/guide/template-examples-date.png)

![Wstaw ▾ w Przeglądarce pokazuje wszystkie symbole zastępcze](site/img/guide/insert-menu.png)

Najbardziej przydatne:

| Symbol zastępczy | Wynik |
|-------------|--------|
| `{date}` `{time}` `{datetime}` | Dzisiejsza data / bieżąca godzina, format systemowy |
| `{date:yyyy-MM-dd}` | Dowolny format (`yyyy MM dd EEEE HH mm …`) |
| `{date:long}` `{time:short}` `{datetime:medium}` | Styl nazwany: `short` `medium` `long` `full` |
| `{date+7d}` `{date-1m:MMMM}` `{time+1h}` `{date+1y-2d}` | Przesunięcie: `d` dni, `w` tygodnie, `m` miesiące, `y` lata, `h` godziny; dla `date`, `time`, `datetime`, także kilka pod rząd |
| `{clipboard}` `{clipboard:2}` | Schowek albo element historii N |
| `{clipboard\|upper}` `{clipboard\|trim\|oneline}` | Filtry `upper` `lower` `title` `trim` `oneline` `url`, można je łączyć |
| `{cursor}` | Miejsce, w którym po wklejeniu znajdzie się kursor tekstowy |
| `{user}` `{username}` `{host}` | Imię i nazwisko, nazwa konta, nazwa komputera |
| `{uuid}` `{random:1-100}` | Nowy UUID; liczba losowa |
| `{{` `}}` | Dosłowne nawiasy klamrowe: szablon `{{"x":1}}` wkleja `{"x":1}` |

Nazwy symboli zastępczych pisze się małymi literami: `{date}` jest symbolem, natomiast `{Date}`
i `{DATE}` to tekst, który wkleja się bez zmian. Nazwy stylów i filtry (`{date:LONG}`,
`{clipboard|UPPER}`) można pisać dowolnie.

Pełna lista znajduje się w [ściądze z symboli zastępczych](#placeholder-cheat-sheet).

### Szablony, które zadają pytania

`{input:Imię}` i `{choice:Etykieta=A|B|C}` zamieniają szablon w mały formularz: gdy go wklejasz,
Keepit najpierw pyta o wartości, a potem wkleja gotowy tekst. O tę samą nazwę pyta tylko raz,
niezależnie od tego, ile razy występuje; `{input:Imię=Domyślne}` wstępnie wypełnia pole.

![Wklejenie szablonu z {input:Name} najpierw pyta o wartość](site/img/guide/input-dialog.png)

Na przykład szablon odpowiedzi:

```
Dzień dobry, {input:Imię},

dziękuję za wiadomość z {date-1d}. Odezwę się do {date+3d:d MMMM}.
{cursor}
{user}
```

Przy wklejaniu Keepit pyta o *Imię*, uzupełnia daty, podpisuje Twoim imieniem i nazwiskiem
i zostawia kursor w pustym wierszu.

---

## Część 4. Przeglądarka

*Przeglądarka…* w menu albo kliknięcie ikony 📎 prawym przyciskiem otwiera okno z trzema drzewami:
**Schowek** (bieżąca zawartość schowka, tylko do odczytu), **Historia** (*Tekst i pliki* oraz
*Obrazy*) i **Szablony**.

![Przeglądarka z zaznaczonym szablonem](site/img/guide/viewer.png)

- Zaznacz element, żeby zobaczyć go po prawej. Tekst można edytować na miejscu, a zmiany są
  zapisywane po opuszczeniu edytora. Obraz jest pokazywany w skali dopasowanej do panelu, nad nim
  widać jego wymiary w pikselach i rozmiar pliku. Listy plików otwierają plik dwukrotnym
  kliknięciem. *Pokaż jako zrzut szesnastkowy* z menu kontekstowego pokazuje surowe bajty.
- Pasek narzędzi: *Wyślij do schowka*, *Wklej* (do aplikacji, z której otwarto Przeglądarkę), *Dodaj do
  szablonów*, *Nowy element*, *Nowy folder*, *Usuń*, *Wstaw ▾* (symbole zastępcze) oraz **?**,
  czyli ten podręcznik.
- **Szukaj** (`⌘F`): pole po lewej filtruje historię i szablony po nazwie i treści oraz wyróżnia
  dopasowanie.
- Elementy historii zachowasz, przeciągając je do drzewa Szablony, a szablony skopiujesz
  z powrotem, przeciągając je do Historii. Kolejność zmienisz przeciąganiem albo poleceniami
  *W górę* / *W dół*. ⌫ usuwa zaznaczony element.
- Pasek stanu pokazuje datę, aplikację źródłową, format i rozmiar.

![Wyszukiwanie w Przeglądarce wyróżnia dopasowania](site/img/guide/viewer-search.png)

---

## Część 5. Ustawienia

`⌘,` w menu, *Ustawienia…* albo ⌥S z dowolnej aplikacji. Okno działa tak, jak okna ustawień na
Macu: wybierz panel na pasku narzędzi, a każda zmiana obowiązuje od razu. Nie ma przycisku Zapisz;
okno zamkniesz przez ⌘W albo Esc. Każda opcja z **?** obok ma dymek z wyjaśnieniem.

![Ustawienia → Ogólne](site/img/guide/prefs-general.png)

| Panel | Co tam jest |
|-----|---------------|
| **Ogólne** | Uruchamianie przy logowaniu · zapisywanie historii przy zakończeniu i przywracanie jej przy starcie · wklejanie po wybraniu (wyłączone = tylko kopiowanie) · opóźnienie wklejania, które warto zwiększyć dla aplikacji wolno wychodzących na pierwszy plan · otwieranie menu przy kursorze tekstowym · Aktualizacje: *Automatycznie sprawdzaj aktualizacje* (wersja pobierana ze strony; wyłączone = żadnego zapytania sieciowego), zobacz [Aktualizacje](#updates) |
| **Skróty** | Wszystkie globalne skróty w jednym miejscu, zobacz niżej |
| **Kolejka wklejania** | Trzy klawisze kolejki, czas bezczynności, po którym kolejka się wyłącza, oraz to, co wstawiać między elementami przy poleceniu *Wklej całą resztę*, zobacz [Kolejka wklejania](#the-paste-queue) |
| **Historia** | Ile elementów tekstowych i plikowych oraz ile obrazów przechowywać (1000 / 30) · zapominanie elementów starszych niż … · *Usuwaj duplikaty* (ponowne skopiowanie tego samego przenosi element na górę) · *Ignoruj ukryte dane schowka* · lista ignorowanych aplikacji (identyfikatory pakietów; menedżery haseł są ignorowane zawsze) |
| **Menu** | Pole wyszukiwania · numeracja · panel podglądu · podpowiedzi · ikony aplikacji źródłowych · miniatury obrazów · elementy w menu (ile najnowszych wpisów pokazuje menu, domyślnie 60; pozostałe nadal można wyszukać) · długość tytułu · wysokość miniatur |
| **Ochrona** | Hasło, Touch ID, blokowanie, fraza odzyskiwania, zobacz [Część 6](#part-6-security) |
| **Kopia zapasowa** | Automatyczna kopia zapasowa (wiersz stanu obok nagłówka): *Automatycznie twórz kopie w folderze*, nazwa Maca w plikach, folder, ile kopii zachować · Kopia ręczna: *Utwórz kopię teraz*, *Zapisz archiwum…* · Przywracanie: *Przywróć…*, zobacz [Kopia zapasowa](#backup) |
| **Zaawansowane** | Interwał odpytywania schowka · Automatyzacja: *Zezwalaj na polecenia URL keepit://* (domyślnie wyłączone, zobacz [Automatyzacja](#automation-the-keepit-url-scheme)) · Dane: *Otwórz folder* · Reset i odinstalowanie: *Resetuj…* (powrót do stanu świeżej instalacji, wracają przykładowe szablony) · *Odinstaluj…* (reset, a potem usunięcie aplikacji, uruchamiania przy logowaniu, wpisu w pęku kluczy i uprawnień) |

![Ustawienia → Historia: limity i lista ignorowanych aplikacji](site/img/guide/prefs-history.png)

![Ustawienia → Skróty](site/img/guide/prefs-hotkeys.png)

W panelu **Skróty** kliknij pole i naciśnij kombinację; ⌫ wyłącza klawisz. Kombinacja używana już
przez inne polecenie jest odrzucana, a powód pojawia się pod polami. *Przywróć domyślne* przywraca
zestaw ⌥ + litera (⌥M historia, ⌥T szablony, ⌥E Przeglądarka, ⌥S Ustawienia, ⌥C Wyczyść historię,
⌥P wstrzymanie, ⌥L blokada, ⌥Q zakończenie), ⌥⇧V i ⌃⌥. Opcje *Wklej element według numeru*
i *Działania na najnowszym elemencie* przyjmują tylko modyfikatory, a cyfrę lub literę dodaje
Keepit. Jeśli któryś skrót należy już do macOS albo innej aplikacji, Keepit informuje o tym przy
starcie. *Przeglądarka* ⌥E, *Ustawienia* ⌥S, *Wyczyść historię* ⌥C, *Wstrzymaj nagrywanie* ⌥P,
*Zablokuj Keepit* ⌥L i *Zakończ Keepit* ⌥Q działają z dowolnej aplikacji i są pokazane w menu obok
swoich poleceń. W układzie amerykańskim ⌥ + litera zwykle wpisuje znak specjalny (⌥S = ß, ⌥C = ç …);
jeśli któregoś z nich potrzebujesz, przenieś skrót na inny klawisz. Keepit odczytuje też twoje układy klawiatury: litery pokazywane w Ustawieniach i w menu są literami klawiszy układu, którego właśnie używasz, a domyślny skrót, który zabrałby znak potrzebny w twoim układzie (⌥L wpisuje @ w układzie niemieckim, ł w polskim), Keepit zostawia wolny przy uruchomieniu — mówi o tym notatka pod jego polem; kliknij pole i naciśnij kombinację, aby mimo to jej użyć.

---

## Część 6. Ochrona

### Hasło i szyfrowanie

*Ustawienia → Ochrona → Wymagaj hasła przy uruchomieniu* szyfruje historię i szablony algorytmem
AES-256-GCM. Klucz jest wyprowadzany z Twojego hasła (PBKDF2, 200 000 iteracji) i istnieje tylko
w pamięci. Jest z niej usuwany, gdy Keepit się blokuje: po wybraniu *Zablokuj Keepit* (`⌥L`), przy
zakończeniu i opcjonalnie po tym, jak Mac przez pewien czas był zablokowany lub uśpiony.
*Automatyczna blokada Keepit* ma w nowej instalacji wartość **Nigdy** (aktualizacja z wersji 3.0.3
zachowuje dawny wybór, czyli *Natychmiast*, jeśli pole blokowania razem z ekranem było zaznaczone):
z menedżera schowka, który prosi o hasło po każdej przerwie na kawę, przestaje się korzystać, a na
ważne chwile jest `⌥L`. *Natychmiast* blokuje razem z ekranem. Opcje *Po 5 minutach*,
*Po 15 minutach* i *Po 1 godzinie* nie reagują na krótką nieobecność (Keepit pozostaje odblokowany
i dalej zapisuje) i blokują dopiero wtedy, gdy Mac przez cały ustawiony czas pozostawał zablokowany lub uśpiony. To samo dotyczy
sytuacji, gdy Keepit uruchamia się, kiedy Mac jest już zablokowany albo na pierwszym planie jest
sesja innego użytkownika (na przykład ponowne uruchomienie po aktualizacji): nieobecność liczy się
od startu, o ile macOS zgłasza ten stan Keepit (zwykle tak; gdy nie może, odliczanie zaczyna się
przy następnym zablokowaniu lub uśpieniu). Przy włączonym Touch ID Keepit prosi o dotknięcie
w chwili odblokowania Maca, więc jest gotowy przed pierwszym `⌥M`.

![Ustawianie hasła za pomocą klawiatury ekranowej. To zdjęcie ekranu, a nie zrzut: na Macu autora zrzut tej sceny pokazuje sam dialog](site/img/guide/set-password-keyboard.jpg)

Okna dialogowe hasła pokazują bieżący układ klawiatury i ostrzegają o Caps Locku, więc odrzucone
hasło rzadko jest zagadką. Przycisk z klawiaturą obok pola otwiera **klawiaturę ekranową** do
wpisywania hasła myszą: kliknięcia nigdy nie przechodzą przez system jako naciśnięcia klawiszy,
klawisze są tasowane przy każdym otwarciu, a klawiatura prosi macOS, żeby nie trafiała na zrzuty
ani nagrania ekranu (w niektórych konfiguracjach jest z nich wykluczana; nie ma na to gwarancji).
Przydaje się na Macu, któremu nie ufasz w pełni, albo takim, którego ekran jest udostępniany. Przy
uruchomieniu i po zablokowaniu Keepit prosi o hasło (albo Touch ID); *Odzyskaj dostęp…* przyjmuje
zamiast niego frazę z 24 wyrazów, zobacz [Fraza odzyskiwania](#recovery-phrase).

![Odblokowywanie przy uruchomieniu: hasło, Zakończ albo fraza odzyskiwania; OK pozostaje nieaktywne, dopóki czegoś nie wpiszesz. Sfotografowane z tego samego powodu co wyżej](site/img/guide/unlock-keyboard.jpg)

![Ustawienia → Ochrona](site/img/guide/prefs-security.png)

### Touch ID

Przy włączonej opcji *Odblokowuj przez Touch ID* klucz jest przechowywany także w Secure Enclave za
Twoim odciskiem palca: Keepit prosi o dotknięcie zamiast o hasło. Hasło nadal działa jako
rozwiązanie zapasowe, wystarczy wybrać *Użyj hasła* w monicie. Przy zamkniętej pokrywie
i zewnętrznej klawiaturze Magic Keyboard z Touch ID Keepit pyta na klawiaturze. *Zezwalaj na zmianę
hasła przez Touch ID* pozwala, żeby przy zmianie hasła odcisk palca zastąpił stare hasło.

![Odblokowywanie przez Touch ID; hasło pozostaje rozwiązaniem zapasowym](site/img/guide/touch-id.png)

### Fraza odzyskiwania

Gdy ustawiasz hasło, Keepit jeden raz pokazuje frazę z 24 wyrazów. Wydrukuj ją albo zapisz
w menedżerze haseł. Jeśli zapomnisz hasła, *Odzyskaj dostęp…* w oknie odblokowywania otworzy dane
i pozwoli ustawić nowe. *Fraza odzyskiwania → Utwórz nową…* wydaje nową frazę i unieważnia starą;
*Pokaż…* obok ponownie pokazuje bieżącą frazę po potwierdzeniu przez Touch ID albo hasłem.

Bez hasła, Touch ID na tym samym Macu ani frazy danych nie da się odzyskać: nie ma serwera i nie ma
czego resetować.

![Fraza odzyskiwania z 24 wyrazów (wyrazy są tu ukryte)](site/img/guide/recovery-phrase.png)

### Kopia zapasowa

Keepit może przechowywać zaszyfrowaną kopię historii i szablonów w wybranym przez Ciebie folderze
(iCloud Drive, Dropbox, Google Drive, dysk zewnętrzny, NAS) i zapisywać nową, gdy tylko coś się
zmieni. Serwera Keepit nie ma: folder należy do Ciebie. Dostawca, który za nim stoi, widzi
zaszyfrowany plik, jego rozmiar i mały niezaszyfrowany nagłówek (kiedy i przez którą wersję Keepit
plik został zapisany, jak wyprowadzany jest klucz, losowe identyfikatory oraz nazwę Twojego Maca,
ale tylko wtedy, gdy to włączysz); [strona o bezpieczeństwie](/security#backups) (po angielsku)
opisuje go pole po polu.

![Ustawienia → Kopia zapasowa: kopia automatyczna, kopia ręczna, przywracanie](site/img/guide/prefs-backup.png)

**Włączanie.** *Ustawienia → Kopia zapasowa → Automatycznie twórz kopie w folderze*, a potem
*Wybierz…* folder (okno wyboru otwiera się w iCloud Drive). Automatyczna kopia zapasowa wymaga
ochrony hasłem z *Ustawienia → Ochrona*: każda kopia jest zapieczętowana kluczem wyprowadzonym
z klucza Twojego sejfu, więc otworzysz ją swoim hasłem Keepit albo frazą odzyskiwania na tym Macu
i na każdym innym, i niczego nie trzeba w tym celu konfigurować. Bez hasła pole wyboru jest
nieaktywne i informuje o przyczynie.

**Co dzieje się potem: harmonogram.** Mniej więcej pięć minut po ostatniej zmianie (i co najmniej
raz dziennie, dopóki Keepit działa) Keepit zapisuje w folderze plik o nazwie
`Keepit-<data i godzina>-<instalacja>-<id>.keepit`, odczytuje go, żeby go sprawdzić, i dopiero
potem usuwa najstarsze ze swoich kopii ponad liczbę *Zachowaj ostatnie* (domyślnie 10, zakres
1–100). Każda kopia jest kompletna sama w sobie, to nie przyrost, więc zawsze wystarczy jeden plik.
Kopii zrobionych przez innego Maca ani plików, które tam umieścisz, Keepit nigdy nie rusza: dwa
Maki korzystające z jednego folderu zapisują dwie niezależne serie. Wiersz stanu obok nagłówka
*Automatyczna kopia zapasowa* pokazuje godzinę i rozmiar ostatniej kopii albo powód, dla którego
ostatnia próba się nie udała. Gdy Keepit jest zablokowany, nic się nie dzieje; *Utwórz kopię teraz*
(w sekcji *Kopia ręczna*) nie czeka na okres spokoju.

**Dołączaj nazwę tego Maca** (domyślnie wyłączone) umieszcza nazwę komputera w niezaszyfrowanym
nagłówku każdego pliku, dzięki czemu dwie serie w jednym folderze łatwo odróżnić w Finderze.
Dostawca przechowywania widzi tę nazwę i dlatego opcja jest dobrowolna.

**Przywracanie.** *Przywróć…* otwiera kopię zapasową (z tego Maca, z innego Maca albo
wyeksportowany plik) po jej odblokowaniu: hasłem Maca, na którym powstała, albo frazą odzyskiwania,
którą ten Mac pokazał przy ustawianiu hasła (*Odzyskaj dostęp…* w oknie hasła). Podgląd pokazuje,
kiedy i gdzie plik powstał oraz ile elementów zawiera. Potem masz dwie możliwości:

![Podgląd przywracania: kiedy i przez którą wersję Keepit plik został zapisany, co zawiera, Scal albo Zastąp](site/img/guide/restore-preview.png)

- *Scal* dodaje to, czego jeszcze nie ma: elementy historii według treści, a szablony z kopii jako
  jeden nowy folder o nazwie *Import <data>*, bez ich skrótów klawiszowych. Widać dzięki temu
  dokładnie, co pochodzi z kopii, i można to przenieść albo usunąć. Nic z Twoich danych nie
  zostanie nadpisane.
- *Zastąp* odrzuca bieżącą historię i szablony i bierze w ich miejsce te z kopii. Wcześniej Keepit
  zapisuje kopię tego, co masz teraz (`Keepit-before-restore-…`), w folderze kopii zapasowych albo
  w folderze, który wskażesz; jeśli tej kopii nie da się zapisać, zastępowanie się nie rozpocznie.
  Jeśli Keepit nie ma jeszcze hasła, zapyta o hasło dla tej kopii, tak jak przy *Zapisz
  archiwum…*.

*Przywróć też preferencje* przenosi z kopii skróty klawiszowe, limity i opcje. Ustawienia, które
wyrażają zaufanie do konkretnego Maca (Touch ID, automatyzacja przez URL i jej zaufane aplikacje,
sam folder kopii zapasowych), zawsze pozostają takie, jakie są tutaj. Jeśli historia z kopii jest
większa, niż pozwalają limity tego Maca, Keepit przed potwierdzeniem informuje, ile się zmieści.

Kopia przywrócona jej frazą odzyskiwania na Macu, który nie ma jeszcze hasła? Keepit prosi
o wcześniejsze ustawienie hasła, żeby przywrócone dane nigdy nie trafiły na dysk niezaszyfrowane,
i pozwala zachować tę frazę dla tego Maca albo otrzymać nową. Kopia przywrócona hasłem? Keepit
proponuje zachowanie go jako hasła tego Maca. W obu przypadkach sama automatyczna kopia zapasowa
jest ustawieniem osobnym dla każdego Maca: włącz ją tutaj i wybierz folder (może być ten sam),
a ten Mac zacznie własną serię plików obok plików starego Maca.

**Przeprowadzka na nowego Maca** to główny cel tego wszystkiego: zainstaluj Keepit, przy pierwszym
uruchomieniu wybierz *Przywróć z kopii…*, wskaż najnowszy plik w swoim folderze, wpisz hasło
starego Maca i wybierz *Zastąp*; potem włącz automatyczną kopię zapasową na nowym Macu. Dotychczasowe
kopie otwierają się hasłem i frazą, które obowiązywały w chwili ich zapisu: po zmianie hasła stare
kopie nadal wymagają starego hasła.

**Kopia ręczna.** Są tu dwa przyciski i każdy robi coś innego. *Utwórz kopię teraz* od razu tworzy
kopię taką jak automatyczna: ten sam rodzaj pliku, ten sam folder i ta sama seria, otwierana Twoim
hasłem Keepit albo frazą. *Zapisz archiwum…* zapisuje jedno *archiwum* `.keepit` we wskazanym
miejscu i blokuje je hasłem, które dla niego wybierzesz. Nie wymaga ochrony Keepit hasłem, a Keepit
nie śledzi potem tego pliku. Przydaje się do przekazania danych albo jako kopia poza folderem kopii
zapasowych. Proponowana nazwa mówi, co to jest: `Keepit-archive-<data>-manual.keepit`, obok
automatycznych kopii `Keepit-<data i godzina>-<instalacja>-<id>.keepit`.

![Zapisz archiwum…: w nazwie pliku są słowa archive i manual](site/img/guide/save-to-archive.png)

![Własne hasło archiwum ze wskaźnikiem siły: nie jest nigdzie zapisywane](site/img/guide/archive-password.png)

*Przywróć…* otwiera oba rodzaje. Archiwum zastępuje *Eksportuj…* / *Importuj…* z wersji 2.x. Plik
przenosi dane między wersją pobieraną ze strony a wersją z App Store oraz między Keepit 2.x a 3.x:
plik zapisany przez wersję 3.0 otworzy tylko wersja 3.0 lub nowsza; wersja 3.0 odczytuje wszystko,
co zapisała 2.x.

**Gdy coś pójdzie nie tak.** Nieudana kopia jest zgłaszana w wierszu stanu, a próba jest
ponawiana z coraz dłuższymi przerwami; poprzednie kopie zostają. Jeśli Keepit został zakończony
albo Mac się wyłączył w trakcie przywracania, następne uruchomienie po cichu przywraca wszystko do
stanu sprzed przywracania. W rzadkim przypadku, gdy to niemożliwe (plik, którego nie da się
zapisać, pełny dysk), Keepit podaje nazwę pliku i kończy działanie, niczego nie zmieniając: napraw
plik i uruchom Keepit ponownie. Szczegóły, w tym budowa formatu pliku od środka, są na
[stronie o bezpieczeństwie](/security#backups) (po angielsku).

---

## Część 7. Dla zaawansowanych

### Automatyzacja: schemat URL keepit://

Skróty (*Otwórz adresy URL*), Raycast, Alfred, Keyboard Maestro albo polecenie `open` w powłoce mogą
sterować Keepit, **gdy to włączysz** w *Ustawienia → Zaawansowane → Automatyzacja → Zezwalaj na
polecenia URL keepit://*. Domyślnie jest to wyłączone, bo URL może otworzyć dowolna aplikacja albo
strona internetowa, a `add` / `paste` zmieniają schowek i piszą w aplikacji na pierwszym planie;
przy wyłączonej opcji Keepit ignoruje takie adresy i wydaje sygnał dźwiękowy. Przy włączonej opcji
Keepit sprawdza, kto otworzył URL: pierwsze polecenie z danej aplikacji, które coś zmienia (`paste`,
`copy`, `template`, `add`, `add-template`, `pause`, `resume`), jest pokazywane w oknie dialogowym.
*Zezwól* wykonuje je jeden raz, *Zawsze zezwalaj* dodaje aplikację do listy zaufanych (wyczyścisz ją
poleceniem *Zapomnij zaufane aplikacje* w tym samym panelu). Przeglądarka internetowa albo nadawca,
którego macOS nie potrafi nazwać, są pytani za każdym razem. Polecenia, które tylko otwierają
własne okna Keepit, nigdy nie pytają.

| URL | Efekt |
|-----|--------|
| `keepit://paste/2`<br>`keepit://paste/latest`<br>`keepit://paste/previous` | Wkleja element historii N (albo najnowszy / poprzedni) do aplikacji na pierwszym planie |
| `keepit://copy/3` | Umieszcza element N w schowku bez wklejania |
| `keepit://template/Signature`<br>`keepit://template/Work/Reply?copy=1` | Wkleja (albo kopiuje) szablon według nazwy albo ścieżki folderu |
| `keepit://add?text=…` | Dodaje tekst do historii i do schowka |
| `keepit://add-template?text=…&name=…` | Tworzy szablon |
| `keepit://history`<br>`keepit://templates`<br>`keepit://viewer`<br>`keepit://settings` | Otwiera menu historii, menu szablonów, Przeglądarkę, Ustawienia |
| `keepit://pause`<br>`keepit://resume` | Wstrzymuje zapisywanie na 10 minut / wznawia je |

Tekst koduj procentowo (`%20` zamiast spacji). Gdy Keepit jest zablokowany, adresy URL są
ignorowane.

### Aktualizacje

Keepit raz dziennie sprawdza GitHub Releases i proponuje aktualizacje w oknie dialogowym; *Sprawdź
uaktualnienia…* robi to od razu. Aktualizacje są podpisane (EdDSA) i poświadczone przez Apple.
W Homebrew to samo robi `brew upgrade --cask keepit`. Sumy kontrolne wszystkich pobieranych plików
są w `SHA256SUMS` na stronie wydania.

To sprawdzanie jest jedynym zapytaniem sieciowym, jakie wysyła Keepit, i jest opcjonalne:
*Ustawienia → Ogólne → Aktualizacje → Automatycznie sprawdzaj aktualizacje*. Po wyłączeniu Keepit
z niczym się nie łączy, nawet na Twoją prośbę, a *Sprawdź uaktualnienia…* znika z menu. Aktualizujesz
wtedy, pobierając aplikację z [keep.it.com](https://keep.it.com) albo przez Homebrew. Wersja z App
Store nie ma aktualizatora ani takiej opcji; aktualizuje ją App Store.

### Odinstalowanie

*Ustawienia → Zaawansowane → Reset i odinstalowanie → Odinstaluj…* usuwa aplikację, folder
z danymi, wpisy w pęku kluczy (w tym klucz Touch ID), rzecz otwieraną przy logowaniu i wpis
w Dostępności. Prosi o hasło albo Touch ID, wpisanie słowa `DELETE` i potwierdzenie. Jeśli dane
mogą się jeszcze przydać, najpierw wyeksportuj kopię zapasową. W Homebrew uruchom potem
`brew uninstall --cask --force keepit`, żeby Homebrew zapomniał o tym casku.

![Ustawienia → Zaawansowane](site/img/guide/prefs-advanced.png)

---

## Informacje pomocnicze

### Rozwiązywanie problemów

**Po wybraniu elementu nic się nie wkleja.** Brakuje uprawnienia Dostępność: *Ustawienia systemowe
→ Prywatność i ochrona → Dostępność → Keepit*. Jeśli Keepit jest na liście, a mimo to nie wkleja,
wyłącz go i włącz ponownie. macOS zapomina przyznane uprawnienie po ponownej instalacji aplikacji.

**Skrót klawiszowy nic nie robi.** Należy do innej aplikacji albo do macOS; Keepit zgłasza to przy
uruchomieniu. Wybierz inną kombinację w panelu *Skróty*. Kombinacja ⌃⌥ z cyframi i literami jest
wolna na Macu w stanie fabrycznym. Albo jest to domyślny skrót, który Keepit zostawił wolny, bo w jednym z twoich układów klawiatury wpisuje znak; mówi o tym notatka pod jego polem w panelu *Skróty*. Wybierz inną kombinację albo kliknij pole i naciśnij tę samą, aby mimo to jej użyć.

**Menu otwiera się w złym miejscu.** Aplikacja, w której jesteś, nie udostępnia swojego kursora
tekstowego, więc menu otwiera się przy wskaźniku myszy. Opcja *Otwieraj menu przy kursorze
tekstowym, gdy to możliwe* w panelu Ogólne wyłącza szukanie kursora, jeśli wolisz zawsze wskaźnik.

**Brakuje czegoś, co zostało skopiowane.** Nie jest zapisywane nic, co aplikacja źródłowa oznaczyła
jako ukryte, ani kopia zrobiona wtedy, gdy na pierwszym planie był menedżer haseł (wbudowana lista)
albo aplikacja z Twojej listy ignorowanych, łącznie z aplikacją, z której przed chwilą przełączono
się gdzie indziej. Zobacz *Ustawienia → Historia* oraz
[stronę o bezpieczeństwie](/security#what-is-not-recorded) (po angielsku).

**Touch ID nie jest proponowane.** W tej chwili żaden czujnik Touch ID nie jest dostępny (zamknięta
pokrywa, brak klawiatury z Touch ID). Keepit zachowuje ustawienie i poprosi o odcisk palca, gdy
tylko czujnik będzie dostępny.

**Stan kopii zapasowej informuje, że folder jest niedostępny.** Folder został przeniesiony,
otrzymał inną nazwę, został odmontowany albo (iCloud Drive) usunięty z pamięci lokalnej. Zamontuj
go albo przywróć, a następna kopia się powiedzie; możesz też użyć *Wybierz…* i wskazać nowy folder.
Nowy folder zaczyna nową serię, a stare pliki zostają tam, gdzie są.

**Pliku kopii zapasowej nie da się otworzyć.** *Błędne hasło* oznacza, że nie zgadzał się znacznik
uwierzytelniający pliku: upewnij się, że używasz hasła Maca, który ten plik *zapisał* (po zmianie
hasła stare kopie nadal otwierają się starym hasłem), albo jego frazy odzyskiwania. *Ta kopia
zapasowa wymaga Keepit 3.0 lub nowszego* oznacza, że plik zapisała wersja nowsza niż ta, która go
otwiera.

**Homebrew odmawia instalacji na istniejącej aplikacji.** Najpierw zakończ Keepit i przenieś
`/Applications/Keepit.app` do Kosza albo dodaj `--force`.

Nadal nie działa? [GitHub Issues](https://github.com/andrey-insarov/Keepit/issues) · admin@keep.it.com

### Ściąga ze skrótów klawiszowych

| Klawisze | Działanie |
|------|--------|
| `⌥M` | Menu historii, pisz, żeby wyszukać |
| `⌥T` | Menu szablonów |
| `⌃⌥1` … `⌃⌥0` | Wklej element 1–10 (w menu i wszędzie indziej) |
| `⇧` w menu | Menu rozszerzone: wszystkie działania dla każdego elementu |
| `⌥⇧V` | Wklej poprzedni element / zamień |
| `⌃⌥V` | Wklej schowek jako zwykły tekst |
| `⌃⌥U` `⌃⌥L` `⌃⌥T` `⌃⌥S` | WIELKIE LITERY / małe litery / Każde Słowo Wielką / jak w zdaniu |
| `⌃⌥W` `⌃⌥J` | Bez spacji na brzegach / w jednym wierszu |
| `⌃⌥K` `⌃⌥D` `⌃⌥Y` `⌃⌥X` | Przekreślenie / podkreślenie / wężyk / usuń ozdobniki |
| `⌃⌥A` | Dodaj schowek do Szablonów |
| `⌃⌥⌫` | Usuń najnowszy element |
| `⌥N` · `⌥V` · `⌥⇧N` | Kolejka wklejania: włącz / wyłącz · wklej następny · wklej całą resztę |
| `⌥E` `⌥S` `⌥C` `⌥P` `⌥L` `⌥Q` | Przeglądarka · Ustawienia · Wyczyść historię · Wstrzymaj nagrywanie · Zablokuj · Zakończ |
| `⌘F` w Przeglądarce | Szukaj |
| `⌘,` | Ustawienia |

### Ściąga z symboli zastępczych

| Symbol zastępczy | Wynik |
|-------------|--------|
| `{date}` `{time}` `{datetime}` | Data / godzina / jedno i drugie, format systemowy |
| `{date:yyyy-MM-dd}` `{time:HH:mm}` | Własny format (wzorce dat Unicode) |
| `{date:long}` `{time:short}` `{datetime:full}` | Styl nazwany: `short` `medium` `long` `full` |
| `{date+7d}` `{date-1m:MMMM}` `{time+1h}` `{datetime-1d:long}` `{date+1y-2d}` | Przesunięcie (`d` `w` `m` `y` `h`; do czterech przesunięć pod rząd) |
| `{weekday}` `{month}` `{year}` | Nazwa dnia, nazwa miesiąca, rok |
| `{iso}` `{unix}` | Znacznik czasu ISO 8601, czas uniksowy |
| `{clipboard}` `{clipboard:2}` | Schowek (element 1) albo element N |
| `{clipboard\|upper}` `\|lower` `\|title` `\|trim` `\|oneline` `\|url` | Filtry, można je łączyć |
| `{input:Imię}` `{input:Imię=Domyślne}` | Pyta o wartość przed wklejeniem |
| `{choice:Etykieta=A\|B\|C}` | Prosi o wybranie opcji |
| `{cursor}` | Położenie kursora po wklejeniu |
| `{user}` `{username}` `{host}` | Imię i nazwisko, nazwa konta, nazwa komputera |
| `{uuid}` `{random:1-100}` | Nowy UUID, liczba losowa z zakresu |
| `{{` `}}` | Dosłowne nawiasy klamrowe |
