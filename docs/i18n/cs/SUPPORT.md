<!-- source: SUPPORT.md b7c2b2a3fb8a171f4a5c7809742c5a119d4e8cc1 -->
# Podpora Keepit

Našli jste chybu nebo špatný překlad, nebo máte otázku? Napište nám pomocí formuláře níže. Chyby můžete hlásit také na [GitHub Issues](https://github.com/andrey-insarov/Keepit/issues).

<form id="fb" class="fb" action="/api/feedback" method="post" enctype="multipart/form-data" novalidate>
  <div class="row2">
    <label>Jméno<input name="name" type="text" maxlength="100" autocomplete="name" required></label>
    <label>E-mail<input name="email" type="email" maxlength="254" autocomplete="email" required></label>
  </div>
  <label>Čeho se zpráva týká
    <select name="type" required>
      <option value="app">Problém s aplikací</option>
      <option value="translation">Chyba v překladu</option>
      <option value="other">Něco jiného</option>
    </select>
  </label>
  <label>Zpráva <span class="hint" id="fb-count">alespoň 70 znaků</span>
    <textarea name="message" rows="7" minlength="70" maxlength="5000" required placeholder="Co se stalo, co jste čekali, jakou verzi macOS a Keepit používáte…"></textarea>
  </label>
  <label>Snímky obrazovky <span class="hint">nepovinné · až 5 obrázků, každý do 1 MB</span>
    <input id="fb-files" type="file" accept="image/png,image/jpeg,image/gif,image/webp,image/heic" multiple>
  </label>
  <ul class="fb-list" id="fb-list" hidden></ul>
  <div class="cf-turnstile" data-sitekey="__TURNSTILE_SITE_KEY__" data-theme="light" data-language="cs"></div>
  <p class="fb-err" id="fb-err" hidden></p>
  <button type="submit" class="btn">Odeslat</button>
  <p class="hint fb-legal">To, co odešlete, nám přijde e-mailem a použijeme to jen k odpovědi. Viz <a href="/privacy">Zásady ochrany soukromí</a> (anglicky).</p>
  <div class="fb-ok" id="fb-ok" hidden><b>Děkujeme, zpráva byla odeslána.</b><br>Na vaši adresu posíláme potvrzení.</div>
</form>
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
<script>
(function(){
  var f=document.getElementById('fb'),err=document.getElementById('fb-err'),ok=document.getElementById('fb-ok'),
      msg=f.elements.message,count=document.getElementById('fb-count'),picker=document.getElementById('fb-files'),
      list=document.getElementById('fb-list'),btn=f.querySelector('button'),files=[];
  var PF={one:' znak',few:' znaky',other:' znaků'},PR=window.Intl&&Intl.PluralRules?new Intl.PluralRules('cs'):null;
  function pf(n){var k=PR?PR.select(n):'other';return Object.prototype.hasOwnProperty.call(PF,k)?PF[k]:PF.other;}
  var EM={name:'Uveďte prosím své jméno.',email:'Uveďte prosím platnou e-mailovou adresu.',type:'Vyberte prosím, čeho se zpráva týká.',short:'Popište to prosím alespoň 70 znaky.',long:'Zpráva je příliš dlouhá (nejvýše 5000 znaků).',files:'Přiložit lze nejvýše 5 snímků obrazovky. Odeberte přebytečné a odešlete formulář znovu.',total:'Přílohy jsou příliš velké (nejvýše 5 snímků obrazovky, každý do 1 MB).',form:'Formulář se nepodařilo přečíst.',spam:'Dokončete prosím kontrolu proti spamu.',send:'Zprávu se teď nepodařilo odeslat. Napište nám prosím e-mail.'};
  function emsg(r){var c=r&&r.code,n=(r&&r.file)||'';if(c==='toobig')return'„'+n+'“ je větší než 1 MB. Soubor odeberte nebo zmenšete. Potom formulář odešlete znovu.';if(c==='notimage')return'„'+n+'“ nebyl rozpoznán jako podporovaný obrázek. Soubor odeberte nebo nahraďte. Potom formulář odešlete znovu.';return typeof c==='string'&&Object.prototype.hasOwnProperty.call(EM,c)?EM[c]:'Něco se pokazilo.';}
  function show(e){err.textContent=e;err.hidden=!e;}
  function kb(n){return n<1048576?Math.round(n/1024)+' kB':(n/1048576).toFixed(1).replace('.',',')+' MB';}
  function render(){
    list.innerHTML='';list.hidden=!files.length;
    files.forEach(function(file,i){
      var li=document.createElement('li'),x=document.createElement('button');
      li.textContent=file.name+' · '+kb(file.size)+' ';x.type='button';x.textContent='Odebrat';x.setAttribute('aria-label','Odebrat '+file.name);
      x.addEventListener('click',function(){files.splice(i,1);render();show('');});li.appendChild(x);list.appendChild(li);
    });
    picker.hidden=files.length>=5;
  }
  picker.addEventListener('change',function(){
    show('');
    for(var i=0;i<picker.files.length;i++){
      var file=picker.files[i];
      if(files.length>=5){show('Nejvýše 5 snímků obrazovky. Ostatní nebyly přidány.');break;}
      if(file.size>1048576){show('„'+file.name+'“ je větší než 1 MB a nebyl přidán.');continue;}
      if(!/^image\//.test(file.type)){show('„'+file.name+'“ není obrázek a nebyl přidán.');continue;}
      files.push(file);
    }
    picker.value='';render();
  });
  msg.addEventListener('input',function(){var n=msg.value.trim().length;count.textContent=n<70?'ještě '+(70-n)+pf(70-n):n+pf(n);});
  f.addEventListener('submit',function(ev){
    ev.preventDefault();show('');
    if(!f.elements.name.value.trim())return show('Uveďte prosím své jméno.');
    if(!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(f.elements.email.value.trim()))return show('Uveďte prosím platnou e-mailovou adresu.');
    if(msg.value.trim().length<70)return show('Popište to prosím alespoň 70 znaky.');
    if(msg.value.length>5000)return show('Zpráva je příliš dlouhá (nejvýše 5000 znaků).');
    var ts=f.querySelector('[name=cf-turnstile-response]');
    if(!ts||!ts.value)return show('Dokončete prosím kontrolu proti spamu.');
    var fd=new FormData();
    ['name','email','type','message'].forEach(function(k){fd.append(k,f.elements[k].value);});
    fd.append('cf-turnstile-response',ts.value);
    files.forEach(function(file){fd.append('files',file,file.name);});
    btn.disabled=true;btn.textContent='Odesílá se…';
    fetch(f.action,{method:'POST',body:fd}).then(function(r){return r.json().catch(function(){return{error:'Něco se pokazilo.'};}).then(function(j){return[r.ok,j];});})
      .then(function(x){if(x[0]){[].forEach.call(f.querySelectorAll('label,.fb-list,.cf-turnstile,button'),function(el){el.hidden=true;});ok.hidden=false;ok.scrollIntoView({block:'center'});}else{show(emsg(x[1]));if(window.turnstile)turnstile.reset();}})
      .catch(function(){show('Spojení se nezdařilo. Zkuste to znovu nebo napište na admin@keep.it.com.');})
      .finally(function(){btn.disabled=false;btn.textContent='Odeslat';});
  });
})();
</script>

E-mail: [admin@keep.it.com](mailto:admin@keep.it.com) · Krok za krokem: [Příručka](/guide) · Jak jsou vaše data chráněna: [Zabezpečení](/security) (anglicky).

## Krátké odpovědi

**Po výběru položky se nic nevloží.** Udělte oprávnění Zpřístupnění: Nastavení systému → Soukromí a zabezpečení → Zpřístupnění → zapněte Keepit (pokud už v seznamu je, vypněte ho a znovu zapněte). Do té doby stiskněte ⌘V sami, položka už ve schránce je.

**Zapomněl(a) jsem heslo.** V okně pro odemčení klikněte na *Obnovit přístup…* nebo použijte Touch ID na stejném Macu. Bez jednoho z nich data obnovit nelze.

**Kde jsou moje data?** `~/Library/Application Support/Keepit/` (verze z App Storu: uvnitř `~/Library/Containers/com.it.keep/`).
