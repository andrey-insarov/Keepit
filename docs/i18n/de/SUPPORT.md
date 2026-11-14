<!-- source: SUPPORT.md b7c2b2a3fb8a171f4a5c7809742c5a119d4e8cc1 -->
# Keepit-Support

Du hast einen Fehler oder eine falsche Übersetzung gefunden oder hast eine Frage? Schreib uns unten. Fehler kannst du auch bei [GitHub Issues](https://github.com/andrey-insarov/Keepit/issues) melden.

<form id="fb" class="fb" action="/api/feedback" method="post" enctype="multipart/form-data" novalidate>
  <div class="row2">
    <label>Name<input name="name" type="text" maxlength="100" autocomplete="name" required></label>
    <label>E-mail<input name="email" type="email" maxlength="254" autocomplete="email" required></label>
  </div>
  <label>Worum geht es
    <select name="type" required>
      <option value="app">Problem mit der App</option>
      <option value="translation">Übersetzungsfehler</option>
      <option value="other">Sonstiges</option>
    </select>
  </label>
  <label>Nachricht <span class="hint" id="fb-count">mindestens 70 Zeichen</span>
    <textarea name="message" rows="7" minlength="70" maxlength="5000" required placeholder="Was ist passiert, was hast du erwartet, welche Versionen von macOS und Keepit…"></textarea>
  </label>
  <label>Bildschirmfotos <span class="hint">optional · bis zu 5 Bilder, je 1 MB</span>
    <input id="fb-files" type="file" accept="image/png,image/jpeg,image/gif,image/webp,image/heic" multiple>
  </label>
  <ul class="fb-list" id="fb-list" hidden></ul>
  <div class="cf-turnstile" data-sitekey="__TURNSTILE_SITE_KEY__" data-theme="light" data-language="de"></div>
  <p class="fb-err" id="fb-err" hidden></p>
  <button type="submit" class="btn">Senden</button>
  <p class="hint fb-legal">Was du abschickst, erreicht uns per E-Mail und wird nur verwendet, um dir zu antworten. Siehe <a href="/privacy">Datenschutzerklärung</a> (englisch).</p>
  <div class="fb-ok" id="fb-ok" hidden><b>Danke, die Nachricht ist gesendet.</b><br>Eine Bestätigung ist an deine Adresse unterwegs.</div>
</form>
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
<script>
(function(){
  var f=document.getElementById('fb'),err=document.getElementById('fb-err'),ok=document.getElementById('fb-ok'),
      msg=f.elements.message,count=document.getElementById('fb-count'),picker=document.getElementById('fb-files'),
      list=document.getElementById('fb-list'),btn=f.querySelector('button'),files=[];
  var EM={name:'Bitte gib deinen Namen an.',email:'Bitte gib eine gültige E-Mail-Adresse an.',type:'Bitte wähle aus, worum es geht.',short:'Bitte beschreibe es in mindestens 70 Zeichen.',long:'Die Nachricht ist zu lang (höchstens 5000 Zeichen).',files:'Höchstens 5 Bildschirmfotos. Die übrigen wurden nicht hinzugefügt.',total:'Die Anhänge sind zu groß (höchstens 5 Bildschirmfotos mit je 1 MB).',form:'Das Formular konnte nicht gelesen werden.',spam:'Bitte schließe die Spam-Prüfung ab.',send:'Die Nachricht konnte gerade nicht gesendet werden. Bitte schreib uns eine E-Mail.'};
  function emsg(r){if(r.code==='toobig')return'„'+(r.file||'')+'“ ist größer als 1 MB und wurde nicht hinzugefügt.';if(r.code==='notimage')return'„'+(r.file||'')+'“ ist kein Bild und wurde nicht hinzugefügt.';return EM[r.code]||'Etwas ist schiefgegangen.';}
  function show(e){err.textContent=e;err.hidden=!e;}
  function kb(n){return n<1048576?Math.round(n/1024)+' KB':(n/1048576).toFixed(1).replace('.',',')+' MB';}
  function render(){
    list.innerHTML='';list.hidden=!files.length;
    files.forEach(function(file,i){
      var li=document.createElement('li'),x=document.createElement('button');
      li.textContent=file.name+' · '+kb(file.size)+' ';x.type='button';x.textContent='Entfernen';x.setAttribute('aria-label','Entfernen '+file.name);
      x.addEventListener('click',function(){files.splice(i,1);render();show('');});li.appendChild(x);list.appendChild(li);
    });
    picker.hidden=files.length>=5;
  }
  picker.addEventListener('change',function(){
    show('');
    for(var i=0;i<picker.files.length;i++){
      var file=picker.files[i];
      if(files.length>=5){show('Höchstens 5 Bildschirmfotos. Die übrigen wurden nicht hinzugefügt.');break;}
      if(file.size>1048576){show('„'+file.name+'“ ist größer als 1 MB und wurde nicht hinzugefügt.');continue;}
      if(!/^image\//.test(file.type)){show('„'+file.name+'“ ist kein Bild und wurde nicht hinzugefügt.');continue;}
      files.push(file);
    }
    picker.value='';render();
  });
  msg.addEventListener('input',function(){var n=msg.value.trim().length;count.textContent=n<70?'noch '+(70-n)+' Zeichen':n+' Zeichen';});
  f.addEventListener('submit',function(ev){
    ev.preventDefault();show('');
    if(!f.elements.name.value.trim())return show('Bitte gib deinen Namen an.');
    if(!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(f.elements.email.value.trim()))return show('Bitte gib eine gültige E-Mail-Adresse an.');
    if(msg.value.trim().length<70)return show('Bitte beschreibe es in mindestens 70 Zeichen.');
    if(msg.value.length>5000)return show('Die Nachricht ist zu lang (höchstens 5000 Zeichen).');
    var ts=f.querySelector('[name=cf-turnstile-response]');
    if(!ts||!ts.value)return show('Bitte schließe die Spam-Prüfung ab.');
    var fd=new FormData();
    ['name','email','type','message'].forEach(function(k){fd.append(k,f.elements[k].value);});
    fd.append('cf-turnstile-response',ts.value);
    files.forEach(function(file){fd.append('files',file,file.name);});
    btn.disabled=true;btn.textContent='Wird gesendet…';
    fetch(f.action,{method:'POST',body:fd}).then(function(r){return r.json().catch(function(){return{error:'Etwas ist schiefgegangen.'};}).then(function(j){return[r.ok,j];});})
      .then(function(x){if(x[0]){[].forEach.call(f.querySelectorAll('label,.fb-list,.cf-turnstile,button'),function(el){el.hidden=true;});ok.hidden=false;ok.scrollIntoView({block:'center'});}else{show(emsg(x[1]));if(window.turnstile)turnstile.reset();}})
      .catch(function(){show('Keine Verbindung. Versuch es noch einmal oder schreib an admin@keep.it.com.');})
      .finally(function(){btn.disabled=false;btn.textContent='Senden';});
  });
})();
</script>

E-Mail: [admin@keep.it.com](mailto:admin@keep.it.com) · Schritt für Schritt: [Handbuch](/guide) · So sind deine Daten geschützt: [Sicherheit](/security) (englisch).

## Kurze Antworten

**Nach der Auswahl eines Eintrags wird nichts eingefügt.** Erteile die Berechtigung für Bedienungshilfen: Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen → Keepit einschalten (steht es schon in der Liste, schalte es aus und wieder ein). Bis dahin drückst du ⌘V selbst, der Eintrag liegt bereits in der Zwischenablage.

**Ich habe das Passwort vergessen.** Klicke im Entsperrdialog auf *Zugang wiederherstellen…* oder nutze Touch ID auf demselben Mac. Ohne beides lassen sich die Daten nicht wiederherstellen.

**Wo liegen meine Daten?** `~/Library/Application Support/Keepit/` (App-Store-Version: innerhalb von `~/Library/Containers/com.it.keep/`).
