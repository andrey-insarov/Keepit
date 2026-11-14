<!-- source: GUIDE.md 39bab8b4f2a3de5ce61f2427db3f17e669b6f280 -->
# Guida di Keepit

Keepit gestisce la cronologia degli appunti e i modelli su macOS. Vive nella barra dei menu,
ricorda tutto ciò che copi e incolla di nuovo qualsiasi elemento con un tasto rapido. Tutti i tasti
rapidi indicati qui sotto sono quelli predefiniti e ognuno si può cambiare in *Impostazioni →
Abbreviazioni*. Questa guida descrive Keepit 3; la guida di Keepit 2.x resta invariata
all’indirizzo [keep.it.com/v2/guide](https://keep.it.com/v2/guide) (in inglese).

![Il menu della cronologia](site/img/guide/menu.png)

**Indice**

- [Parte 1. Per iniziare](#part-1--getting-started): [Installazione](#install) · [Primo avvio](#first-launch)
- [Parte 2. Uso quotidiano](#part-2--everyday-use): [Il menu della cronologia](#the-history-menu) · [Ricerca e anteprima](#search-and-preview) · [Incollare senza menu](#paste-without-the-menu) · [La coda di incolla](#the-paste-queue) · [Il menu esteso](#the-extended-menu)
- [Parte 3. Modelli](#part-3--templates): [Creare e organizzare](#creating-and-organising) · [Segnaposto](#placeholders) · [Modelli che fanno domande](#templates-that-ask-questions)
- [Parte 4. Il Visualizzatore](#part-4--the-viewer)
- [Parte 5. Impostazioni](#part-5--settings)
- [Parte 6. Sicurezza](#part-6-security): [Password e crittografia](#password-and-encryption) · [Touch ID](#touch-id) · [Frase di recupero](#recovery-phrase) · [Backup](#backup)
- [Parte 7. Funzioni avanzate](#part-7--advanced): [Automazione](#automation-the-keepit-url-scheme) · [Aggiornamenti](#updates) · [Disinstallazione](#uninstalling)
- [Riferimenti](#reference): [Risoluzione dei problemi](#troubleshooting) · [Promemoria dei tasti](#keyboard-cheat-sheet) · [Promemoria dei segnaposto](#placeholder-cheat-sheet)

---

## Parte 1. Per iniziare

### Installazione

**Homebrew.** È il metodo consigliato, perché `brew upgrade` mantiene l’app aggiornata:

```bash
brew tap andrey-insarov/keepit https://github.com/andrey-insarov/Keepit
brew install --cask andrey-insarov/keepit/keepit
```

**DMG.** Scarica `Keepit-<versione>.dmg` dalla
[release più recente](https://github.com/andrey-insarov/Keepit/releases/latest), aprilo e trascina
Keepit in *Applicazioni*.

![Il DMG: trascina Keepit in Applicazioni](site/img/guide/dmg.png)

La prima volta che apri l’app, macOS conferma che proviene da Internet e che è stata controllata da
Apple. Fai clic su *Apri*.

![La conferma di Gatekeeper in macOS](site/img/guide/gatekeeper.png)

Keepit è firmato e autenticato, si aggiorna da solo e funziona in modo nativo sui Mac con Apple
silicon e con processore Intel, con macOS 13 Ventura o successivo.

### Primo avvio

Keepit è un’app della barra dei menu: non ha un’icona nel Dock né una finestra finché non ne apri
una. Dopo il primo avvio nella barra dei menu compare l’icona 📎 e Keepit chiede tre cose.

**1. Ripristinare da un backup?** Se questo è un Mac nuovo e hai un backup di Keepit (automatico,
in iCloud Drive o in un’altra cartella, oppure un file `.keepit` esportato), *Ripristina da
backup…* riporta la cronologia e i modelli prima che succeda qualsiasi altra cosa. Sblocchi il
file con la password del Mac da cui proviene oppure con la sua frase di recupero. *Inizia da zero*
salta questo passaggio. Lo stesso ripristino è disponibile più tardi in *Impostazioni → Backup →
Ripristina…*, e un file `.keepit` si apre anche con un doppio clic nel Finder. I dettagli sono
nella sezione [Backup](#backup).

![La prima domanda su un Mac nuovo: ripristinare da un backup o iniziare da zero](site/img/guide/restore-first-run.png)

**2. Una password (facoltativa).** Keepit può salvare la cronologia e i modelli crittografati
e sbloccarli con Touch ID. Puoi decidere subito oppure più tardi in *Impostazioni → Sicurezza*; la
[Parte 6](#part-6-security) spiega come funziona. Con *Non ora* tutto resta sul disco non
crittografato. Se un attimo prima hai ripristinato un backup con la sua password, Keepit propone di
mantenere quella password anche per questo Mac.

![La proposta della password al primo avvio](site/img/guide/password-offer.png)

![Scegliendo Non ora: una spiegazione chiara di che cosa comporta e di dove si può cambiare](site/img/guide/no-password-notice.png)

**3. L’autorizzazione Accessibilità.** Per incollare al posto tuo, Keepit invia ⌘V all’app in cui
stavi lavorando. macOS lo consente solo alle app elencate in *Impostazioni di Sistema → Privacy
e sicurezza → Accessibilità*. Fai clic su *Apri Impostazioni di Sistema* e attiva Keepit. Senza
questa autorizzazione Keepit continua a registrare e a copiare, ma ⌘V lo premi tu.

![Keepit chiede l’autorizzazione Accessibilità](site/img/guide/accessibility-prompt.png)

![Keepit attivato in Privacy e sicurezza → Accessibilità](site/img/guide/accessibility-settings.png)

Di default Keepit si avvia al login. Puoi disattivarlo in *Impostazioni → Generali*.

---

## Parte 2. Uso quotidiano

### Il menu della cronologia

Premi **⌥M** in qualsiasi app oppure fai clic sull’icona 📎. Il menu si apre accanto al cursore di
testo, se Keepit riesce a trovarlo, altrimenti accanto al puntatore del mouse.

Ogni riga è un elemento copiato e il più recente sta in alto. Il più recente è in **grassetto**,
perché è quello che si trova negli appunti in questo momento. L’icona mostra l’app da cui hai
copiato. Un titolo che termina con `…` ha più righe di quante ne mostri il menu. Le immagini hanno
una miniatura, gli elenchi di file mostrano i nomi dei file.

![Il pannello di anteprima accanto al menu mostra per intero l’elemento evidenziato, con l’app di origine, l’ora e la dimensione](site/img/guide/menu-preview.png)

![Un’immagine nella cronologia: miniatura nel menu, immagine intera nell’anteprima](site/img/guide/menu-image.png)

Per incollare un elemento fai clic su di esso, oppure raggiungilo con ↑ ↓ e premi Invio, oppure
premi il suo numero con **⌃⌥**: `⌃⌥3` incolla l’elemento 3. Lo stesso tasto funziona ovunque,
anche senza aprire il menu.

Sotto la cronologia trovi il sottomenu *Modelli*, il Visualizzatore (⌥E), le Impostazioni (⌥S),
*Cancella cronologia* (⌥C), *Sospendi la registrazione per 10 minuti* (⌥P, per quando scrivi
qualcosa che non vuoi registrare), *Blocca Keepit* (⌥L) se è impostata una password, e gli
aggiornamenti. **⌥T** apre direttamente il menu dei modelli. Ognuno di questi tasti funziona anche
senza il menu.

### Ricerca e anteprima

**Ricerca.** Con il menu aperto inizia a scrivere: il campo in alto filtra l’elenco per titolo
e per testo completo, quindi trova anche una riga nel mezzo di un elemento lungo. Invio incolla la
prima corrispondenza, Esc svuota il campo e un secondo Esc chiude il menu.

**Anteprima.** Passa con il puntatore su un elemento (o raggiungilo con la tastiera) e un pannello
accanto al menu mostra l’immagine intera oppure le prime righe di un testo lungo, con l’app di
origine, la data e la dimensione. I testi brevi di una sola riga non hanno anteprima, perché la
riga del menu li mostra già per intero.

![Scrivendo si filtra il menu; il pannello di anteprima mostra l’elemento evidenziato](site/img/guide/search-preview.png)

### Incollare senza menu

I tasti rapidi globali agiscono sulla cronologia così com’è in quel momento (l’elemento 1 sono gli
appunti), da qualsiasi app:

| Tasti | Che cosa succede |
|------|--------------|
| `⌃⌥1` … `⌃⌥9`, `⌃⌥0` | Incolla l’elemento 1–10 della cronologia |
| `⌥⇧V` | Incolla l’elemento *precedente* (il 2); premendo di nuovo li scambi ancora |
| `⌃⌥V` | Incolla gli appunti come testo semplice, senza formattazione |
| `⌃⌥U` `⌃⌥L` `⌃⌥T` `⌃⌥S` | Incolla gli appunti in MAIUSCOLE / minuscole / Iniziali Maiuscole / come una frase |
| `⌃⌥W` | Incolla gli appunti senza gli spazi iniziali e finali |
| `⌃⌥J` | Incolla gli appunti riuniti in una sola riga |
| `⌃⌥K` `⌃⌥D` `⌃⌥Y` | Incolla gli appunti barrati / sottolineati / con sottolineatura ondulata, come testo semplice che conserva l’aspetto ovunque, chat comprese (vedi sotto) |
| `⌃⌥X` | Incolla gli appunti dopo aver rimosso queste decorazioni |
| `⌃⌥A` | Aggiunge gli appunti ai Modelli |
| `⌃⌥⌫` | Elimina dalla cronologia l’elemento più recente |

Le tre decorazioni non sono formattazione: Keepit aggiunge dopo ogni carattere un *segno
combinatorio* Unicode (b̶a̶r̶r̶a̶t̶o̶, s̲o̲t̲t̲o̲l̲i̲n̲e̲a̲t̲o̲, o̰n̰d̰ṵl̰a̰t̰o̰), così il testo ha lo stesso aspetto in
un’app di messaggistica, in un modulo web o in un terminale, dove la formattazione vera andrebbe
persa. C’è un prezzo: un testo così occupa il triplo, una ricerca della parola semplice non lo
trova, gli screen reader vi inciampano e alcuni font disegnano la linea in modo irregolare.
*Rimuovi decorazioni* (`⌃⌥X`) toglie di nuovo i segni, anche da un testo decorato altrove. In
entrambi i casi i segni vengono rimossi per punto di codice, qualunque sia la loro provenienza:
una trascrizione fonetica che usa gli stessi segni come lettere (U+0330 è anche il segno IPA della
voce cricchiata) li perde, e anche le tre decorazioni prima li rimuovono. Con VoiceOver attivo,
`⌃⌥` è il modificatore di VoiceOver stesso: assegnane un altro ad *Azioni sull’ultimo elemento* in
Impostazioni → Abbreviazioni.

Le trasformazioni si applicano al testo; con un’immagine o un elenco di file il tasto emette solo
un segnale acustico. Tutti questi tasti si possono cambiare o disattivare in *Impostazioni →
Abbreviazioni*.

### La coda di incolla

A volte serve copiare cinque cose da un posto e incollarle in ordine da un’altra parte: celle in
un modulo, righe di una pagina in un documento. La coda di incolla lo fa senza il menu:

1. Premi **⌥N** (oppure scegli *Avvia la coda di incolla* nel menu). L’icona nella barra dei menu
   mostra un punto rosso e un contatore: `📎 ● 0`.
2. Copia come al solito con ⌘C, tutte le volte che vuoi. Il contatore sale a ogni copia: 1, 2, 3…
   Tutto viene registrato anche nella cronologia.

   ![La barra dei menu con la coda attiva: punto rosso e contatore](site/img/guide/queue-menubar.png)

3. Passa al punto in cui va il testo e premi **⌥V** per ogni elemento. Ciò che hai copiato per
   primo viene incollato per primo e il contatore scende. ⌘V continua a incollare gli appunti come
   sempre, quindi puoi alternare i due.
4. La coda si disattiva da sola dopo aver incollato l’ultimo elemento, oppure dopo due minuti
   senza copie né incolla (il tempo si può regolare). Un altro ⌥N la ferma prima.

**⌥⇧N** incolla in una volta tutto ciò che resta nella coda. Gli elementi vengono uniti con un
ritorno a capo, una tabulazione, uno spazio o niente: lo scegli nel pannello *Coda di incolla*
delle Impostazioni, dove si regola anche il tempo di inattività. Finché la coda è attiva, il menu
della cronologia ne contrassegna gli elementi: `▶` è il prossimo da incollare, `○` è ancora in
coda, `✓` è già stato incollato.

![Il menu della cronologia con la coda attiva: ○ in coda, ▶ prossimo, ✓ incollato; la riga del menu mostra quanti ne restano](site/img/guide/queue-menu.png)

![Impostazioni → Coda di incolla](site/img/guide/prefs-queue.png)

### Il menu esteso

Con il menu della cronologia aperto tieni premuto **⇧** e ogni elemento riceve un sottomenu `▸`
con tutte le azioni disponibili per quell’elemento: Incolla, Incolla come testo semplice, Solo
copia (negli appunti, senza incollare), le trasformazioni *Incolla come*, Aggiungi ai Modelli,
Mostra nel Visualizzatore, Elimina. Per aprirlo punta l’elemento o premi →; una volta aperto puoi
rilasciare ⇧.

![Tieni premuto ⇧: ogni elemento riceve un sottomenu; per il più recente mostra i tasti rapidi globali](site/img/guide/extended-menu.png)

Per l’elemento più recente il sottomenu elenca i tasti rapidi globali della tabella qui sopra.
Sono le stesse azioni con gli stessi tasti, quindi puoi impararli qui. Gli altri elementi mostrano
le azioni senza tasti: un tasto rapido o funziona ovunque oppure non viene mostrato.

![Per gli altri elementi: le stesse azioni, senza tasti rapidi](site/img/guide/extended-menu-item2.png)

![Per un’immagine le azioni di testo sono in grigio; valgono solo Incolla, Solo copia, Aggiungi ai Modelli, Mostra nel Visualizzatore ed Elimina](site/img/guide/extended-menu-image.png)

---

## Parte 3. Modelli

I modelli sono elementi che conservi per sempre: firme, indirizzi, risposte pronte, frammenti di
codice, un logo che incolli spesso. Stanno in un albero con cartelle e compaiono nel sottomenu
*Modelli* del menu della cronologia e sotto **⌥T**. Una nuova installazione include una cartella
*Esempi* (un saluto, la data di oggi, una citazione degli appunti e una firma), così puoi vedere
che cosa sanno fare i modelli prima di scriverne di tuoi. Eliminali o modificali come preferisci.
Puoi ripristinare i modelli di esempio da *Impostazioni → Avanzate → Ripristino e disinstallazione
→ Ripristina…*; questa operazione però reimposta anche gli altri dati e le impostazioni.

![La cartella Esempi: passando su un elemento se ne vede il testo](site/img/guide/template-examples.png)

![Il menu dei modelli: le cartelle si aprono come sottomenu, le lettere dopo & diventano scorciatoie](site/img/guide/template-menu-letters.png)

### Creare e organizzare

**Aggiungere un modello**

- Dal menu della cronologia: `⌃⌥A` per l’elemento più recente, *Aggiungi gli appunti ai modelli*
  in fondo, oppure ⇧ → sottomenu dell’elemento → *Aggiungi ai Modelli* per qualsiasi elemento.
- Nel Visualizzatore: seleziona un elemento della cronologia e fai clic su *Aggiungi ai modelli*,
  oppure trascinalo nell’albero Modelli. *Nuovo elemento* crea un modello di testo vuoto; *Nuovo
  elemento da file* (menu contestuale) ne crea uno da un file di testo o da un’immagine.

**Organizzare**

- *Nuova cartella* crea una cartella. Trascina gli elementi tra le cartelle, oppure usa *Su* /
  *Giù* nel menu contestuale.
- Un modello chiamato `-` diventa una linea di separazione nel menu.
- Una `&` prima di una lettera del nome, per esempio `&Firma`, fa di quella lettera la scorciatoia
  dell’elemento nel menu dei modelli: con il menu aperto premi `F`.
- *Imposta tasto rapido* nel menu contestuale assegna al modello un tasto rapido globale tutto suo.
- Un modello senza nome mostra la sua prima riga. *Rinomina* e *Cancella nome* sono nel menu
  contestuale, oppure puoi modificare il campo *Nome* sopra il testo.

### Segnaposto

I modelli di testo possono contenere segnaposto `{…}`, che vengono compilati al momento di
incollare. Tutto il resto viene incollato senza modifiche. Nel Visualizzatore, **Inserisci ▾**
elenca tutti i segnaposto e mette quello scelto nel punto del cursore, quindi non c’è niente da
imparare a memoria.

![L’esempio Data di oggi: `{date:EEEE, d MMMM yyyy}` diventa la data corrente quando viene incollato](site/img/guide/template-examples-date.png)

![Inserisci ▾ nel Visualizzatore elenca tutti i segnaposto](site/img/guide/insert-menu.png)

I più utili:

| Segnaposto | Risultato |
|-------------|--------|
| `{date}` `{time}` `{datetime}` | Data di oggi / ora corrente, formato di sistema |
| `{date:yyyy-MM-dd}` | Qualsiasi formato (`yyyy MM dd EEEE HH mm …`) |
| `{date:long}` `{time:short}` `{datetime:medium}` | Uno stile con nome: `short` `medium` `long` `full` |
| `{date+7d}` `{date-1m:MMMM}` `{time+1h}` `{date+1y-2d}` | Spostamento: `d` giorni, `w` settimane, `m` mesi, `y` anni, `h` ore; su `date`, `time`, `datetime`, anche più di uno di seguito |
| `{clipboard}` `{clipboard:2}` | Gli appunti, oppure l’elemento N della cronologia |
| `{clipboard\|upper}` `{clipboard\|trim\|oneline}` | Filtri `upper` `lower` `title` `trim` `oneline` `url`, concatenabili |
| `{cursor}` | Il punto in cui si troverà il cursore di testo dopo aver incollato |
| `{user}` `{username}` `{host}` | Nome completo, nome dell’account, nome del computer |
| `{uuid}` `{random:1-100}` | Un nuovo UUID; un numero casuale |
| `{{` `}}` | Parentesi graffe letterali: un modello `{{"x":1}}` incolla `{"x":1}` |

I nomi dei segnaposto sono in minuscolo: `{date}` è un segnaposto, mentre `{Date}` e `{DATE}` sono
testo e vengono incollati così come sono. I nomi degli stili e i filtri (`{date:LONG}`,
`{clipboard|UPPER}`) si possono scrivere in entrambi i modi.

L’elenco completo è nel [promemoria dei segnaposto](#placeholder-cheat-sheet).

### Modelli che fanno domande

`{input:Nome}` e `{choice:Etichetta=A|B|C}` trasformano un modello in un piccolo modulo: quando lo
incolli, Keepit chiede prima i valori e poi incolla il testo completo. Lo stesso nome viene chiesto
una sola volta, per quante volte compaia; `{input:Nome=Predefinito}` precompila il campo.

![Incollando un modello con {input:Name} viene chiesto prima il valore](site/img/guide/input-dialog.png)

Per esempio, un modello di risposta:

```
Buongiorno {input:Nome},

grazie per il tuo messaggio del {date-1d}. Ti risponderò entro {date+3d:EEEE}.
{cursor}
{user}
```

Quando lo incolli chiede il *Nome*, inserisce le date, firma con il tuo nome completo e lascia il
cursore sulla riga vuota.

---

## Parte 4. Il Visualizzatore

*Visualizzatore…* nel menu, oppure un clic con il tasto destro sull’icona 📎, apre una finestra con
tre alberi: **Appunti** (gli appunti in questo momento, in sola lettura), **Cronologia** (*Testo
e file* e *Immagini*) e **Modelli**.

![Il Visualizzatore con un modello selezionato](site/img/guide/viewer.png)

- Seleziona un elemento per vederlo a destra. Il testo si modifica sul posto e le modifiche
  vengono applicate quando esci dall’editor. Un’immagine viene mostrata ridimensionata per stare
  nel pannello, con sopra le dimensioni in pixel e la dimensione del file. Gli elenchi di file
  aprono il file con un doppio clic. *Mostra come dump esadecimale* nel menu contestuale mostra
  i byte grezzi.
- La barra degli strumenti: *Invia agli appunti*, *Incolla* (nell’app da cui provieni),
  *Aggiungi ai modelli*, *Nuovo elemento*, *Nuova cartella*, *Elimina*, *Inserisci ▾* (segnaposto)
  e **?**, cioè questa guida.
- **Cerca** (`⌘F`): il campo a sinistra filtra la cronologia e i modelli per nome e per contenuto
  ed evidenzia la corrispondenza.
- Trascina gli elementi della cronologia nell’albero Modelli per conservarli, e i modelli nella
  Cronologia per copiarli di nuovo; riordina trascinando oppure con *Su* / *Giù*. ⌫ elimina
  l’elemento selezionato.
- La barra di stato mostra la data, l’app di origine, il formato e la dimensione.

![La ricerca nel Visualizzatore evidenzia le corrispondenze](site/img/guide/viewer-search.png)

---

## Parte 5. Impostazioni

`⌘,` nel menu, *Impostazioni…*, oppure ⌥S da qualsiasi app. La finestra funziona come le finestre
delle impostazioni sul Mac: scegli un pannello nella barra degli strumenti e ogni modifica vale
dal momento in cui la fai. Non c’è un pulsante Salva; chiudi la finestra con ⌘W o Esc. Ogni
opzione con un **?** accanto ha un popover che la spiega.

![Impostazioni → Generali](site/img/guide/prefs-general.png)

| Pannello | Che cosa contiene |
|-----|---------------|
| **Generali** | Avvio al login · salvataggio della cronologia all’uscita e ripristino all’avvio · incolla dopo la scelta (disattivato = solo copia) · ritardo dell’incolla, da aumentare per le app lente a venire in primo piano · apertura del menu al cursore di testo · Aggiornamenti: *Cerca aggiornamenti automaticamente* (edizione scaricata dal sito; disattivato = nessuna richiesta di rete), vedi [Aggiornamenti](#updates) |
| **Abbreviazioni** | Tutti i tasti rapidi globali in un unico posto, vedi sotto |
| **Coda di incolla** | I tre tasti della coda, il tempo di inattività dopo il quale la coda si disattiva e che cosa mettere tra gli elementi per *Incolla tutto il resto*, vedi [La coda di incolla](#the-paste-queue) |
| **Cronologia** | Quanti elementi di testo e file e quante immagini conservare (1000 / 30) · dimentica gli elementi più vecchi di … · *Rimuovi i duplicati* (copiare di nuovo la stessa cosa la riporta in cima) · *Ignora i dati nascosti degli appunti* · l’elenco delle app ignorate (identificatori bundle; i gestori di password sono sempre ignorati) |
| **Menu** | Campo di ricerca · numerazione · pannello di anteprima · suggerimenti · icone delle app di origine · miniature delle immagini · elementi nel menu (quante delle voci più recenti elenca il menu, 60 di default; le altre restano ricercabili) · lunghezza del titolo · altezza delle miniature |
| **Sicurezza** | Password, Touch ID, blocco, frase di recupero, vedi la [Parte 6](#part-6-security) |
| **Backup** | Backup automatico (riga di stato accanto al titolo): *Esegui il backup automaticamente in una cartella*, il nome del Mac nei file, la cartella, quante copie conservare · Backup manuale: *Esegui backup ora*, *Salva in archivio…* · Ripristino: *Ripristina…*, vedi [Backup](#backup) |
| **Avanzate** | Intervallo di interrogazione degli appunti · Automazione: *Consenti comandi URL keepit://* (disattivato di default, vedi [Automazione](#automation-the-keepit-url-scheme)) · Dati: *Apri cartella* · Ripristino e disinstallazione: *Ripristina…* (ritorno allo stato di una nuova installazione, tornano i modelli di esempio) · *Disinstalla…* (ripristino, poi rimozione dell’app, dell’avvio al login, della voce nel portachiavi e delle autorizzazioni) |

![Impostazioni → Cronologia: limiti ed elenco delle app ignorate](site/img/guide/prefs-history.png)

![Impostazioni → Abbreviazioni](site/img/guide/prefs-hotkeys.png)

Nel pannello **Abbreviazioni** fai clic su un campo e premi una combinazione; ⌫ disattiva un
tasto. Una combinazione già usata da un altro comando viene rifiutata e il motivo compare sotto
i campi. *Ripristina predefiniti* riporta il set ⌥ + lettera (⌥M cronologia, ⌥T modelli,
⌥E Visualizzatore, ⌥S Impostazioni, ⌥C Cancella cronologia, ⌥P sospensione, ⌥L blocco, ⌥Q uscita),
⌥⇧V e ⌃⌥. *Incolla elemento per numero* e *Azioni sull’ultimo elemento* accettano solo
modificatori: la cifra o la lettera la aggiunge Keepit. Se macOS o un’altra app occupa già una
combinazione, Keepit lo segnala all’avvio. *Visualizzatore* ⌥E, *Impostazioni* ⌥S, *Cancella
cronologia* ⌥C, *Sospendi la registrazione* ⌥P, *Blocca Keepit* ⌥L ed *Esci da Keepit* ⌥Q
funzionano da qualsiasi app e sono mostrati nel menu accanto ai rispettivi comandi. Con il layout
statunitense ⌥ + lettera di solito scrive un carattere speciale (⌥S = ß, ⌥C = ç …); se te ne serve
uno, sposta il tasto rapido.

---

## Parte 6. Sicurezza

### Password e crittografia

*Impostazioni → Sicurezza → Richiedi la password all’avvio* crittografa la cronologia e i modelli
con AES-256-GCM. La chiave è derivata dalla tua password (PBKDF2, 200 000 iterazioni) ed esiste
solo in memoria. Viene cancellata quando Keepit si blocca: con *Blocca Keepit* (`⌥L`), all’uscita
e, se lo desideri, dopo che il Mac è rimasto bloccato o in stop per un certo tempo. *Blocco
automatico di Keepit* è impostato su **Mai** in una nuova installazione (un aggiornamento dalla
3.0.3 conserva la vecchia scelta, cioè *Subito* se era selezionata la casella del blocco insieme
allo schermo): un gestore degli appunti che chiede la password dopo ogni pausa caffè smette di
essere usato, e per i momenti che contano c’è `⌥L`. *Subito* blocca insieme allo schermo. *Dopo
5 minuti*, *Dopo 15 minuti* e *Dopo 1 ora* ignorano un’assenza breve (Keepit resta sbloccato
e continua a registrare) e bloccano solo se il Mac è rimasto bloccato o in stop per tutto l’intervallo impostato. Lo
stesso vale quando Keepit si avvia mentre il Mac è già bloccato o è in primo piano la sessione di
un altro utente (un riavvio dopo un aggiornamento, per esempio): l’assenza si conta dall’avvio,
nella misura in cui macOS comunica quello stato a Keepit (di norma lo fa; quando non può, il
conteggio parte dal blocco o dallo stop successivo). Con Touch ID attivo, Keepit chiede un tocco
nel momento in cui il Mac viene sbloccato, così è pronto prima del primo `⌥M`.

![Impostazione della password con la tastiera a schermo. È una fotografia dello schermo, non una schermata: sul Mac dell’autore una schermata di questa scena mostra solo la finestra di dialogo](site/img/guide/set-password-keyboard.jpg)

Le finestre della password mostrano il layout di tastiera attuale e avvisano se è attivo Bloc
Maiusc, quindi una password rifiutata è raramente un mistero. Il pulsante con la tastiera accanto
al campo apre una **tastiera a schermo** per digitare la password con il mouse: i clic non passano
mai dal sistema come pressioni di tasti, i tasti vengono mescolati a ogni apertura e la tastiera
chiede a macOS di tenerla fuori dalle schermate e dalle registrazioni dello schermo (in alcune
configurazioni viene esclusa; non è garantito). È pensata per un Mac di cui non ti fidi del tutto
o il cui schermo è condiviso. All’avvio e dopo un blocco Keepit chiede la password (o Touch ID);
*Recupera accesso…* accetta al suo posto la frase di 24 parole, vedi
[Frase di recupero](#recovery-phrase).

![Sblocco all’avvio: password, Esci oppure la frase di recupero; OK resta disattivato finché non scrivi qualcosa. Fotografato per lo stesso motivo di sopra](site/img/guide/unlock-keyboard.jpg)

![Impostazioni → Sicurezza](site/img/guide/prefs-security.png)

### Touch ID

Con *Sblocca con Touch ID* la chiave viene conservata anche nella Secure Enclave, dietro la tua
impronta: Keepit chiede un tocco invece della password. La password continua a funzionare come
alternativa, basta scegliere *Usa password* nella richiesta. Con il coperchio chiuso e una Magic
Keyboard esterna con Touch ID, Keepit chiede il tocco sulla tastiera. *Consenti di cambiare la
password con Touch ID* permette all’impronta di sostituire la vecchia password quando la cambi.

![Sblocco con Touch ID; la password resta come alternativa](site/img/guide/touch-id.png)

### Frase di recupero

Quando imposti una password, Keepit mostra una sola volta una frase di 24 parole. Stampala
o conservala in un gestore di password. Se dimentichi la password, *Recupera accesso…* nella
finestra di sblocco apre i dati e ti permette di impostarne una nuova. *Frase di recupero → Crea
nuova…* genera una nuova frase e invalida la vecchia; *Mostra…*, lì accanto, mostra di nuovo la
frase attuale dopo Touch ID o la password.

Senza la password, Touch ID sullo stesso Mac o la frase, i dati non si possono recuperare: non
c’è un server e non c’è niente da reimpostare.

![La frase di recupero di 24 parole (qui le parole sono nascoste)](site/img/guide/recovery-phrase.png)

### Backup

Keepit può conservare una copia crittografata della cronologia e dei modelli in una cartella a tua
scelta (iCloud Drive, Dropbox, Google Drive, un disco esterno, un NAS) e scriverne una nuova ogni
volta che qualcosa cambia. Un server Keepit non esiste: la cartella è tua. Il fornitore che la
ospita vede il file crittografato, la sua dimensione e una piccola intestazione non crittografata
(quando e con quale Keepit è stato scritto, come viene derivata la chiave, identificatori casuali
e il nome del tuo Mac solo se lo attivi); la [pagina sulla sicurezza](/security#backups) (in
inglese) la elenca campo per campo.

![Impostazioni → Backup: backup automatico, backup manuale, ripristino](site/img/guide/prefs-backup.png)

**Attivazione.** *Impostazioni → Backup → Esegui il backup automaticamente in una cartella*, poi
*Scegli…* una cartella (la finestra di scelta si apre in iCloud Drive). Il backup automatico
richiede la protezione con password di *Impostazioni → Sicurezza*: ogni copia è sigillata con una
chiave derivata dalla chiave della tua cassaforte, quindi si apre con la tua password di Keepit
o con la frase di recupero, su questo Mac o su qualsiasi altro, e non c’è nient’altro da
configurare. Senza una password la casella è disattivata e ne indica il motivo.

**Che cosa succede dopo: la pianificazione.** Circa cinque minuti dopo l’ultima modifica
(e almeno una volta al giorno finché Keepit è in esecuzione) Keepit scrive nella cartella un file
chiamato `Keepit-<data e ora>-<installazione>-<id>.keepit`, lo rilegge per verificarlo e solo
allora elimina le più vecchie tra le proprie copie oltre il numero indicato in *Conserva gli
ultimi* (10 di default, 1–100). Ogni copia è completa di per sé, non è un
incremento, quindi un solo file è tutto ciò che ti serve. Le copie fatte da un altro Mac, o i file
che metti lì tu, non vengono mai toccati: due Mac che condividono una cartella scrivono due serie
indipendenti. La riga di stato accanto al titolo *Backup automatico* mostra l’ora e la dimensione
dell’ultima copia, oppure il motivo per cui l’ultimo tentativo è fallito. Mentre Keepit è
bloccato non succede nulla; *Esegui backup ora* (sotto *Backup manuale*) non aspetta il periodo
di quiete.

**Includi il nome di questo Mac** (disattivato di default) inserisce il nome del computer
nell’intestazione non crittografata di ogni file, così due serie nella stessa cartella si
distinguono facilmente nel Finder. Il fornitore dello spazio di archiviazione vede quel nome, ed
è per questo che l’opzione è facoltativa.

**Ripristino.** *Ripristina…* apre un backup (di questo Mac, di un altro Mac o un file esportato)
dopo che l’hai sbloccato: con la password del Mac su cui è stato creato, oppure con la frase di
recupero che quel Mac ha mostrato quando è stata impostata la password (*Recupera accesso…* nella
finestra della password). Un’anteprima mostra quando e dove è stato creato il file e quanti
elementi contiene. Poi hai due possibilità:

![L’anteprima del ripristino: quando e con quale Keepit è stato scritto il file, che cosa contiene, Unisci o Sostituisci](site/img/guide/restore-preview.png)

- *Unisci* aggiunge ciò che non c’è ancora: gli elementi della cronologia in base al contenuto
  e i modelli del backup come un’unica nuova cartella chiamata *Importato <data>*, senza i loro
  tasti rapidi. Così vedi esattamente che cosa è arrivato dal backup e puoi spostarlo
  o eliminarlo. Niente di tuo viene sovrascritto.
- *Sostituisci* scarta la cronologia e i modelli attuali e prende al loro posto quelli del
  backup. Prima di farlo, Keepit scrive una copia di ciò che hai adesso
  (`Keepit-before-restore-…`) nella cartella dei backup o in una cartella che scegli; se quella
  copia non può essere scritta, la sostituzione non parte. Se Keepit non ha ancora una password,
  te ne viene chiesta una per quella copia, come con *Salva in archivio…*.

*Ripristina anche le preferenze* riporta dal backup i tasti rapidi, i limiti e le opzioni. Le
impostazioni che esprimono fiducia in un Mac specifico (Touch ID, l’automazione via URL e le sue
app attendibili, la cartella stessa dei backup) restano sempre come sono qui. Se la cronologia del
backup è più grande di quanto consentono i limiti di questo Mac, Keepit dice quanto ci starebbe
prima che tu confermi.

Hai ripristinato un backup con la sua frase di recupero su un Mac che non ha ancora una password?
Keepit ti chiede prima di impostarne una, così i dati ripristinati non finiscono mai sul disco non
crittografati, e ti lascia mantenere quella frase per questo Mac oppure ottenerne una nuova. L’hai
ripristinato con la password? Keepit propone di mantenerla come password di questo Mac. In
entrambi i casi il backup automatico è un’impostazione propria di ciascun Mac: attivalo qui
e scegli la cartella (va bene anche la stessa) e questo Mac inizierà una propria serie di file
accanto a quella del vecchio Mac.

**Il passaggio a un Mac nuovo** è lo scopo di tutto questo: installa Keepit, al primo avvio scegli
*Ripristina da backup…*, seleziona il file più recente nella tua cartella, inserisci la password
del vecchio Mac e scegli *Sostituisci*; poi attiva il backup automatico sul nuovo Mac. Le copie
fatte fin lì si aprono con la password e la frase in vigore quando ciascuna è stata scritta: dopo
un cambio di password, quelle vecchie richiedono ancora la vecchia password.

**Backup manuale.** Ci sono due pulsanti e fanno due cose diverse. *Esegui backup ora* crea subito
una copia come quelle automatiche: stesso tipo di file, stessa cartella e stessa serie, e si apre
con la tua password di Keepit o con la frase. *Salva in archivio…* scrive un singolo *archivio*
`.keepit` dove vuoi tu, bloccato con una password che scegli apposta. Non richiede la protezione
con password di Keepit, e Keepit poi non tiene traccia del file. Serve per consegnare i dati
a qualcuno o per una copia fuori dalla cartella dei backup. Il nome proposto dice di che cosa si
tratta: `Keepit-archive-<data>-manual.keepit`, accanto alle copie automatiche
`Keepit-<data e ora>-<installazione>-<id>.keepit`.

![Salva in archivio…: il nome del file contiene archive e manual](site/img/guide/save-to-archive.png)

![La password dell’archivio, con un indicatore di robustezza: non viene salvata da nessuna parte](site/img/guide/archive-password.png)

*Ripristina…* apre entrambi i tipi. L’archivio sostituisce *Esporta…* / *Importa…* della 2.x. Il
file trasferisce i dati tra l’edizione scaricata dal sito e quella dell’App Store, e tra Keepit
2.x e 3.x: un file scritto dalla 3.0 richiede la 3.0 o successiva per essere aperto; la 3.0 legge
tutto ciò che ha scritto la 2.x.

**Se qualcosa va storto.** Una copia non riuscita viene segnalata nella riga di stato e ritentata
con pause sempre più lunghe; le copie precedenti restano. Se Keepit è stato chiuso o il Mac si
è spento nel mezzo di un ripristino, l’avvio successivo rimette tutto in silenzio com’era prima
del ripristino. Nel raro caso in cui non ci riesca (un file che non può scrivere, il disco pieno),
indica il file ed esce senza modificare nulla: sistema il file e avvia di nuovo Keepit. I dettagli,
compresa la struttura interna del formato del file, sono nella
[pagina sulla sicurezza](/security#backups) (in inglese).

---

## Parte 7. Funzioni avanzate

### Automazione: lo schema URL keepit://

Comandi Rapidi (*Apri URL*), Raycast, Alfred, Keyboard Maestro o `open` in una shell possono
comandare Keepit, **una volta che lo attivi** in *Impostazioni → Avanzate → Automazione → Consenti
comandi URL keepit://*. È disattivato di default perché qualsiasi app o pagina web può aprire un
URL, e `add` / `paste` modificano gli appunti e scrivono nell’app in primo piano; quando
è disattivato, Keepit ignora questi URL con un segnale acustico. Quando è attivo, Keepit guarda
chi ha aperto l’URL: il primo comando di ciascuna app che modifica qualcosa (`paste`, `copy`,
`template`, `add`, `add-template`, `pause`, `resume`) viene mostrato in una finestra di dialogo.
*Consenti* lo esegue una volta, *Consenti sempre* mette l’app nell’elenco di quelle attendibili
(si svuota con *Dimentica app attendibili* nello stesso pannello). A un browser web, o a un
mittente che macOS non sa identificare, la conferma viene chiesta ogni volta. I comandi che aprono
soltanto le finestre di Keepit non chiedono mai nulla.

| URL | Effetto |
|-----|--------|
| `keepit://paste/2`<br>`keepit://paste/latest`<br>`keepit://paste/previous` | Incolla l’elemento N della cronologia (oppure l’ultimo / il precedente) nell’app in primo piano |
| `keepit://copy/3` | Mette l’elemento N negli appunti senza incollarlo |
| `keepit://template/Signature`<br>`keepit://template/Work/Reply?copy=1` | Incolla (o copia) un modello per nome o per percorso di cartella |
| `keepit://add?text=…` | Aggiunge testo alla cronologia e agli appunti |
| `keepit://add-template?text=…&name=…` | Crea un modello |
| `keepit://history`<br>`keepit://templates`<br>`keepit://viewer`<br>`keepit://settings` | Apre il menu della cronologia, il menu dei modelli, il Visualizzatore, le Impostazioni |
| `keepit://pause`<br>`keepit://resume` | Sospende la registrazione per 10 minuti / la riprende |

Codifica il testo con la codifica percentuale (`%20` per uno spazio). Mentre Keepit è bloccato gli
URL vengono ignorati.

### Aggiornamenti

Keepit controlla GitHub Releases una volta al giorno e propone gli aggiornamenti in una finestra
di dialogo; *Controlla aggiornamenti…* lo fa subito. Gli aggiornamenti sono firmati (EdDSA)
e autenticati. Con Homebrew, `brew upgrade --cask keepit` fa la stessa cosa. I checksum di ogni
download sono in `SHA256SUMS` nella pagina della release.

Questo controllo è l’unica richiesta di rete che Keepit invia, ed è facoltativo: *Impostazioni →
Generali → Aggiornamenti → Cerca aggiornamenti automaticamente*. Una volta disattivato, Keepit non
contatta più nulla, nemmeno su tua richiesta, e *Controlla aggiornamenti…* scompare dai menu. In
quel caso aggiorni scaricando l’app da [keep.it.com](https://keep.it.com) oppure con Homebrew.
L’edizione App Store non ha un programma di aggiornamento né questa opzione; la aggiorna l’App
Store.

### Disinstallazione

*Impostazioni → Avanzate → Ripristino e disinstallazione → Disinstalla…* rimuove l’app, la
cartella dei dati, le voci nel portachiavi (compresa la chiave di Touch ID), l’elemento di login
e la voce in Accessibilità. Chiede la password o Touch ID, la parola `DELETE` digitata e una
conferma. Se pensi che i dati possano servirti ancora, esporta prima un backup. Con Homebrew esegui poi
`brew uninstall --cask --force keepit`, in modo che Homebrew dimentichi il cask.

![Impostazioni → Avanzate](site/img/guide/prefs-advanced.png)

---

## Riferimenti

### Risoluzione dei problemi

**Dopo aver scelto un elemento non viene incollato nulla.** Manca l’autorizzazione Accessibilità:
*Impostazioni di Sistema → Privacy e sicurezza → Accessibilità → Keepit*. Se Keepit è nell’elenco
ma non incolla comunque, disattivalo e riattivalo. macOS dimentica l’autorizzazione quando l’app
viene reinstallata.

**Un tasto rapido non fa nulla.** Appartiene a un’altra app o a macOS; Keepit lo segnala
all’avvio. Scegli un’altra combinazione nel pannello *Abbreviazioni*. ⌃⌥ con cifre e lettere
è libero su un Mac con le impostazioni di fabbrica.

**Il menu si apre nel posto sbagliato.** L’app in cui ti trovi non espone il suo cursore di testo,
quindi il menu ripiega sul puntatore del mouse. *Apri il menu al cursore di testo quando
possibile*, nel pannello Generali, disattiva la ricerca del cursore se preferisci sempre il
puntatore.

**Manca qualcosa che ho copiato.** Non viene registrato nulla di ciò che l’app di origine ha
contrassegnato come nascosto, né una copia fatta mentre era in primo piano un gestore di password
(elenco integrato) o un’app del tuo elenco di app ignorate, compresa l’app che hai appena
lasciato. Vedi *Impostazioni → Cronologia* e la
[pagina sulla sicurezza](/security#what-is-not-recorded) (in inglese).

**Touch ID non viene proposto.** Al momento nessun sensore Touch ID è raggiungibile (coperchio
chiuso, nessuna tastiera con Touch ID). Keepit conserva l’impostazione e chiede l’impronta non
appena un sensore è disponibile.

**Lo stato del backup dice che la cartella non è disponibile.** La cartella è stata spostata,
rinominata, disattivata oppure (iCloud Drive) rimossa dall’archivio locale. Rendila di nuovo
disponibile e la copia successiva andrà a buon fine; in alternativa usa *Scegli…* per indicare una
nuova cartella. Una nuova cartella inizia una nuova serie, i vecchi file restano dove sono.

**Un file di backup non si apre.** *Password errata* significa che il tag di autenticazione del
file non corrispondeva: assicurati di usare la password del Mac che ha *scritto* il file (dopo un
cambio di password le vecchie copie si aprono ancora con la vecchia password), oppure la sua frase
di recupero. *Questo backup richiede Keepit 3.0 o successivo* significa che il file è stato
scritto da una versione più recente di quella che lo sta aprendo.

**Homebrew si rifiuta di installare sopra un’app esistente.** Prima esci da Keepit e sposta
`/Applications/Keepit.app` nel Cestino, oppure aggiungi `--force`.

Non hai risolto? [GitHub Issues](https://github.com/andrey-insarov/Keepit/issues) · admin@keep.it.com

### Promemoria dei tasti

| Tasti | Azione |
|------|--------|
| `⌥M` | Menu della cronologia, scrivi per cercare |
| `⌥T` | Menu dei modelli |
| `⌃⌥1` … `⌃⌥0` | Incolla l’elemento 1–10 (nel menu e ovunque) |
| `⇧` nel menu | Menu esteso: tutte le azioni per ogni elemento |
| `⌥⇧V` | Incolla l’elemento precedente / scambia |
| `⌃⌥V` | Incolla gli appunti come testo semplice |
| `⌃⌥U` `⌃⌥L` `⌃⌥T` `⌃⌥S` | MAIUSCOLE / minuscole / Iniziali Maiuscole / come una frase |
| `⌃⌥W` `⌃⌥J` | Senza spazi ai bordi / su una sola riga |
| `⌃⌥K` `⌃⌥D` `⌃⌥Y` `⌃⌥X` | Barrato / sottolineato / sottolineatura ondulata / rimuovi decorazioni |
| `⌃⌥A` | Aggiungi gli appunti ai Modelli |
| `⌃⌥⌫` | Elimina l’elemento più recente |
| `⌥N` · `⌥V` · `⌥⇧N` | Coda di incolla: avvia / ferma · incolla il successivo · incolla tutto il resto |
| `⌥E` `⌥S` `⌥C` `⌥P` `⌥L` `⌥Q` | Visualizzatore · Impostazioni · Cancella cronologia · Sospendi la registrazione · Blocca · Esci |
| `⌘F` nel Visualizzatore | Cerca |
| `⌘,` | Impostazioni |

### Promemoria dei segnaposto

| Segnaposto | Risultato |
|-------------|--------|
| `{date}` `{time}` `{datetime}` | Data / ora / entrambe, formato di sistema |
| `{date:yyyy-MM-dd}` `{time:HH:mm}` | Formato personalizzato (modelli di data Unicode) |
| `{date:long}` `{time:short}` `{datetime:full}` | Stile con nome: `short` `medium` `long` `full` |
| `{date+7d}` `{date-1m:MMMM}` `{time+1h}` `{datetime-1d:long}` `{date+1y-2d}` | Spostamento (`d` `w` `m` `y` `h`; fino a quattro spostamenti di seguito) |
| `{weekday}` `{month}` `{year}` | Nome del giorno, nome del mese, anno |
| `{iso}` `{unix}` | Data e ora ISO 8601, tempo Unix |
| `{clipboard}` `{clipboard:2}` | Gli appunti (elemento 1) oppure l’elemento N |
| `{clipboard\|upper}` `\|lower` `\|title` `\|trim` `\|oneline` `\|url` | Filtri, concatenabili |
| `{input:Nome}` `{input:Nome=Predefinito}` | Chiede un valore prima di incollare |
| `{choice:Etichetta=A\|B\|C}` | Chiede di scegliere un’opzione |
| `{cursor}` | Posizione del cursore dopo aver incollato |
| `{user}` `{username}` `{host}` | Nome completo, nome dell’account, nome del computer |
| `{uuid}` `{random:1-100}` | Nuovo UUID, numero casuale in un intervallo |
| `{{` `}}` | Parentesi graffe letterali |
