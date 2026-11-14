<!-- source: SUPPORT.md b7c2b2a3fb8a171f4a5c7809742c5a119d4e8cc1 -->
# Keepit 지원

버그나 잘못된 번역을 발견했거나 궁금한 점이 있으신가요? 아래 양식으로 알려 주세요. 버그는 [GitHub Issues](https://github.com/andrey-insarov/Keepit/issues)에 올리셔도 됩니다.

<form id="fb" class="fb" action="/api/feedback" method="post" enctype="multipart/form-data" novalidate>
  <div class="row2">
    <label>이름<input name="name" type="text" maxlength="100" autocomplete="name" required></label>
    <label>E-mail<input name="email" type="email" maxlength="254" autocomplete="email" required></label>
  </div>
  <label>문의 유형
    <select name="type" required>
      <option value="app">앱 문제</option>
      <option value="translation">번역 오류</option>
      <option value="other">기타</option>
    </select>
  </label>
  <label>메시지 <span class="hint" id="fb-count">70자 이상</span>
    <textarea name="message" rows="7" minlength="70" maxlength="5000" required placeholder="어떤 일이 있었는지, 어떻게 되기를 기대했는지, 사용 중인 macOS와 Keepit 버전을 적어 주세요…"></textarea>
  </label>
  <label>스크린샷 <span class="hint">선택 사항 · 이미지 최대 5개, 각 1MB 이하</span>
    <input id="fb-files" type="file" accept="image/png,image/jpeg,image/gif,image/webp,image/heic" multiple>
  </label>
  <ul class="fb-list" id="fb-list" hidden></ul>
  <div class="cf-turnstile" data-sitekey="__TURNSTILE_SITE_KEY__" data-theme="light" data-language="ko"></div>
  <p class="fb-err" id="fb-err" hidden></p>
  <button type="submit" class="btn">보내기</button>
  <p class="hint fb-legal">보내신 내용은 이메일로 전달되며 답변을 드리는 데에만 사용됩니다. <a href="/privacy">개인정보 처리방침</a>(영어)을 참고하세요.</p>
  <div class="fb-ok" id="fb-ok" hidden><b>감사합니다. 메시지를 보냈습니다.</b><br>입력하신 주소로 확인 메일을 보내 드립니다.</div>
</form>
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
<script>
(function(){
  var f=document.getElementById('fb'),err=document.getElementById('fb-err'),ok=document.getElementById('fb-ok'),
      msg=f.elements.message,count=document.getElementById('fb-count'),picker=document.getElementById('fb-files'),
      list=document.getElementById('fb-list'),btn=f.querySelector('button'),files=[];
  var EM={name:'이름을 입력해 주세요.',email:'올바른 이메일 주소를 입력해 주세요.',type:'문의 유형을 선택해 주세요.',short:'70자 이상으로 설명해 주세요.',long:'메시지가 너무 깁니다(최대 5000자).',files:'스크린샷은 최대 5개까지 첨부할 수 있습니다. 초과한 파일을 제거하고 양식을 다시 보내 주세요.',total:'첨부 파일이 너무 큽니다(스크린샷 최대 5개, 각 1MB 이하).',form:'양식을 읽을 수 없습니다.',spam:'스팸 방지 확인을 완료해 주세요.',send:'지금은 메시지를 보낼 수 없습니다. 이메일로 연락해 주세요.'};
  function emsg(r){var c=r&&r.code,n=(r&&r.file)||'';if(c==='toobig')return'“'+n+'” 파일이 1MB보다 큽니다. 파일을 제거하거나 크기를 줄인 다음 양식을 다시 보내 주세요.';if(c==='notimage')return'“'+n+'” 파일이 지원되는 이미지로 인식되지 않았습니다. 파일을 제거하거나 바꾼 다음 양식을 다시 보내 주세요.';return typeof c==='string'&&Object.prototype.hasOwnProperty.call(EM,c)?EM[c]:'문제가 발생했습니다.';}
  function show(e){err.textContent=e;err.hidden=!e;}
  function kb(n){return n<1048576?Math.round(n/1024)+'KB':(n/1048576).toFixed(1).replace('.','.')+'MB';}
  function render(){
    list.innerHTML='';list.hidden=!files.length;
    files.forEach(function(file,i){
      var li=document.createElement('li'),x=document.createElement('button');
      li.textContent=file.name+' · '+kb(file.size)+' ';x.type='button';x.textContent='제거';x.setAttribute('aria-label','제거 '+file.name);
      x.addEventListener('click',function(){files.splice(i,1);render();show('');});li.appendChild(x);list.appendChild(li);
    });
    picker.hidden=files.length>=5;
  }
  picker.addEventListener('change',function(){
    show('');
    for(var i=0;i<picker.files.length;i++){
      var file=picker.files[i];
      if(files.length>=5){show('스크린샷은 최대 5개까지입니다. 나머지는 추가되지 않았습니다.');break;}
      if(file.size>1048576){show('“'+file.name+'” 파일은 1MB보다 커서 추가되지 않았습니다.');continue;}
      if(!/^image\//.test(file.type)){show('“'+file.name+'” 파일은 이미지가 아니어서 추가되지 않았습니다.');continue;}
      files.push(file);
    }
    picker.value='';render();
  });
  msg.addEventListener('input',function(){var n=msg.value.trim().length;count.textContent=n<70?'앞으로 '+(70-n)+'자 더':n+'자';});
  f.addEventListener('submit',function(ev){
    ev.preventDefault();show('');
    if(!f.elements.name.value.trim())return show('이름을 입력해 주세요.');
    if(!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(f.elements.email.value.trim()))return show('올바른 이메일 주소를 입력해 주세요.');
    if(msg.value.trim().length<70)return show('70자 이상으로 설명해 주세요.');
    if(msg.value.length>5000)return show('메시지가 너무 깁니다(최대 5000자).');
    var ts=f.querySelector('[name=cf-turnstile-response]');
    if(!ts||!ts.value)return show('스팸 방지 확인을 완료해 주세요.');
    var fd=new FormData();
    ['name','email','type','message'].forEach(function(k){fd.append(k,f.elements[k].value);});
    fd.append('cf-turnstile-response',ts.value);
    files.forEach(function(file){fd.append('files',file,file.name);});
    btn.disabled=true;btn.textContent='보내는 중…';
    fetch(f.action,{method:'POST',body:fd}).then(function(r){return r.json().catch(function(){return{error:'문제가 발생했습니다.'};}).then(function(j){return[r.ok,j];});})
      .then(function(x){if(x[0]){[].forEach.call(f.querySelectorAll('label,.fb-list,.cf-turnstile,button'),function(el){el.hidden=true;});ok.hidden=false;ok.scrollIntoView({block:'center'});}else{show(emsg(x[1]));if(window.turnstile)turnstile.reset();}})
      .catch(function(){show('연결할 수 없습니다. 다시 시도하거나 admin@keep.it.com으로 메일을 보내 주세요.');})
      .finally(function(){btn.disabled=false;btn.textContent='보내기';});
  });
})();
</script>

이메일: [admin@keep.it.com](mailto:admin@keep.it.com) · 단계별 안내: [사용 설명서](/guide) · 데이터 보호 방식: [보안](/security)(영어).

## 짧은 답변

**항목을 선택해도 아무것도 붙여넣어지지 않습니다.** 손쉬운 사용 권한을 허용하세요. 시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용에서 Keepit을 켭니다(이미 목록에 있으면 껐다가 다시 켜세요). 그때까지는 ⌘V를 직접 누르세요. 항목은 이미 클립보드에 들어 있습니다.

**암호를 잊어버렸습니다.** 잠금 해제 창에서 *접근 복구…*를 클릭하거나 같은 Mac에서 Touch ID를 사용하세요. 둘 다 없으면 데이터를 복구할 수 없습니다.

**내 데이터는 어디에 있나요?** `~/Library/Application Support/Keepit/`(App Store 버전은 `~/Library/Containers/com.it.keep/` 안).
