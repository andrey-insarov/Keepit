<!-- source: SUPPORT.md b7c2b2a3fb8a171f4a5c7809742c5a119d4e8cc1 -->
# Підтримка Keepit

Знайшли помилку, неточний переклад або маєте запитання? Напишіть нижче. Про помилки можна повідомляти і в [GitHub Issues](https://github.com/andrey-insarov/Keepit/issues).

<form id="fb" class="fb" action="/api/feedback" method="post" enctype="multipart/form-data" novalidate>
  <div class="row2">
    <label>Ім’я<input name="name" type="text" maxlength="100" autocomplete="name" required></label>
    <label>E-mail<input name="email" type="email" maxlength="254" autocomplete="email" required></label>
  </div>
  <label>Тема
    <select name="type" required>
      <option value="app">Проблема в програмі</option>
      <option value="translation">Помилка перекладу</option>
      <option value="other">Інше</option>
    </select>
  </label>
  <label>Повідомлення <span class="hint" id="fb-count">не менше 70 символів</span>
    <textarea name="message" rows="7" minlength="70" maxlength="5000" required placeholder="Що сталося, чого ви очікували, версії macOS і Keepit…"></textarea>
  </label>
  <label>Знімки екрана <span class="hint">за бажанням · до 5 зображень, по 1 МБ</span>
    <input id="fb-files" type="file" accept="image/png,image/jpeg,image/gif,image/webp,image/heic" multiple>
  </label>
  <ul class="fb-list" id="fb-list" hidden></ul>
  <div class="cf-turnstile" data-sitekey="__TURNSTILE_SITE_KEY__" data-theme="light" data-language="uk"></div>
  <p class="fb-err" id="fb-err" hidden></p>
  <button type="submit" class="btn">Надіслати</button>
  <p class="hint fb-legal">Надіслане надходить нам електронною поштою і використовується лише для відповіді вам — див. <a href="/privacy">політику конфіденційності</a> (англ.).</p>
  <div class="fb-ok" id="fb-ok" hidden><b>Дякуємо — повідомлення надіслано.</b><br>Підтвердження надіслано на вашу адресу.</div>
</form>
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
<script>
(function(){
  var f=document.getElementById('fb'),err=document.getElementById('fb-err'),ok=document.getElementById('fb-ok'),
      msg=f.elements.message,count=document.getElementById('fb-count'),picker=document.getElementById('fb-files'),
      list=document.getElementById('fb-list'),btn=f.querySelector('button'),files=[];
  var EM={name:'Вкажіть ім’я.',email:'Вкажіть правильну адресу e-mail.',type:'Виберіть тему повідомлення.',short:'Опишіть, будь ласка, хоча б у 70 символах.',long:'Повідомлення задовге (не більше 5000 символів).',files:'Не більше 5 знімків — решту не додано.',total:'Вкладення завеликі (не більше 5 знімків по 1 МБ).',form:'Не вдалося прочитати форму.',spam:'Пройдіть, будь ласка, перевірку від спаму.',send:'Зараз не вдалося надіслати повідомлення. Напишіть нам, будь ласка, електронною поштою.'};
  function emsg(r){if(r.code==='toobig')return'«'+(r.file||'')+'» більший за 1 МБ, його не додано.';if(r.code==='notimage')return'«'+(r.file||'')+'» — не зображення, його не додано.';return EM[r.code]||'Щось пішло не так.';}
  function show(e){err.textContent=e;err.hidden=!e;}
  function kb(n){return n<1048576?Math.round(n/1024)+' КБ':(n/1048576).toFixed(1).replace('.',',')+' МБ';}
  function render(){
    list.innerHTML='';list.hidden=!files.length;
    files.forEach(function(file,i){
      var li=document.createElement('li'),x=document.createElement('button');
      li.textContent=file.name+' · '+kb(file.size)+' ';x.type='button';x.textContent='Прибрати';x.setAttribute('aria-label','Прибрати '+file.name);
      x.addEventListener('click',function(){files.splice(i,1);render();show('');});li.appendChild(x);list.appendChild(li);
    });
    picker.hidden=files.length>=5;
  }
  picker.addEventListener('change',function(){
    show('');
    for(var i=0;i<picker.files.length;i++){
      var file=picker.files[i];
      if(files.length>=5){show('Не більше 5 знімків — решту не додано.');break;}
      if(file.size>1048576){show('«'+file.name+'» більший за 1 МБ, його не додано.');continue;}
      if(!/^image\//.test(file.type)){show('«'+file.name+'» — не зображення, його не додано.');continue;}
      files.push(file);
    }
    picker.value='';render();
  });
  msg.addEventListener('input',function(){var n=msg.value.trim().length;count.textContent=n<70?'ще '+(70-n)+' симв.':n+' симв.';});
  f.addEventListener('submit',function(ev){
    ev.preventDefault();show('');
    if(!f.elements.name.value.trim())return show('Вкажіть ім’я.');
    if(!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(f.elements.email.value.trim()))return show('Вкажіть правильну адресу e-mail.');
    if(msg.value.trim().length<70)return show('Опишіть, будь ласка, хоча б у 70 символах.');
    if(msg.value.length>5000)return show('Повідомлення задовге (не більше 5000 символів).');
    var ts=f.querySelector('[name=cf-turnstile-response]');
    if(!ts||!ts.value)return show('Пройдіть, будь ласка, перевірку від спаму.');
    var fd=new FormData();
    ['name','email','type','message'].forEach(function(k){fd.append(k,f.elements[k].value);});
    fd.append('cf-turnstile-response',ts.value);
    files.forEach(function(file){fd.append('files',file,file.name);});
    btn.disabled=true;btn.textContent='Надсилання…';
    fetch(f.action,{method:'POST',body:fd}).then(function(r){return r.json().catch(function(){return{error:'Щось пішло не так.'};}).then(function(j){return[r.ok,j];});})
      .then(function(x){if(x[0]){[].forEach.call(f.querySelectorAll('label,.fb-list,.cf-turnstile,button'),function(el){el.hidden=true;});ok.hidden=false;ok.scrollIntoView({block:'center'});}else{show(emsg(x[1]));if(window.turnstile)turnstile.reset();}})
      .catch(function(){show('Немає з’єднання. Спробуйте ще раз або напишіть на admin@keep.it.com.');})
      .finally(function(){btn.disabled=false;btn.textContent='Надіслати';});
  });
})();
</script>

E-mail: [admin@keep.it.com](mailto:admin@keep.it.com) · Покроково: [посібник](/guide) · Як захищено ваші дані: [безпека](/security) (англ.).

## Короткі відповіді

**Після вибору елемента нічого не вставляється.** Надайте дозвіл Доступності: Системні параметри → Приватність і безпека → Доступність → увімкніть Keepit (якщо він уже у списку, вимкніть і ввімкніть знову). До того часу натискайте ⌘V самі — елемент уже в буфері обміну.

**Я забув пароль.** Натисніть *Відновлення доступу…* у вікні розблокування або скористайтеся Touch ID на тому самому Mac. Без них дані відновити неможливо.

**Де мої дані?** `~/Library/Application Support/Keepit/` (версія з App Store: всередині `~/Library/Containers/com.it.keep/`).
