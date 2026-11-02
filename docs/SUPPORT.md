# Keepit support

Found a bug, a wrong translation, or have a question? Write below — a reply usually comes within a day or two. Bugs can also go to [GitHub Issues](https://github.com/andrey-insarov/Keepit/issues).

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
    <input name="files" type="file" accept="image/png,image/jpeg,image/gif,image/webp,image/heic" multiple>
  </label>
  <div class="cf-turnstile" data-sitekey="__TURNSTILE_SITE_KEY__" data-theme="light"></div>
  <p class="fb-err" id="fb-err" hidden></p>
  <button type="submit" class="btn">Send</button>
  <p class="fb-ok" id="fb-ok" hidden>Thank you — your message is on its way.</p>
</form>
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
<script>
(function(){
  var f=document.getElementById('fb'),err=document.getElementById('fb-err'),ok=document.getElementById('fb-ok'),
      msg=f.elements.message,count=document.getElementById('fb-count'),files=f.elements.files,btn=f.querySelector('button');
  function show(e){err.textContent=e;err.hidden=!e;}
  msg.addEventListener('input',function(){var n=msg.value.trim().length;count.textContent=n<70?(70-n)+' more characters':n+' characters';});
  f.addEventListener('submit',function(ev){
    ev.preventDefault();show('');
    if(!f.elements.name.value.trim())return show('Please enter your name.');
    if(!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(f.elements.email.value.trim()))return show('Please enter a valid e-mail address.');
    if(msg.value.trim().length<70)return show('Please describe it in at least 70 characters.');
    if(files.files.length>5)return show('At most 5 screenshots.');
    for(var i=0;i<files.files.length;i++){if(files.files[i].size>1048576)return show('“'+files.files[i].name+'” is larger than 1 MB.');}
    if(!f.querySelector('[name=cf-turnstile-response]')||!f.querySelector('[name=cf-turnstile-response]').value)return show('Please complete the anti-spam check.');
    btn.disabled=true;btn.textContent='Sending…';
    fetch(f.action,{method:'POST',body:new FormData(f)}).then(function(r){return r.json().catch(function(){return{error:'Something went wrong.'};}).then(function(j){return[r.ok,j];});})
      .then(function(x){if(x[0]){f.reset();ok.hidden=false;btn.hidden=true;count.textContent='at least 70 characters';}else{show(x[1].error||'Something went wrong.');if(window.turnstile)turnstile.reset();}})
      .catch(function(){show('No connection. Please try again or e-mail admin@it.com.');})
      .finally(function(){btn.disabled=false;btn.textContent='Send';});
  });
})();
</script>

E-mail: [admin@it.com](mailto:admin@it.com) · Step-by-step: [the user guide](guide.html) · How your data is protected: [security](security.html).

## Quick answers

**Nothing is pasted after I pick an item.** Grant the Accessibility permission: System Settings → Privacy & Security → Accessibility → enable Keepit (if it is already listed, toggle it off and on). Until then, press ⌘V yourself — the item is on the clipboard.

**I forgot the password.** Use *Recovery Access…* on the unlock dialog, or Touch ID on the same Mac. Without either, the data cannot be recovered.

**Where is my data?** `~/Library/Application Support/Keepit/` (App Store edition: inside `~/Library/Containers/com.it.keep/`).
