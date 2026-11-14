<!-- source: SUPPORT.md b7c2b2a3fb8a171f4a5c7809742c5a119d4e8cc1 -->
# Keepit desteği

Bir hata ya da yanlış bir çeviri mi buldunuz, yoksa bir sorunuz mu var? Aşağıdaki formdan bize yazın. Hataları [GitHub Issues](https://github.com/andrey-insarov/Keepit/issues) üzerinden de bildirebilirsiniz.

<form id="fb" class="fb" action="/api/feedback" method="post" enctype="multipart/form-data" novalidate>
  <div class="row2">
    <label>Ad<input name="name" type="text" maxlength="100" autocomplete="name" required></label>
    <label>E-mail<input name="email" type="email" maxlength="254" autocomplete="email" required></label>
  </div>
  <label>Konu
    <select name="type" required>
      <option value="app">Uygulamayla ilgili sorun</option>
      <option value="translation">Çeviri hatası</option>
      <option value="other">Başka bir şey</option>
    </select>
  </label>
  <label>Mesaj <span class="hint" id="fb-count">en az 70 karakter</span>
    <textarea name="message" rows="7" minlength="70" maxlength="5000" required placeholder="Ne oldu, ne olmasını bekliyordunuz, hangi macOS ve Keepit sürümünü kullanıyorsunuz…"></textarea>
  </label>
  <label>Ekran görüntüleri <span class="hint">isteğe bağlı · en çok 5 görüntü, her biri en çok 1 MB</span>
    <input id="fb-files" type="file" accept="image/png,image/jpeg,image/gif,image/webp,image/heic" multiple>
  </label>
  <ul class="fb-list" id="fb-list" hidden></ul>
  <div class="cf-turnstile" data-sitekey="__TURNSTILE_SITE_KEY__" data-theme="light" data-language="tr"></div>
  <p class="fb-err" id="fb-err" hidden></p>
  <button type="submit" class="btn">Gönder</button>
  <p class="hint fb-legal">Gönderdikleriniz bize e-postayla ulaşır ve yalnızca size yanıt vermek için kullanılır. Bkz. <a href="/privacy">Gizlilik politikası</a> (İngilizce).</p>
  <div class="fb-ok" id="fb-ok" hidden><b>Teşekkürler, mesajınız gönderildi.</b><br>Adresinize bir onay e-postası gönderiliyor.</div>
</form>
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
<script>
(function(){
  var f=document.getElementById('fb'),err=document.getElementById('fb-err'),ok=document.getElementById('fb-ok'),
      msg=f.elements.message,count=document.getElementById('fb-count'),picker=document.getElementById('fb-files'),
      list=document.getElementById('fb-list'),btn=f.querySelector('button'),files=[];
  var EM={name:'Lütfen adınızı yazın.',email:'Lütfen geçerli bir e-posta adresi yazın.',type:'Lütfen konuyu seçin.',short:'Lütfen durumu en az 70 karakterle anlatın.',long:'Mesaj çok uzun (en çok 5000 karakter).',files:'En çok 5 ekran görüntüsü eklenebilir. Fazla olanları kaldırıp formu yeniden gönderin.',total:'Ekler çok büyük (en çok 5 ekran görüntüsü, her biri en çok 1 MB).',form:'Form okunamadı.',spam:'Lütfen spam denetimini tamamlayın.',send:'Mesaj şu anda gönderilemedi. Lütfen bize e-posta yazın.'};
  function emsg(r){var c=r&&r.code,n=(r&&r.file)||'';if(c==='toobig')return'“'+n+'” 1 MB’tan büyük. Dosyayı kaldırın ya da küçültün, sonra formu yeniden gönderin.';if(c==='notimage')return'“'+n+'” desteklenen bir görüntü olarak tanınmadı. Dosyayı kaldırın ya da değiştirin, sonra formu yeniden gönderin.';return typeof c==='string'&&Object.prototype.hasOwnProperty.call(EM,c)?EM[c]:'Bir şeyler ters gitti.';}
  function show(e){err.textContent=e;err.hidden=!e;}
  function kb(n){return n<1048576?Math.round(n/1024)+' KB':(n/1048576).toFixed(1).replace('.',',')+' MB';}
  function render(){
    list.innerHTML='';list.hidden=!files.length;
    files.forEach(function(file,i){
      var li=document.createElement('li'),x=document.createElement('button');
      li.textContent=file.name+' · '+kb(file.size)+' ';x.type='button';x.textContent='Kaldır';x.setAttribute('aria-label','Kaldır '+file.name);
      x.addEventListener('click',function(){files.splice(i,1);render();show('');});li.appendChild(x);list.appendChild(li);
    });
    picker.hidden=files.length>=5;
  }
  picker.addEventListener('change',function(){
    show('');
    for(var i=0;i<picker.files.length;i++){
      var file=picker.files[i];
      if(files.length>=5){show('En çok 5 ekran görüntüsü eklenebilir. Diğerleri eklenmedi.');break;}
      if(file.size>1048576){show('“'+file.name+'” 1 MB’tan büyük olduğu için eklenmedi.');continue;}
      if(!/^image\//.test(file.type)){show('“'+file.name+'” bir görüntü olmadığı için eklenmedi.');continue;}
      files.push(file);
    }
    picker.value='';render();
  });
  msg.addEventListener('input',function(){var n=msg.value.trim().length;count.textContent=n<70?''+(70-n)+' karakter daha':n+' karakter';});
  f.addEventListener('submit',function(ev){
    ev.preventDefault();show('');
    if(!f.elements.name.value.trim())return show('Lütfen adınızı yazın.');
    if(!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(f.elements.email.value.trim()))return show('Lütfen geçerli bir e-posta adresi yazın.');
    if(msg.value.trim().length<70)return show('Lütfen durumu en az 70 karakterle anlatın.');
    if(msg.value.length>5000)return show('Mesaj çok uzun (en çok 5000 karakter).');
    var ts=f.querySelector('[name=cf-turnstile-response]');
    if(!ts||!ts.value)return show('Lütfen spam denetimini tamamlayın.');
    var fd=new FormData();
    ['name','email','type','message'].forEach(function(k){fd.append(k,f.elements[k].value);});
    fd.append('cf-turnstile-response',ts.value);
    files.forEach(function(file){fd.append('files',file,file.name);});
    btn.disabled=true;btn.textContent='Gönderiliyor…';
    fetch(f.action,{method:'POST',body:fd}).then(function(r){return r.json().catch(function(){return{error:'Bir şeyler ters gitti.'};}).then(function(j){return[r.ok,j];});})
      .then(function(x){if(x[0]){[].forEach.call(f.querySelectorAll('label,.fb-list,.cf-turnstile,button'),function(el){el.hidden=true;});ok.hidden=false;ok.scrollIntoView({block:'center'});}else{show(emsg(x[1]));if(window.turnstile)turnstile.reset();}})
      .catch(function(){show('Bağlantı kurulamadı. Yeniden deneyin ya da admin@keep.it.com adresine yazın.');})
      .finally(function(){btn.disabled=false;btn.textContent='Gönder';});
  });
})();
</script>

E-posta: [admin@keep.it.com](mailto:admin@keep.it.com) · Adım adım: [Kılavuz](/guide) · Verileriniz nasıl korunuyor: [Güvenlik](/security) (İngilizce).

## Kısa yanıtlar

**Bir öğe seçtikten sonra hiçbir şey yapıştırılmıyor.** Erişilebilirlik iznini verin: Sistem Ayarları → Gizlilik ve Güvenlik → Erişilebilirlik → Keepit’i açın (listede zaten varsa kapatıp yeniden açın). O zamana kadar ⌘V tuşlarına kendiniz basın; öğe zaten panodadır.

**Parolamı unuttum.** Kilit açma penceresinde *Erişimi Kurtar…* düğmesini tıklayın ya da aynı Mac’te Touch ID’yi kullanın. İkisi de yoksa veriler kurtarılamaz.

**Verilerim nerede?** `~/Library/Application Support/Keepit/` (App Store sürümünde: `~/Library/Containers/com.it.keep/` içinde).
