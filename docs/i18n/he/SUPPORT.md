<!-- source: SUPPORT.md b7c2b2a3fb8a171f4a5c7809742c5a119d4e8cc1 -->
# התמיכה של Keepit

מצאתם באג או תרגום שגוי, או שיש לכם שאלה? כתבו לנו בטופס שלמטה. על באגים אפשר לדווח גם ב-[GitHub Issues](https://github.com/andrey-insarov/Keepit/issues).

<form id="fb" class="fb" action="/api/feedback" method="post" enctype="multipart/form-data" novalidate>
  <div class="row2">
    <label>שם<input name="name" type="text" maxlength="100" autocomplete="name" required></label>
    <label>דוא״ל<input name="email" type="email" maxlength="254" autocomplete="email" required></label>
  </div>
  <label>נושא הפנייה
    <select name="type" required>
      <option value="app">בעיה ביישום</option>
      <option value="translation">טעות בתרגום</option>
      <option value="other">משהו אחר</option>
    </select>
  </label>
  <label>הודעה <span class="hint" id="fb-count">לפחות 70 תווים</span>
    <textarea name="message" rows="7" minlength="70" maxlength="5000" required placeholder="מה קרה, למה ציפיתם, באילו גרסאות של macOS ושל Keepit אתם משתמשים…"></textarea>
  </label>
  <label>צילומי מסך <span class="hint">לא חובה · עד 5 תמונות, עד 1 MB כל אחת</span>
    <input id="fb-files" type="file" accept="image/png,image/jpeg,image/gif,image/webp,image/heic" multiple>
  </label>
  <ul class="fb-list" id="fb-list" hidden></ul>
  <div class="cf-turnstile" data-sitekey="__TURNSTILE_SITE_KEY__" data-theme="light" data-language="he"></div>
  <p class="fb-err" id="fb-err" hidden></p>
  <button type="submit" class="btn">שליחה</button>
  <p class="hint fb-legal">מה שתשלחו יגיע אלינו בדוא״ל וישמש רק כדי לענות לכם. ראו את <a href="/privacy">מדיניות הפרטיות</a> (באנגלית).</p>
  <div class="fb-ok" id="fb-ok" hidden><b>תודה, ההודעה נשלחה.</b><br>אישור נשלח לכתובת שלכם.</div>
</form>
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
<script>
(function(){
  var f=document.getElementById('fb'),err=document.getElementById('fb-err'),ok=document.getElementById('fb-ok'),
      msg=f.elements.message,count=document.getElementById('fb-count'),picker=document.getElementById('fb-files'),
      list=document.getElementById('fb-list'),btn=f.querySelector('button'),files=[];
  var PF={one:' תו',other:' תווים'},PR=window.Intl&&Intl.PluralRules?new Intl.PluralRules('he'):null;
  function pf(n){var k=PR?PR.select(n):'other';return Object.prototype.hasOwnProperty.call(PF,k)?PF[k]:PF.other;}
  var EM={name:'נא לכתוב את שמכם.',email:'נא לכתוב כתובת דוא״ל תקינה.',type:'נא לבחור את נושא הפנייה.',short:'נא לתאר את הפנייה ב-70 תווים לפחות.',long:'ההודעה ארוכה מדי (עד 5000 תווים).',files:'אפשר לצרף עד 5 צילומי מסך. הסירו את העודפים ושלחו את הטופס שוב.',total:'הקבצים המצורפים גדולים מדי (עד 5 צילומי מסך, עד 1 MB כל אחד).',form:'לא ניתן היה לקרוא את הטופס.',spam:'נא להשלים את בדיקת הספאם.',send:'לא ניתן היה לשלוח את ההודעה כרגע. כתבו לנו בדוא״ל.'};
  function emsg(r){var c=r&&r.code,n=(r&&r.file)||'';if(c==='toobig')return'“'+n+'” גדול מ-1 MB. הסירו את הקובץ או הקטינו אותו, ואז שלחו את הטופס שוב.';if(c==='notimage')return'“'+n+'” לא זוהה כתמונה נתמכת. הסירו את הקובץ או החליפו אותו, ואז שלחו את הטופס שוב.';return typeof c==='string'&&Object.prototype.hasOwnProperty.call(EM,c)?EM[c]:'משהו השתבש.';}
  function show(e){err.textContent=e;err.hidden=!e;}
  function kb(n){return n<1048576?Math.round(n/1024)+' KB':(n/1048576).toFixed(1).replace('.','.')+' MB';}
  function render(){
    list.innerHTML='';list.hidden=!files.length;
    files.forEach(function(file,i){
      var li=document.createElement('li'),x=document.createElement('button');
      li.textContent=file.name+' · '+kb(file.size)+' ';x.type='button';x.textContent='הסרה';x.setAttribute('aria-label','הסרה '+file.name);
      x.addEventListener('click',function(){files.splice(i,1);render();show('');});li.appendChild(x);list.appendChild(li);
    });
    picker.hidden=files.length>=5;
  }
  picker.addEventListener('change',function(){
    show('');
    for(var i=0;i<picker.files.length;i++){
      var file=picker.files[i];
      if(files.length>=5){show('אפשר לצרף עד 5 צילומי מסך. השאר לא נוספו.');break;}
      if(file.size>1048576){show('“'+file.name+'” גדול מ-1 MB ולא נוסף.');continue;}
      if(!/^image\//.test(file.type)){show('“'+file.name+'” אינו תמונה ולא נוסף.');continue;}
      files.push(file);
    }
    picker.value='';render();
  });
  msg.addEventListener('input',function(){var n=msg.value.trim().length;count.textContent=n<70?'עוד '+(70-n)+pf(70-n):n+pf(n);});
  f.addEventListener('submit',function(ev){
    ev.preventDefault();show('');
    if(!f.elements.name.value.trim())return show('נא לכתוב את שמכם.');
    if(!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(f.elements.email.value.trim()))return show('נא לכתוב כתובת דוא״ל תקינה.');
    if(msg.value.trim().length<70)return show('נא לתאר את הפנייה ב-70 תווים לפחות.');
    if(msg.value.length>5000)return show('ההודעה ארוכה מדי (עד 5000 תווים).');
    var ts=f.querySelector('[name=cf-turnstile-response]');
    if(!ts||!ts.value)return show('נא להשלים את בדיקת הספאם.');
    var fd=new FormData();
    ['name','email','type','message'].forEach(function(k){fd.append(k,f.elements[k].value);});
    fd.append('cf-turnstile-response',ts.value);
    files.forEach(function(file){fd.append('files',file,file.name);});
    btn.disabled=true;btn.textContent='שולח…';
    fetch(f.action,{method:'POST',body:fd}).then(function(r){return r.json().catch(function(){return{error:'משהו השתבש.'};}).then(function(j){return[r.ok,j];});})
      .then(function(x){if(x[0]){[].forEach.call(f.querySelectorAll('label,.fb-list,.cf-turnstile,button'),function(el){el.hidden=true;});ok.hidden=false;ok.scrollIntoView({block:'center'});}else{show(emsg(x[1]));if(window.turnstile)turnstile.reset();}})
      .catch(function(){show('אין חיבור. נסו שוב או כתבו אל admin@keep.it.com.');})
      .finally(function(){btn.disabled=false;btn.textContent='שליחה';});
  });
})();
</script>

דוא״ל: [admin@keep.it.com](mailto:admin@keep.it.com) · צעד אחר צעד: [מדריך](/guide) · איך הנתונים שלכם מוגנים: [אבטחה](/security) (באנגלית).

## תשובות קצרות

**אחרי בחירת פריט לא מודבק דבר.** העניקו את הרשאת הנגישות: הגדרות המערכת ← פרטיות ואבטחה ← נגישות ← הפעילו את Keepit (אם הוא כבר ברשימה, כבו אותו והפעילו שוב). עד אז לחצו על `⌘V` בעצמכם; הפריט כבר נמצא בלוח.

**שכחתי את הסיסמה.** בחלון ביטול הנעילה לחצו על “שחזור גישה…”, או השתמשו ב-Touch ID באותו Mac. בלי אחד מהם אי אפשר לשחזר את הנתונים.

**איפה הנתונים שלי?** `~/Library/Application Support/Keepit/` (בגרסת ה-App Store: בתוך `~/Library/Containers/com.it.keep/`).
