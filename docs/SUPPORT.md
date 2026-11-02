# Keepit support

Found a bug, a wrong translation, or have a question? Write below. Bugs can also go to [GitHub Issues](https://github.com/andrey-insarov/Keepit/issues).

<form id="fb" class="fb" action="/api/feedback" method="post" enctype="multipart/form-data" novalidate>
  <div class="row2">
    <label>Name<input name="name" type="text" maxlength="100" autocomplete="name" required></label>
    <label>E-mail<input name="email" type="email" maxlength="254" autocomplete="email" required></label>
  </div>
  <label>What is it about
    <select name="type" required>
      <option value="app">App issue</option>
      <option value="translation">Translation issue</option>
      <option value="other">Other</option>
    </select>
  </label>
  <label>Message <span class="hint" id="fb-count">at least 70 characters</span>
    <textarea name="message" rows="7" minlength="70" maxlength="5000" required placeholder="What happened, what you expected, macOS and Keepit versions…"></textarea>
  </label>
  <label>Screenshots <span class="hint">optional · up to 5 images, 1 MB each</span>
    <input id="fb-files" type="file" accept="image/png,image/jpeg,image/gif,image/webp,image/heic" multiple>
  </label>
  <ul class="fb-list" id="fb-list" hidden></ul>
  <div class="cf-turnstile" data-sitekey="__TURNSTILE_SITE_KEY__" data-theme="light"></div>
  <p class="fb-err" id="fb-err" hidden></p>
  <button type="submit" class="btn">Send</button>
  <p class="hint fb-legal">What you send is e-mailed to us and used only to answer you — see the <a href="privacy.html">privacy policy</a>.</p>
  <div class="fb-ok" id="fb-ok" hidden><b>Thank you — your message has been sent.</b><br>A copy went to your e-mail address.</div>
</form>
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
<script>
(function(){
  var f=document.getElementById('fb'),err=document.getElementById('fb-err'),ok=document.getElementById('fb-ok'),
      msg=f.elements.message,count=document.getElementById('fb-count'),picker=document.getElementById('fb-files'),
      list=document.getElementById('fb-list'),btn=f.querySelector('button'),files=[];
  function show(e){err.textContent=e;err.hidden=!e;}
  function kb(n){return n<1048576?Math.round(n/1024)+' KB':(n/1048576).toFixed(1)+' MB';}
  function render(){
    list.innerHTML='';list.hidden=!files.length;
    files.forEach(function(file,i){
      var li=document.createElement('li'),x=document.createElement('button');
      li.textContent=file.name+' · '+kb(file.size)+' ';x.type='button';x.textContent='Remove';x.setAttribute('aria-label','Remove '+file.name);
      x.addEventListener('click',function(){files.splice(i,1);render();show('');});li.appendChild(x);list.appendChild(li);
    });
    picker.hidden=files.length>=5;
  }
  picker.addEventListener('change',function(){
    show('');
    for(var i=0;i<picker.files.length;i++){
      var file=picker.files[i];
      if(files.length>=5){show('At most 5 screenshots — the rest were not added.');break;}
      if(file.size>1048576){show('“'+file.name+'” is larger than 1 MB and was not added.');continue;}
      if(!/^image\//.test(file.type)){show('“'+file.name+'” is not an image and was not added.');continue;}
      files.push(file);
    }
    picker.value='';render();
  });
  msg.addEventListener('input',function(){var n=msg.value.trim().length;count.textContent=n<70?(70-n)+' more characters':n+' characters';});
  f.addEventListener('submit',function(ev){
    ev.preventDefault();show('');
    if(!f.elements.name.value.trim())return show('Please enter your name.');
    if(!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(f.elements.email.value.trim()))return show('Please enter a valid e-mail address.');
    if(msg.value.trim().length<70)return show('Please describe it in at least 70 characters.');
    if(msg.value.length>5000)return show('The message is too long (5000 characters at most).');
    var ts=f.querySelector('[name=cf-turnstile-response]');
    if(!ts||!ts.value)return show('Please complete the anti-spam check.');
    var fd=new FormData();
    ['name','email','type','message'].forEach(function(k){fd.append(k,f.elements[k].value);});
    fd.append('cf-turnstile-response',ts.value);
    files.forEach(function(file){fd.append('files',file,file.name);});
    btn.disabled=true;btn.textContent='Sending…';
    fetch(f.action,{method:'POST',body:fd}).then(function(r){return r.json().catch(function(){return{error:'Something went wrong.'};}).then(function(j){return[r.ok,j];});})
      .then(function(x){if(x[0]){[].forEach.call(f.querySelectorAll('label,.fb-list,.cf-turnstile,button'),function(el){el.hidden=true;});ok.hidden=false;ok.scrollIntoView({block:'center'});}else{show(x[1].error||'Something went wrong.');if(window.turnstile)turnstile.reset();}})
      .catch(function(){show('No connection. Please try again or e-mail admin@keep.it.com.');})
      .finally(function(){btn.disabled=false;btn.textContent='Send';});
  });
})();
</script>

E-mail: [admin@keep.it.com](mailto:admin@keep.it.com) · Step-by-step: [the user guide](guide.html) · How your data is protected: [security](security.html).

## Quick answers

**Nothing is pasted after I pick an item.** Grant the Accessibility permission: System Settings → Privacy & Security → Accessibility → enable Keepit (if it is already listed, toggle it off and on). Until then, press ⌘V yourself — the item is on the clipboard.

**I forgot the password.** Use *Recovery Access…* on the unlock dialog, or Touch ID on the same Mac. Without either, the data cannot be recovered.

**Where is my data?** `~/Library/Application Support/Keepit/` (App Store edition: inside `~/Library/Containers/com.it.keep/`).
