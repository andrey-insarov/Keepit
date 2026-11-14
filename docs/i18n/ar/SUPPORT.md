<!-- source: SUPPORT.md b7c2b2a3fb8a171f4a5c7809742c5a119d4e8cc1 -->
# دعم Keepit

هل وجدت خطأ أو ترجمة غير دقيقة، أو لديك سؤال؟ اكتب إلينا في الأسفل. يمكن أيضًا الإبلاغ عن الأخطاء في [GitHub Issues](https://github.com/andrey-insarov/Keepit/issues).

<form id="fb" class="fb" action="/api/feedback" method="post" enctype="multipart/form-data" novalidate>
  <div class="row2">
    <label>الاسم<input name="name" type="text" maxlength="100" autocomplete="name" required></label>
    <label>E-mail<input name="email" type="email" maxlength="254" autocomplete="email" required></label>
  </div>
  <label>الموضوع
    <select name="type" required>
      <option value="app">مشكلة في التطبيق</option>
      <option value="translation">خطأ في الترجمة</option>
      <option value="other">غير ذلك</option>
    </select>
  </label>
  <label>الرسالة <span class="hint" id="fb-count">70 حرفًا على الأقل</span>
    <textarea name="message" rows="7" minlength="70" maxlength="5000" required placeholder="ما الذي حدث، وما الذي كنت تتوقعه، وإصدار macOS وإصدار Keepit…"></textarea>
  </label>
  <label>لقطات الشاشة <span class="hint">اختياري · حتى 5 صور، كل منها 1 ميغابايت</span>
    <input id="fb-files" type="file" accept="image/png,image/jpeg,image/gif,image/webp,image/heic" multiple>
  </label>
  <ul class="fb-list" id="fb-list" hidden></ul>
  <div class="cf-turnstile" data-sitekey="__TURNSTILE_SITE_KEY__" data-theme="light" data-language="ar"></div>
  <p class="fb-err" id="fb-err" hidden></p>
  <button type="submit" class="btn">إرسال</button>
  <p class="hint fb-legal">ما ترسله يصلنا بالبريد الإلكتروني ويُستخدم للرد عليك فقط. راجع <a href="/privacy">سياسة الخصوصية</a> (بالإنجليزية).</p>
  <div class="fb-ok" id="fb-ok" hidden><b>شكرًا، تم إرسال الرسالة.</b><br>أرسلنا تأكيدًا إلى عنوانك.</div>
</form>
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
<script>
(function(){
  var f=document.getElementById('fb'),err=document.getElementById('fb-err'),ok=document.getElementById('fb-ok'),
      msg=f.elements.message,count=document.getElementById('fb-count'),picker=document.getElementById('fb-files'),
      list=document.getElementById('fb-list'),btn=f.querySelector('button'),files=[];
  var EM={name:'أدخل اسمك.',email:'أدخل عنوان بريد إلكتروني صحيحًا.',type:'اختر موضوع الرسالة.',short:'يرجى الوصف في 70 حرفًا على الأقل.',long:'الرسالة طويلة جدًا (5000 حرف على الأكثر).',files:'5 لقطات على الأكثر. لم تُضف البقية.',total:'المرفقات كبيرة جدًا (5 لقطات على الأكثر، كل منها 1 ميغابايت).',form:'تعذرت قراءة النموذج.',spam:'يرجى إكمال التحقق من الرسائل المزعجة.',send:'تعذر إرسال الرسالة الآن. راسلنا بالبريد الإلكتروني.'};
  function emsg(r){if(r.code==='toobig')return'«'+(r.file||'')+'» أكبر من 1 ميغابايت ولم يُضف.';if(r.code==='notimage')return'«'+(r.file||'')+'» ليس صورة ولم يُضف.';return EM[r.code]||'حدث خطأ ما.';}
  function show(e){err.textContent=e;err.hidden=!e;}
  function kb(n){return n<1048576?Math.round(n/1024)+' ك.ب':(n/1048576).toFixed(1).replace('.','.')+' م.ب';}
  function render(){
    list.innerHTML='';list.hidden=!files.length;
    files.forEach(function(file,i){
      var li=document.createElement('li'),x=document.createElement('button');
      li.textContent=file.name+' · '+kb(file.size)+' ';x.type='button';x.textContent='إزالة';x.setAttribute('aria-label','إزالة '+file.name);
      x.addEventListener('click',function(){files.splice(i,1);render();show('');});li.appendChild(x);list.appendChild(li);
    });
    picker.hidden=files.length>=5;
  }
  picker.addEventListener('change',function(){
    show('');
    for(var i=0;i<picker.files.length;i++){
      var file=picker.files[i];
      if(files.length>=5){show('5 لقطات على الأكثر. لم تُضف البقية.');break;}
      if(file.size>1048576){show('«'+file.name+'» أكبر من 1 ميغابايت ولم يُضف.');continue;}
      if(!/^image\//.test(file.type)){show('«'+file.name+'» ليس صورة ولم يُضف.');continue;}
      files.push(file);
    }
    picker.value='';render();
  });
  msg.addEventListener('input',function(){var n=msg.value.trim().length;count.textContent=n<70?'بقي '+(70-n)+' حرفًا':n+' حرفًا';});
  f.addEventListener('submit',function(ev){
    ev.preventDefault();show('');
    if(!f.elements.name.value.trim())return show('أدخل اسمك.');
    if(!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(f.elements.email.value.trim()))return show('أدخل عنوان بريد إلكتروني صحيحًا.');
    if(msg.value.trim().length<70)return show('يرجى الوصف في 70 حرفًا على الأقل.');
    if(msg.value.length>5000)return show('الرسالة طويلة جدًا (5000 حرف على الأكثر).');
    var ts=f.querySelector('[name=cf-turnstile-response]');
    if(!ts||!ts.value)return show('يرجى إكمال التحقق من الرسائل المزعجة.');
    var fd=new FormData();
    ['name','email','type','message'].forEach(function(k){fd.append(k,f.elements[k].value);});
    fd.append('cf-turnstile-response',ts.value);
    files.forEach(function(file){fd.append('files',file,file.name);});
    btn.disabled=true;btn.textContent='جارٍ الإرسال…';
    fetch(f.action,{method:'POST',body:fd}).then(function(r){return r.json().catch(function(){return{error:'حدث خطأ ما.'};}).then(function(j){return[r.ok,j];});})
      .then(function(x){if(x[0]){[].forEach.call(f.querySelectorAll('label,.fb-list,.cf-turnstile,button'),function(el){el.hidden=true;});ok.hidden=false;ok.scrollIntoView({block:'center'});}else{show(emsg(x[1]));if(window.turnstile)turnstile.reset();}})
      .catch(function(){show('لا يوجد اتصال. حاول مرة أخرى أو اكتب إلى admin@keep.it.com.');})
      .finally(function(){btn.disabled=false;btn.textContent='إرسال';});
  });
})();
</script>

البريد الإلكتروني: [admin@keep.it.com](mailto:admin@keep.it.com) · خطوة بخطوة: [الدليل](/guide) · كيف تُحمى بياناتك: [الأمن](/security) (بالإنجليزية).

## إجابات سريعة

**لا يُلصق شيء بعد اختيار عنصر.** امنح إذن تسهيلات الاستخدام: إعدادات النظام ← الخصوصية والأمن ← تسهيلات الاستخدام ← شغّل Keepit (إذا كان موجودًا في القائمة فأوقفه ثم شغّله من جديد). وإلى ذلك الحين اضغط ‎⌘V‎ بنفسك، فالعنصر موجود في الحافظة.

**نسيت كلمة المرور.** انقر «استعادة الوصول…» في نافذة إلغاء القفل، أو استخدم Touch ID على الـ Mac نفسه. من دونهما لا يمكن استعادة البيانات.

**أين بياناتي؟** `~/Library/Application Support/Keepit/` (إصدار App Store: داخل `~/Library/Containers/com.it.keep/`).
