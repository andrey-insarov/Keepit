<!-- source: SUPPORT.md b7c2b2a3fb8a171f4a5c7809742c5a119d4e8cc1 -->
# Keepit 支援

發現了錯誤或不正確的翻譯，或者有問題想問？請用下方的表單寫信給我們。錯誤也可以回報到 [GitHub Issues](https://github.com/andrey-insarov/Keepit/issues)。

<form id="fb" class="fb" action="/api/feedback" method="post" enctype="multipart/form-data" novalidate>
  <div class="row2">
    <label>姓名<input name="name" type="text" maxlength="100" autocomplete="name" required></label>
    <label>電子郵件<input name="email" type="email" maxlength="254" autocomplete="email" required></label>
  </div>
  <label>問題類型
    <select name="type" required>
      <option value="app">App 的問題</option>
      <option value="translation">翻譯錯誤</option>
      <option value="other">其他</option>
    </select>
  </label>
  <label>訊息 <span class="hint" id="fb-count">至少 70 個字元</span>
    <textarea name="message" rows="7" minlength="70" maxlength="5000" required placeholder="發生了什麼事、你原本預期的結果、使用的 macOS 與 Keepit 版本…"></textarea>
  </label>
  <label>截圖 <span class="hint">選填 · 最多 5 張圖片，每張不超過 1 MB</span>
    <input id="fb-files" type="file" accept="image/png,image/jpeg,image/gif,image/webp,image/heic" multiple>
  </label>
  <ul class="fb-list" id="fb-list" hidden></ul>
  <div class="cf-turnstile" data-sitekey="__TURNSTILE_SITE_KEY__" data-theme="light" data-language="zh-TW"></div>
  <p class="fb-err" id="fb-err" hidden></p>
  <button type="submit" class="btn">傳送</button>
  <p class="hint fb-legal">你送出的內容會以電子郵件寄給我們，只用於回覆你。請參閱<a href="/privacy">隱私權政策</a>（英文）。</p>
  <div class="fb-ok" id="fb-ok" hidden><b>謝謝，訊息已送出。</b><br>確認信正在寄往你的信箱。</div>
</form>
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
<script>
(function(){
  var f=document.getElementById('fb'),err=document.getElementById('fb-err'),ok=document.getElementById('fb-ok'),
      msg=f.elements.message,count=document.getElementById('fb-count'),picker=document.getElementById('fb-files'),
      list=document.getElementById('fb-list'),btn=f.querySelector('button'),files=[];
  var EM={name:'請填寫你的姓名。',email:'請填寫有效的電子郵件地址。',type:'請選擇問題類型。',short:'請用至少 70 個字元描述問題。',long:'訊息太長（最多 5000 個字元）。',files:'最多只能附上 5 張截圖。請移除多餘的檔案，然後重新送出表單。',total:'附件太大（最多 5 張截圖，每張不超過 1 MB）。',form:'無法讀取表單。',spam:'請完成人機驗證。',send:'目前無法送出訊息。請寫電子郵件給我們。'};
  function emsg(r){var c=r&&r.code,n=(r&&r.file)||'';if(c==='toobig')return'「'+n+'」超過 1 MB。請移除或縮小該檔案，然後重新送出表單。';if(c==='notimage')return'「'+n+'」無法辨識為支援的圖片。請移除或更換該檔案，然後重新送出表單。';return typeof c==='string'&&Object.prototype.hasOwnProperty.call(EM,c)?EM[c]:'發生了錯誤。';}
  function show(e){err.textContent=e;err.hidden=!e;}
  function kb(n){return n<1048576?Math.round(n/1024)+' KB':(n/1048576).toFixed(1).replace('.','.')+' MB';}
  function render(){
    list.innerHTML='';list.hidden=!files.length;
    files.forEach(function(file,i){
      var li=document.createElement('li'),x=document.createElement('button');
      li.textContent=file.name+' · '+kb(file.size)+' ';x.type='button';x.textContent='移除';x.setAttribute('aria-label','移除 '+file.name);
      x.addEventListener('click',function(){files.splice(i,1);render();show('');});li.appendChild(x);list.appendChild(li);
    });
    picker.hidden=files.length>=5;
  }
  picker.addEventListener('change',function(){
    show('');
    for(var i=0;i<picker.files.length;i++){
      var file=picker.files[i];
      if(files.length>=5){show('最多 5 張截圖。其餘的未加入。');break;}
      if(file.size>1048576){show('「'+file.name+'」超過 1 MB，未加入。');continue;}
      if(!/^image\//.test(file.type)){show('「'+file.name+'」不是圖片，未加入。');continue;}
      files.push(file);
    }
    picker.value='';render();
  });
  msg.addEventListener('input',function(){var n=msg.value.trim().length;count.textContent=n<70?'還差 '+(70-n)+' 個字元':n+' 個字元';});
  f.addEventListener('submit',function(ev){
    ev.preventDefault();show('');
    if(!f.elements.name.value.trim())return show('請填寫你的姓名。');
    if(!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(f.elements.email.value.trim()))return show('請填寫有效的電子郵件地址。');
    if(msg.value.trim().length<70)return show('請用至少 70 個字元描述問題。');
    if(msg.value.length>5000)return show('訊息太長（最多 5000 個字元）。');
    var ts=f.querySelector('[name=cf-turnstile-response]');
    if(!ts||!ts.value)return show('請完成人機驗證。');
    var fd=new FormData();
    ['name','email','type','message'].forEach(function(k){fd.append(k,f.elements[k].value);});
    fd.append('cf-turnstile-response',ts.value);
    files.forEach(function(file){fd.append('files',file,file.name);});
    btn.disabled=true;btn.textContent='正在傳送…';
    fetch(f.action,{method:'POST',body:fd}).then(function(r){return r.json().catch(function(){return{error:'發生了錯誤。'};}).then(function(j){return[r.ok,j];});})
      .then(function(x){if(x[0]){[].forEach.call(f.querySelectorAll('label,.fb-list,.cf-turnstile,button'),function(el){el.hidden=true;});ok.hidden=false;ok.scrollIntoView({block:'center'});}else{show(emsg(x[1]));if(window.turnstile)turnstile.reset();}})
      .catch(function(){show('無法連線。請再試一次，或寫信到 admin@keep.it.com。');})
      .finally(function(){btn.disabled=false;btn.textContent='傳送';});
  });
})();
</script>

電子郵件：[admin@keep.it.com](mailto:admin@keep.it.com) · 逐步說明：[使用手冊](/guide) · 你的資料如何受到保護：[安全性](/security)（英文）。

## 簡短解答

**選擇項目後沒有貼上任何內容。** 請授予「輔助使用」權限：系統設定 → 隱私權與安全性（香港版 macOS 顯示為「私隱與保安」）→ 輔助使用 → 開啟 Keepit（如果已在列表中，請先關閉再重新開啟）。在此之前請自行按 ⌘V，項目已經在剪貼板上了。

**我忘記密碼了。** 在解鎖視窗中按一下「復原存取…」，或在同一部 Mac 上使用 Touch ID。兩者都沒有的話，資料無法復原。

**我的資料在哪裡？** `~/Library/Application Support/Keepit/`（App Store 版本：位於 `~/Library/Containers/com.it.keep/` 內）。
