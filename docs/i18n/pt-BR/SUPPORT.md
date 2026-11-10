<!-- source: SUPPORT.md b7c2b2a3fb8a171f4a5c7809742c5a119d4e8cc1 -->
# Suporte do Keepit

Encontrou um erro, uma tradução incorreta ou tem alguma dúvida? Escreva abaixo. Erros também podem ser relatados no [GitHub Issues](https://github.com/andrey-insarov/Keepit/issues).

<form id="fb" class="fb" action="/api/feedback" method="post" enctype="multipart/form-data" novalidate>
  <div class="row2">
    <label>Nome<input name="name" type="text" maxlength="100" autocomplete="name" required></label>
    <label>E-mail<input name="email" type="email" maxlength="254" autocomplete="email" required></label>
  </div>
  <label>Assunto
    <select name="type" required>
      <option value="app">Problema no app</option>
      <option value="translation">Erro de tradução</option>
      <option value="other">Outro</option>
    </select>
  </label>
  <label>Mensagem <span class="hint" id="fb-count">pelo menos 70 caracteres</span>
    <textarea name="message" rows="7" minlength="70" maxlength="5000" required placeholder="O que aconteceu, o que você esperava e as versões do macOS e do Keepit…"></textarea>
  </label>
  <label>Capturas de tela <span class="hint">opcional · até 5 imagens de 1 MB cada</span>
    <input id="fb-files" type="file" accept="image/png,image/jpeg,image/gif,image/webp,image/heic" multiple>
  </label>
  <ul class="fb-list" id="fb-list" hidden></ul>
  <div class="cf-turnstile" data-sitekey="__TURNSTILE_SITE_KEY__" data-theme="light" data-language="pt-BR"></div>
  <p class="fb-err" id="fb-err" hidden></p>
  <button type="submit" class="btn">Enviar</button>
  <p class="hint fb-legal">O que você envia chega até nós por e-mail e é usado apenas para responder a você. Veja a <a href="/privacy">política de privacidade</a> (em inglês).</p>
  <div class="fb-ok" id="fb-ok" hidden><b>Obrigado, a mensagem foi enviada.</b><br>Uma confirmação foi enviada para o seu endereço.</div>
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
      li.textContent=file.name+' · '+kb(file.size)+' ';x.type='button';x.textContent='Remover';x.setAttribute('aria-label','Remover '+file.name);
      x.addEventListener('click',function(){files.splice(i,1);render();show('');});li.appendChild(x);list.appendChild(li);
    });
    picker.hidden=files.length>=5;
  }
  picker.addEventListener('change',function(){
    show('');
    for(var i=0;i<picker.files.length;i++){
      var file=picker.files[i];
      if(files.length>=5){show('No máximo 5 capturas. As demais não foram adicionadas.');break;}
      if(file.size>1048576){show('“'+file.name+'” tem mais de 1 MB e não foi adicionado.');continue;}
      if(!/^image\//.test(file.type)){show('“'+file.name+'” não é uma imagem e não foi adicionado.');continue;}
      files.push(file);
    }
    picker.value='';render();
  });
  msg.addEventListener('input',function(){var n=msg.value.trim().length;count.textContent=n<70?'faltam '+(70-n)+' caracteres':n+' caracteres';});
  f.addEventListener('submit',function(ev){
    ev.preventDefault();show('');
    if(!f.elements.name.value.trim())return show('Informe o seu nome.');
    if(!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(f.elements.email.value.trim()))return show('Informe um endereço de e-mail válido.');
    if(msg.value.trim().length<70)return show('Descreva em pelo menos 70 caracteres.');
    if(msg.value.length>5000)return show('A mensagem está longa demais (no máximo 5000 caracteres).');
    var ts=f.querySelector('[name=cf-turnstile-response]');
    if(!ts||!ts.value)return show('Conclua a verificação antispam.');
    var fd=new FormData();
    ['name','email','type','message'].forEach(function(k){fd.append(k,f.elements[k].value);});
    fd.append('cf-turnstile-response',ts.value);
    files.forEach(function(file){fd.append('files',file,file.name);});
    btn.disabled=true;btn.textContent='Enviando…';
    fetch(f.action,{method:'POST',body:fd}).then(function(r){return r.json().catch(function(){return{error:'Algo deu errado.'};}).then(function(j){return[r.ok,j];});})
      .then(function(x){if(x[0]){[].forEach.call(f.querySelectorAll('label,.fb-list,.cf-turnstile,button'),function(el){el.hidden=true;});ok.hidden=false;ok.scrollIntoView({block:'center'});}else{show(x[1].error||'Algo deu errado.');if(window.turnstile)turnstile.reset();}})
      .catch(function(){show('Sem conexão. Tente de novo ou escreva para admin@keep.it.com.');})
      .finally(function(){btn.disabled=false;btn.textContent='Enviar';});
  });
})();
</script>

E-mail: [admin@keep.it.com](mailto:admin@keep.it.com) · Passo a passo: o [guia](/guide) · Como seus dados são protegidos: [segurança](/security) (em inglês).

## Respostas rápidas

**Nada é colado depois que escolho um item.** Conceda a permissão de Acessibilidade: Ajustes do Sistema → Privacidade e Segurança → Acessibilidade → ative o Keepit (se ele já estiver na lista, desative e ative de novo). Enquanto isso, pressione ⌘V você mesmo: o item já está na área de transferência.

**Esqueci a senha.** Clique em *Recuperar acesso…* na janela de desbloqueio ou use o Touch ID no mesmo Mac. Sem nenhum dos dois, não há como recuperar os dados.

**Onde ficam os meus dados?** `~/Library/Application Support/Keepit/` (versão da App Store: dentro de `~/Library/Containers/com.it.keep/`).
