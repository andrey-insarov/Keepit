<!-- source: SUPPORT.md b7c2b2a3fb8a171f4a5c7809742c5a119d4e8cc1 -->
# Supporto Keepit

Hai trovato un bug o una traduzione sbagliata, oppure hai una domanda? Scrivici con il modulo qui sotto. I bug si possono segnalare anche su [GitHub Issues](https://github.com/andrey-insarov/Keepit/issues).

<form id="fb" class="fb" action="/api/feedback" method="post" enctype="multipart/form-data" novalidate>
  <div class="row2">
    <label>Nome<input name="name" type="text" maxlength="100" autocomplete="name" required></label>
    <label>E-mail<input name="email" type="email" maxlength="254" autocomplete="email" required></label>
  </div>
  <label>Di cosa si tratta
    <select name="type" required>
      <option value="app">Problema con l’app</option>
      <option value="translation">Errore di traduzione</option>
      <option value="other">Altro</option>
    </select>
  </label>
  <label>Messaggio <span class="hint" id="fb-count">almeno 70 caratteri</span>
    <textarea name="message" rows="7" minlength="70" maxlength="5000" required placeholder="Che cosa è successo, che cosa ti aspettavi, quali versioni di macOS e di Keepit usi…"></textarea>
  </label>
  <label>Schermate <span class="hint">facoltativo · fino a 5 immagini, 1 MB ciascuna</span>
    <input id="fb-files" type="file" accept="image/png,image/jpeg,image/gif,image/webp,image/heic" multiple>
  </label>
  <ul class="fb-list" id="fb-list" hidden></ul>
  <div class="cf-turnstile" data-sitekey="__TURNSTILE_SITE_KEY__" data-theme="light" data-language="it"></div>
  <p class="fb-err" id="fb-err" hidden></p>
  <button type="submit" class="btn">Invia</button>
  <p class="hint fb-legal">Quello che invii ci arriva per e-mail e viene usato solo per risponderti. Vedi l’<a href="/privacy">Informativa sulla privacy</a> (in inglese).</p>
  <div class="fb-ok" id="fb-ok" hidden><b>Grazie, il messaggio è stato inviato.</b><br>Una conferma è in arrivo al tuo indirizzo.</div>
</form>
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
<script>
(function(){
  var f=document.getElementById('fb'),err=document.getElementById('fb-err'),ok=document.getElementById('fb-ok'),
      msg=f.elements.message,count=document.getElementById('fb-count'),picker=document.getElementById('fb-files'),
      list=document.getElementById('fb-list'),btn=f.querySelector('button'),files=[];
  var PF={one:' carattere',other:' caratteri'},PR=window.Intl&&Intl.PluralRules?new Intl.PluralRules('it'):null;
  function pf(n){var k=PR?PR.select(n):'other';return Object.prototype.hasOwnProperty.call(PF,k)?PF[k]:PF.other;}
  var EM={name:'Inserisci il tuo nome.',email:'Inserisci un indirizzo e-mail valido.',type:'Scegli di cosa si tratta.',short:'Descrivi il problema in almeno 70 caratteri.',long:'Il messaggio è troppo lungo (al massimo 5000 caratteri).',files:'Si possono allegare al massimo 5 schermate. Rimuovi quelle in più e invia di nuovo il modulo.',total:'Gli allegati sono troppo grandi (al massimo 5 schermate da 1 MB ciascuna).',form:'Non è stato possibile leggere il modulo.',spam:'Conferma di essere una persona.',send:'Al momento non è stato possibile inviare il messaggio. Scrivici un’e-mail.'};
  function emsg(r){var c=r&&r.code,n=(r&&r.file)||'';if(c==='toobig')return'«'+n+'» supera 1 MB. Rimuovi il file o riducilo. Poi invia di nuovo il modulo.';if(c==='notimage')return'«'+n+'» non è stato riconosciuto come immagine supportata. Rimuovi il file o sostituiscilo. Poi invia di nuovo il modulo.';return typeof c==='string'&&Object.prototype.hasOwnProperty.call(EM,c)?EM[c]:'Qualcosa è andato storto.';}
  function show(e){err.textContent=e;err.hidden=!e;}
  function kb(n){return n<1048576?Math.round(n/1024)+' KB':(n/1048576).toFixed(1).replace('.',',')+' MB';}
  function render(){
    list.innerHTML='';list.hidden=!files.length;
    files.forEach(function(file,i){
      var li=document.createElement('li'),x=document.createElement('button');
      li.textContent=file.name+' · '+kb(file.size)+' ';x.type='button';x.textContent='Rimuovi';x.setAttribute('aria-label','Rimuovi '+file.name);
      x.addEventListener('click',function(){files.splice(i,1);render();show('');});li.appendChild(x);list.appendChild(li);
    });
    picker.hidden=files.length>=5;
  }
  picker.addEventListener('change',function(){
    show('');
    for(var i=0;i<picker.files.length;i++){
      var file=picker.files[i];
      if(files.length>=5){show('Al massimo 5 schermate. Le altre non sono state aggiunte.');break;}
      if(file.size>1048576){show('«'+file.name+'» supera 1 MB e non è stato aggiunto.');continue;}
      if(!/^image\//.test(file.type)){show('«'+file.name+'» non è un’immagine e non è stato aggiunto.');continue;}
      files.push(file);
    }
    picker.value='';render();
  });
  msg.addEventListener('input',function(){var n=msg.value.trim().length;count.textContent=n<70?'ancora '+(70-n)+pf(70-n):n+pf(n);});
  f.addEventListener('submit',function(ev){
    ev.preventDefault();show('');
    if(!f.elements.name.value.trim())return show('Inserisci il tuo nome.');
    if(!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(f.elements.email.value.trim()))return show('Inserisci un indirizzo e-mail valido.');
    if(msg.value.trim().length<70)return show('Descrivi il problema in almeno 70 caratteri.');
    if(msg.value.length>5000)return show('Il messaggio è troppo lungo (al massimo 5000 caratteri).');
    var ts=f.querySelector('[name=cf-turnstile-response]');
    if(!ts||!ts.value)return show('Conferma di essere una persona.');
    var fd=new FormData();
    ['name','email','type','message'].forEach(function(k){fd.append(k,f.elements[k].value);});
    fd.append('cf-turnstile-response',ts.value);
    files.forEach(function(file){fd.append('files',file,file.name);});
    btn.disabled=true;btn.textContent='Invio in corso…';
    fetch(f.action,{method:'POST',body:fd}).then(function(r){return r.json().catch(function(){return{error:'Qualcosa è andato storto.'};}).then(function(j){return[r.ok,j];});})
      .then(function(x){if(x[0]){[].forEach.call(f.querySelectorAll('label,.fb-list,.cf-turnstile,button'),function(el){el.hidden=true;});ok.hidden=false;ok.scrollIntoView({block:'center'});}else{show(emsg(x[1]));if(window.turnstile)turnstile.reset();}})
      .catch(function(){show('Connessione assente. Riprova o scrivi a admin@keep.it.com.');})
      .finally(function(){btn.disabled=false;btn.textContent='Invia';});
  });
})();
</script>

E-mail: [admin@keep.it.com](mailto:admin@keep.it.com) · Passo dopo passo: [Guida](/guide) · Come sono protetti i tuoi dati: [Sicurezza](/security) (in inglese).

## Risposte brevi

**Dopo aver scelto un elemento non viene incollato nulla.** Concedi l’autorizzazione Accessibilità: Impostazioni di Sistema → Privacy e sicurezza → Accessibilità → attiva Keepit (se è già nell’elenco, disattivalo e riattivalo). Nel frattempo premi ⌘V da te: l’elemento è già negli appunti.

**Ho dimenticato la password.** Nella finestra di sblocco fai clic su *Recupera accesso…* oppure usa Touch ID sullo stesso Mac. Senza uno dei due i dati non si possono recuperare.

**Dove sono i miei dati?** `~/Library/Application Support/Keepit/` (versione App Store: all’interno di `~/Library/Containers/com.it.keep/`).
