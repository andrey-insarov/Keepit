<!-- source: SUPPORT.md b7c2b2a3fb8a171f4a5c7809742c5a119d4e8cc1 -->
# Wsparcie Keepit

Widzisz błąd w aplikacji lub w tłumaczeniu albo masz pytanie? Napisz do nas w formularzu poniżej. Błędy możesz też zgłaszać w [GitHub Issues](https://github.com/andrey-insarov/Keepit/issues).

<form id="fb" class="fb" action="/api/feedback" method="post" enctype="multipart/form-data" novalidate>
  <div class="row2">
    <label>Imię<input name="name" type="text" maxlength="100" autocomplete="name" required></label>
    <label>E-mail<input name="email" type="email" maxlength="254" autocomplete="email" required></label>
  </div>
  <label>Czego dotyczy wiadomość
    <select name="type" required>
      <option value="app">Problem z aplikacją</option>
      <option value="translation">Błąd w tłumaczeniu</option>
      <option value="other">Coś innego</option>
    </select>
  </label>
  <label>Wiadomość <span class="hint" id="fb-count">co najmniej 70 znaków</span>
    <textarea name="message" rows="7" minlength="70" maxlength="5000" required placeholder="Co się stało, jakiego działania się spodziewasz, jakiej wersji macOS i Keepit używasz…"></textarea>
  </label>
  <label>Zrzuty ekranu <span class="hint">opcjonalnie · do 5 obrazów, każdy do 1 MB</span>
    <input id="fb-files" type="file" accept="image/png,image/jpeg,image/gif,image/webp,image/heic" multiple>
  </label>
  <ul class="fb-list" id="fb-list" hidden></ul>
  <div class="cf-turnstile" data-sitekey="__TURNSTILE_SITE_KEY__" data-theme="light" data-language="pl"></div>
  <p class="fb-err" id="fb-err" hidden></p>
  <button type="submit" class="btn">Wyślij</button>
  <p class="hint fb-legal">To, co wyślesz, trafi do nas e-mailem i posłuży wyłącznie do udzielenia odpowiedzi. Zobacz <a href="/privacy">Politykę prywatności</a> (po angielsku).</p>
  <div class="fb-ok" id="fb-ok" hidden><b>Dziękujemy, wiadomość została wysłana.</b><br>Potwierdzenie jest w drodze na Twój adres.</div>
</form>
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
<script>
(function(){
  var f=document.getElementById('fb'),err=document.getElementById('fb-err'),ok=document.getElementById('fb-ok'),
      msg=f.elements.message,count=document.getElementById('fb-count'),picker=document.getElementById('fb-files'),
      list=document.getElementById('fb-list'),btn=f.querySelector('button'),files=[];
  var PF={one:' znak',few:' znaki',many:' znaków',other:' znaków'},PR=window.Intl&&Intl.PluralRules?new Intl.PluralRules('pl'):null;
  function pf(n){var k=PR?PR.select(n):'other';return Object.prototype.hasOwnProperty.call(PF,k)?PF[k]:PF.other;}
  var EM={name:'Podaj swoje imię.',email:'Podaj prawidłowy adres e-mail.',type:'Wybierz, czego dotyczy wiadomość.',short:'Opisz sprawę w co najmniej 70 znakach.',long:'Wiadomość jest za długa (najwyżej 5000 znaków).',files:'Można dołączyć najwyżej 5 zrzutów ekranu. Usuń nadmiarowe i wyślij formularz ponownie.',total:'Załączniki są za duże (najwyżej 5 zrzutów ekranu, każdy do 1 MB).',form:'Nie udało się odczytać formularza.',spam:'Potwierdź, że jesteś człowiekiem.',send:'Nie udało się teraz wysłać wiadomości. Napisz do nas e-mail.'};
  function emsg(r){var c=r&&r.code,n=(r&&r.file)||'';if(c==='toobig')return'„'+n+'” ma ponad 1 MB. Usuń plik lub go zmniejsz. Następnie wyślij formularz ponownie.';if(c==='notimage')return'„'+n+'” nie został rozpoznany jako obsługiwany obraz. Usuń plik lub go zastąp. Następnie wyślij formularz ponownie.';return typeof c==='string'&&Object.prototype.hasOwnProperty.call(EM,c)?EM[c]:'Coś poszło nie tak.';}
  function show(e){err.textContent=e;err.hidden=!e;}
  function kb(n){return n<1048576?Math.round(n/1024)+' KB':(n/1048576).toFixed(1).replace('.',',')+' MB';}
  function render(){
    list.innerHTML='';list.hidden=!files.length;
    files.forEach(function(file,i){
      var li=document.createElement('li'),x=document.createElement('button');
      li.textContent=file.name+' · '+kb(file.size)+' ';x.type='button';x.textContent='Usuń';x.setAttribute('aria-label','Usuń '+file.name);
      x.addEventListener('click',function(){files.splice(i,1);render();show('');});li.appendChild(x);list.appendChild(li);
    });
    picker.hidden=files.length>=5;
  }
  picker.addEventListener('change',function(){
    show('');
    for(var i=0;i<picker.files.length;i++){
      var file=picker.files[i];
      if(files.length>=5){show('Najwyżej 5 zrzutów ekranu. Pozostałe nie zostały dodane.');break;}
      if(file.size>1048576){show('„'+file.name+'” ma ponad 1 MB i nie został dodany.');continue;}
      if(!/^image\//.test(file.type)){show('„'+file.name+'” nie jest obrazem i nie został dodany.');continue;}
      files.push(file);
    }
    picker.value='';render();
  });
  msg.addEventListener('input',function(){var n=msg.value.trim().length;count.textContent=n<70?'jeszcze '+(70-n)+pf(70-n):n+pf(n);});
  f.addEventListener('submit',function(ev){
    ev.preventDefault();show('');
    if(!f.elements.name.value.trim())return show('Podaj swoje imię.');
    if(!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(f.elements.email.value.trim()))return show('Podaj prawidłowy adres e-mail.');
    if(msg.value.trim().length<70)return show('Opisz sprawę w co najmniej 70 znakach.');
    if(msg.value.length>5000)return show('Wiadomość jest za długa (najwyżej 5000 znaków).');
    var ts=f.querySelector('[name=cf-turnstile-response]');
    if(!ts||!ts.value)return show('Potwierdź, że jesteś człowiekiem.');
    var fd=new FormData();
    ['name','email','type','message'].forEach(function(k){fd.append(k,f.elements[k].value);});
    fd.append('cf-turnstile-response',ts.value);
    files.forEach(function(file){fd.append('files',file,file.name);});
    btn.disabled=true;btn.textContent='Wysyłanie…';
    fetch(f.action,{method:'POST',body:fd}).then(function(r){return r.json().catch(function(){return{error:'Coś poszło nie tak.'};}).then(function(j){return[r.ok,j];});})
      .then(function(x){if(x[0]){[].forEach.call(f.querySelectorAll('label,.fb-list,.cf-turnstile,button'),function(el){el.hidden=true;});ok.hidden=false;ok.scrollIntoView({block:'center'});}else{show(emsg(x[1]));if(window.turnstile)turnstile.reset();}})
      .catch(function(){show('Brak połączenia. Spróbuj ponownie lub napisz na admin@keep.it.com.');})
      .finally(function(){btn.disabled=false;btn.textContent='Wyślij';});
  });
})();
</script>

E-mail: [admin@keep.it.com](mailto:admin@keep.it.com) · Krok po kroku: [Podręcznik](/guide) · Jak chronione są Twoje dane: [Bezpieczeństwo](/security) (po angielsku).

## Krótkie odpowiedzi

**Po wybraniu elementu nic się nie wkleja.** Przyznaj uprawnienie Dostępność: Ustawienia systemowe → Prywatność i ochrona → Dostępność → włącz Keepit (jeśli jest już na liście, wyłącz go i włącz ponownie). Do tego czasu naciskaj ⌘V samodzielnie, element jest już w schowku.

**Nie pamiętam hasła.** W oknie odblokowywania kliknij *Odzyskaj dostęp…* albo użyj Touch ID na tym samym Macu. Bez jednego z nich danych nie da się odzyskać.

**Gdzie są moje dane?** `~/Library/Application Support/Keepit/` (wersja z App Store: wewnątrz `~/Library/Containers/com.it.keep/`).
