<!-- source: SUPPORT.md b7c2b2a3fb8a171f4a5c7809742c5a119d4e8cc1 -->
# Keepitサポート

不具合や誤訳を見つけた場合や、ご質問がある場合は、以下のフォームからお知らせください。不具合は[GitHub Issues](https://github.com/andrey-insarov/Keepit/issues)でも報告できます。

<form id="fb" class="fb" action="/api/feedback" method="post" enctype="multipart/form-data" novalidate>
  <div class="row2">
    <label>お名前<input name="name" type="text" maxlength="100" autocomplete="name" required></label>
    <label>E-mail<input name="email" type="email" maxlength="254" autocomplete="email" required></label>
  </div>
  <label>お問い合わせの種類
    <select name="type" required>
      <option value="app">アプリの問題</option>
      <option value="translation">翻訳の誤り</option>
      <option value="other">その他</option>
    </select>
  </label>
  <label>メッセージ <span class="hint" id="fb-count">70文字以上</span>
    <textarea name="message" rows="7" minlength="70" maxlength="5000" required placeholder="何が起きたか、どうなると期待していたか、macOSとKeepitのバージョン…"></textarea>
  </label>
  <label>スクリーンショット <span class="hint">任意 · 画像5枚まで、各1 MB以内</span>
    <input id="fb-files" type="file" accept="image/png,image/jpeg,image/gif,image/webp,image/heic" multiple>
  </label>
  <ul class="fb-list" id="fb-list" hidden></ul>
  <div class="cf-turnstile" data-sitekey="__TURNSTILE_SITE_KEY__" data-theme="light" data-language="ja"></div>
  <p class="fb-err" id="fb-err" hidden></p>
  <button type="submit" class="btn">送信</button>
  <p class="hint fb-legal">送信された内容はメールで私たちに届き、ご返信のためだけに使用します。<a href="/privacy">プライバシーポリシー</a>（英語）をご覧ください。</p>
  <div class="fb-ok" id="fb-ok" hidden><b>ありがとうございます。メッセージを送信しました。</b><br>確認のメールをご入力のアドレスにお送りしました。</div>
</form>
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
<script>
(function(){
  var f=document.getElementById('fb'),err=document.getElementById('fb-err'),ok=document.getElementById('fb-ok'),
      msg=f.elements.message,count=document.getElementById('fb-count'),picker=document.getElementById('fb-files'),
      list=document.getElementById('fb-list'),btn=f.querySelector('button'),files=[];
  var EM={name:'お名前を入力してください。',email:'正しいメールアドレスを入力してください。',type:'お問い合わせの種類を選択してください。',short:'70文字以上でご記入ください。',long:'メッセージが長すぎます（5000文字以内）。',files:'スクリーンショットは5枚までです。残りは追加されませんでした。',total:'添付ファイルが大きすぎます（スクリーンショットは5枚まで、各1 MB以内）。',form:'フォームを読み取れませんでした。',spam:'スパム対策の確認を完了してください。',send:'現在メッセージを送信できません。メールでご連絡ください。'};
  function emsg(r){if(r.code==='toobig')return'「'+(r.file||'')+'」は1 MBを超えているため追加されませんでした。';if(r.code==='notimage')return'「'+(r.file||'')+'」は画像ではないため追加されませんでした。';return EM[r.code]||'エラーが発生しました。';}
  function show(e){err.textContent=e;err.hidden=!e;}
  function kb(n){return n<1048576?Math.round(n/1024)+' KB':(n/1048576).toFixed(1).replace('.','.')+' MB';}
  function render(){
    list.innerHTML='';list.hidden=!files.length;
    files.forEach(function(file,i){
      var li=document.createElement('li'),x=document.createElement('button');
      li.textContent=file.name+' · '+kb(file.size)+' ';x.type='button';x.textContent='削除';x.setAttribute('aria-label','削除 '+file.name);
      x.addEventListener('click',function(){files.splice(i,1);render();show('');});li.appendChild(x);list.appendChild(li);
    });
    picker.hidden=files.length>=5;
  }
  picker.addEventListener('change',function(){
    show('');
    for(var i=0;i<picker.files.length;i++){
      var file=picker.files[i];
      if(files.length>=5){show('スクリーンショットは5枚までです。残りは追加されませんでした。');break;}
      if(file.size>1048576){show('「'+file.name+'」は1 MBを超えているため追加されませんでした。');continue;}
      if(!/^image\//.test(file.type)){show('「'+file.name+'」は画像ではないため追加されませんでした。');continue;}
      files.push(file);
    }
    picker.value='';render();
  });
  msg.addEventListener('input',function(){var n=msg.value.trim().length;count.textContent=n<70?'あと'+(70-n)+'文字':n+'文字';});
  f.addEventListener('submit',function(ev){
    ev.preventDefault();show('');
    if(!f.elements.name.value.trim())return show('お名前を入力してください。');
    if(!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(f.elements.email.value.trim()))return show('正しいメールアドレスを入力してください。');
    if(msg.value.trim().length<70)return show('70文字以上でご記入ください。');
    if(msg.value.length>5000)return show('メッセージが長すぎます（5000文字以内）。');
    var ts=f.querySelector('[name=cf-turnstile-response]');
    if(!ts||!ts.value)return show('スパム対策の確認を完了してください。');
    var fd=new FormData();
    ['name','email','type','message'].forEach(function(k){fd.append(k,f.elements[k].value);});
    fd.append('cf-turnstile-response',ts.value);
    files.forEach(function(file){fd.append('files',file,file.name);});
    btn.disabled=true;btn.textContent='送信中…';
    fetch(f.action,{method:'POST',body:fd}).then(function(r){return r.json().catch(function(){return{error:'エラーが発生しました。'};}).then(function(j){return[r.ok,j];});})
      .then(function(x){if(x[0]){[].forEach.call(f.querySelectorAll('label,.fb-list,.cf-turnstile,button'),function(el){el.hidden=true;});ok.hidden=false;ok.scrollIntoView({block:'center'});}else{show(emsg(x[1]));if(window.turnstile)turnstile.reset();}})
      .catch(function(){show('接続できません。もう一度お試しいただくか、admin@keep.it.com までメールでご連絡ください。');})
      .finally(function(){btn.disabled=false;btn.textContent='送信';});
  });
})();
</script>

メール：[admin@keep.it.com](mailto:admin@keep.it.com) · 手順の説明：[ガイド](/guide) · データの保護について：[セキュリティ](/security)（英語）

## よくある質問への短い回答

**項目を選んでも何もペーストされません。** アクセシビリティの許可を与えてください。「システム設定」→「プライバシーとセキュリティ」→「アクセシビリティ」でKeepitをオンにします（すでにリストにある場合は、いったんオフにしてからオンに戻してください）。それまでは ⌘V を自分で押してください。項目はすでにクリップボードに入っています。

**パスワードを忘れました。** ロック解除のウインドウで「アクセスを復旧…」をクリックするか、同じMacのTouch IDを使ってください。どちらもない場合、データは復元できません。

**データはどこにありますか？** `~/Library/Application Support/Keepit/`（App Store版は `~/Library/Containers/com.it.keep/` の中）。
