<!-- source: SUPPORT.md b7c2b2a3fb8a171f4a5c7809742c5a119d4e8cc1 -->
# Soporte de Keepit

¿Has encontrado un error o una traducción incorrecta, o tienes alguna pregunta? Escríbenos aquí abajo. Los errores también se pueden comunicar en [GitHub Issues](https://github.com/andrey-insarov/Keepit/issues).

<form id="fb" class="fb" action="/api/feedback" method="post" enctype="multipart/form-data" novalidate>
  <div class="row2">
    <label>Nombre<input name="name" type="text" maxlength="100" autocomplete="name" required></label>
    <label>E-mail<input name="email" type="email" maxlength="254" autocomplete="email" required></label>
  </div>
  <label>Asunto
    <select name="type" required>
      <option value="app">Problema con la app</option>
      <option value="translation">Error de traducción</option>
      <option value="other">Otro</option>
    </select>
  </label>
  <label>Mensaje <span class="hint" id="fb-count">70 caracteres como mínimo</span>
    <textarea name="message" rows="7" minlength="70" maxlength="5000" required placeholder="Qué ha pasado, qué esperabas y qué versiones de macOS y Keepit usas…"></textarea>
  </label>
  <label>Capturas de pantalla <span class="hint">opcional · hasta 5 imágenes de 1 MB cada una</span>
    <input id="fb-files" type="file" accept="image/png,image/jpeg,image/gif,image/webp,image/heic" multiple>
  </label>
  <ul class="fb-list" id="fb-list" hidden></ul>
  <div class="cf-turnstile" data-sitekey="__TURNSTILE_SITE_KEY__" data-theme="light" data-language="es"></div>
  <p class="fb-err" id="fb-err" hidden></p>
  <button type="submit" class="btn">Enviar</button>
  <p class="hint fb-legal">Lo que envíes nos llega por correo electrónico y solo se usa para responderte. Consulta la <a href="/privacy">política de privacidad</a> (en inglés).</p>
  <div class="fb-ok" id="fb-ok" hidden><b>Gracias, el mensaje se ha enviado.</b><br>Hemos enviado una confirmación a tu dirección.</div>
</form>
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
<script>
(function(){
  var f=document.getElementById('fb'),err=document.getElementById('fb-err'),ok=document.getElementById('fb-ok'),
      msg=f.elements.message,count=document.getElementById('fb-count'),picker=document.getElementById('fb-files'),
      list=document.getElementById('fb-list'),btn=f.querySelector('button'),files=[];
  function show(e){err.textContent=e;err.hidden=!e;}
  function kb(n){return n<1048576?Math.round(n/1024)+' KB':(n/1048576).toFixed(1).replace('.',',')+' MB';}
  function render(){
    list.innerHTML='';list.hidden=!files.length;
    files.forEach(function(file,i){
      var li=document.createElement('li'),x=document.createElement('button');
      li.textContent=file.name+' · '+kb(file.size)+' ';x.type='button';x.textContent='Quitar';x.setAttribute('aria-label','Quitar '+file.name);
      x.addEventListener('click',function(){files.splice(i,1);render();show('');});li.appendChild(x);list.appendChild(li);
    });
    picker.hidden=files.length>=5;
  }
  picker.addEventListener('change',function(){
    show('');
    for(var i=0;i<picker.files.length;i++){
      var file=picker.files[i];
      if(files.length>=5){show('5 capturas como máximo. Las demás no se han añadido.');break;}
      if(file.size>1048576){show('«'+file.name+'» ocupa más de 1 MB y no se ha añadido.');continue;}
      if(!/^image\//.test(file.type)){show('«'+file.name+'» no es una imagen y no se ha añadido.');continue;}
      files.push(file);
    }
    picker.value='';render();
  });
  msg.addEventListener('input',function(){var n=msg.value.trim().length;count.textContent=n<70?'faltan '+(70-n)+' caracteres':n+' caracteres';});
  f.addEventListener('submit',function(ev){
    ev.preventDefault();show('');
    if(!f.elements.name.value.trim())return show('Indica tu nombre.');
    if(!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(f.elements.email.value.trim()))return show('Indica una dirección de correo válida.');
    if(msg.value.trim().length<70)return show('Descríbelo con 70 caracteres como mínimo.');
    if(msg.value.length>5000)return show('El mensaje es demasiado largo (5000 caracteres como máximo).');
    var ts=f.querySelector('[name=cf-turnstile-response]');
    if(!ts||!ts.value)return show('Completa la verificación antispam.');
    var fd=new FormData();
    ['name','email','type','message'].forEach(function(k){fd.append(k,f.elements[k].value);});
    fd.append('cf-turnstile-response',ts.value);
    files.forEach(function(file){fd.append('files',file,file.name);});
    btn.disabled=true;btn.textContent='Enviando…';
    fetch(f.action,{method:'POST',body:fd}).then(function(r){return r.json().catch(function(){return{error:'Algo ha salido mal.'};}).then(function(j){return[r.ok,j];});})
      .then(function(x){if(x[0]){[].forEach.call(f.querySelectorAll('label,.fb-list,.cf-turnstile,button'),function(el){el.hidden=true;});ok.hidden=false;ok.scrollIntoView({block:'center'});}else{show(x[1].error||'Algo ha salido mal.');if(window.turnstile)turnstile.reset();}})
      .catch(function(){show('No hay conexión. Inténtalo de nuevo o escribe a admin@keep.it.com.');})
      .finally(function(){btn.disabled=false;btn.textContent='Enviar';});
  });
})();
</script>

Correo: [admin@keep.it.com](mailto:admin@keep.it.com) · Paso a paso: la [guía](/guide) · Cómo se protegen tus datos: [seguridad](/security) (en inglés).

## Respuestas rápidas

**No se pega nada después de elegir un elemento.** Concede el permiso de Accesibilidad: Ajustes del Sistema → Privacidad y seguridad → Accesibilidad → activa Keepit (si ya aparece en la lista, desactívalo y vuelve a activarlo). Mientras tanto, pulsa ⌘V tú mismo: el elemento ya está en el portapapeles.

**He olvidado la contraseña.** Haz clic en *Recuperar acceso…* en la ventana de desbloqueo o usa Touch ID en el mismo Mac. Sin ninguna de las dos cosas, los datos no se pueden recuperar.

**¿Dónde están mis datos?** `~/Library/Application Support/Keepit/` (versión del App Store: dentro de `~/Library/Containers/com.it.keep/`).
