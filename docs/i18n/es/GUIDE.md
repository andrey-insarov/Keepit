<!-- source: GUIDE.md 39bab8b4f2a3de5ce61f2427db3f17e669b6f280 -->
# Guía de Keepit

Keepit es un gestor del historial del portapapeles y de plantillas para macOS. Vive en la barra de
menús, recuerda todo lo que copias y vuelve a pegar cualquier elemento con un atajo de teclado. Todos
los atajos que aparecen aquí son los que vienen por omisión, y cada uno se puede cambiar en *Ajustes →
Atajos*. Esta guía describe Keepit 3. La guía de Keepit 2.x se conserva sin cambios en
[keep.it.com/v2/guide](https://keep.it.com/v2/guide) (en inglés).

![El menú del historial](site/img/guide/menu.png)

**Contenido**

- [Parte 1: Primeros pasos](#part-1--getting-started): [Instalación](#install) · [Primer arranque](#first-launch)
- [Parte 2: Uso diario](#part-2--everyday-use): [El menú del historial](#the-history-menu) · [Búsqueda y vista previa](#search-and-preview) · [Pegar sin el menú](#paste-without-the-menu) · [La cola de pegado](#the-paste-queue) · [El menú ampliado](#the-extended-menu)
- [Parte 3: Plantillas](#part-3--templates): [Crear y organizar](#creating-and-organising) · [Marcadores](#placeholders) · [Plantillas que hacen preguntas](#templates-that-ask-questions)
- [Parte 4: El Visor](#part-4--the-viewer)
- [Parte 5: Ajustes](#part-5--settings)
- [Parte 6: Seguridad](#part-6-security): [Contraseña y cifrado](#password-and-encryption) · [Touch ID](#touch-id) · [Frase de recuperación](#recovery-phrase) · [Copia de seguridad](#backup)
- [Parte 7: Funciones avanzadas](#part-7--advanced): [Automatización](#automation-the-keepit-url-scheme) · [Actualizaciones](#updates) · [Desinstalación](#uninstalling)
- [Referencia](#reference): [Solución de problemas](#troubleshooting) · [Resumen de atajos](#keyboard-cheat-sheet) · [Resumen de marcadores](#placeholder-cheat-sheet)

---

## Parte 1: Primeros pasos

### Instalación

**Homebrew** es el método recomendado, porque `brew upgrade` mantiene la app al día:

```bash
brew tap andrey-insarov/keepit https://github.com/andrey-insarov/Keepit
brew install --cask andrey-insarov/keepit/keepit
```

**DMG:** descarga `Keepit-<version>.dmg` desde la página de la
[última versión](https://github.com/andrey-insarov/Keepit/releases/latest), ábrelo y arrastra Keepit
a *Aplicaciones*.

![El DMG: arrastra Keepit a Aplicaciones](site/img/guide/dmg.png)

La primera vez que abres la app, macOS confirma que procede de internet y que Apple la ha comprobado.
Haz clic en *Abrir*.

![Confirmación de Gatekeeper en macOS](site/img/guide/gatekeeper.png)

Keepit está firmado y certificado por Apple, se actualiza solo y funciona de forma nativa en los Mac
con chip de Apple y con Intel que tengan macOS 13 Ventura o posterior.

### Primer arranque

Keepit es una app de la barra de menús: no tiene icono en el Dock ni ventana hasta que abras alguna.
Tras el primer arranque aparece el icono 📎 en la barra de menús y Keepit te hace tres preguntas.

**1. ¿Restaurar desde una copia de seguridad?** Si es un Mac nuevo y tienes una copia de Keepit (una
automática en iCloud Drive o en otra carpeta, o un archivo `.keepit` exportado), *Restaurar desde
copia…* recupera el historial y las plantillas antes de que ocurra nada más. El archivo se desbloquea
con la contraseña del Mac del que procede o con su frase de recuperación. *Empezar de cero* se salta
este paso. La misma restauración está disponible más adelante en *Ajustes → Copia de seguridad →
Restaurar…*, y también se abre al hacer doble clic en un archivo `.keepit` en el Finder. Los detalles
están en [Copia de seguridad](#backup).

![La primera pregunta en un Mac nuevo: restaurar desde una copia o empezar de cero](site/img/guide/restore-first-run.png)

**2. Una contraseña (opcional).** Keepit puede guardar cifrados el historial y las plantillas y
desbloquearlos con Touch ID. Puedes decidirlo ahora o más adelante en *Ajustes → Seguridad*. La
[Parte 6](#part-6-security) explica cómo funciona. Con *Ahora no* todo queda sin cifrar en el disco.
Si acabas de restaurar una copia con su contraseña, Keepit te ofrece mantener esa contraseña en este
Mac.

![La propuesta de contraseña en el primer arranque](site/img/guide/password-offer.png)

![Al elegir «Ahora no»: se dice con claridad qué significa y dónde se cambia](site/img/guide/no-password-notice.png)

**3. El permiso de Accesibilidad.** Para pegar por ti, Keepit envía ⌘V a la app en la que estabas
trabajando. macOS solo lo permite a las apps que figuran en *Ajustes del Sistema → Privacidad y
seguridad → Accesibilidad*. Haz clic en *Abrir Ajustes del Sistema* y activa Keepit. Sin el permiso,
Keepit sigue grabando y copiando, pero ⌘V lo pulsas tú.

![Keepit pide el permiso de Accesibilidad](site/img/guide/accessibility-prompt.png)

![Keepit activado en Privacidad y seguridad → Accesibilidad](site/img/guide/accessibility-settings.png)

Keepit se abre al iniciar sesión por omisión. Se desactiva en *Ajustes → General*.

---

## Parte 2: Uso diario

### El menú del historial

Pulsa **⌥M** en cualquier app o haz clic en el icono 📎. El menú se abre junto al cursor de texto
cuando Keepit consigue localizarlo y, si no, junto al puntero del ratón.

Cada línea es un elemento copiado, con el más reciente arriba. Ese aparece en **negrita**, porque es
lo que hay ahora mismo en el portapapeles. El icono indica la app desde la que copiaste. Un título
que termina en `…` tiene más líneas de las que muestra el menú. Las imágenes se ven en miniatura y las
listas de archivos, con los nombres de los archivos.

![El panel de vista previa junto al menú muestra entero el elemento resaltado, con su app de origen, la hora y el tamaño](site/img/guide/menu-preview.png)

![Una imagen en el historial: miniatura en el menú, imagen completa en la vista previa](site/img/guide/menu-image.png)

Para pegar un elemento, haz clic en él, o llega hasta él con ↑ ↓ y pulsa Retorno, o pulsa su número
con **⌃⌥**: `⌃⌥3` pega el elemento 3. La misma tecla funciona desde cualquier sitio, sin abrir el
menú.

Debajo del historial están el submenú *Plantillas*, el Visor (⌥E), los Ajustes (⌥S), *Borrar historial*
(⌥C), *Pausar la grabación 10 minutos* (⌥P, para escribir algo que no quieres que quede grabado),
*Bloquear Keepit* (⌥L) cuando hay contraseña, y las actualizaciones. **⌥T** abre el menú de plantillas
por separado. Todas estas teclas funcionan también sin el menú.

### Búsqueda y vista previa

**Búsqueda.** Empieza a escribir con el menú abierto: el campo de arriba filtra la lista por título y
por el texto completo, así que también encuentra una línea en mitad de un elemento largo. Retorno pega
la primera coincidencia, Esc vacía el campo y un segundo Esc cierra el menú.

**Vista previa.** Pasa el puntero por encima de un elemento (o llega hasta él con el teclado) y un
panel junto al menú mostrará la imagen completa o las primeras líneas de un texto largo, con la app de
origen, la fecha y el tamaño. Los textos cortos de una sola línea no tienen vista previa, porque la
línea del menú ya los muestra enteros.

![Al escribir se filtra el menú; el panel de vista previa muestra el elemento resaltado](site/img/guide/search-preview.png)

### Pegar sin el menú

Los atajos globales actúan desde cualquier app sobre el historial tal como está en ese momento. El
elemento 1 es el portapapeles:

| Teclas | Qué ocurre |
|------|--------------|
| `⌃⌥1` … `⌃⌥9`, `⌃⌥0` | Pegar el elemento 1 a 10 del historial |
| `⌥⇧V` | Pegar el elemento *anterior* (el 2); pulsa otra vez para volver al primero |
| `⌃⌥V` | Pegar el portapapeles como texto sin formato |
| `⌃⌥U` `⌃⌥L` `⌃⌥T` `⌃⌥S` | Pegar el portapapeles en MAYÚSCULAS / minúsculas / Mayúscula En Cada Palabra / con mayúscula inicial |
| `⌃⌥W` | Pegar el portapapeles sin los espacios del principio y del final |
| `⌃⌥J` | Pegar el portapapeles unido en una sola línea |
| `⌃⌥K` `⌃⌥D` `⌃⌥Y` | Pegar el portapapeles tachado / subrayado / con subrayado ondulado, como texto sin formato que conserva su aspecto en cualquier sitio, también en los chats (ver más abajo) |
| `⌃⌥X` | Pegar el portapapeles sin esas decoraciones |
| `⌃⌥A` | Añadir el portapapeles a Plantillas |
| `⌃⌥⌫` | Eliminar del historial el elemento más reciente |

Las tres decoraciones no son formato: Keepit añade detrás de cada carácter un *signo combinable* de
Unicode (t̶a̶c̶h̶a̶d̶o̶, s̲u̲b̲r̲a̲y̲a̲d̲o̲, o̰n̰d̰ṵl̰a̰d̰o̰), de modo que el texto se ve igual en una app de
mensajería, en un formulario web o en un terminal, donde el formato real se perdería. El precio es que
ese texto ocupa el triple, que una búsqueda de la palabra normal no lo encuentra, que los lectores de
pantalla tropiezan con él y que algunas tipografías dibujan la línea de forma irregular. *Quitar
decoraciones* (`⌃⌥X`) elimina esos signos, también de un texto decorado en otro sitio. En los dos
sentidos los signos se eliminan por su punto de código, vengan de donde vengan: una transcripción
fonética que usa esos mismos signos como letras (U+0330 es también el signo del AFI para la voz
laringalizada) los pierde, y las tres decoraciones también empiezan por quitarlos. Con VoiceOver
activado, `⌃⌥` es su propio modificador: asigna otro a *Acciones sobre el último elemento* en
Ajustes → Atajos.

Las transformaciones se aplican al texto. Con una imagen o una lista de archivos, la tecla emite un
pitido. Todo esto se puede cambiar o desactivar en *Ajustes → Atajos*.

### La cola de pegado

A veces quieres copiar cinco cosas en un sitio y pegarlas en orden en otro: celdas en un formulario,
líneas de una página en un documento. La cola de pegado lo hace sin el menú:

1. Pulsa **⌥N** (o elige *Iniciar la cola de pegado* en el menú). El icono de la barra de menús
   muestra un punto rojo y un contador: `📎 ● 0`.
2. Copia como siempre con ⌘C, todas las veces que quieras. El contador sube con cada copia: 1, 2, 3…
   Todo queda también en el historial.

   ![La barra de menús con la cola activa: punto rojo y contador](site/img/guide/queue-menubar.png)

3. Ve al lugar donde va el texto y pulsa **⌥V** para cada elemento. Lo que copiaste primero se pega
   primero, y el contador baja. ⌘V sigue pegando el portapapeles como siempre, así que puedes combinar
   las dos cosas.
4. La cola se desactiva sola cuando se pega el último elemento, o tras dos minutos sin copiar ni pegar
   (el tiempo se puede ajustar). Otro ⌥N la detiene antes.

**⌥⇧N** pega de una vez todo lo que queda en la cola. Los elementos se unen con un salto de línea, un
tabulador, un espacio o nada: se elige en el panel *Cola de pegado* de los Ajustes, donde también está
el tiempo de inactividad. Mientras la cola está activa, el menú del historial marca sus elementos: `▶`
es el siguiente en pegarse, `○` sigue en cola y `✓` ya se ha pegado.

![El menú del historial con la cola activa: ○ en cola, ▶ siguiente, ✓ pegado; la línea del menú indica cuántos quedan](site/img/guide/queue-menu.png)

![Ajustes → Cola de pegado](site/img/guide/prefs-queue.png)

### El menú ampliado

Mantén pulsada **⇧** con el menú del historial abierto y cada elemento tendrá un submenú `▸` con todas
sus acciones: Pegar, Pegar como texto sin formato, Solo copiar (al portapapeles, sin pegar), las
transformaciones de *Pegar como*, Añadir a Plantillas, Mostrar en el Visor y Eliminar. Señala un
elemento o pulsa → para abrirlo. Una vez abierto, puedes soltar ⇧.

![Con ⇧ pulsada, cada elemento tiene un submenú; en el elemento más reciente muestra los atajos globales](site/img/guide/extended-menu.png)

En el elemento más reciente, el submenú indica los atajos globales de la tabla anterior. Son las mismas
acciones con las mismas teclas, así que es un buen sitio para aprenderlas. Los demás elementos muestran
las acciones sin teclas: un atajo funciona en todas partes o no se muestra.

![En los demás elementos: las mismas acciones, sin atajos](site/img/guide/extended-menu-item2.png)

![En una imagen, las acciones de texto aparecen atenuadas: solo se aplican Pegar, Solo copiar, Añadir a Plantillas, Mostrar en el Visor y Eliminar](site/img/guide/extended-menu-image.png)

---

## Parte 3: Plantillas

Las plantillas son elementos que guardas para siempre: firmas, direcciones, respuestas tipo, fragmentos
de código, un logotipo que pegas a menudo. Están en un árbol con carpetas y aparecen en el submenú
*Plantillas* del menú del historial y con **⌥T**. Una instalación nueva trae una carpeta *Ejemplos*
(un saludo, la fecha de hoy, una cita del portapapeles y una firma) para que veas lo que pueden hacer
las plantillas antes de escribir las tuyas. Bórralas o edítalas como quieras (*Restablecer…* en los
Ajustes las recupera).

![La carpeta Ejemplos: al pasar el puntero por un elemento se ve su texto](site/img/guide/template-examples.png)

![El menú de plantillas: las carpetas se abren como submenús y las letras precedidas de & se convierten en teclas de acceso rápido](site/img/guide/template-menu-letters.png)

### Crear y organizar

**Añadir una plantilla**

- Desde el menú del historial: `⌃⌥A` para el elemento más reciente, *Añadir el portapapeles a las
  plantillas* al final del menú, o ⇧ → submenú del elemento → *Añadir a Plantillas* para cualquier
  elemento.
- En el Visor: selecciona un elemento del historial y haz clic en *Añadir a plantillas*, o arrástralo
  al árbol de plantillas. *Nuevo elemento* crea una plantilla de texto vacía; *Nuevo elemento desde
  archivo…* (menú contextual) crea una a partir de un archivo de texto o de imagen.

**Organizar**

- *Nueva carpeta* crea una carpeta. Arrastra elementos de una carpeta a otra, o usa *Subir* / *Bajar*
  en el menú contextual.
- Una plantilla llamada `-` se convierte en una línea de separación en el menú.
- Un `&` delante de una letra del nombre (por ejemplo `&Firma`) convierte esa letra en la tecla de
  acceso rápido del elemento en el menú de plantillas: pulsa `F` con el menú abierto.
- *Definir atajo…* en el menú contextual da a una plantilla su propio atajo global.
- Una plantilla sin nombre muestra su primera línea. *Renombrar* y *Borrar nombre* están en el menú
  contextual, o edita el campo *Nombre* que hay encima del texto.

### Marcadores

Las plantillas de texto pueden contener marcadores `{…}` que se rellenan en el momento de pegar. Todo
lo demás se pega tal cual. En el Visor, **Insertar ▾** muestra todos los marcadores y coloca el que
elijas donde está el cursor, así que no hay nada que memorizar.

![El ejemplo «Fecha de hoy»: `{date:EEEE, d MMMM yyyy}` se convierte en la fecha actual al pegar](site/img/guide/template-examples-date.png)

![Insertar ▾ en el Visor muestra todos los marcadores](site/img/guide/insert-menu.png)

Los más útiles:

| Marcador | Resultado |
|-------------|--------|
| `{date}` `{time}` `{datetime}` | Fecha de hoy / hora actual, en el formato del sistema |
| `{date:yyyy-MM-dd}` | Cualquier formato (`yyyy MM dd EEEE HH mm …`) |
| `{date:long}` `{time:short}` `{datetime:medium}` | Un estilo con nombre: `short` `medium` `long` `full` |
| `{date+7d}` `{date-1m:MMMM}` `{time+1h}` `{date+1y-2d}` | Desplazamiento: `d` días, `w` semanas, `m` meses, `y` años, `h` horas; en `date`, `time` y `datetime`, y se pueden encadenar varios |
| `{clipboard}` `{clipboard:2}` | El portapapeles o el elemento N del historial |
| `{clipboard\|upper}` `{clipboard\|trim\|oneline}` | Filtros `upper` `lower` `title` `trim` `oneline` `url`, que se pueden encadenar |
| `{cursor}` | Dónde queda el cursor de texto después de pegar |
| `{user}` `{username}` `{host}` | Nombre completo, nombre de la cuenta, nombre del ordenador |
| `{uuid}` `{random:1-100}` | Un UUID nuevo; un número aleatorio |
| `{{` `}}` | Llaves literales: la plantilla `{{"x":1}}` pega `{"x":1}` |

Los nombres de los marcadores van en minúsculas: `{date}` es un marcador, mientras que `{Date}` y
`{DATE}` son texto y se pegan tal cual. Los nombres de estilos y filtros (`{date:LONG}`,
`{clipboard|UPPER}`) se pueden escribir de cualquiera de las dos formas.

La lista completa está en el [resumen de marcadores](#placeholder-cheat-sheet).

### Plantillas que hacen preguntas

`{input:Name}` y `{choice:Label=A|B|C}` convierten una plantilla en un pequeño formulario: al pegarla,
Keepit pide primero los valores y después pega el texto terminado. El mismo nombre solo se pregunta una
vez, por muchas veces que aparezca. `{input:Name=Default}` rellena el campo de antemano.

![Al pegar una plantilla con {input:Name} se pide primero el valor](site/img/guide/input-dialog.png)

Por ejemplo, una plantilla de respuesta:

```
Hola, {input:Nombre}:

Gracias por tu mensaje del {date-1d}. Te respondo antes del {date+3d:EEEE}.
{cursor}
{user}
```

Al pegarla pide *Nombre*, rellena las fechas, firma con tu nombre completo y deja el cursor en la
línea vacía.

---

## Parte 4: El Visor

*Visor…* en el menú, o un clic con el botón derecho en el icono 📎, abre una ventana con tres árboles:
**Portapapeles** (su contenido actual, solo lectura), **Historial** (*Texto y archivos* e *Imágenes*) y
**Plantillas**.

![El Visor con una plantilla seleccionada](site/img/guide/viewer.png)

- Selecciona un elemento para verlo a la derecha. El texto se edita ahí mismo y los cambios se aplican
  al salir del editor. Una imagen se muestra ajustada al panel, con su tamaño en píxeles y el tamaño
  del archivo encima. En las listas de archivos, el doble clic abre el archivo. *Mostrar como volcado
  hexadecimal* en el menú contextual muestra los bytes en bruto.
- La barra de herramientas: *Enviar al portapapeles*, *Pegar* (en la app de la que vienes), *Añadir a
  plantillas*, *Nuevo elemento*, *Nueva carpeta*, *Eliminar*, *Insertar ▾* (marcadores) y **?**, que
  abre esta guía.
- **Buscar** (`⌘F`): el campo de la izquierda filtra el historial y las plantillas por nombre y
  contenido y resalta la coincidencia.
- Arrastra elementos del historial al árbol de plantillas para conservarlos, y plantillas al Historial
  para copiarlas de vuelta. El orden se cambia arrastrando o con *Subir* / *Bajar*. ⌫ elimina el
  elemento seleccionado.
- La barra de estado muestra la fecha, la app de origen, el formato y el tamaño.

![La búsqueda en el Visor resalta las coincidencias](site/img/guide/viewer-search.png)

---

## Parte 5: Ajustes

`⌘,` en el menú, *Ajustes…* o ⌥S desde cualquier app. La ventana funciona como las ventanas de ajustes
del Mac: elige un panel en la barra de herramientas y cada cambio se aplica en el momento. No hay
botón Guardar. La ventana se cierra con ⌘W o Esc. Cada opción con un **?** al lado tiene una ventana
emergente que la explica.

![Ajustes → General](site/img/guide/prefs-general.png)

| Panel | Qué hay |
|-----|---------------|
| **General** | Abrir al iniciar sesión · guardar el historial al salir y restaurarlo al arrancar · pegar después de elegir (desactivado = solo copiar) · retraso de pegado (súbelo para las apps que tardan en pasar a primer plano) · abrir el menú junto al cursor de texto · Actualizaciones: *Buscar actualizaciones automáticamente* (versión de descarga directa; desactivado = ninguna petición de red) — [Actualizaciones](#updates) |
| **Atajos** | Todos los atajos globales en un solo sitio, ver más abajo |
| **Cola de pegado** | Las tres teclas de la cola, el tiempo de inactividad tras el que se desactiva y qué se pone entre los elementos en *Pegar todo lo restante* — [La cola de pegado](#the-paste-queue) |
| **Historial** | Cuántos elementos de texto/archivos e imágenes se conservan (1000 / 30) · olvidar los elementos más antiguos que … · *Eliminar duplicados* (volver a copiar lo mismo lo sube al principio) · *Ignorar datos ocultos del portapapeles* · la lista de apps ignoradas (identificadores de paquete; los gestores de contraseñas se ignoran siempre) |
| **Menú** | Campo de búsqueda · numeración · panel de vista previa · etiquetas de ayuda · iconos de la app de origen · miniaturas de imágenes · elementos en el menú (cuántas de las entradas más recientes muestra, 60 por omisión; las demás se encuentran con la búsqueda) · longitud del título · altura de las miniaturas |
| **Seguridad** | Contraseña, Touch ID, bloqueo, frase de recuperación — [Parte 6](#part-6-security) |
| **Copia de seguridad** | Copia de seguridad automática (línea de estado junto al título): *Guardar copias automáticamente en una carpeta*, el nombre del Mac en los archivos, la carpeta, cuántas copias se conservan · Copia manual: *Hacer copia ahora*, *Guardar archivo…* · Restaurar: *Restaurar…* — [Copia de seguridad](#backup) |
| **Avanzado** | Intervalo de consulta del portapapeles · Automatización: *Permitir comandos URL keepit://* (desactivado por omisión — [Automatización](#automation-the-keepit-url-scheme)) · Datos: *Abrir carpeta* · Restablecer y desinstalar: *Restablecer…* (vuelve al estado de una instalación nueva y regresan las plantillas de ejemplo) · *Desinstalar…* (restablece y después elimina la app, la apertura al iniciar sesión, la entrada del llavero y los permisos) |

![Ajustes → Historial: límites y lista de apps ignoradas](site/img/guide/prefs-history.png)

![Ajustes → Atajos](site/img/guide/prefs-hotkeys.png)

En el panel **Atajos**, haz clic en un campo y pulsa una combinación. ⌫ desactiva una tecla. Una
combinación que ya usa otro comando se rechaza, y el motivo aparece debajo de los campos. *Restablecer
valores predeterminados* recupera el juego de ⌥+letra (⌥M historial, ⌥T plantillas, ⌥E Visor, ⌥S
Ajustes, ⌥C Borrar historial, ⌥P pausa, ⌥L bloquear, ⌥Q salir), además de ⌥⇧V y ⌃⌥. *Pegar elemento
por número* y *Acciones sobre el último elemento* solo admiten modificadores, y el dígito o la letra
los añade Keepit. Si macOS u otra app ya usa alguna combinación, Keepit lo avisa al arrancar. *Visor*
⌥E, *Ajustes* ⌥S, *Borrar historial* ⌥C, *Pausar la grabación* ⌥P, *Bloquear Keepit* ⌥L y *Salir de
Keepit* ⌥Q funcionan desde cualquier app y aparecen junto a sus comandos en el menú. En el Mac,
⌥+letra suele escribir un carácter especial (por ejemplo ⌥C = © o ⌥E = € en el teclado español); si
necesitas alguno, mueve el comando a otra tecla.

---

## Parte 6: Seguridad

### Contraseña y cifrado

*Ajustes → Seguridad → Pedir contraseña al iniciar* cifra el historial y las plantillas con
AES-256-GCM. La clave se deriva de tu contraseña (PBKDF2, 200 000 iteraciones) y solo existe en
memoria. Se borra cuando Keepit se bloquea: con *Bloquear Keepit* (`⌥L`), al salir y, si quieres,
después de que el Mac haya estado un rato bloqueado o en reposo. *Bloqueo automático de Keepit* vale
**Nunca** en una instalación nueva (una actualización desde la 3.0.3 conserva lo que había elegido:
*Inmediatamente* si estaba activado el bloqueo junto con la pantalla). Un gestor de portapapeles que
pide la contraseña después de cada pausa para el café acaba por no usarse, y `⌥L` está ahí para los
momentos que importan. *Inmediatamente* bloquea a la vez que la pantalla. *Tras 5 minutos*,
*15 minutos* o *1 hora* pasan por alto una ausencia corta: Keepit sigue desbloqueado y grabando, y solo
se bloquea cuando el Mac ha estado ausente todo ese tiempo. Lo mismo vale cuando Keepit arranca con el
Mac ya bloqueado o con la sesión de otro usuario en primer plano (por ejemplo, al reiniciarse tras una
actualización): la ausencia cuenta desde el arranque, en la medida en que macOS comunica ese estado a
Keepit (normalmente lo hace; si no puede, la cuenta empieza en el siguiente bloqueo o reposo). Con
Touch ID activado, Keepit pide la huella en el momento en que se desbloquea el Mac, y así está listo
antes del primer `⌥M`.

![Definir la contraseña con el teclado en pantalla. Es una fotografía de la pantalla y no una captura: en el Mac del autor, una captura de esta escena muestra solo el cuadro de diálogo](site/img/guide/set-password-keyboard.jpg)

Los cuadros de diálogo de contraseña muestran la distribución de teclado activa y avisan del bloqueo de
mayúsculas, así que una contraseña rechazada rara vez es un misterio. El botón del teclado que hay
junto al campo abre un **teclado en pantalla** para escribir la contraseña con el ratón: los clics
nunca pasan por el sistema como pulsaciones de teclas, las teclas se mezclan cada vez que se abre y el
teclado pide a macOS que lo deje fuera de las capturas y grabaciones de pantalla (en algunas
configuraciones queda excluido, pero no está garantizado). Sirve para un Mac del que no te fías del
todo o cuya pantalla se está compartiendo. Al arrancar y después de un bloqueo, Keepit pide la
contraseña (o Touch ID). *Recuperar acceso…* acepta en su lugar la frase de 24 palabras; consulta
[Frase de recuperación](#recovery-phrase).

![Desbloqueo al arrancar: contraseña, Salir o la frase de recuperación; Aceptar sigue desactivado hasta que se escribe algo. Fotografiado por el mismo motivo](site/img/guide/unlock-keyboard.jpg)

![Ajustes → Seguridad](site/img/guide/prefs-security.png)

### Touch ID

Con *Desbloquear con Touch ID*, la clave se guarda además en el Secure Enclave, protegida por tu
huella: Keepit pide un toque en lugar de la contraseña. La contraseña sigue funcionando como
alternativa (el botón de contraseña del aviso). Con la tapa cerrada y un Magic Keyboard externo con
Touch ID, Keepit lo pide en el teclado. *Permitir cambiar la contraseña con Touch ID* deja que la
huella sustituya a la contraseña antigua cuando la cambias.

![Desbloqueo con Touch ID; la contraseña queda como alternativa](site/img/guide/touch-id.png)

### Frase de recuperación

Cuando defines una contraseña, Keepit muestra una sola vez una frase de 24 palabras. Imprímela o
guárdala en un gestor de contraseñas. Si olvidas la contraseña, *Recuperar acceso…* en la ventana de
desbloqueo abre los datos y te deja definir una nueva. *Frase de recuperación → Crear nueva…* genera
una frase nueva e invalida la anterior. *Mostrar…*, al lado, vuelve a mostrar la frase actual después
de Touch ID o de la contraseña.

Sin la contraseña, sin Touch ID en el mismo Mac y sin la frase, los datos no se pueden recuperar: no
hay servidor ni nada que restablecer.

![La frase de recuperación de 24 palabras (aquí con las palabras ocultas)](site/img/guide/recovery-phrase.png)

### Copia de seguridad

Keepit puede guardar una copia cifrada del historial y las plantillas en la carpeta que elijas (iCloud
Drive, Dropbox, Google Drive, un disco externo, un NAS) y escribir una nueva cada vez que algo cambia.
No existe un servidor de Keepit: la carpeta es tuya. El proveedor que hay detrás ve el archivo
cifrado, su tamaño y una pequeña cabecera sin cifrar (cuándo y con qué versión de Keepit se escribió,
cómo se deriva la clave, identificadores aleatorios y el nombre de tu Mac solo si lo activas). La
[página de seguridad](/security#backups) (en inglés) la detalla campo por campo.

![Ajustes → Copia de seguridad: copia automática, copia manual, restaurar](site/img/guide/prefs-backup.png)

**Activación.** *Ajustes → Copia de seguridad → Guardar copias automáticamente en una carpeta* y luego
*Elegir…* una carpeta (el selector se abre en iCloud Drive). La copia automática necesita la
protección con contraseña de *Ajustes → Seguridad*: cada copia se sella con una clave derivada de la
de tu almacén, así que se abre con tu contraseña de Keepit o con tu frase de recuperación en este Mac o
en cualquier otro, sin configurar nada más. Sin contraseña, la casilla está desactivada y lo indica.

**Qué ocurre después: el calendario.** Unos cinco minutos después del último cambio (y como muy tarde
una vez al día mientras Keepit está abierto), Keepit escribe en la carpeta un archivo llamado
`Keepit-<date and time>-<installation>-<id>.keepit`, lo vuelve a leer para comprobarlo y solo entonces
elimina las más antiguas de sus propias copias que superan *Conservar las últimas* (10 por omisión, de
1 a 100). Cada copia es completa por sí sola, no un incremento, de modo que siempre te basta un único
archivo. Las copias hechas por otro Mac y los archivos que pongas tú no se tocan nunca: dos Mac que
comparten una carpeta escriben dos series independientes. La línea de estado junto al título *Copia de
seguridad automática* muestra la hora y el tamaño de la última copia, o por qué falló el último
intento. Mientras Keepit está bloqueado no ocurre nada. *Hacer copia ahora* (en *Copia manual*) no
espera al periodo de calma.

**Incluir el nombre de este Mac en los archivos de copia** (desactivado por omisión) pone el nombre
del ordenador en la cabecera sin cifrar de cada archivo, para distinguir fácilmente en el Finder dos
series de una misma carpeta. El proveedor de almacenamiento puede ver ese nombre, y por eso es
opcional.

**Restaurar.** *Restaurar…* abre una copia (de este Mac, de otro Mac o un archivo exportado) después
de que la desbloquees: con la contraseña del Mac en el que se hizo, o con la frase de recuperación que
ese Mac mostró cuando se definió su contraseña (*Recuperar acceso…* en el cuadro de la contraseña). Una
vista previa indica cuándo y dónde se creó el archivo y cuántos elementos contiene. Después hay dos
opciones:

![La vista previa de la restauración: cuándo y con qué versión de Keepit se escribió el archivo, qué contiene, Combinar o Reemplazar](site/img/guide/restore-preview.png)

- *Combinar* añade lo que todavía no está: los elementos del historial según su contenido, y las
  plantillas de la copia en una carpeta nueva llamada *Importado <fecha>*, sin sus atajos. Así ves
  exactamente qué ha venido de la copia y puedes moverlo o eliminarlo. No se sobrescribe nada tuyo.
- *Reemplazar* descarta el historial y las plantillas actuales y toma los de la copia. Antes, Keepit
  escribe una copia de lo que tienes ahora (`Keepit-before-restore-…`) en la carpeta de copias o en
  una carpeta que elijas. Si esa copia no se puede escribir, el reemplazo no empieza. Si Keepit aún no
  tiene contraseña, te pide una para esa copia, igual que en *Guardar archivo…*.

*Restaurar también las preferencias* trae de la copia los atajos, los límites y las opciones. Los
ajustes que expresan confianza en un Mac concreto (Touch ID, la automatización por URL y sus apps de
confianza, la propia carpeta de copias) se quedan siempre como están aquí. Si el historial de la copia
es mayor de lo que permiten los límites de este Mac, Keepit te dice cuánto cabe antes de que confirmes.

¿Has restaurado una copia con su frase de recuperación en un Mac que todavía no tiene contraseña?
Keepit te pide que definas una primero, para que los datos restaurados no queden nunca sin cifrar, y te
deja conservar esa frase para este Mac u obtener una nueva. ¿La has restaurado con la contraseña?
Keepit te ofrece mantenerla como contraseña de este Mac. En los dos casos, la copia automática es un
ajuste de cada Mac: actívala aquí y elige la carpeta (puede ser la misma), y este Mac empezará su
propia serie de archivos junto a la del Mac antiguo.

**Pasar a un Mac nuevo** es para lo que sirve todo esto: instala Keepit, elige *Restaurar desde
copia…* en el primer arranque, selecciona el archivo más reciente de tu carpeta, introduce la
contraseña del Mac antiguo y pulsa *Reemplazar*. Después activa la copia automática en el Mac nuevo.
Las copias hechas hasta entonces se abren con la contraseña y la frase que estaban en vigor cuando se
escribió cada una: tras un cambio de contraseña, las antiguas siguen necesitando la antigua.

**Copia manual.** Dos botones, dos cosas distintas. *Hacer copia ahora* crea en el momento una copia
como las automáticas: el mismo tipo de archivo, la misma carpeta y la misma serie, y se abre con tu
contraseña de Keepit o con la frase. *Guardar archivo…* escribe un único *archivo* `.keepit` donde tú
digas, protegido con una contraseña que eliges para él. No necesita la protección con contraseña de
Keepit, y Keepit no hace seguimiento del archivo después. Sirve para entregar datos a alguien o para
tener una copia fuera de la carpeta de copias. El nombre propuesto dice lo que es:
`Keepit-archive-<date>-manual.keepit`, frente a las copias automáticas
`Keepit-<date and time>-<installation>-<id>.keepit`.

![Guardar archivo…: el nombre del archivo incluye archive y manual](site/img/guide/save-to-archive.png)

![La contraseña propia del archivo, con un indicador de seguridad: no se guarda en ningún sitio](site/img/guide/archive-password.png)

*Restaurar…* abre los dos tipos. El archivo sustituye a *Exportar…* / *Importar…* de la 2.x. Con él se
pasan datos entre la versión de descarga directa y la del App Store, y entre Keepit 2.x y 3.x. Un
archivo escrito con la 3.0 necesita la 3.0 o posterior para abrirse; la 3.0 lee todo lo que escribió
la 2.x.

**Si algo sale mal.** Una copia fallida se indica en la línea de estado y se reintenta con pausas cada
vez más largas. Las copias anteriores se conservan. Si Keepit se cerró o el Mac se apagó en mitad de
una restauración, el siguiente arranque deja todo discretamente como estaba antes de restaurar. En el
caso poco frecuente de que no pueda (un archivo que no se puede escribir, un disco lleno), Keepit
indica el archivo y se cierra sin cambiar nada: arregla el problema del archivo y vuelve a abrirlo. Los
detalles, incluido cómo es por dentro el formato del archivo, están en la
[página de seguridad](/security#backups) (en inglés).

---

## Parte 7: Funciones avanzadas

### Automatización: el esquema de URL keepit://

Atajos (*Abrir URL*), Raycast, Alfred, Keyboard Maestro u `open` en un terminal pueden controlar
Keepit **una vez que lo actives** en *Ajustes → Avanzado → Automatización → Permitir comandos URL
keepit://*. Viene desactivado porque cualquier app o página web puede abrir una URL, y `add` / `paste`
cambian el portapapeles y escriben en la app que está en primer plano. Con la opción desactivada,
Keepit ignora esas URL con un pitido. Con la opción activada, Keepit mira quién ha abierto la URL: el
primer comando de cada app que cambia algo (`paste`, `copy`, `template`, `add`, `add-template`,
`pause`, `resume`) se muestra en un cuadro de diálogo. *Permitir* lo ejecuta una vez y *Permitir
siempre* añade la app a la lista de confianza (que se vacía con *Olvidar apps de confianza* en el
mismo panel). A un navegador web, o a un remitente que macOS no sabe identificar, se le pregunta
siempre. Los comandos que solo abren las ventanas de Keepit no preguntan nunca.

| URL | Efecto |
|-----|--------|
| `keepit://paste/2`<br>`keepit://paste/latest`<br>`keepit://paste/previous` | Pegar el elemento N del historial (o el último / el anterior) en la app en primer plano |
| `keepit://copy/3` | Poner el elemento N en el portapapeles sin pegarlo |
| `keepit://template/Signature`<br>`keepit://template/Work/Reply?copy=1` | Pegar (o copiar) una plantilla por su nombre o por la ruta de su carpeta |
| `keepit://add?text=…` | Añadir texto al historial y al portapapeles |
| `keepit://add-template?text=…&name=…` | Crear una plantilla |
| `keepit://history`<br>`keepit://templates`<br>`keepit://viewer`<br>`keepit://settings` | Abrir el menú del historial, el menú de plantillas, el Visor o los Ajustes |
| `keepit://pause`<br>`keepit://resume` | Pausar la grabación 10 minutos / reanudarla |

Codifica el texto con porcentajes (`%20` para un espacio). Las URL se ignoran mientras Keepit está
bloqueado.

### Actualizaciones

Keepit consulta GitHub Releases una vez al día y ofrece las actualizaciones en un cuadro de diálogo.
*Buscar actualizaciones…* lo hace en el momento. Las actualizaciones van firmadas (EdDSA) y
certificadas por Apple. Con Homebrew, `brew upgrade --cask keepit` hace lo mismo. Las sumas de
verificación de cada descarga están en `SHA256SUMS`, en la página de la versión.

Esta consulta es la única petición de red que hace Keepit, y es opcional: *Ajustes → General →
Actualizaciones → Buscar actualizaciones automáticamente*. Si la desactivas, Keepit no contacta con
nada, ni siquiera cuando se lo pides, y *Buscar actualizaciones…* desaparece de los menús. En ese caso
se actualiza descargando la app desde [keep.it.com](https://keep.it.com) o con Homebrew. La versión del
App Store no tiene actualizador ni esta opción: la actualiza el App Store.

### Desinstalación

*Ajustes → Avanzado → Restablecer y desinstalar → Desinstalar…* elimina la app, la carpeta de datos,
las entradas del llavero (incluida la clave de Touch ID), el ítem de inicio de sesión y la entrada de
Accesibilidad. Keepit pide tu contraseña o Touch ID, que escribas `DELETE` y una confirmación. Exporta
antes una copia de seguridad si crees que puedes volver a necesitar los datos. Con Homebrew, ejecuta
después `brew uninstall --cask --force keepit` para que Homebrew olvide el cask.

![Ajustes → Avanzado](site/img/guide/prefs-advanced.png)

---

## Referencia

### Solución de problemas

**No se pega nada después de elegir un elemento.** Falta el permiso de Accesibilidad: *Ajustes del
Sistema → Privacidad y seguridad → Accesibilidad → Keepit*. Si Keepit aparece en la lista pero sigue
sin pegar, desactívalo y vuelve a activarlo: macOS olvida el permiso cuando se reinstala la app.

**Un atajo no hace nada.** Lo está usando otra app o macOS. Keepit lo avisa al arrancar. Elige otra
combinación en el panel *Atajos*. ⌃⌥ con dígitos y letras está libre en un Mac recién configurado.

**El menú se abre en un sitio equivocado.** La app en la que estás no expone su cursor de texto, así
que el menú recurre al puntero del ratón. *Abrir el menú en el cursor de texto cuando sea posible*, en
el panel General, desactiva esa localización si prefieres siempre el puntero.

**Falta algo que copié.** Lo que la app de origen marca como oculto no se graba, y tampoco una copia
hecha mientras estaba en primer plano un gestor de contraseñas (lista integrada) o una app de tu lista
de ignoradas, incluida la app de la que acabas de salir. Consulta *Ajustes → Historial* y la
[página de seguridad](/security#what-is-not-recorded) (en inglés).

**No se ofrece Touch ID.** En este momento no hay ningún sensor de Touch ID accesible (tapa cerrada,
sin teclado con Touch ID). Keepit conserva el ajuste y pedirá la huella en cuanto haya un sensor
disponible.

**El estado de la copia de seguridad dice que la carpeta no está disponible.** La carpeta se ha
movido, se ha renombrado, se ha desmontado o (iCloud Drive) se ha retirado del almacenamiento local.
Móntala o recupérala y la siguiente copia saldrá bien. También puedes *Elegir…* una carpeta nueva:
empieza una serie nueva y los archivos antiguos se quedan donde están.

**Un archivo de copia no se abre.** *Contraseña incorrecta* significa que la etiqueta de autenticación
del archivo no coincide: comprueba que usas la contraseña del Mac que *escribió* el archivo (tras un
cambio de contraseña, las copias antiguas siguen abriéndose con la antigua) o su frase de
recuperación. *Esta copia de seguridad necesita Keepit 3.0 o posterior* significa que el archivo lo
escribió una versión más nueva que la que intenta abrirlo.

**Homebrew se niega a instalar sobre una app existente.** Cierra Keepit y mueve antes
`/Applications/Keepit.app` a la Papelera, o añade `--force`.

¿Sigues sin resolverlo? [GitHub Issues](https://github.com/andrey-insarov/Keepit/issues) · admin@keep.it.com

### Resumen de atajos

| Teclas | Acción |
|------|--------|
| `⌥M` | Menú del historial; escribe para buscar |
| `⌥T` | Menú de plantillas |
| `⌃⌥1` … `⌃⌥0` | Pegar el elemento 1 a 10 (en el menú y en cualquier sitio) |
| `⇧` en el menú | Menú ampliado: todas las acciones de cada elemento |
| `⌥⇧V` | Pegar el elemento anterior / alternar |
| `⌃⌥V` | Pegar el portapapeles como texto sin formato |
| `⌃⌥U` `⌃⌥L` `⌃⌥T` `⌃⌥S` | MAYÚSCULAS / minúsculas / Mayúscula En Cada Palabra / mayúscula inicial |
| `⌃⌥W` `⌃⌥J` | Sin espacios en los extremos / en una sola línea |
| `⌃⌥K` `⌃⌥D` `⌃⌥Y` `⌃⌥X` | Tachado / subrayado / subrayado ondulado / quitar decoraciones |
| `⌃⌥A` | Añadir el portapapeles a Plantillas |
| `⌃⌥⌫` | Eliminar el elemento más reciente |
| `⌥N` · `⌥V` · `⌥⇧N` | Cola de pegado: iniciar / detener · pegar el siguiente · pegar todo lo restante |
| `⌥E` `⌥S` `⌥C` `⌥P` `⌥L` `⌥Q` | Visor · Ajustes · Borrar historial · Pausar la grabación · Bloquear · Salir |
| `⌘F` en el Visor | Buscar |
| `⌘,` | Ajustes |

### Resumen de marcadores

| Marcador | Resultado |
|-------------|--------|
| `{date}` `{time}` `{datetime}` | Fecha / hora / ambas, en el formato del sistema |
| `{date:yyyy-MM-dd}` `{time:HH:mm}` | Formato personalizado (patrones de fecha de Unicode) |
| `{date:long}` `{time:short}` `{datetime:full}` | Estilo con nombre: `short` `medium` `long` `full` |
| `{date+7d}` `{date-1m:MMMM}` `{time+1h}` `{datetime-1d:long}` `{date+1y-2d}` | Desplazamiento (`d` `w` `m` `y` `h`; hasta cuatro seguidos) |
| `{weekday}` `{month}` `{year}` | Nombre del día, nombre del mes, año |
| `{iso}` `{unix}` | Marca de tiempo ISO 8601, hora Unix |
| `{clipboard}` `{clipboard:2}` | El portapapeles (elemento 1) o el elemento N |
| `{clipboard\|upper}` `\|lower` `\|title` `\|trim` `\|oneline` `\|url` | Filtros, que se pueden encadenar |
| `{input:Name}` `{input:Name=Default}` | Pedir un valor antes de pegar |
| `{choice:Label=A\|B\|C}` | Pedir que se elija una opción |
| `{cursor}` | Posición del cursor después de pegar |
| `{user}` `{username}` `{host}` | Nombre completo, nombre de la cuenta, nombre del ordenador |
| `{uuid}` `{random:1-100}` | UUID nuevo, número aleatorio dentro de un intervalo |
| `{{` `}}` | Llaves literales |
