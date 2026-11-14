<!-- source: SUPPORT.md b7c2b2a3fb8a171f4a5c7809742c5a119d4e8cc1 -->
# Keepit-support

Heb je een bug of een vertaalfout gevonden, of heb je een vraag? Stuur ons een bericht via het formulier hieronder. Bugs kun je ook melden op [GitHub Issues](https://github.com/andrey-insarov/Keepit/issues).

<form id="fb" class="fb" action="/api/feedback" method="post" enctype="multipart/form-data" novalidate>
  <div class="row2">
    <label>Naam<input name="name" type="text" maxlength="100" autocomplete="name" required></label>
    <label>E-mail<input name="email" type="email" maxlength="254" autocomplete="email" required></label>
  </div>
  <label>Waar gaat het over
    <select name="type" required>
      <option value="app">Probleem met de app</option>
      <option value="translation">Vertaalfout</option>
      <option value="other">Iets anders</option>
    </select>
  </label>
  <label>Bericht <span class="hint" id="fb-count">minimaal 70 tekens</span>
    <textarea name="message" rows="7" minlength="70" maxlength="5000" required placeholder="Wat gebeurde er, wat had je verwacht, welke versies van macOS en Keepit gebruik je…"></textarea>
  </label>
  <label>Schermafbeeldingen <span class="hint">optioneel · maximaal 5 afbeeldingen van elk 1 MB</span>
    <input id="fb-files" type="file" accept="image/png,image/jpeg,image/gif,image/webp,image/heic" multiple>
  </label>
  <ul class="fb-list" id="fb-list" hidden></ul>
  <div class="cf-turnstile" data-sitekey="__TURNSTILE_SITE_KEY__" data-theme="light" data-language="nl"></div>
  <p class="fb-err" id="fb-err" hidden></p>
  <button type="submit" class="btn">Versturen</button>
  <p class="hint fb-legal">Wat je verstuurt, komt per e-mail bij ons binnen en wordt alleen gebruikt om je te antwoorden. Zie het <a href="/privacy">privacybeleid</a> (Engels).</p>
  <div class="fb-ok" id="fb-ok" hidden><b>Bedankt, het bericht is verstuurd.</b><br>Er is een bevestiging onderweg naar je adres.</div>
</form>
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
<script>
(function(){
  var f=document.getElementById('fb'),err=document.getElementById('fb-err'),ok=document.getElementById('fb-ok'),
      msg=f.elements.message,count=document.getElementById('fb-count'),picker=document.getElementById('fb-files'),
      list=document.getElementById('fb-list'),btn=f.querySelector('button'),files=[];
  var PF={one:' teken',other:' tekens'},PR=window.Intl&&Intl.PluralRules?new Intl.PluralRules('nl'):null;
  function pf(n){var k=PR?PR.select(n):'other';return Object.prototype.hasOwnProperty.call(PF,k)?PF[k]:PF.other;}
  var EM={name:'Vul je naam in.',email:'Vul een geldig e-mailadres in.',type:'Kies waar het over gaat.',short:'Beschrijf het in minimaal 70 tekens.',long:'Het bericht is te lang (maximaal 5000 tekens).',files:'Je kunt maximaal 5 schermafbeeldingen meesturen. Verwijder de overige en verstuur het formulier opnieuw.',total:'De bijlagen zijn te groot (maximaal 5 schermafbeeldingen van elk 1 MB).',form:'Het formulier kon niet worden gelezen.',spam:'Rond de spamcontrole af.',send:'Het bericht kon nu niet worden verstuurd. Stuur ons een e-mail.'};
  function emsg(r){var c=r&&r.code,n=(r&&r.file)||'';if(c==='toobig')return'‘'+n+'’ is groter dan 1 MB. Verwijder het bestand of maak het kleiner. Verstuur het formulier daarna opnieuw.';if(c==='notimage')return'‘'+n+'’ is niet herkend als ondersteunde afbeelding. Verwijder of vervang het bestand. Verstuur het formulier daarna opnieuw.';return typeof c==='string'&&Object.prototype.hasOwnProperty.call(EM,c)?EM[c]:'Er is iets misgegaan.';}
  function show(e){err.textContent=e;err.hidden=!e;}
  function kb(n){return n<1048576?Math.round(n/1024)+' kB':(n/1048576).toFixed(1).replace('.',',')+' MB';}
  function render(){
    list.innerHTML='';list.hidden=!files.length;
    files.forEach(function(file,i){
      var li=document.createElement('li'),x=document.createElement('button');
      li.textContent=file.name+' · '+kb(file.size)+' ';x.type='button';x.textContent='Verwijder';x.setAttribute('aria-label','Verwijder '+file.name);
      x.addEventListener('click',function(){files.splice(i,1);render();show('');});li.appendChild(x);list.appendChild(li);
    });
    picker.hidden=files.length>=5;
  }
  picker.addEventListener('change',function(){
    show('');
    for(var i=0;i<picker.files.length;i++){
      var file=picker.files[i];
      if(files.length>=5){show('Maximaal 5 schermafbeeldingen. De overige zijn niet toegevoegd.');break;}
      if(file.size>1048576){show('‘'+file.name+'’ is groter dan 1 MB en is niet toegevoegd.');continue;}
      if(!/^image\//.test(file.type)){show('‘'+file.name+'’ is geen afbeelding en is niet toegevoegd.');continue;}
      files.push(file);
    }
    picker.value='';render();
  });
  msg.addEventListener('input',function(){var n=msg.value.trim().length;count.textContent=n<70?'nog '+(70-n)+pf(70-n):n+pf(n);});
  f.addEventListener('submit',function(ev){
    ev.preventDefault();show('');
    if(!f.elements.name.value.trim())return show('Vul je naam in.');
    if(!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(f.elements.email.value.trim()))return show('Vul een geldig e-mailadres in.');
    if(msg.value.trim().length<70)return show('Beschrijf het in minimaal 70 tekens.');
    if(msg.value.length>5000)return show('Het bericht is te lang (maximaal 5000 tekens).');
    var ts=f.querySelector('[name=cf-turnstile-response]');
    if(!ts||!ts.value)return show('Rond de spamcontrole af.');
    var fd=new FormData();
    ['name','email','type','message'].forEach(function(k){fd.append(k,f.elements[k].value);});
    fd.append('cf-turnstile-response',ts.value);
    files.forEach(function(file){fd.append('files',file,file.name);});
    btn.disabled=true;btn.textContent='Bezig met versturen…';
    fetch(f.action,{method:'POST',body:fd}).then(function(r){return r.json().catch(function(){return{error:'Er is iets misgegaan.'};}).then(function(j){return[r.ok,j];});})
      .then(function(x){if(x[0]){[].forEach.call(f.querySelectorAll('label,.fb-list,.cf-turnstile,button'),function(el){el.hidden=true;});ok.hidden=false;ok.scrollIntoView({block:'center'});}else{show(emsg(x[1]));if(window.turnstile)turnstile.reset();}})
      .catch(function(){show('Geen verbinding. Probeer het opnieuw of mail naar admin@keep.it.com.');})
      .finally(function(){btn.disabled=false;btn.textContent='Versturen';});
  });
})();
</script>

E-mail: [admin@keep.it.com](mailto:admin@keep.it.com) · Stap voor stap: [Handleiding](/guide) · Zo zijn je gegevens beschermd: [Beveiliging](/security) (Engels).

## Korte antwoorden

**Na het kiezen van een item wordt er niets geplakt.** Geef toestemming voor Toegankelijkheid: Systeeminstellingen → Privacy en beveiliging → Toegankelijkheid → zet Keepit aan (staat het al in de lijst, zet het dan uit en weer aan). Tot die tijd druk je zelf op ⌘V; het item staat al op het klembord.

**Ik ben mijn wachtwoord vergeten.** Klik in het ontgrendelvenster op *Toegang herstellen…* of gebruik Touch ID op dezelfde Mac. Zonder een van beide zijn de gegevens niet terug te halen.

**Waar staan mijn gegevens?** `~/Library/Application Support/Keepit/` (App Store-versie: binnen `~/Library/Containers/com.it.keep/`).
