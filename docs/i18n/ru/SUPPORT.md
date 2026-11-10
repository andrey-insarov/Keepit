<!-- source: SUPPORT.md b7c2b2a3fb8a171f4a5c7809742c5a119d4e8cc1 -->
# Поддержка Keepit

Нашли ошибку, неточный перевод или есть вопрос? Напишите ниже. Об ошибках можно сообщать и в [GitHub Issues](https://github.com/andrey-insarov/Keepit/issues).

<form id="fb" class="fb" action="/api/feedback" method="post" enctype="multipart/form-data" novalidate>
  <div class="row2">
    <label>Имя<input name="name" type="text" maxlength="100" autocomplete="name" required></label>
    <label>E-mail<input name="email" type="email" maxlength="254" autocomplete="email" required></label>
  </div>
  <label>Тема
    <select name="type" required>
      <option value="app">Проблема в приложении</option>
      <option value="translation">Ошибка перевода</option>
      <option value="other">Другое</option>
    </select>
  </label>
  <label>Сообщение <span class="hint" id="fb-count">не меньше 70 символов</span>
    <textarea name="message" rows="7" minlength="70" maxlength="5000" required placeholder="Что произошло, чего вы ожидали, версии macOS и Keepit…"></textarea>
  </label>
  <label>Снимки экрана <span class="hint">по желанию · до 5 изображений, по 1 МБ</span>
    <input id="fb-files" type="file" accept="image/png,image/jpeg,image/gif,image/webp,image/heic" multiple>
  </label>
  <ul class="fb-list" id="fb-list" hidden></ul>
  <div class="cf-turnstile" data-sitekey="__TURNSTILE_SITE_KEY__" data-theme="light" data-language="ru"></div>
  <p class="fb-err" id="fb-err" hidden></p>
  <button type="submit" class="btn">Отправить</button>
  <p class="hint fb-legal">Отправленное приходит нам по e-mail и используется только для ответа вам. См. <a href="/privacy">политику конфиденциальности</a> (англ.).</p>
  <div class="fb-ok" id="fb-ok" hidden><b>Спасибо, сообщение отправлено.</b><br>Подтверждение ушло на ваш адрес.</div>
</form>
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
<script>
(function(){
  var f=document.getElementById('fb'),err=document.getElementById('fb-err'),ok=document.getElementById('fb-ok'),
      msg=f.elements.message,count=document.getElementById('fb-count'),picker=document.getElementById('fb-files'),
      list=document.getElementById('fb-list'),btn=f.querySelector('button'),files=[];
  function show(e){err.textContent=e;err.hidden=!e;}
  function kb(n){return n<1048576?Math.round(n/1024)+' КБ':(n/1048576).toFixed(1).replace('.',',')+' МБ';}
  function render(){
    list.innerHTML='';list.hidden=!files.length;
    files.forEach(function(file,i){
      var li=document.createElement('li'),x=document.createElement('button');
      li.textContent=file.name+' · '+kb(file.size)+' ';x.type='button';x.textContent='Убрать';x.setAttribute('aria-label','Убрать '+file.name);
      x.addEventListener('click',function(){files.splice(i,1);render();show('');});li.appendChild(x);list.appendChild(li);
    });
    picker.hidden=files.length>=5;
  }
  picker.addEventListener('change',function(){
    show('');
    for(var i=0;i<picker.files.length;i++){
      var file=picker.files[i];
      if(files.length>=5){show('Не больше 5 снимков. Остальные не добавлены.');break;}
      if(file.size>1048576){show('«'+file.name+'» больше 1 МБ и не добавлен.');continue;}
      if(!/^image\//.test(file.type)){show('«'+file.name+'» не является изображением и не добавлен.');continue;}
      files.push(file);
    }
    picker.value='';render();
  });
  msg.addEventListener('input',function(){var n=msg.value.trim().length;count.textContent=n<70?'ещё '+(70-n)+' симв.':n+' симв.';});
  f.addEventListener('submit',function(ev){
    ev.preventDefault();show('');
    if(!f.elements.name.value.trim())return show('Укажите имя.');
    if(!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(f.elements.email.value.trim()))return show('Укажите правильный адрес e-mail.');
    if(msg.value.trim().length<70)return show('Опишите, пожалуйста, хотя бы в 70 символах.');
    if(msg.value.length>5000)return show('Сообщение слишком длинное (не больше 5000 символов).');
    var ts=f.querySelector('[name=cf-turnstile-response]');
    if(!ts||!ts.value)return show('Пройдите, пожалуйста, проверку от спама.');
    var fd=new FormData();
    ['name','email','type','message'].forEach(function(k){fd.append(k,f.elements[k].value);});
    fd.append('cf-turnstile-response',ts.value);
    files.forEach(function(file){fd.append('files',file,file.name);});
    btn.disabled=true;btn.textContent='Отправка…';
    fetch(f.action,{method:'POST',body:fd}).then(function(r){return r.json().catch(function(){return{error:'Что-то пошло не так.'};}).then(function(j){return[r.ok,j];});})
      .then(function(x){if(x[0]){[].forEach.call(f.querySelectorAll('label,.fb-list,.cf-turnstile,button'),function(el){el.hidden=true;});ok.hidden=false;ok.scrollIntoView({block:'center'});}else{show(x[1].error||'Что-то пошло не так.');if(window.turnstile)turnstile.reset();}})
      .catch(function(){show('Нет соединения. Попробуйте ещё раз или напишите на admin@keep.it.com.');})
      .finally(function(){btn.disabled=false;btn.textContent='Отправить';});
  });
})();
</script>

E-mail: [admin@keep.it.com](mailto:admin@keep.it.com) · Пошагово: [руководство](/guide) · Как защищены ваши данные: [безопасность](/security) (англ.).

## Короткие ответы

**После выбора элемента ничего не вставляется.** Дайте разрешение Универсального доступа: Системные настройки → Конфиденциальность и безопасность → Универсальный доступ → включите Keepit (если он уже в списке, выключите и включите снова). До тех пор нажимайте ⌘V сами: элемент уже в буфере обмена.

**Я забыл пароль.** Нажмите *Восстановление доступа…* в окне разблокировки или воспользуйтесь Touch ID на том же Mac. Без них данные восстановить нельзя.

**Где мои данные?** `~/Library/Application Support/Keepit/` (версия из App Store: внутри `~/Library/Containers/com.it.keep/`).
