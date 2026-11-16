<!-- source: GUIDE.md 5e4e05273c142ac7759f3c994f7665d09f9b8d3c -->
# Keepit kullanım kılavuzu

Keepit, macOS için bir pano geçmişi ve şablon yöneticisidir. Menü çubuğunda durur, kopyaladığınız
her şeyi hatırlar ve istediğiniz öğeyi bir kısayol tuşuyla geri yapıştırır. Aşağıdaki kısayolların
tümü varsayılandır ve her biri *Ayarlar → Kısayollar* bölümünden değiştirilebilir. Bu kılavuz
Keepit 3’ü anlatır; Keepit 2.x kılavuzu
[keep.it.com/v2/guide](https://keep.it.com/v2/guide) adresinde değiştirilmeden durmaktadır
(İngilizce).

![Geçmiş menüsü](site/img/guide/menu.png)

**İçindekiler**

- [Bölüm 1. Başlarken](#part-1-getting-started): [Kurulum](#install) · [İlk açılış](#first-launch)
- [Bölüm 2. Günlük kullanım](#part-2-everyday-use): [Geçmiş menüsü](#the-history-menu) · [Arama ve önizleme](#search-and-preview) · [Menüsüz yapıştırma](#paste-without-the-menu) · [Yapıştırma kuyruğu](#the-paste-queue) · [Genişletilmiş menü](#the-extended-menu)
- [Bölüm 3. Şablonlar](#part-3-templates): [Oluşturma ve düzenleme](#creating-and-organising) · [Yer tutucular](#placeholders) · [Soru soran şablonlar](#templates-that-ask-questions)
- [Bölüm 4. Görüntüleyici](#part-4-the-viewer)
- [Bölüm 5. Ayarlar](#part-5-settings)
- [Bölüm 6. Güvenlik](#part-6-security): [Parola ve şifreleme](#password-and-encryption) · [Touch ID](#touch-id) · [Kurtarma ifadesi](#recovery-phrase) · [Yedekleme](#backup)
- [Bölüm 7. Gelişmiş](#part-7-advanced): [Otomasyon](#automation-the-keepit-url-scheme) · [Güncellemeler](#updates) · [Kaldırma](#uninstalling)
- [Başvuru](#reference): [Sorun giderme](#troubleshooting) · [Kısayol özeti](#keyboard-cheat-sheet) · [Yer tutucu özeti](#placeholder-cheat-sheet)

---

## Bölüm 1. Başlarken

### Kurulum

**Homebrew.** Önerilen yol budur, çünkü `brew upgrade` uygulamayı güncel tutar:

```bash
brew tap andrey-insarov/keepit https://github.com/andrey-insarov/Keepit
brew install --cask andrey-insarov/keepit/keepit
```

**DMG.** `Keepit-<sürüm>.dmg` dosyasını
[en son sürüm sayfasından](https://github.com/andrey-insarov/Keepit/releases/latest) indirin, açın
ve Keepit’i *Uygulamalar* klasörüne sürükleyin.

![DMG: Keepit’i Uygulamalar klasörüne sürükleyin](site/img/guide/dmg.png)

Uygulamayı ilk açtığınızda macOS, uygulamanın internetten indirildiğini ve Apple tarafından
denetlendiğini doğrular. *Aç* düğmesini tıklayın.

![macOS Gatekeeper onayı](site/img/guide/gatekeeper.png)

Keepit imzalıdır ve Apple tarafından onaylanmıştır, kendi kendini günceller ve macOS 13 Ventura veya sonrasını
çalıştıran Apple silicon ve Intel işlemcili Mac’lerde yerel olarak çalışır.

### İlk açılış

Keepit bir menü çubuğu uygulamasıdır: Dock simgesi yoktur, siz açana kadar penceresi de yoktur.
İlk açılıştan sonra menü çubuğunda 📎 simgesi belirir ve Keepit üç şey sorar.

**1. Yedekten geri yüklensin mi?** Bu yeni bir Mac ise ve bir Keepit yedeğiniz varsa (iCloud
Drive’da ya da başka bir klasörde otomatik bir yedek veya dışa aktarılmış bir `.keepit` dosyası),
*Yedekten Geri Yükle…* seçeneği başka hiçbir şey olmadan önce geçmişinizi ve şablonlarınızı geri
getirir. Dosyanın kilidini, geldiği Mac’in parolasıyla ya da o Mac’in kurtarma ifadesiyle açarsınız.
*Sıfırdan Başla* bu adımı atlar. Aynı geri yükleme sonradan *Ayarlar → Yedekleme → Geri Yükle…*
üzerinden de yapılabilir; Finder’da bir `.keepit` dosyasını çift tıklamak da onu açar. Ayrıntılar
[Yedekleme](#backup) bölümündedir.

![Yeni bir Mac’te ilk soru: yedekten geri yüklemek ya da sıfırdan başlamak](site/img/guide/restore-first-run.png)

**2. Parola (isteğe bağlı).** Keepit geçmişi ve şablonları şifreli saklayabilir ve kilidi Touch ID
ile açabilir. Şimdi ya da sonra *Ayarlar → Güvenlik* bölümünde karar verebilirsiniz; nasıl
çalıştığını [Bölüm 6](#part-6-security) anlatır. *Şimdi Değil* seçeneğinde her şey diskte şifresiz
kalır. Az önce bir yedeği kendi parolasıyla geri yüklediyseniz Keepit bu parolayı bu Mac için de
kullanmayı önerir.

![İlk açılışta parola önerisi](site/img/guide/password-offer.png)

![Şimdi Değil seçildiğinde: bunun ne anlama geldiğini ve nereden değiştirileceğini açıkça söyleyen bir bildirim](site/img/guide/no-password-notice.png)

**3. Erişilebilirlik izni.** Keepit sizin yerinize yapıştırmak için çalıştığınız uygulamaya ⌘V
gönderir. macOS buna yalnızca *Sistem Ayarları → Gizlilik ve Güvenlik → Erişilebilirlik* altında
listelenen uygulamalar için izin verir. *Sistem Ayarları’nı Aç* düğmesini tıklayın ve Keepit’i
açın. Bu izin olmadan Keepit kaydetmeyi ve kopyalamayı sürdürür, ama ⌘V tuşlarına siz basarsınız.

![Keepit Erişilebilirlik iznini istiyor](site/img/guide/accessibility-prompt.png)

![Gizlilik ve Güvenlik → Erişilebilirlik altında Keepit açık](site/img/guide/accessibility-settings.png)

Keepit varsayılan olarak oturum açılırken başlar. Bunu *Ayarlar → Genel* bölümünden
kapatabilirsiniz.

---

## Bölüm 2. Günlük kullanım

### Geçmiş menüsü

Herhangi bir uygulamada **⌥M** tuşlarına basın ya da 📎 simgesini tıklayın. Keepit metin imlecini
bulabilirse menü onun yanında, bulamazsa fare imlecinin yanında açılır.

Her satır kopyalanmış bir öğedir ve en yenisi en üsttedir. En yeni öğe **kalın** yazılır, çünkü şu
anda panoda olan odur. Simge, kopyalama yaptığınız uygulamayı gösterir. `…` ile biten bir başlığın
menüde görünenden daha fazla satırı vardır. Görüntülerde küçük resim, dosya listelerinde dosya
adları gösterilir.

![Menünün yanındaki önizleme paneli, vurgulanan öğeyi kaynak uygulaması, saati ve boyutuyla birlikte tam olarak gösterir](site/img/guide/menu-preview.png)

![Geçmişte bir görüntü: menüde küçük resim, önizlemede tam görüntü](site/img/guide/menu-image.png)

Bir öğeyi yapıştırmak için onu tıklayın, ↑ ↓ ile üzerine gidip Return’e basın ya da numarasına
**⌃⌥** ile birlikte basın: `⌃⌥3` 3 numaralı öğeyi yapıştırır. Aynı tuş, menüyü açmadan her yerde
çalışır.

Geçmişin altında *Şablonlar* alt menüsü, Görüntüleyici (⌥E), Ayarlar (⌥S), *Geçmişi temizle* (⌥C),
*Kaydı 10 Dakika Duraklat* (⌥P; kaydedilmesini istemediğiniz bir şey yazarken), parola
belirlenmişse *Keepit’i kilitle* (⌥L) ve güncelleme komutu bulunur. **⌥T** yalnızca şablon menüsünü
açar. Bu tuşların her biri menü olmadan da çalışır.

### Arama ve önizleme

**Arama.** Menü açıkken yazmaya başlayın: üstteki alan listeyi başlığa ve tam metne göre süzer,
böylece uzun bir öğenin ortasındaki bir satır da bulunur. Return ilk eşleşmeyi yapıştırır, Esc
alanı temizler, ikinci Esc menüyü kapatır.

**Önizleme.** İmleci bir öğenin üzerine getirin (ya da klavyeyle üzerine gidin); menünün yanındaki
bir panel, görüntünün tamamını ya da uzun bir metnin ilk satırlarını kaynak uygulama, tarih ve
boyutla birlikte gösterir. Tek satırlık kısa metinlerin önizlemesi yoktur, çünkü menü satırı onları
zaten bütün olarak gösterir.

![Yazmak menüyü süzer; önizleme paneli vurgulanan öğeyi gösterir](site/img/guide/search-preview.png)

### Menüsüz yapıştırma

Genel kısayol tuşları, geçmiş o anda nasılsa onun üzerinde (1 numaralı öğe panodur) ve her
uygulamadan çalışır:

| Tuşlar | Ne olur |
|------|--------------|
| `⌃⌥1` … `⌃⌥9`, `⌃⌥0` | 1–10 numaralı geçmiş öğesini yapıştırır |
| `⌥⇧V` | *Önceki* öğeyi (2 numaralı öğeyi) yapıştırır; yeniden basınca ikisi geri yer değiştirir |
| `⌃⌥V` | Panoyu biçimlendirmesi kaldırılmış düz metin olarak yapıştırır |
| `⌃⌥U` `⌃⌥L` `⌃⌥T` `⌃⌥S` | Panoyu BÜYÜK HARF / küçük harf / Her Kelime Büyük / cümle düzeninde yapıştırır |
| `⌃⌥W` | Panoyu baştaki ve sondaki boşlukları kırparak yapıştırır |
| `⌃⌥J` | Panoyu tek satırda birleştirerek yapıştırır |
| `⌃⌥K` `⌃⌥D` `⌃⌥Y` | Panoyu üstü çizili / altı çizili / dalgalı altı çizili olarak yapıştırır; bu, sohbetler dahil her yerde görünümünü koruyan düz metindir (aşağıya bakın) |
| `⌃⌥X` | Panoyu bu süslemeler kaldırılmış olarak yapıştırır |
| `⌃⌥A` | Panoyu Şablonlara ekler |
| `⌃⌥⌫` | En yeni öğeyi geçmişten siler |

Bu üç süsleme biçimlendirme değildir: Keepit her karakterden sonra bir Unicode *birleştirici
işareti* ekler (ü̶s̶t̶ü̶ ̶ç̶i̶z̶i̶l̶i̶, a̲l̲t̲ı̲ ̲ç̲i̲z̲i̲l̲i̲, d̰a̰l̰g̰a̰l̰ı̰), böylece metin gerçek biçimlendirmenin kaybolacağı bir
mesajlaşma uygulamasında, web formunda ya da terminalde aynı görünür. Bunun bir bedeli vardır:
böyle bir metin üç kat yer kaplar, sade sözcükle yapılan arama onu bulmaz, ekran okuyucular
üzerinde takılır ve bazı fontlar çizgiyi düzensiz çizer. *Süslemeleri kaldır* (`⌃⌥X`) işaretleri
yeniden kaldırır; başka yerde süslenmiş metinden de kaldırır. Her iki yönde de işaretler, nereden
gelmiş olurlarsa olsunlar kod noktasına göre kaldırılır: aynı işaretleri harf olarak kullanan bir
fonetik yazı (U+0330 aynı zamanda IPA’da gıcırtılı ses işaretidir) onları kaybeder; üç süsleme de
önce onları kaldırır. VoiceOver açıkken `⌃⌥` VoiceOver’ın kendi niteleyici tuşudur: Ayarlar →
Kısayollar bölümünde *En son öğe için eylemler* seçeneğine başka bir niteleyici atayın.

Dönüştürmeler metne uygulanır; bir görüntü ya da dosya listesi için tuş yalnızca uyarı sesi verir.
Bunların hepsi *Ayarlar → Kısayollar* bölümünden değiştirilebilir ya da kapatılabilir.

### Yapıştırma kuyruğu

Bazen bir yerden beş şey kopyalayıp bunları aynı sırayla başka bir yere yapıştırmak istersiniz:
hücreleri bir forma, bir sayfadaki satırları bir belgeye. Yapıştırma kuyruğu bunu menü olmadan
yapar:

1. **⌥N** tuşlarına basın (ya da menüde *Yapıştırma kuyruğunu başlat* komutunu seçin). Menü
   çubuğu simgesi kırmızı bir nokta ve bir sayaç gösterir: `📎 ● 0`.
2. Her zamanki gibi ⌘C ile istediğiniz kadar kopyalayın. Sayaç her kopyalamada artar: 1, 2, 3…
   Her şey geçmişe de kaydedilir.

   ![Kuyruk açıkken menü çubuğu: kırmızı nokta ve sayaç](site/img/guide/queue-menubar.png)

3. Metnin gideceği yere geçin ve her öğe için **⌥V** tuşlarına basın. İlk kopyaladığınız şey ilk
   yapıştırılır ve sayaç azalır. ⌘V panoyu her zamanki gibi yapıştırmayı sürdürür, yani ikisini
   karıştırarak kullanabilirsiniz.
4. Kuyruk, son öğe yapıştırıldıktan sonra ya da kopyalama ve yapıştırma olmadan iki dakika geçince
   kendiliğinden kapanır (süre ayarlanabilir). ⌥N tuşlarına yeniden basmak onu daha erken durdurur.

**⌥⇧N** kuyrukta kalan her şeyi tek seferde yapıştırır. Öğeler satır sonu, sekme, boşluk ya da
hiçbir şeyle birleştirilir; bunu Ayarlar’ın *Yapıştırma kuyruğu* bölmesinde seçersiniz, boşta kalma
süresi de oradadır. Kuyruk açıkken geçmiş menüsü kuyruğun öğelerini işaretler: `▶` sıradaki
yapıştırılacak öğe, `○` hâlâ kuyrukta, `✓` yapıştırılmış.

![Kuyruk açıkken geçmiş menüsü: ○ kuyrukta, ▶ sıradaki, ✓ yapıştırıldı; menü satırı kaç öğe kaldığını gösterir](site/img/guide/queue-menu.png)

![Ayarlar → Yapıştırma kuyruğu](site/img/guide/prefs-queue.png)

### Genişletilmiş menü

Geçmiş menüsü açıkken **⇧** tuşunu basılı tutun; her öğe, o öğeyle ilgili bütün eylemleri içeren
bir `▸` alt menüsü alır: Yapıştır, Düz metin olarak yapıştır, Yalnızca kopyala (panoya, yapıştırma
yok), *Şu şekilde yapıştır* dönüştürmeleri, Şablonlara ekle, Görüntüleyicide göster, Sil. Alt menüyü
açmak için öğenin üzerine gelin ya da → tuşuna basın; açıldıktan sonra ⇧ tuşunu bırakabilirsiniz.

![⇧ tuşunu basılı tutun: her öğe bir alt menü alır; en yeni öğede genel kısayol tuşları gösterilir](site/img/guide/extended-menu.png)

En yeni öğe için alt menü, yukarıdaki tablodaki genel kısayol tuşlarını listeler. Bunlar aynı
tuşlarla yapılan aynı eylemlerdir, yani onları burada öğrenebilirsiniz. Diğer öğelerde eylemler
tuşsuz gösterilir: bir kısayol ya her yerde çalışır ya da gösterilmez.

![Diğer öğeler için: aynı eylemler, kısayol yok](site/img/guide/extended-menu-item2.png)

![Bir görüntü için metin eylemleri soluk görünür; yalnızca Yapıştır, Yalnızca kopyala, Şablonlara ekle, Görüntüleyicide göster ve Sil kullanılabilir](site/img/guide/extended-menu-image.png)

---

## Bölüm 3. Şablonlar

Şablonlar kalıcı olarak sakladığınız öğelerdir: imzalar, adresler, hazır yanıtlar, kod parçaları,
sık yapıştırdığınız bir logo. Klasörleri olan bir ağaçta dururlar ve geçmiş menüsünün *Şablonlar*
alt menüsünde ve **⌥T** altında görünürler. Yeni bir kurulumda bir *Örnekler* klasörü bulunur (bir
selamlama, bugünün tarihi, panodan bir alıntı ve bir imza); böylece kendinizinkileri yazmadan önce
şablonların neler yapabildiğini görürsünüz. Onları dilediğiniz gibi silin ya da düzenleyin. Örnek
şablonları *Ayarlar → Gelişmiş → Sıfırla ve kaldır → Sıfırla…* geri getirir; ancak bu komut diğer
verileri ve ayarları da sıfırlar.

![Örnekler klasörü: bir öğenin üzerine gelince metni görünür](site/img/guide/template-examples.png)

![Şablon menüsü: klasörler alt menü olarak açılır, & işaretinden sonraki harfler kısayol olur](site/img/guide/template-menu-letters.png)

### Oluşturma ve düzenleme

**Şablon ekleme**

- Geçmiş menüsünden: en yeni öğe için `⌃⌥A`, en alttaki *Panoyu Şablonlara Ekle* ya da herhangi
  bir öğe için ⇧ → öğenin alt menüsü → *Şablonlara ekle*.
- Görüntüleyici’de: bir geçmiş öğesi seçip *Şablonlara Ekle* düğmesini tıklayın ya da öğeyi
  Şablonlar ağacına sürükleyin. *Yeni Öğe* boş bir metin şablonu oluşturur; *Dosyadan Yeni Öğe*
  (bağlam menüsü) bir metin ya da görüntü dosyasından şablon oluşturur.

**Düzenleme**

- *Yeni Klasör* bir klasör oluşturur. Öğeleri klasörler arasında sürükleyin ya da bağlam
  menüsündeki *Yukarı* / *Aşağı* komutlarını kullanın.
- Adı `-` olan bir şablon menüde ayırıcı çizgiye dönüşür.
- Adda bir harfin önüne konan `&`, örneğin `&Teşekkür`, o harfi şablon menüsünde öğenin kısayolu
  yapar: menü açıkken `T` tuşuna basın.
- Bağlam menüsündeki *Kısayol Tuşu Ayarla* şablona kendi genel kısayol tuşunu verir.
- Adı olmayan bir şablon ilk satırını gösterir. *Yeniden Adlandır* ve *Adı Temizle* bağlam
  menüsündedir; metnin üstündeki *Ad* alanını da düzenleyebilirsiniz.

### Yer tutucular

Metin şablonları, yapıştırma anında doldurulan `{…}` yer tutucuları içerebilir. Geri kalan her şey
değiştirilmeden yapıştırılır. Görüntüleyici’de **Ekle ▾** bütün yer tutucuları listeler ve seçileni
imlecin olduğu yere koyar; yani ezberlemeniz gereken bir şey yoktur.

![Bugünün tarihi örneği: `{date:EEEE, d MMMM yyyy}` yapıştırıldığında geçerli tarihe dönüşür](site/img/guide/template-examples-date.png)

![Görüntüleyici’de Ekle ▾ bütün yer tutucuları listeler](site/img/guide/insert-menu.png)

En kullanışlı olanlar:

| Yer tutucu | Sonuç |
|-------------|--------|
| `{date}` `{time}` `{datetime}` | Bugünün tarihi / geçerli saat, sistem biçiminde |
| `{date:yyyy-MM-dd}` | Herhangi bir biçim (`yyyy MM dd EEEE HH mm …`) |
| `{date:long}` `{time:short}` `{datetime:medium}` | Adlandırılmış bir stil: `short` `medium` `long` `full` |
| `{date+7d}` `{date-1m:MMMM}` `{time+1h}` `{date+1y-2d}` | Kaydırma: `d` gün, `w` hafta, `m` ay, `y` yıl, `h` saat; `date`, `time`, `datetime` üzerinde, art arda birkaç tane olabilir |
| `{clipboard}` `{clipboard:2}` | Pano ya da N numaralı geçmiş öğesi |
| `{clipboard\|upper}` `{clipboard\|trim\|oneline}` | `upper` `lower` `title` `trim` `oneline` `url` süzgeçleri, zincirlenebilir |
| `{cursor}` | Yapıştırmadan sonra metin imlecinin duracağı yer |
| `{user}` `{username}` `{host}` | Tam ad, hesap adı, bilgisayar adı |
| `{uuid}` `{random:1-100}` | Yeni bir UUID; rastgele bir sayı |
| `{{` `}}` | Düz küme ayraçları: `{{"x":1}}` şablonu `{"x":1}` yapıştırır |

Yer tutucu adları küçük harfle yazılır: `{date}` bir yer tutucudur, `{Date}` ve `{DATE}` ise
metindir ve olduğu gibi yapıştırılır. Stil adları ve süzgeçler (`{date:LONG}`,
`{clipboard|UPPER}`) iki biçimde de yazılabilir.

Tam liste [yer tutucu özetindedir](#placeholder-cheat-sheet).

### Soru soran şablonlar

`{input:Ad}` ve `{choice:Etiket=A|B|C}` bir şablonu küçük bir forma dönüştürür: yapıştırdığınızda
Keepit önce değerleri sorar, sonra tamamlanmış metni yapıştırır. Aynı ad kaç kez geçerse geçsin
yalnızca bir kez sorulur; `{input:Ad=Varsayılan}` alanı önceden doldurur.

![{input:Name} içeren bir şablon yapıştırılırken önce değer sorulur](site/img/guide/input-dialog.png)

Örneğin bir yanıt şablonu:

```
Merhaba {input:Ad},

{date-1d} tarihli mesajınız için teşekkürler. Size en geç {date+3d:d MMMM} tarihinde dönüş yapacağım.
{cursor}
{user}
```

Yapıştırılırken *Ad* sorulur, tarihler doldurulur, tam adınızla imzalanır ve imleç boş satırda
bırakılır.

---

## Bölüm 4. Görüntüleyici

Menüdeki *Görüntüleyici…* ya da 📎 simgesine sağ tıklamak, üç ağaçlı bir pencere açar: **Pano**
(panonun şu anki içeriği, salt okunur), **Geçmiş** (*Metin ve dosyalar* ile *Görüntüler*) ve
**Şablonlar**.

![Bir şablonun seçili olduğu Görüntüleyici](site/img/guide/viewer.png)

- Bir öğeyi sağda görmek için seçin. Metin yerinde düzenlenebilir ve değişiklikler düzenleyiciden
  çıktığınızda uygulanır. Bir görüntü bölmeye sığacak ölçekte gösterilir; üstünde piksel boyutu ve
  dosya boyutu yazar. Dosya listeleri, çift tıklamayla dosyayı açar. Bağlam menüsündeki *Onaltılık
  döküm olarak göster* ham baytları gösterir.
- Araç çubuğu: *Panoya Gönder*, *Yapıştır* (geldiğiniz uygulamaya), *Şablonlara Ekle*, *Yeni Öğe*,
  *Yeni Klasör*, *Sil*, *Ekle ▾* (yer tutucular) ve bu kılavuzu açan **?**.
- **Ara** (`⌘F`): soldaki alan geçmişi ve şablonları ada ve içeriğe göre süzer ve eşleşmeyi
  vurgular.
- Geçmiş öğelerini saklamak için Şablonlar ağacına, şablonları geri kopyalamak için Geçmiş’e
  sürükleyin; sıralamayı sürükleyerek ya da *Yukarı* / *Aşağı* ile değiştirin. ⌫ seçili öğeyi
  siler.
- Durum çubuğu tarihi, kaynak uygulamayı, biçimi ve boyutu gösterir.

![Görüntüleyici’de arama eşleşmeleri vurgular](site/img/guide/viewer-search.png)

---

## Bölüm 5. Ayarlar

Menüde `⌘,`, *Ayarlar…* ya da herhangi bir uygulamadan ⌥S. Pencere, Mac’teki ayar pencereleri gibi
çalışır: araç çubuğundan bir bölme seçin; her değişiklik yaptığınız anda geçerli olur. Kaydet
düğmesi yoktur; pencereyi ⌘W ya da Esc ile kapatın. Yanında **?** olan her seçeneğin, onu açıklayan
bir açılır penceresi vardır.

![Ayarlar → Genel](site/img/guide/prefs-general.png)

| Bölme | Neler var |
|-----|---------------|
| **Genel** | Oturum açılırken başlatma · çıkışta geçmişi kaydetme ve açılışta geri yükleme · seçimden sonra yapıştırma (kapalı = yalnızca kopyalar) · yapıştırma gecikmesi; öne gelmesi yavaş olan uygulamalar için artırın · menüyü metin imlecinde açma · Güncellemeler: *Güncellemeleri otomatik denetle* (siteden indirilen sürüm; kapalı = hiçbir ağ isteği yok), bkz. [Güncellemeler](#updates) |
| **Kısayollar** | Bütün genel kısayollar tek yerde, aşağıya bakın |
| **Yapıştırma kuyruğu** | Kuyruğun üç tuşu, kuyruğun kapanacağı boşta kalma süresi ve *Kalanların tümünü yapıştır* için öğelerin arasına ne konacağı, bkz. [Yapıştırma kuyruğu](#the-paste-queue) |
| **Geçmiş** | Kaç metin/dosya öğesi ve kaç görüntü saklanacağı (1000 / 30) · … süreden eski öğeleri unutma · *Yinelenenleri kaldır* (aynı şeyi yeniden kopyalamak onu en üste taşır) · *Gizli pano verilerini yoksay* · yoksayılan uygulamalar listesi (paket tanıtıcıları; parola yöneticileri her zaman yoksayılır) |
| **Menü** | Arama alanı · numaralandırma · önizleme paneli · ipuçları · kaynak uygulama simgeleri · görüntü küçük resimleri · menüdeki öğeler (menünün en son kayıtlardan kaçını listeleyeceği, varsayılan 60; kalanlar aranabilir durumda kalır) · başlık uzunluğu · küçük resim yüksekliği |
| **Güvenlik** | Parola, Touch ID, kilitleme, kurtarma ifadesi, bkz. [Bölüm 6](#part-6-security) |
| **Yedekleme** | Otomatik yedekleme (başlığın yanında durum satırı): *Bir klasöre otomatik yedekle*, dosyalarda Mac’in adı, klasör, kaç kopya saklanacağı · Elle yedekleme: *Şimdi Yedekle*, *Arşive Kaydet…* · Geri yükleme: *Geri Yükle…*, bkz. [Yedekleme](#backup) |
| **Gelişmiş** | Pano yoklama aralığı · Otomasyon: *keepit:// URL komutlarına izin ver* (varsayılan olarak kapalı, bkz. [Otomasyon](#automation-the-keepit-url-scheme)) · Veriler: *Klasörü aç* · Sıfırla ve kaldır: *Sıfırla…* (yeni kurulum durumuna dönüş, örnek şablonlar geri gelir) · *Kaldır…* (sıfırlama, ardından uygulamanın, oturum açılırken başlatmanın, anahtar zinciri kaydının ve izinlerin kaldırılması) |

![Ayarlar → Geçmiş: sınırlar ve yoksayılan uygulamalar listesi](site/img/guide/prefs-history.png)

![Ayarlar → Kısayollar](site/img/guide/prefs-hotkeys.png)

**Kısayollar** bölmesinde bir alanı tıklayın ve bir tuş birleşimine basın; ⌫ bir tuşu kapatır.
Başka bir komutun kullandığı birleşim reddedilir ve nedeni alanların altında gösterilir.
*Varsayılanlara sıfırla*, ⌥ + harf takımını (⌥M geçmiş, ⌥T şablonlar, ⌥E Görüntüleyici, ⌥S Ayarlar,
⌥C Geçmişi temizle, ⌥P duraklatma, ⌥L kilit, ⌥Q çıkış), ⌥⇧V ile ⌃⌥ birleşimlerini geri getirir.
*Öğeyi numarayla yapıştır* ve *En son öğe için eylemler* yalnızca niteleyici tuş alır; rakamı ya da
harfi Keepit ekler. macOS ya da başka bir uygulama bir birleşimi zaten kullanıyorsa Keepit bunu
açılışta bildirir. *Görüntüleyici* ⌥E, *Ayarlar* ⌥S, *Geçmişi temizle* ⌥C, *Kaydı duraklat* ⌥P,
*Keepit’i kilitle* ⌥L ve *Keepit’ten çık* ⌥Q her uygulamadan çalışır ve menüde komutlarının yanında
gösterilir. ABD klavye düzeninde ⌥ + harf normalde özel bir karakter yazar (⌥S = ß, ⌥C = ç …);
bunlardan birine ihtiyacınız varsa kısayolu başka bir tuşa taşıyın. Keepit klavye düzenlerinizi de okur: Ayarlar’da ve menülerde gösterilen harfler, kullandığınız düzende o tuşların üzerindeki harflerdir; düzeninizin ihtiyaç duyduğu bir karakteri alacak varsayılan kısayolu (Almanca düzende ⌥L @ yazar, Lehçe düzende ł) Keepit açılışta boş bırakır — alanının altındaki not bunu söyler; yine de kullanmak için alana tıklayıp kombinasyona basın. Rusça gibi Latin olmayan bir düzende adlar, macOS’un o düzenle eşlediği Latin düzeninden alınır; sistemin kendi menülerinde de böyledir.

---

## Bölüm 6. Güvenlik

### Parola ve şifreleme

*Ayarlar → Güvenlik → Başlangıçta parola iste* geçmişi ve şablonları AES-256-GCM ile şifreler.
Anahtar parolanızdan türetilir (PBKDF2, 200 000 tur) ve yalnızca bellekte bulunur. Keepit
kilitlendiğinde silinir: *Keepit’i kilitle* (`⌥L`) komutuyla, çıkışta ve isteğe bağlı olarak Mac
bir süre kilitli ya da uykuda kaldıktan sonra. *Keepit otomatik kilit* yeni bir kurulumda
**Hiçbir zaman** değerindedir (3.0.3’ten yapılan güncelleme eski seçimini korur; ekranla birlikte
kilitleme kutusu işaretliyse *Hemen*): her kahve molasından sonra parolasını soran bir pano
yöneticisi kullanılmaz olur, önemli anlar için de `⌥L` vardır. *Hemen*, ekranla birlikte kilitler.
*5 dakika sonra*, *15 dakika sonra* ve *1 saat sonra* seçenekleri kısa bir yokluğu görmezden gelir
(Keepit açık kalır ve kaydetmeyi sürdürür) ve yalnızca Mac ayarlanan sürenin tamamı boyunca kilitli
ya da uykuda kaldıysa kilitler. Aynısı, Keepit Mac zaten kilitliyken ya da önde başka bir
kullanıcının oturumu varken başladığında da geçerlidir (örneğin güncellemeden sonraki yeniden
başlatma): süre, macOS bu durumu Keepit’e bildirdiği ölçüde başlangıçtan itibaren sayılır
(normalde bildirir; bildiremediğinde sayım bir sonraki kilitlenme ya da uykuyla başlar). Touch ID
açıkken Keepit, Mac’in kilidi açıldığı anda dokunmanızı ister; böylece ilk `⌥M` öncesinde hazır
olur.

![Ekran klavyesiyle parola belirleme. Bu bir ekran görüntüsü değil, ekranın fotoğrafıdır: yazarın Mac’inde bu sahnenin ekran görüntüsü yalnızca iletişim penceresini gösterir](site/img/guide/set-password-keyboard.jpg)

Parola pencereleri geçerli klavye düzenini gösterir ve Caps Lock konusunda uyarır; bu yüzden
reddedilen bir parola nadiren bilmece olur. Alanın yanındaki klavye düğmesi, parolayı fareyle
yazmak için bir **ekran klavyesi** açar: tıklamalar sistemden hiçbir zaman tuş basışı olarak
geçmez, tuşlar her açılışta karıştırılır ve klavye macOS’ten kendisini ekran görüntülerinin ve
ekran kayıtlarının dışında tutmasını ister (bazı yapılandırmalarda dışarıda tutulur; bu garanti
edilmez). Tam güvenmediğiniz ya da ekranı paylaşılan bir Mac içindir. Açılışta ve kilitlenmeden
sonra Keepit parolayı (ya da Touch ID’yi) sorar; *Erişimi Kurtar…* bunun yerine 24 kelimelik
ifadeyi kabul eder, bkz. [Kurtarma ifadesi](#recovery-phrase).

![Açılışta kilit açma: parola, Çık ya da kurtarma ifadesi; bir şey yazılana kadar Tamam devre dışı kalır. Yukarıdakiyle aynı nedenle fotoğraflanmıştır](site/img/guide/unlock-keyboard.jpg)

![Ayarlar → Güvenlik](site/img/guide/prefs-security.png)

### Touch ID

*Touch ID ile kilidi aç* seçeneğiyle anahtar, parmak izinizin arkasında Secure Enclave’de de
saklanır: Keepit parola yerine dokunmanızı ister. Parola yedek yöntem olarak çalışmayı sürdürür;
istem penceresinde *Parola Kullan…* seçeneğini kullanın. Kapak kapalıyken ve Touch ID’li harici
bir Magic Keyboard varken Keepit dokunmayı klavyede ister. *Parolayı Touch ID ile değiştirmeye izin
ver*, parolayı değiştirirken parmak izinin eski parolanın yerini tutmasını sağlar.

![Touch ID ile kilit açma; parola yedek yöntem olarak kalır](site/img/guide/touch-id.png)

### Kurtarma ifadesi

Bir parola belirlediğinizde Keepit 24 kelimelik bir ifadeyi bir kez gösterir. Yazdırın ya da bir
parola yöneticisinde saklayın. Parolayı unutursanız kilit açma penceresindeki *Erişimi Kurtar…*
verileri açar ve yeni bir parola belirlemenizi sağlar. *Kurtarma ifadesi → Yeni oluştur…* yeni bir
ifade üretir ve eskisini geçersiz kılar; yanındaki *Göster…*, Touch ID ya da paroladan sonra geçerli
ifadeyi yeniden gösterir.

Parola, aynı Mac’te Touch ID ya da ifade olmadan veriler kurtarılamaz: bir sunucu yoktur ve
sıfırlanacak bir şey de yoktur.

![24 kelimelik kurtarma ifadesi (kelimeler burada gizlenmiştir)](site/img/guide/recovery-phrase.png)

### Yedekleme

Keepit, geçmişinizin ve şablonlarınızın şifreli bir kopyasını seçtiğiniz bir klasörde (iCloud
Drive, Dropbox, Google Drive, harici bir disk, bir NAS) saklayabilir ve bir şey değiştiğinde
yenisini yazabilir. Keepit sunucusu yoktur: klasör sizindir. Klasörün arkasındaki sağlayıcı şifreli
dosyayı, boyutunu ve şifrelenmemiş küçük bir başlığı görebilir (dosyanın ne zaman ve hangi Keepit
tarafından yazıldığı, anahtarın nasıl türetildiği, rastgele tanıtıcılar ve yalnızca siz açarsanız
Mac’inizin adı); [güvenlik sayfası](/security#backups) (İngilizce) bunu alan alan listeler.

![Ayarlar → Yedekleme: otomatik yedekleme, elle yedekleme, geri yükleme](site/img/guide/prefs-backup.png)

**Açma.** *Ayarlar → Yedekleme → Bir klasöre otomatik yedekle*, ardından *Seç…* ile bir klasör
seçin (seçici iCloud Drive’da açılır). Otomatik yedekleme, *Ayarlar → Güvenlik* bölümündeki parola
korumasını gerektirir: her kopya, kasanızın anahtarından türetilen bir anahtarla mühürlenir; bu
yüzden bu Mac’te ya da başka herhangi bir Mac’te Keepit parolanızla ya da kurtarma ifadenizle
açılır ve bunun için ayrıca bir şey ayarlamak gerekmez. Parola yokken onay kutusu devre dışıdır ve
nedenini belirtir.

**Sonra ne olur: zamanlama.** Son değişiklikten yaklaşık beş dakika sonra (ve Keepit çalıştığı
sürece en az günde bir kez) Keepit klasöre `Keepit-<tarih ve saat>-<kurulum>-<kimlik>.keepit` adlı
bir dosya yazar, denetlemek için geri okur ve ancak ondan sonra kendi kopyalarından *Son şu
kadarını sakla* sayısını (varsayılan 10, aralık 1–100) aşan en eskileri siler. Her kopya kendi
başına eksiksizdir, artımlı değildir; yani tek bir dosya ihtiyacınız olan her şeydir. Başka bir
Mac’in yaptığı kopyalara ya da oraya sizin koyduğunuz dosyalara hiç dokunulmaz: bir klasörü
paylaşan iki Mac iki bağımsız dizi yazar. *Otomatik yedekleme* başlığının yanındaki durum satırı
son kopyanın saatini ve boyutunu ya da son denemenin neden başarısız olduğunu gösterir. Keepit
kilitliyken hiçbir şey olmaz; *Şimdi Yedekle* (*Elle yedekleme* altında) sakin dönemi beklemez.

**Bu Mac’in adını ekle** (varsayılan olarak kapalı), bilgisayarın adını her dosyanın şifrelenmemiş
başlığına koyar; böylece tek klasördeki iki dizi Finder’da kolayca ayırt edilir. Depolama
sağlayıcısı bu adı görebilir; seçeneğin isteğe bağlı olmasının nedeni budur.

**Geri yükleme.** *Geri Yükle…*, kilidini açmanızın ardından bir yedeği açar (bu Mac’in, başka bir
Mac’in ya da dışa aktarılmış bir dosya): yedeğin yapıldığı Mac’in parolasıyla ya da o Mac’in
parolası belirlenirken gösterdiği kurtarma ifadesiyle (parola penceresinde *Erişimi Kurtar…*). Bir
önizleme, dosyanın ne zaman ve nerede yapıldığını ve kaç öğe içerdiğini gösterir. Sonra iki seçenek
vardır:

![Geri yükleme önizlemesi: dosyanın ne zaman ve hangi Keepit tarafından yazıldığı, ne içerdiği, Birleştir ya da Değiştir](site/img/guide/restore-preview.png)

- *Birleştir* henüz burada olmayanları ekler: geçmiş öğelerini içeriğe göre, yedekteki şablonları
  ise kısayol tuşları olmadan *İçe aktarıldı <tarih>* adlı tek bir yeni klasör olarak. Böylece
  yedekten tam olarak neyin geldiğini görür, onu taşıyabilir ya da silebilirsiniz. Sizin hiçbir
  verinizin üzerine yazılmaz.
- *Değiştir* geçerli geçmişi ve şablonları atar ve yerine yedektekileri alır. Bunu yapmadan önce
  Keepit şu anda sahip olduklarınızın bir kopyasını (`Keepit-before-restore-…`) yedek klasörüne ya
  da sizin seçtiğiniz bir klasöre yazar; bu kopya yazılamazsa Değiştir başlamaz. Keepit’in henüz
  parolası yoksa, *Arşive Kaydet…* komutunda olduğu gibi bu kopya için bir parola istenir.

*Tercihleri de geri yükle*, kısayol tuşlarını, sınırları ve seçenekleri yedekten getirir. Belirli
bir Mac’e duyulan güveni ifade eden ayarlar (Touch ID, URL otomasyonu ve güvenilen uygulamaları,
yedek klasörünün kendisi) her zaman buradaki gibi kalır. Yedeğin geçmişi bu Mac’in sınırlarının
izin verdiğinden büyükse Keepit, siz onaylamadan önce ne kadarının sığacağını söyler.

Henüz parolası olmayan bir Mac’te bir yedeği kurtarma ifadesiyle mi geri yüklediniz? Keepit önce
bir parola belirlemenizi ister; böylece geri yüklenen veriler diske hiçbir zaman şifresiz yazılmaz.
Ayrıca o ifadeyi bu Mac için tutmanıza ya da yenisini almanıza izin verir. Parolayla mı geri
yüklediniz? Keepit onu bu Mac’in parolası olarak tutmayı önerir. Her iki durumda da otomatik
yedekleme her Mac için ayrı bir ayardır: burada açın ve klasörü seçin (aynı klasör olabilir); bu
Mac, eski Mac’in dosyalarının yanında kendi dosya dizisini başlatır.

**Yeni bir Mac’e geçiş** bütün bunların asıl amacıdır: Keepit’i kurun, ilk açılışta *Yedekten Geri
Yükle…* seçeneğini seçin, klasörünüzdeki en yeni dosyayı seçin, eski Mac’in parolasını girin ve
*Değiştir* seçeneğini kullanın; ardından yeni Mac’te otomatik yedeklemeyi açın. O ana kadar
yapılmış kopyalar, her biri yazıldığında geçerli olan parola ve ifadeyle açılır: parola
değiştirildikten sonra eski kopyalar yine eski parolayı gerektirir.

**Elle yedekleme.** İki düğme vardır ve ikisi farklı işler yapar. *Şimdi Yedekle* hemen, otomatik
kopyalarla aynı türden bir kopya yapar: aynı tür dosya, aynı klasör ve dizi; Keepit parolanızla ya
da ifadenizle açılır. *Arşive Kaydet…* ise seçtiğiniz yere tek bir `.keepit` *arşivi* yazar ve onu,
o arşiv için belirlediğiniz bir parolayla kilitler. Keepit’in parola korumasını gerektirmez ve
Keepit sonrasında dosyayı izlemez. Veri devretmek ya da yedek klasörünün dışında bir kopya
bulundurmak içindir. Önerilen ad ne olduğunu söyler: otomatik kopyaların
`Keepit-<tarih ve saat>-<kurulum>-<kimlik>.keepit` adının yanında
`Keepit-archive-<tarih>-manual.keepit`.

![Arşive Kaydet…: dosya adında archive ve manual sözcükleri geçer](site/img/guide/save-to-archive.png)

![Arşivin güç göstergeli kendi parolası: hiçbir yerde saklanmaz](site/img/guide/archive-password.png)

*Geri Yükle…* ikisini de açar. Arşiv, 2.x’teki *Dışa aktar…* / *İçe aktar…* komutlarının yerini
alır. Dosya, verileri siteden indirilen sürüm ile App Store sürümü arasında ve Keepit 2.x ile 3.x
arasında taşır: 3.0 ile yazılmış bir dosyayı açmak için 3.0 veya sonrası gerekir; 3.0, 2.x’in
yazdığı her şeyi okur.

**Bir şeyler ters giderse.** Başarısız bir kopya durum satırında bildirilir ve giderek uzayan
aralarla yeniden denenir; önceki kopyalar yerinde kalır. Geri yüklemenin ortasında Keepit’ten
çıkıldıysa ya da Mac kapandıysa, bir sonraki açılış her şeyi sessizce geri yüklemeden önceki
durumuna döndürür. Bunun yapılamadığı ender durumda (yazılamayan bir dosya, dolu bir disk) Keepit
dosyanın adını bildirir ve hiçbir şeyi değiştirmeden çıkar: dosyayla ilgili sorunu giderin ve
Keepit’i yeniden açın. Dosya biçiminin içeriden nasıl göründüğü de dahil ayrıntılar
[güvenlik sayfasındadır](/security#backups) (İngilizce).

---

## Bölüm 7. Gelişmiş

### Otomasyon: keepit:// URL şeması

Kestirmeler (*URL’leri Aç*), Raycast, Alfred, Keyboard Maestro ya da kabuktaki `open` komutu
Keepit’i yönetebilir; ancak **siz açtıktan sonra**: *Ayarlar → Gelişmiş → Otomasyon → keepit://
URL komutlarına izin ver*. Varsayılan olarak kapalıdır, çünkü herhangi bir uygulama ya da web
sayfası bir URL açabilir, `add` / `paste` ise panoyu değiştirir ve öndeki uygulamaya yazar; kapalıyken
Keepit bu tür URL’leri bir uyarı sesiyle yoksayar. Açıkken Keepit, URL’yi kimin açtığına bakar: her
uygulamadan gelen ve bir şeyi değiştiren ilk komut (`paste`, `copy`, `template`, `add`,
`add-template`, `pause`, `resume`) bir iletişim penceresinde gösterilir. *İzin ver* onu bir kez
çalıştırır, *Her zaman izin ver* uygulamayı güvenilenler listesine ekler (liste aynı bölmedeki
*Güvenilen uygulamaları unut* ile temizlenir). Bir web tarayıcısına ya da macOS’in adlandıramadığı
bir göndericiye her seferinde sorulur. Yalnızca Keepit’in kendi pencerelerini açan komutlar hiçbir
zaman sormaz.

| URL | Etki |
|-----|--------|
| `keepit://paste/2`<br>`keepit://paste/latest`<br>`keepit://paste/previous` | N numaralı geçmiş öğesini (ya da en sonuncuyu / bir öncekini) öndeki uygulamaya yapıştırır |
| `keepit://copy/3` | N numaralı öğeyi yapıştırmadan panoya koyar |
| `keepit://template/Signature`<br>`keepit://template/Work/Reply?copy=1` | Bir şablonu adına ya da klasör yoluna göre yapıştırır (ya da kopyalar) |
| `keepit://add?text=…` | Geçmişe ve panoya metin ekler |
| `keepit://add-template?text=…&name=…` | Bir şablon oluşturur |
| `keepit://history`<br>`keepit://templates`<br>`keepit://viewer`<br>`keepit://settings` | Geçmiş menüsünü, şablon menüsünü, Görüntüleyici’yi, Ayarlar’ı açar |
| `keepit://pause`<br>`keepit://resume` | Kaydı 10 dakika duraklatır / sürdürür |

Metni yüzde kodlamasıyla kodlayın (boşluk için `%20`). Keepit kilitliyken URL’ler yoksayılır.

### Güncellemeler

Keepit günde bir kez GitHub Releases sayfasını denetler ve güncellemeleri bir iletişim penceresinde
önerir; *Güncellemeleri Denetle…* bunu hemen yapar. Güncellemeler imzalıdır (EdDSA) ve Apple
tarafından onaylanmıştır. Homebrew ile aynı işi `brew upgrade --cask keepit` yapar. Her indirmenin sağlama
toplamları sürüm sayfasındaki `SHA256SUMS` dosyasındadır.

Bu denetim, Keepit’in gönderdiği tek ağ isteğidir ve isteğe bağlıdır: *Ayarlar → Genel →
Güncellemeler → Güncellemeleri otomatik denetle*. Kapatıldığında Keepit, siz isteseniz bile hiçbir
yere bağlanmaz ve *Güncellemeleri Denetle…* menülerden kaybolur. O zaman güncellemeyi
[keep.it.com](https://keep.it.com) adresinden indirerek ya da Homebrew ile yaparsınız. App Store
sürümünde güncelleyici de böyle bir seçenek de yoktur; onu App Store günceller.

### Kaldırma

*Ayarlar → Gelişmiş → Sıfırla ve kaldır → Kaldır…* uygulamayı, veri klasörünü, anahtar zinciri
kayıtlarını (Touch ID anahtarı dahil), giriş öğesini ve Erişilebilirlik kaydını kaldırır.
Parolanızı ya da Touch ID’yi, elle yazılmış bir `DELETE` sözcüğünü ve bir onay ister. Verileri
geri isteyebilecekseniz önce bir yedeği dışa aktarın. Homebrew kullanıyorsanız, Homebrew’un cask’i
unutması için ardından `brew uninstall --cask --force keepit` komutunu çalıştırın.

![Ayarlar → Gelişmiş](site/img/guide/prefs-advanced.png)

---

## Başvuru

### Sorun giderme

**Bir öğe seçtikten sonra hiçbir şey yapıştırılmıyor.** Erişilebilirlik izni eksik: *Sistem
Ayarları → Gizlilik ve Güvenlik → Erişilebilirlik → Keepit*. Keepit listede olduğu hâlde
yapıştırmıyorsa kapatıp yeniden açın. Uygulama yeniden kurulduğunda macOS verilen izni unutur.

**Bir kısayol tuşu hiçbir şey yapmıyor.** Onu başka bir uygulama ya da macOS kullanıyor; Keepit
bunu açılışta bildirir. *Kısayollar* bölmesinde başka bir birleşim seçin. Rakam ve harflerle ⌃⌥,
fabrika ayarlarındaki bir Mac’te boştadır. Ya da klavye düzenlerinizden birinde bir karakter yazdığı için Keepit’in boş bıraktığı varsayılan bir kısayoldur; *Kısayollar* panelinde alanının altındaki not bunu söyler. Başka bir kombinasyon seçin ya da yine de kullanmak için alana tıklayıp aynısına basın. Bir Keepit menüsü açıkken ⌃⌥V hiçbir şey yapıştırmaz: macOS, menülerde seçimi taşımak için ⌃V’yi (ayrıca ⌃N ve ⌃P’yi) kullanır. Önce menüyü kapatın ya da ⇧ tuşunu basılı tutup öğenin alt menüsünden *Düz metin olarak yapıştır* seçeneğini seçin. Aynı nedenle *Keepit'i kilitle* kısayolu ⌃ ile V, N veya P olamaz.

**Menü yanlış yerde açılıyor.** İçinde bulunduğunuz uygulama metin imlecini bildirmiyor; bu yüzden
menü fare imlecinin yanında açılıyor. Her zaman fare imlecini tercih ediyorsanız Genel bölmesindeki
*Mümkünse menüyü metin imlecinde aç* seçeneği imleç aramayı kapatır.

**Kopyaladığım bir şey eksik.** Kopyalayan uygulamanın gizli olarak işaretlediği hiçbir şey
kaydedilmez; bir parola yöneticisi (yerleşik liste) ya da yoksayma listenizdeki bir uygulama
öndeyken yapılan kopya da kaydedilmez. Buna, az önce ayrıldığınız uygulama da dahildir. Bkz.
*Ayarlar → Geçmiş* ve [güvenlik sayfası](/security#what-is-not-recorded) (İngilizce).

**Touch ID önerilmiyor.** Şu anda erişilebilir bir Touch ID algılayıcısı yok (kapak kapalı, Touch
ID’li klavye yok). Keepit ayarı korur ve bir algılayıcı kullanılabilir olur olmaz parmak izini ister.

**Yedekleme durumu klasörün kullanılamadığını söylüyor.** Klasör taşınmış, yeniden adlandırılmış,
bağlantısı kesilmiş ya da (iCloud Drive’da) yerel depolamadan çıkarılmış. Klasörü yeniden bağlayın
ya da geri getirin, bir sonraki kopya yazılır; ya da *Seç…* ile yeni bir klasör seçin. Yeni klasör
yeni bir dizi başlatır, eski dosyalar olduğu yerde kalır.

**Bir yedek dosyası açılmıyor.** *Yanlış parola*, dosyanın kimlik doğrulama etiketinin eşleşmediği
anlamına gelir: dosyayı *yazan* Mac’in parolasını (parola değiştirildikten sonra eski kopyalar yine
eski parolayla açılır) ya da o Mac’in kurtarma ifadesini kullandığınızdan emin olun. *Bu yedek,
Keepit 3.0 veya daha yenisini gerektirir*, dosyanın onu açan sürümden daha yeni bir sürümle
yazıldığı anlamına gelir.

**Homebrew var olan bir uygulamanın üzerine kurmayı reddediyor.** Önce Keepit’ten çıkın ve
`/Applications/Keepit.app` dosyasını Çöp Sepeti’ne taşıyın ya da `--force` ekleyin.

Sorun sürüyor mu? [GitHub Issues](https://github.com/andrey-insarov/Keepit/issues) · admin@keep.it.com

### Kısayol özeti

| Tuşlar | Eylem |
|------|--------|
| `⌥M` | Geçmiş menüsü; aramak için yazın |
| `⌥T` | Şablon menüsü |
| `⌃⌥1` … `⌃⌥0` | 1–10 numaralı öğeyi yapıştır (menüde ve her yerde) |
| Menüde `⇧` | Genişletilmiş menü: her öğe için bütün eylemler |
| `⌥⇧V` | Önceki öğeyi yapıştır / yer değiştir |
| `⌃⌥V` | Panoyu düz metin olarak yapıştır |
| `⌃⌥U` `⌃⌥L` `⌃⌥T` `⌃⌥S` | BÜYÜK HARF / küçük harf / Her Kelime Büyük / Cümle düzeni |
| `⌃⌥W` `⌃⌥J` | Kırpılmış / tek satır |
| `⌃⌥K` `⌃⌥D` `⌃⌥Y` `⌃⌥X` | Üstü çizili / altı çizili / dalgalı altı çizili / süslemeleri kaldır |
| `⌃⌥A` | Panoyu Şablonlara ekle |
| `⌃⌥⌫` | En yeni öğeyi sil |
| `⌥N` · `⌥V` · `⌥⇧N` | Yapıştırma kuyruğu: başlat / durdur · sıradakini yapıştır · kalanların tümünü yapıştır |
| `⌥E` `⌥S` `⌥C` `⌥P` `⌥L` `⌥Q` | Görüntüleyici · Ayarlar · Geçmişi temizle · Kaydı duraklat · Kilitle · Çık |
| Görüntüleyici’de `⌘F` | Ara |
| `⌘,` | Ayarlar |

### Yer tutucu özeti

| Yer tutucu | Sonuç |
|-------------|--------|
| `{date}` `{time}` `{datetime}` | Tarih / saat / ikisi birden, sistem biçiminde |
| `{date:yyyy-MM-dd}` `{time:HH:mm}` | Özel biçim (Unicode tarih kalıpları) |
| `{date:long}` `{time:short}` `{datetime:full}` | Adlandırılmış stil: `short` `medium` `long` `full` |
| `{date+7d}` `{date-1m:MMMM}` `{time+1h}` `{datetime-1d:long}` `{date+1y-2d}` | Kaydırma (`d` `w` `m` `y` `h`; art arda en çok dört kaydırma) |
| `{weekday}` `{month}` `{year}` | Gün adı, ay adı, yıl |
| `{iso}` `{unix}` | ISO 8601 zaman damgası, Unix zamanı |
| `{clipboard}` `{clipboard:2}` | Pano (1 numaralı öğe) ya da N numaralı öğe |
| `{clipboard\|upper}` `\|lower` `\|title` `\|trim` `\|oneline` `\|url` | Süzgeçler, zincirlenebilir |
| `{input:Ad}` `{input:Ad=Varsayılan}` | Yapıştırmadan önce bir değer sorar |
| `{choice:Etiket=A\|B\|C}` | Bir seçenek seçmenizi ister |
| `{cursor}` | Yapıştırmadan sonra imlecin konumu |
| `{user}` `{username}` `{host}` | Tam ad, hesap adı, bilgisayar adı |
| `{uuid}` `{random:1-100}` | Yeni UUID, bir aralıkta rastgele sayı |
| `{{` `}}` | Düz küme ayraçları |
