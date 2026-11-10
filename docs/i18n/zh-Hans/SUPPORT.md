<!-- source: SUPPORT.md b7c2b2a3fb8a171f4a5c7809742c5a119d4e8cc1 -->
# Keepit 支持

发现了错误或不准确的翻译，或者有问题想问？请在下面留言。错误也可以提交到 [GitHub Issues](https://github.com/andrey-insarov/Keepit/issues)。

<form id="fb" class="fb" action="/api/feedback" method="post" enctype="multipart/form-data" novalidate>
  <div class="row2">
    <label>姓名<input name="name" type="text" maxlength="100" autocomplete="name" required></label>
    <label>E-mail<input name="email" type="email" maxlength="254" autocomplete="email" required></label>
  </div>
  <label>问题类型
    <select name="type" required>
      <option value="app">应用问题</option>
      <option value="translation">翻译错误</option>
      <option value="other">其他</option>
    </select>
  </label>
  <label>留言 <span class="hint" id="fb-count">至少 70 个字符</span>
    <textarea name="message" rows="7" minlength="70" maxlength="5000" required placeholder="发生了什么、你原本期望的结果，以及 macOS 和 Keepit 的版本…"></textarea>
  </label>
  <label>截屏 <span class="hint">可选 · 最多 5 张图片，每张不超过 1 MB</span>
    <input id="fb-files" type="file" accept="image/png,image/jpeg,image/gif,image/webp,image/heic" multiple>
  </label>
  <ul class="fb-list" id="fb-list" hidden></ul>
  <div class="cf-turnstile" data-sitekey="__TURNSTILE_SITE_KEY__" data-theme="light" data-language="zh-CN"></div>
  <p class="fb-err" id="fb-err" hidden></p>
  <button type="submit" class="btn">发送</button>
  <p class="hint fb-legal">你提交的内容会通过电子邮件发给我们，并且只用于回复你。请参阅<a href="/privacy">隐私政策</a>（英文）。</p>
  <div class="fb-ok" id="fb-ok" hidden><b>谢谢，留言已发送。</b><br>确认邮件已发送到你的邮箱。</div>
</form>
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
<script>
(function(){
  var f=document.getElementById('fb'),err=document.getElementById('fb-err'),ok=document.getElementById('fb-ok'),
      msg=f.elements.message,count=document.getElementById('fb-count'),picker=document.getElementById('fb-files'),
      list=document.getElementById('fb-list'),btn=f.querySelector('button'),files=[];
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
      if(files.length>=5){show('最多 5 张截屏，其余的没有添加。');break;}
      if(file.size>1048576){show('“'+file.name+'”超过 1 MB，没有添加。');continue;}
      if(!/^image\//.test(file.type)){show('“'+file.name+'”不是图片，没有添加。');continue;}
      files.push(file);
    }
    picker.value='';render();
  });
  msg.addEventListener('input',function(){var n=msg.value.trim().length;count.textContent=n<70?'还差 '+(70-n)+' 个字符':n+' 个字符';});
  f.addEventListener('submit',function(ev){
    ev.preventDefault();show('');
    if(!f.elements.name.value.trim())return show('请填写姓名。');
    if(!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(f.elements.email.value.trim()))return show('请填写有效的电子邮件地址。');
    if(msg.value.trim().length<70)return show('请至少用 70 个字符描述问题。');
    if(msg.value.length>5000)return show('留言太长（最多 5000 个字符）。');
    var ts=f.querySelector('[name=cf-turnstile-response]');
    if(!ts||!ts.value)return show('请完成防垃圾信息验证。');
    var fd=new FormData();
    ['name','email','type','message'].forEach(function(k){fd.append(k,f.elements[k].value);});
    fd.append('cf-turnstile-response',ts.value);
    files.forEach(function(file){fd.append('files',file,file.name);});
    btn.disabled=true;btn.textContent='正在发送…';
    fetch(f.action,{method:'POST',body:fd}).then(function(r){return r.json().catch(function(){return{error:'出了点问题。'};}).then(function(j){return[r.ok,j];});})
      .then(function(x){if(x[0]){[].forEach.call(f.querySelectorAll('label,.fb-list,.cf-turnstile,button'),function(el){el.hidden=true;});ok.hidden=false;ok.scrollIntoView({block:'center'});}else{show(x[1].error||'出了点问题。');if(window.turnstile)turnstile.reset();}})
      .catch(function(){show('无法连接。请重试，或发邮件到 admin@keep.it.com。');})
      .finally(function(){btn.disabled=false;btn.textContent='发送';});
  });
})();
</script>

电子邮件：[admin@keep.it.com](mailto:admin@keep.it.com) · 分步说明：[使用指南](/guide) · 数据如何受到保护：[安全](/security)（英文）

## 简短解答

**选择项目后没有粘贴任何内容。** 请授予辅助功能权限：打开“系统设置”→“隐私与安全性”→“辅助功能”，把 Keepit 打开（如果它已经在列表中，请先关闭再重新打开）。在此之前请自己按 ⌘V，项目已经在剪贴板里了。

**我忘记了密码。** 在解锁窗口中点按“恢复访问…”，或者在同一台 Mac 上使用Touch ID。两者都没有的话，数据无法恢复。

**我的数据在哪里？** `~/Library/Application Support/Keepit/`（App Store 版本位于 `~/Library/Containers/com.it.keep/` 内）。
