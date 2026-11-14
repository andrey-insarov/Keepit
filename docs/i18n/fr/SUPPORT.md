<!-- source: SUPPORT.md b7c2b2a3fb8a171f4a5c7809742c5a119d4e8cc1 -->
# Assistance Keepit

Vous avez trouvé un bug, une erreur de traduction, ou vous avez une question ? Écrivez-nous ci-dessous. Les bugs peuvent aussi être signalés dans [GitHub Issues](https://github.com/andrey-insarov/Keepit/issues).

<form id="fb" class="fb" action="/api/feedback" method="post" enctype="multipart/form-data" novalidate>
  <div class="row2">
    <label>Nom<input name="name" type="text" maxlength="100" autocomplete="name" required></label>
    <label>E-mail<input name="email" type="email" maxlength="254" autocomplete="email" required></label>
  </div>
  <label>Sujet
    <select name="type" required>
      <option value="app">Problème dans l’app</option>
      <option value="translation">Erreur de traduction</option>
      <option value="other">Autre</option>
    </select>
  </label>
  <label>Message <span class="hint" id="fb-count">70 caractères minimum</span>
    <textarea name="message" rows="7" minlength="70" maxlength="5000" required placeholder="Ce qui s’est passé, ce que vous attendiez, vos versions de macOS et de Keepit…"></textarea>
  </label>
  <label>Captures d’écran <span class="hint">facultatif · jusqu’à 5 images de 1 Mo chacune</span>
    <input id="fb-files" type="file" accept="image/png,image/jpeg,image/gif,image/webp,image/heic" multiple>
  </label>
  <ul class="fb-list" id="fb-list" hidden></ul>
  <div class="cf-turnstile" data-sitekey="__TURNSTILE_SITE_KEY__" data-theme="light" data-language="fr"></div>
  <p class="fb-err" id="fb-err" hidden></p>
  <button type="submit" class="btn">Envoyer</button>
  <p class="hint fb-legal">Ce que vous envoyez nous parvient par e-mail et sert uniquement à vous répondre. Voir la <a href="/privacy">politique de confidentialité</a> (en anglais).</p>
  <div class="fb-ok" id="fb-ok" hidden><b>Merci, votre message est envoyé.</b><br>Une confirmation a été envoyée à votre adresse.</div>
</form>
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
<script>
(function(){
  var f=document.getElementById('fb'),err=document.getElementById('fb-err'),ok=document.getElementById('fb-ok'),
      msg=f.elements.message,count=document.getElementById('fb-count'),picker=document.getElementById('fb-files'),
      list=document.getElementById('fb-list'),btn=f.querySelector('button'),files=[];
  var EM={name:'Indiquez votre nom.',email:'Indiquez une adresse e-mail valide.',type:'Choisissez le sujet du message.',short:'Merci de décrire le problème en 70 caractères au moins.',long:'Le message est trop long (5000 caractères au maximum).',files:'5 captures au maximum. Les autres n’ont pas été ajoutées.',total:'Les pièces jointes sont trop volumineuses (5 captures de 1 Mo au maximum).',form:'Le formulaire n’a pas pu être lu.',spam:'Merci de valider la vérification anti-spam.',send:'Le message n’a pas pu être envoyé pour le moment. Écrivez-nous plutôt par e-mail.'};
  function emsg(r){if(r.code==='toobig')return'« '+(r.file||'')+' » dépasse 1 Mo et n’a pas été ajouté.';if(r.code==='notimage')return'« '+(r.file||'')+' » n’est pas une image et n’a pas été ajouté.';return EM[r.code]||'Une erreur s’est produite.';}
  function show(e){err.textContent=e;err.hidden=!e;}
  function kb(n){return n<1048576?Math.round(n/1024)+' Ko':(n/1048576).toFixed(1).replace('.',',')+' Mo';}
  function render(){
    list.innerHTML='';list.hidden=!files.length;
    files.forEach(function(file,i){
      var li=document.createElement('li'),x=document.createElement('button');
      li.textContent=file.name+' · '+kb(file.size)+' ';x.type='button';x.textContent='Retirer';x.setAttribute('aria-label','Retirer '+file.name);
      x.addEventListener('click',function(){files.splice(i,1);render();show('');});li.appendChild(x);list.appendChild(li);
    });
    picker.hidden=files.length>=5;
  }
  picker.addEventListener('change',function(){
    show('');
    for(var i=0;i<picker.files.length;i++){
      var file=picker.files[i];
      if(files.length>=5){show('5 captures au maximum. Les autres n’ont pas été ajoutées.');break;}
      if(file.size>1048576){show('« '+file.name+' » dépasse 1 Mo et n’a pas été ajouté.');continue;}
      if(!/^image\//.test(file.type)){show('« '+file.name+' » n’est pas une image et n’a pas été ajouté.');continue;}
      files.push(file);
    }
    picker.value='';render();
  });
  msg.addEventListener('input',function(){var n=msg.value.trim().length;count.textContent=n<70?'encore '+(70-n)+' caractères':n+' caractères';});
  f.addEventListener('submit',function(ev){
    ev.preventDefault();show('');
    if(!f.elements.name.value.trim())return show('Indiquez votre nom.');
    if(!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(f.elements.email.value.trim()))return show('Indiquez une adresse e-mail valide.');
    if(msg.value.trim().length<70)return show('Merci de décrire le problème en 70 caractères au moins.');
    if(msg.value.length>5000)return show('Le message est trop long (5000 caractères au maximum).');
    var ts=f.querySelector('[name=cf-turnstile-response]');
    if(!ts||!ts.value)return show('Merci de valider la vérification anti-spam.');
    var fd=new FormData();
    ['name','email','type','message'].forEach(function(k){fd.append(k,f.elements[k].value);});
    fd.append('cf-turnstile-response',ts.value);
    files.forEach(function(file){fd.append('files',file,file.name);});
    btn.disabled=true;btn.textContent='Envoi…';
    fetch(f.action,{method:'POST',body:fd}).then(function(r){return r.json().catch(function(){return{error:'Une erreur s’est produite.'};}).then(function(j){return[r.ok,j];});})
      .then(function(x){if(x[0]){[].forEach.call(f.querySelectorAll('label,.fb-list,.cf-turnstile,button'),function(el){el.hidden=true;});ok.hidden=false;ok.scrollIntoView({block:'center'});}else{show(emsg(x[1]));if(window.turnstile)turnstile.reset();}})
      .catch(function(){show('Pas de connexion. Réessayez ou écrivez à admin@keep.it.com.');})
      .finally(function(){btn.disabled=false;btn.textContent='Envoyer';});
  });
})();
</script>

E-mail : [admin@keep.it.com](mailto:admin@keep.it.com) · Pas à pas : le [guide](/guide) · Comment vos données sont protégées : [sécurité](/security) (en anglais).

## Réponses rapides

**Rien n’est collé après le choix d’un élément.** Accordez l’autorisation d’accessibilité : Réglages Système → Confidentialité et sécurité → Accessibilité → activez Keepit (s’il figure déjà dans la liste, désactivez-le puis réactivez-le). En attendant, appuyez vous-même sur ⌘V : l’élément est déjà dans le presse-papiers.

**J’ai oublié le mot de passe.** Cliquez sur *Récupérer l’accès…* dans la fenêtre de déverrouillage ou utilisez Touch ID sur le même Mac. Sans l’un ni l’autre, les données sont irrécupérables.

**Où sont mes données ?** `~/Library/Application Support/Keepit/` (version App Store : dans `~/Library/Containers/com.it.keep/`).
