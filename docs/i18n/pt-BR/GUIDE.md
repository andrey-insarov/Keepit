<!-- source: GUIDE.md 39bab8b4f2a3de5ce61f2427db3f17e669b6f280 -->
# Guia do Keepit

O Keepit é um gerenciador de histórico da área de transferência e de modelos para macOS. Ele fica na
barra de menus, guarda tudo o que você copia e cola qualquer item de volta com um atalho de teclado.
Todos os atalhos abaixo são os padrões, e cada um pode ser alterado em *Ajustes → Atalhos*. Este guia
descreve o Keepit 3. O guia do Keepit 2.x continua disponível, sem alterações, em
[keep.it.com/v2/guide](https://keep.it.com/v2/guide) (em inglês).

![O menu de histórico](site/img/guide/menu.png)

**Conteúdo**

- [Parte 1: Primeiros passos](#part-1--getting-started): [Instalação](#install) · [Primeira abertura](#first-launch)
- [Parte 2: Uso no dia a dia](#part-2--everyday-use): [O menu de histórico](#the-history-menu) · [Busca e pré-visualização](#search-and-preview) · [Colar sem o menu](#paste-without-the-menu) · [A fila de colagem](#the-paste-queue) · [O menu estendido](#the-extended-menu)
- [Parte 3: Modelos](#part-3--templates): [Criar e organizar](#creating-and-organising) · [Marcadores](#placeholders) · [Modelos que fazem perguntas](#templates-that-ask-questions)
- [Parte 4: O Visualizador](#part-4--the-viewer)
- [Parte 5: Ajustes](#part-5--settings)
- [Parte 6: Segurança](#part-6-security): [Senha e criptografia](#password-and-encryption) · [Touch ID](#touch-id) · [Frase de recuperação](#recovery-phrase) · [Backup](#backup)
- [Parte 7: Recursos avançados](#part-7--advanced): [Automação](#automation-the-keepit-url-scheme) · [Atualizações](#updates) · [Desinstalação](#uninstalling)
- [Referência](#reference): [Solução de problemas](#troubleshooting) · [Resumo dos atalhos](#keyboard-cheat-sheet) · [Resumo dos marcadores](#placeholder-cheat-sheet)

---

## Parte 1: Primeiros passos

### Instalação

**Homebrew** é o método recomendado, porque `brew upgrade` mantém o app atualizado:

```bash
brew tap andrey-insarov/keepit https://github.com/andrey-insarov/Keepit
brew install --cask andrey-insarov/keepit/keepit
```

**DMG:** baixe `Keepit-<version>.dmg` na página da
[versão mais recente](https://github.com/andrey-insarov/Keepit/releases/latest), abra o arquivo e arraste o Keepit
para *Aplicativos*.

![O DMG: arraste o Keepit para Aplicativos](site/img/guide/dmg.png)

Na primeira vez que você abre o app, o macOS confirma que ele veio da internet e foi verificado pela
Apple. Clique em *Abrir*.

![Confirmação do Gatekeeper no macOS](site/img/guide/gatekeeper.png)

O Keepit é assinado e autenticado pela Apple, atualiza sozinho e roda nativamente em Macs com Apple
Silicon e Intel com macOS 13 Ventura ou posterior.

### Primeira abertura

O Keepit é um app de barra de menus: não tem ícone no Dock nem janela até você abrir alguma. Depois da
primeira abertura, o ícone 📎 aparece na barra de menus e o Keepit faz três perguntas.

**1. Restaurar de um backup?** Se este é um Mac novo e você tem um backup do Keepit (automático, no
iCloud Drive ou em outra pasta, ou um arquivo `.keepit` exportado), *Restaurar do backup…* traz de
volta o histórico e os modelos antes de qualquer outra coisa. O arquivo é desbloqueado com a senha do
Mac de onde ele veio ou com a frase de recuperação desse Mac. *Começar do zero* pula essa etapa. A
mesma restauração fica disponível depois em *Ajustes → Backup → Restaurar…*, e um clique duplo em um
arquivo `.keepit` no Finder também o abre. Os detalhes estão em [Backup](#backup).

![A primeira pergunta em um Mac novo: restaurar de um backup ou começar do zero](site/img/guide/restore-first-run.png)

**2. Uma senha (opcional).** O Keepit pode guardar o histórico e os modelos criptografados e
desbloqueá-los com o Touch ID. Você pode decidir agora ou depois em *Ajustes → Segurança*. A
[Parte 6](#part-6-security) explica como funciona. Com *Agora não*, tudo fica sem criptografia no
disco. Se você acabou de restaurar um backup com a senha dele, o Keepit oferece manter essa senha
neste Mac.

![A oferta de senha na primeira abertura](site/img/guide/password-offer.png)

![Ao escolher “Agora não”: uma explicação direta do que isso significa e de onde mudar](site/img/guide/no-password-notice.png)

**3. A permissão de Acessibilidade.** Para colar por você, o Keepit envia ⌘V ao app em que você estava
trabalhando. O macOS só permite isso aos apps listados em *Ajustes do Sistema → Privacidade e
Segurança → Acessibilidade*. Clique em *Abrir Ajustes do Sistema* e ative o Keepit. Sem a permissão, o
Keepit continua gravando e copiando, mas é você quem pressiona ⌘V.

![O Keepit pede a permissão de Acessibilidade](site/img/guide/accessibility-prompt.png)

![Keepit ativado em Privacidade e Segurança → Acessibilidade](site/img/guide/accessibility-settings.png)

Por padrão, o Keepit abre ao iniciar a sessão. Isso pode ser desativado em *Ajustes → Geral*.

---

## Parte 2: Uso no dia a dia

### O menu de histórico

Pressione **⌥M** em qualquer app ou clique no ícone 📎. O menu abre junto ao cursor de texto quando o
Keepit consegue localizá-lo; caso contrário, junto ao cursor do mouse.

Cada linha é um item copiado, com o mais recente no topo. Ele aparece em **negrito**, porque é o que
está na área de transferência neste momento. O ícone mostra o app de onde você copiou. Um título que
termina em `…` tem mais linhas do que o menu mostra. Imagens aparecem como miniatura, e listas de
arquivos mostram os nomes dos arquivos.

![O painel de pré-visualização ao lado do menu mostra o item destacado por inteiro, com o app de origem, a hora e o tamanho](site/img/guide/menu-preview.png)

![Uma imagem no histórico: miniatura no menu, imagem completa na pré-visualização](site/img/guide/menu-image.png)

Para colar um item, clique nele, ou vá até ele com ↑ ↓ e pressione Return, ou pressione o número dele
com **⌃⌥**: `⌃⌥3` cola o item 3. A mesma tecla funciona de qualquer lugar, sem abrir o menu.

Abaixo do histórico ficam o submenu *Modelos*, o Visualizador (⌥E), os Ajustes (⌥S), *Limpar
histórico* (⌥C), *Pausar a gravação por 10 minutos* (⌥P, para digitar algo que você não quer que seja
gravado), *Bloquear o Keepit* (⌥L) quando há senha definida, e as atualizações. **⌥T** abre o menu de
modelos sozinho. Todas essas teclas também funcionam sem o menu.

### Busca e pré-visualização

**Busca.** Comece a digitar com o menu aberto: o campo no topo filtra a lista pelo título e pelo texto
completo, então uma linha no meio de um item longo também é encontrada. Return cola o primeiro
resultado, Esc limpa o campo e um segundo Esc fecha o menu.

**Pré-visualização.** Passe o cursor sobre um item (ou vá até ele pelo teclado) e um painel ao lado do
menu mostra a imagem inteira ou as primeiras linhas de um texto longo, com o app de origem, a data e o
tamanho. Textos curtos de uma linha não têm pré-visualização, porque a linha do menu já os mostra por
inteiro.

![A digitação filtra o menu; o painel de pré-visualização mostra o item destacado](site/img/guide/search-preview.png)

### Colar sem o menu

Os atalhos globais agem, a partir de qualquer app, sobre o histórico como ele está naquele momento. O
item 1 é a área de transferência:

| Teclas | O que acontece |
|------|--------------|
| `⌃⌥1` … `⌃⌥9`, `⌃⌥0` | Colar um dos itens de 1 a 10 do histórico |
| `⌥⇧V` | Colar o item *anterior* (item 2); pressione de novo para voltar |
| `⌃⌥V` | Colar a área de transferência como texto simples, sem formatação |
| `⌃⌥U` `⌃⌥L` `⌃⌥T` `⌃⌥S` | Colar a área de transferência em MAIÚSCULAS / minúsculas / Iniciais Maiúsculas / só a primeira letra maiúscula |
| `⌃⌥W` | Colar a área de transferência sem os espaços do início e do fim |
| `⌃⌥J` | Colar a área de transferência em uma única linha |
| `⌃⌥K` `⌃⌥D` `⌃⌥Y` | Colar a área de transferência tachada / sublinhada / com sublinhado ondulado, como texto simples que mantém a aparência em qualquer lugar, inclusive em chats (veja abaixo) |
| `⌃⌥X` | Colar a área de transferência sem essas decorações |
| `⌃⌥A` | Adicionar a área de transferência aos Modelos |
| `⌃⌥⌫` | Apagar do histórico o item mais recente |

As três decorações não são formatação: o Keepit acrescenta depois de cada caractere um *sinal
combinante* do Unicode (t̶a̶c̶h̶a̶d̶o̶, s̲u̲b̲l̲i̲n̲h̲a̲d̲o̲, o̰n̰d̰ṵl̰a̰d̰o̰), e por isso o texto fica igual em um
mensageiro, em um formulário web ou em um terminal, onde a formatação de verdade se perderia. O custo:
esse texto fica três vezes maior, uma busca pela palavra comum não o encontra, leitores de tela
tropeçam nele e algumas fontes desenham a linha de forma irregular. *Remover decorações* (`⌃⌥X`) tira
esses sinais, inclusive de textos decorados em outro lugar. Nos dois sentidos, os sinais são removidos
pelo ponto de código, venham de onde vierem: uma transcrição fonética que usa os mesmos sinais como
letras (U+0330 também é o sinal do AFI para voz crepitante) os perde, e as três decorações também
começam por removê-los. Com o VoiceOver ativado, `⌃⌥` é o modificador do próprio VoiceOver: atribua
outro a *Ações no item mais recente* em Ajustes → Atalhos.

As transformações valem para texto. Para uma imagem ou uma lista de arquivos, a tecla emite um bipe.
Tudo isso pode ser alterado ou desativado em *Ajustes → Atalhos*.

### A fila de colagem

Às vezes você quer copiar cinco coisas em um lugar e colá-las, em ordem, em outro: células em um
formulário, linhas de uma página em um documento. A fila de colagem faz isso sem o menu:

1. Pressione **⌥N** (ou escolha *Iniciar fila de colagem* no menu). O ícone na barra de menus mostra um
   ponto vermelho e um contador: `📎 ● 0`.
2. Copie como sempre com ⌘C, quantas vezes quiser. O contador sobe a cada cópia: 1, 2, 3… Tudo também
   é gravado no histórico.

   ![A barra de menus com a fila ativa: ponto vermelho e contador](site/img/guide/queue-menubar.png)

3. Vá para onde o texto deve entrar e pressione **⌥V** para cada item. O que você copiou primeiro é
   colado primeiro, e o contador desce. ⌘V continua colando a área de transferência como sempre, então
   dá para misturar os dois.
4. A fila se desativa sozinha depois que o último item é colado, ou após dois minutos sem copiar nem
   colar (o tempo é ajustável). Outro ⌥N a interrompe antes.

**⌥⇧N** cola de uma vez tudo o que ainda está na fila. Os itens são unidos por uma quebra de linha,
uma tabulação, um espaço ou nada: você escolhe no painel *Fila de colagem* dos Ajustes, onde também
fica o tempo de inatividade. Enquanto a fila está ativa, o menu de histórico marca os itens dela: `▶`
é o próximo a ser colado, `○` ainda está na fila e `✓` já foi colado.

![O menu de histórico com a fila ativa: ○ na fila, ▶ próximo, ✓ colado; a linha do menu mostra quantos faltam](site/img/guide/queue-menu.png)

![Ajustes → Fila de colagem](site/img/guide/prefs-queue.png)

### O menu estendido

Segure **⇧** com o menu de histórico aberto e cada item ganha um submenu `▸` com todas as ações
daquele item: Colar, Colar como texto simples, Só copiar (para a área de transferência, sem colar), as
transformações de *Colar como*, Adicionar aos Modelos, Mostrar no Visualizador e Apagar. Aponte para um
item ou pressione → para abrir o submenu. Depois que ele abrir, você pode soltar ⇧.

![Segure ⇧: cada item ganha um submenu; no item mais recente ele mostra os atalhos globais](site/img/guide/extended-menu.png)

No item mais recente, o submenu lista os atalhos globais da tabela acima. São as mesmas ações com as
mesmas teclas, então é um bom lugar para aprendê-las. Os outros itens mostram as ações sem teclas: um
atalho ou funciona em todo lugar, ou não é mostrado.

![Nos outros itens: as mesmas ações, sem atalhos](site/img/guide/extended-menu-item2.png)

![Em uma imagem, as ações de texto ficam esmaecidas: só valem Colar, Só copiar, Adicionar aos Modelos, Mostrar no Visualizador e Apagar](site/img/guide/extended-menu-image.png)

---

## Parte 3: Modelos

Modelos são itens que você guarda de vez: assinaturas, endereços, respostas prontas, trechos de código,
um logotipo que você cola com frequência. Eles ficam em uma árvore com pastas e aparecem no submenu
*Modelos* do menu de histórico e em **⌥T**. Uma instalação nova vem com uma pasta *Exemplos* (uma
saudação, a data de hoje, uma citação da área de transferência e uma assinatura) para você ver o que
os modelos fazem antes de escrever os seus. Apague ou edite esses exemplos como quiser (*Redefinir…*
nos Ajustes traz todos de volta).

![A pasta Exemplos: ao passar o cursor sobre um item, o texto dele aparece](site/img/guide/template-examples.png)

![O menu de modelos: as pastas abrem como submenus e as letras depois de & viram teclas de acesso rápido](site/img/guide/template-menu-letters.png)

### Criar e organizar

**Adicionar um modelo**

- Pelo menu de histórico: `⌃⌥A` para o item mais recente, *Adicionar área de transferência aos
  modelos* no fim do menu, ou ⇧ → submenu do item → *Adicionar aos Modelos* para qualquer item.
- No Visualizador: selecione um item do histórico e clique em *Adicionar aos modelos*, ou arraste-o
  para a árvore de modelos. *Novo item* cria um modelo de texto vazio; *Novo item a partir de
  arquivo…* (menu de contexto) cria um modelo a partir de um arquivo de texto ou de imagem.

**Organizar**

- *Nova pasta* cria uma pasta. Arraste itens de uma pasta para outra, ou use *Para cima* / *Para
  baixo* no menu de contexto.
- Um modelo chamado `-` vira uma linha separadora no menu.
- Um `&` antes de uma letra do nome (por exemplo, `&Assinatura`) transforma essa letra na tecla de
  acesso rápido do item no menu de modelos: pressione `A` com o menu aberto.
- *Definir tecla de atalho…* no menu de contexto dá ao modelo um atalho global próprio.
- Um modelo sem nome mostra a primeira linha dele. *Renomear* e *Limpar nome* estão no menu de
  contexto, ou edite o campo *Nome* acima do texto.

### Marcadores

Modelos de texto podem conter marcadores `{…}`, que são preenchidos na hora de colar. Todo o resto é
colado sem alteração. No Visualizador, **Inserir ▾** lista todos os marcadores e coloca o escolhido na
posição do cursor, então não é preciso decorar nada.

![O exemplo “Data de hoje”: `{date:EEEE, d MMMM yyyy}` vira a data atual ao colar](site/img/guide/template-examples-date.png)

![Inserir ▾ no Visualizador lista todos os marcadores](site/img/guide/insert-menu.png)

Os mais úteis:

| Marcador | Resultado |
|-------------|--------|
| `{date}` `{time}` `{datetime}` | Data de hoje / hora atual, no formato do sistema |
| `{date:yyyy-MM-dd}` | Qualquer formato (`yyyy MM dd EEEE HH mm …`) |
| `{date:long}` `{time:short}` `{datetime:medium}` | Um estilo com nome: `short` `medium` `long` `full` |
| `{date+7d}` `{date-1m:MMMM}` `{time+1h}` `{date+1y-2d}` | Deslocamento: `d` dias, `w` semanas, `m` meses, `y` anos, `h` horas; em `date`, `time` e `datetime`, e vários podem vir em sequência |
| `{clipboard}` `{clipboard:2}` | A área de transferência ou o item N do histórico |
| `{clipboard\|upper}` `{clipboard\|trim\|oneline}` | Filtros `upper` `lower` `title` `trim` `oneline` `url`, que podem ser encadeados |
| `{cursor}` | Onde o cursor de texto fica depois de colar |
| `{user}` `{username}` `{host}` | Nome completo, nome da conta, nome do computador |
| `{uuid}` `{random:1-100}` | Um UUID novo; um número aleatório |
| `{{` `}}` | Chaves literais: o modelo `{{"x":1}}` cola `{"x":1}` |

Os nomes dos marcadores são em minúsculas: `{date}` é um marcador, enquanto `{Date}` e `{DATE}` são
texto e são colados como estão. Nomes de estilos e de filtros (`{date:LONG}`, `{clipboard|UPPER}`)
podem ser escritos das duas formas.

A lista completa está no [resumo dos marcadores](#placeholder-cheat-sheet).

### Modelos que fazem perguntas

`{input:Name}` e `{choice:Label=A|B|C}` transformam um modelo em um pequeno formulário: ao colar, o
Keepit primeiro pede os valores e depois cola o texto pronto. O mesmo nome é perguntado uma única vez,
não importa quantas vezes apareça. `{input:Name=Default}` já deixa o campo preenchido.

![Ao colar um modelo com {input:Name}, o valor é pedido primeiro](site/img/guide/input-dialog.png)

Um modelo de resposta, por exemplo:

```
Olá, {input:Nome}!

Obrigado pela sua mensagem de {date-1d}. Respondo até {date+3d:EEEE}.
{cursor}
{user}
```

Ao colar, ele pede *Nome*, preenche as datas, assina com o seu nome completo e deixa o cursor na linha
vazia.

---

## Parte 4: O Visualizador

*Visualizador…* no menu, ou um clique com o botão direito no ícone 📎, abre uma janela com três
árvores: **Área de transferência** (o conteúdo atual, somente leitura), **Histórico** (*Texto e
arquivos* e *Imagens*) e **Modelos**.

![O Visualizador com um modelo selecionado](site/img/guide/viewer.png)

- Selecione um item para vê-lo à direita. O texto pode ser editado ali mesmo, e as alterações valem
  quando você sai do editor. Uma imagem é mostrada ajustada ao painel, com o tamanho em pixels e o
  tamanho do arquivo acima dela. Em listas de arquivos, um clique duplo abre o arquivo. *Mostrar como
  dump hexadecimal* no menu de contexto mostra os bytes brutos.
- A barra de ferramentas: *Enviar para a área de transferência*, *Colar* (no app de onde você veio),
  *Adicionar aos modelos*, *Novo item*, *Nova pasta*, *Apagar*, *Inserir ▾* (marcadores) e **?**, que
  abre este guia.
- **Buscar** (`⌘F`): o campo à esquerda filtra o histórico e os modelos por nome e conteúdo e destaca
  o resultado.
- Arraste itens do histórico para a árvore de modelos para guardá-los, e modelos para o Histórico para
  copiá-los de volta. A ordem muda arrastando ou com *Para cima* / *Para baixo*. ⌫ apaga o item
  selecionado.
- A barra de status mostra a data, o app de origem, o formato e o tamanho.

![A busca no Visualizador destaca os resultados](site/img/guide/viewer-search.png)

---

## Parte 5: Ajustes

`⌘,` no menu, *Ajustes…* ou ⌥S a partir de qualquer app. A janela funciona como as janelas de ajustes
do Mac: escolha um painel na barra de ferramentas, e cada alteração vale na hora. Não há botão Salvar.
Feche a janela com ⌘W ou Esc. Toda opção com um **?** ao lado tem um popover que a explica.

![Ajustes → Geral](site/img/guide/prefs-general.png)

| Painel | O que há nele |
|-----|---------------|
| **Geral** | Abrir ao iniciar sessão · salvar o histórico ao encerrar e restaurar ao abrir · colar depois de escolher (desativado = só copiar) · atraso de colagem (aumente para apps que demoram a vir para a frente) · abrir o menu no cursor de texto · Atualizações: *Verificar atualizações automaticamente* (versão de download direto; desativado = nenhuma requisição de rede) — [Atualizações](#updates) |
| **Atalhos** | Todos os atalhos globais em um só lugar, veja abaixo |
| **Fila de colagem** | As três teclas da fila, o tempo de inatividade depois do qual ela se desativa e o que colocar entre os itens em *Colar todo o restante* — [A fila de colagem](#the-paste-queue) |
| **Histórico** | Quantos itens de texto/arquivos e quantas imagens manter (1000 / 30) · esquecer itens mais antigos que … · *Remover duplicados* (copiar a mesma coisa de novo a leva para o topo) · *Ignorar dados ocultos da área de transferência* · a lista de apps ignorados (identificadores de pacote; gerenciadores de senhas são sempre ignorados) |
| **Menu** | Campo de busca · numeração · painel de pré-visualização · dicas · ícones do app de origem · miniaturas de imagens · itens no menu (quantas das entradas mais recentes o menu lista, 60 por padrão; as demais continuam acessíveis pela busca) · comprimento do título · altura das miniaturas |
| **Segurança** | Senha, Touch ID, bloqueio, frase de recuperação — [Parte 6](#part-6-security) |
| **Backup** | Backup automático (linha de status ao lado do título): *Fazer backup automaticamente em uma pasta*, o nome do Mac nos arquivos, a pasta, quantas cópias manter · Backup manual: *Fazer backup agora*, *Salvar em arquivo…* · Restaurar: *Restaurar…* — [Backup](#backup) |
| **Avançado** | Intervalo de consulta da área de transferência · Automação: *Permitir comandos de URL keepit://* (desativado por padrão — [Automação](#automation-the-keepit-url-scheme)) · Dados: *Abrir pasta* · Redefinir e desinstalar: *Redefinir…* (volta ao estado de uma instalação nova, e os modelos de exemplo retornam) · *Desinstalar…* (redefine e depois remove o app, a abertura ao iniciar sessão, a entrada das Chaves e as permissões) |

![Ajustes → Histórico: limites e a lista de apps ignorados](site/img/guide/prefs-history.png)

![Ajustes → Atalhos](site/img/guide/prefs-hotkeys.png)

No painel **Atalhos**, clique em um campo e pressione uma combinação. ⌫ desativa uma tecla. Uma
combinação que já é usada por outro comando é recusada, e o motivo aparece abaixo dos campos.
*Restaurar padrões* traz de volta o conjunto ⌥+letra (⌥M histórico, ⌥T modelos, ⌥E Visualizador, ⌥S
Ajustes, ⌥C Limpar histórico, ⌥P pausar, ⌥L bloquear, ⌥Q encerrar), além de ⌥⇧V e ⌃⌥. *Colar item por
número* e *Ações no item mais recente* aceitam apenas modificadores, e o dígito ou a letra é
acrescentado pelo Keepit. Se o macOS ou outro app já usa alguma combinação, o Keepit avisa ao abrir.
*Visualizador* ⌥E, *Ajustes* ⌥S, *Limpar histórico* ⌥C, *Pausar gravação* ⌥P, *Bloquear o Keepit* ⌥L
e *Encerrar o Keepit* ⌥Q funcionam a partir de qualquer app e aparecem ao lado dos comandos no menu.
No Mac, ⌥+letra normalmente digita um caractere especial (por exemplo, ⌥C = ç no layout americano); se
você precisar de algum deles, mude o comando para outra tecla.

---

## Parte 6: Segurança

### Senha e criptografia

*Ajustes → Segurança → Exigir senha ao abrir* criptografa o histórico e os modelos com AES-256-GCM. A
chave é derivada da sua senha (PBKDF2, 200 000 iterações) e existe apenas na memória. Ela é apagada
quando o Keepit é bloqueado: com *Bloquear o Keepit* (`⌥L`), ao encerrar e, opcionalmente, depois que
o Mac fica um tempo bloqueado ou em repouso. *Bloqueio automático do Keepit* vem como **Nunca** em uma
instalação nova (uma atualização a partir da 3.0.3 mantém a escolha anterior: *Imediatamente*, se o
bloqueio junto com a tela estava ativado). Um gerenciador de área de transferência que pede a senha
depois de cada pausa para o café acaba deixando de ser usado, e `⌥L` está aí para os momentos que
importam. *Imediatamente* bloqueia junto com a tela. *Após 5 minutos*, *Após 15 minutos* ou *Após 1 hora*
ignoram uma ausência curta: o Keepit continua desbloqueado e gravando, e só bloqueia quando o Mac
ficou ausente durante todo esse tempo. O mesmo vale quando o Keepit abre com o Mac já bloqueado ou com
a sessão de outro usuário em primeiro plano (uma reabertura depois de uma atualização, por exemplo): a
ausência conta a partir da abertura, na medida em que o macOS informa esse estado ao Keepit
(normalmente informa; quando não consegue, a contagem começa no próximo bloqueio ou repouso). Com o
Touch ID ativado, o Keepit pede um toque no momento em que o Mac é desbloqueado, e assim fica pronto
antes do primeiro `⌥M`.

![Definindo a senha com o teclado na tela. É uma fotografia da tela, não uma captura: no Mac do autor, uma captura dessa cena mostra só o diálogo](site/img/guide/set-password-keyboard.jpg)

Os diálogos de senha mostram o layout de teclado atual e avisam sobre o Caps Lock, de modo que uma
senha recusada raramente é um mistério. O botão de teclado ao lado do campo abre um **teclado na
tela** para digitar a senha com o mouse: os cliques nunca passam pelo sistema como teclas
pressionadas, as teclas são embaralhadas a cada abertura e o teclado pede ao macOS que o deixe fora de
capturas e gravações de tela (em algumas configurações ele é excluído, mas isso não é garantido). Ele
serve para um Mac em que você não confia totalmente ou cuja tela está sendo compartilhada. Ao abrir e
depois de um bloqueio, o Keepit pede a senha (ou o Touch ID). *Recuperar acesso…* aceita, no lugar
dela, a frase de 24 palavras; veja [Frase de recuperação](#recovery-phrase).

![Desbloqueio ao abrir: senha, Encerrar ou a frase de recuperação; OK fica desativado até algo ser digitado. Fotografado pelo mesmo motivo](site/img/guide/unlock-keyboard.jpg)

![Ajustes → Segurança](site/img/guide/prefs-security.png)

### Touch ID

Com *Desbloquear com Touch ID*, a chave também fica guardada no Secure Enclave, protegida pela sua
impressão digital: o Keepit pede um toque em vez da senha. A senha continua valendo como alternativa
(o botão de senha no pedido). Com a tampa fechada e um Magic Keyboard externo com Touch ID, o Keepit
pede no teclado. *Permitir alterar a senha com Touch ID* deixa a impressão digital substituir a senha
antiga quando você a altera.

![Desbloqueio com o Touch ID; a senha continua como alternativa](site/img/guide/touch-id.png)

### Frase de recuperação

Quando você define uma senha, o Keepit mostra uma única vez uma frase de 24 palavras. Imprima-a ou
guarde-a em um gerenciador de senhas. Se você esquecer a senha, *Recuperar acesso…* na janela de
desbloqueio abre os dados e deixa você definir uma nova. *Frase de recuperação → Criar nova…* emite
uma frase nova e invalida a antiga. *Mostrar…*, ao lado, exibe de novo a frase atual depois do Touch
ID ou da senha.

Sem a senha, sem o Touch ID no mesmo Mac e sem a frase, não há como recuperar os dados: não existe
servidor nem nada para redefinir.

![A frase de recuperação de 24 palavras (as palavras estão ocultas aqui)](site/img/guide/recovery-phrase.png)

### Backup

O Keepit pode manter uma cópia criptografada do histórico e dos modelos em uma pasta que você escolhe
(iCloud Drive, Dropbox, Google Drive, um disco externo, um NAS) e gravar uma nova sempre que algo
mudar. Não existe servidor do Keepit: a pasta é sua. O provedor por trás dela vê o arquivo
criptografado, o tamanho dele e um pequeno cabeçalho sem criptografia (quando e por qual versão do
Keepit foi gravado, como a chave é derivada, identificadores aleatórios e o nome do seu Mac somente se
você ativar isso). A [página de segurança](/security#backups) (em inglês) lista o cabeçalho campo a
campo.

![Ajustes → Backup: backup automático, backup manual, restauração](site/img/guide/prefs-backup.png)

**Como ativar.** *Ajustes → Backup → Fazer backup automaticamente em uma pasta* e depois *Escolher…*
uma pasta (o seletor abre no iCloud Drive). O backup automático exige a proteção por senha de
*Ajustes → Segurança*: cada cópia é selada com uma chave derivada da chave do seu cofre, então ela
abre com a sua senha do Keepit ou com a sua frase de recuperação, neste Mac ou em qualquer outro, sem
nenhuma configuração extra. Sem senha, a caixa de seleção fica desativada e informa isso.

**O que acontece depois: a programação.** Cerca de cinco minutos depois da última alteração (e pelo menos uma vez por dia enquanto o Keepit estiver aberto), o Keepit grava na pasta um arquivo chamado
`Keepit-<date and time>-<installation>-<id>.keepit`, lê o arquivo de volta para conferir e só então
apaga as mais antigas das suas próprias cópias além de *Manter os últimos* (10 por padrão, de 1 a
100). Cada cópia é completa por si só, não um incremento, então um único arquivo é tudo de que você
precisa. Cópias feitas por outro Mac e arquivos que você mesmo colocar ali nunca são tocados: dois
Macs que compartilham uma pasta gravam duas séries independentes. A linha de status ao lado do título
*Backup automático* mostra a hora e o tamanho da última cópia, ou por que a última tentativa falhou.
Nada acontece enquanto o Keepit está bloqueado. *Fazer backup agora* (em *Backup manual*) não espera o
período de calmaria.

**Incluir o nome deste Mac nos arquivos de backup** (desativado por padrão) coloca o nome do
computador no cabeçalho sem criptografia de cada arquivo, para que duas séries na mesma pasta sejam
fáceis de distinguir no Finder. O provedor de armazenamento consegue ver esse nome, e por isso a opção
é facultativa.

**Restaurar.** *Restaurar…* abre um backup (deste Mac, de outro Mac ou um arquivo exportado) depois
que você o desbloqueia: com a senha do Mac em que ele foi feito, ou com a frase de recuperação que
aquele Mac mostrou quando a senha foi definida (*Recuperar acesso…* no diálogo de senha). Uma
pré-visualização mostra quando e onde o arquivo foi criado e quantos itens ele contém. Depois há duas
opções:

![A pré-visualização da restauração: quando e por qual versão do Keepit o arquivo foi gravado, o que ele contém, Mesclar ou Substituir](site/img/guide/restore-preview.png)

- *Mesclar* acrescenta o que ainda não existe: os itens do histórico pelo conteúdo, e os modelos do
  backup em uma pasta nova chamada *Importado <data>*, sem as teclas de atalho deles. Assim você vê
  exatamente o que veio do backup e pode mover ou apagar. Nada do que é seu é sobrescrito.
- *Substituir* descarta o histórico e os modelos atuais e fica com os do backup. Antes disso, o Keepit
  grava uma cópia do que você tem agora (`Keepit-before-restore-…`) na pasta de backup ou em uma pasta
  que você escolher. Se essa cópia não puder ser gravada, a substituição não começa. Se o Keepit ainda
  não tem senha, ele pede uma para essa cópia, como em *Salvar em arquivo…*.

*Restaurar também as preferências* traz do backup as teclas de atalho, os limites e as opções. Os
ajustes que expressam confiança em um Mac específico (Touch ID, a automação por URL e os apps
confiáveis dela, a própria pasta de backup) ficam sempre como estão aqui. Se o histórico do backup for
maior do que os limites deste Mac permitem, o Keepit informa quanto cabe antes de você confirmar.

Restaurou um backup com a frase de recuperação em um Mac que ainda não tem senha? O Keepit pede que
você defina uma primeiro, para que os dados restaurados nunca fiquem sem criptografia, e deixa você
manter essa frase neste Mac ou gerar uma nova. Restaurou com a senha? O Keepit oferece mantê-la como a
senha deste Mac. Nos dois casos, o backup automático é um ajuste de cada Mac: ative-o aqui e escolha a
pasta (pode ser a mesma), e este Mac começa a própria série de arquivos ao lado da série do Mac
antigo.

**Mudar para um Mac novo** é o objetivo de tudo isso: instale o Keepit, escolha *Restaurar do
backup…* na primeira abertura, selecione o arquivo mais recente da sua pasta, digite a senha do Mac
antigo e clique em *Substituir*. Depois ative o backup automático no Mac novo. As cópias feitas até
então abrem com a senha e a frase que valiam quando cada uma foi gravada: depois de uma troca de
senha, as antigas continuam exigindo a senha antiga.

**Backup manual.** Dois botões, duas coisas diferentes. *Fazer backup agora* cria na hora uma cópia
igual às automáticas: o mesmo tipo de arquivo, a mesma pasta e a mesma série, aberta com a sua senha
do Keepit ou com a frase. *Salvar em arquivo…* grava um único *arquivo* `.keepit` onde você escolher,
protegido por uma senha que você define para ele. Ele não exige a proteção por senha do Keepit, e o
Keepit não acompanha o arquivo depois. Serve para entregar dados a alguém ou para ter uma cópia fora
da pasta de backup. O nome sugerido diz o que ele é: `Keepit-archive-<date>-manual.keepit`, ao lado
das cópias automáticas `Keepit-<date and time>-<installation>-<id>.keepit`.

![Salvar em arquivo…: o nome do arquivo contém archive e manual](site/img/guide/save-to-archive.png)

![A senha própria do arquivo, com um medidor de força: ela não é guardada em lugar nenhum](site/img/guide/archive-password.png)

*Restaurar…* abre os dois tipos. O arquivo substitui *Exportar…* / *Importar…* da 2.x. Ele leva os
dados entre a versão de download direto e a da App Store, e entre o Keepit 2.x e o 3.x. Um arquivo
gravado pela 3.0 precisa da 3.0 ou posterior para abrir; a 3.0 lê tudo o que a 2.x gravou.

**Se algo der errado.** Uma cópia que falha é informada na linha de status e tentada de novo com
pausas cada vez maiores. As cópias anteriores permanecem. Se o Keepit foi encerrado ou o Mac desligou
no meio de uma restauração, a próxima abertura devolve tudo, em silêncio, ao estado anterior à
restauração. No caso raro de isso não ser possível (um arquivo que não pode ser gravado, um disco
cheio), o Keepit informa qual é o arquivo e encerra sem alterar nada: resolva o problema do arquivo e
abra de novo. Os detalhes, inclusive como é o formato do arquivo por dentro, estão na
[página de segurança](/security#backups) (em inglês).

---

## Parte 7: Recursos avançados

### Automação: o esquema de URL keepit://

O Atalhos (*Abrir URL*), o Raycast, o Alfred, o Keyboard Maestro ou `open` em um terminal podem
controlar o Keepit **depois que você ativar isso** em *Ajustes → Avançado → Automação → Permitir
comandos de URL keepit://*. Vem desativado porque qualquer app ou página web pode abrir uma URL, e
`add` / `paste` alteram a área de transferência e digitam no app em primeiro plano. Com a opção
desativada, o Keepit ignora essas URLs com um bipe. Com ela ativada, o Keepit verifica quem abriu a
URL: o primeiro comando de cada app que altera alguma coisa (`paste`, `copy`, `template`, `add`,
`add-template`, `pause`, `resume`) é mostrado em um diálogo. *Permitir* executa uma vez, e *Sempre
permitir* coloca o app na lista de confiáveis (que é esvaziada com *Esquecer apps confiáveis* no mesmo
painel). Para um navegador, ou um remetente que o macOS não consegue identificar, a pergunta é feita
todas as vezes. Comandos que apenas abrem as janelas do próprio Keepit nunca perguntam.

| URL | Efeito |
|-----|--------|
| `keepit://paste/2`<br>`keepit://paste/latest`<br>`keepit://paste/previous` | Colar o item N do histórico (ou o mais recente / o anterior) no app em primeiro plano |
| `keepit://copy/3` | Colocar o item N na área de transferência sem colar |
| `keepit://template/Signature`<br>`keepit://template/Work/Reply?copy=1` | Colar (ou copiar) um modelo pelo nome ou pelo caminho da pasta |
| `keepit://add?text=…` | Adicionar texto ao histórico e à área de transferência |
| `keepit://add-template?text=…&name=…` | Criar um modelo |
| `keepit://history`<br>`keepit://templates`<br>`keepit://viewer`<br>`keepit://settings` | Abrir o menu de histórico, o menu de modelos, o Visualizador ou os Ajustes |
| `keepit://pause`<br>`keepit://resume` | Pausar a gravação por 10 minutos / retomar |

Codifique o texto com porcentagem (`%20` para um espaço). As URLs são ignoradas enquanto o Keepit está
bloqueado.

### Atualizações

O Keepit consulta o GitHub Releases uma vez por dia e oferece as atualizações em um diálogo.
*Verificar atualizações…* faz isso na hora. As atualizações são assinadas (EdDSA) e autenticadas pela
Apple. Com o Homebrew, `brew upgrade --cask keepit` faz o mesmo. As somas de verificação de cada
download estão em `SHA256SUMS`, na página da versão.

Essa verificação é a única requisição de rede que o Keepit faz, e ela é opcional: *Ajustes → Geral →
Atualizações → Verificar atualizações automaticamente*. Com ela desativada, o Keepit não entra em
contato com nada, nem quando você pede, e *Verificar atualizações…* some dos menus. Nesse caso, você
atualiza baixando o app em [keep.it.com](https://keep.it.com) ou pelo Homebrew. A versão da App Store
não tem atualizador nem essa opção: quem a atualiza é a App Store.

### Desinstalação

*Ajustes → Avançado → Redefinir e desinstalar → Desinstalar…* remove o app, a pasta de dados, as
entradas das Chaves (inclusive a chave do Touch ID), o item de início de sessão e a entrada de
Acessibilidade. O Keepit pede a sua senha ou o Touch ID, a palavra `DELETE` digitada e uma
confirmação. Exporte um backup antes, se achar que pode precisar dos dados de novo. Com o Homebrew,
execute depois `brew uninstall --cask --force keepit` para que o Homebrew esqueça o cask.

![Ajustes → Avançado](site/img/guide/prefs-advanced.png)

---

## Referência

### Solução de problemas

**Nada é colado depois que escolho um item.** Falta a permissão de Acessibilidade: *Ajustes do Sistema
→ Privacidade e Segurança → Acessibilidade → Keepit*. Se o Keepit está na lista e mesmo assim não cola,
desative e ative de novo: o macOS esquece a permissão quando o app é reinstalado.

**Um atalho não faz nada.** Outro app ou o macOS já usa essa combinação. O Keepit avisa ao abrir.
Escolha outra combinação no painel *Atalhos*. ⌃⌥ com dígitos e letras está livre em um Mac com a
configuração de fábrica.

**O menu abre no lugar errado.** O app em que você está não expõe o cursor de texto, então o menu
recorre ao cursor do mouse. *Abrir o menu no cursor de texto quando possível*, no painel Geral,
desativa essa localização, caso você prefira sempre o cursor do mouse.

**Falta alguma coisa que copiei.** O que o app de origem marca como oculto não é gravado, e também não
é gravada uma cópia feita enquanto um gerenciador de senhas (lista integrada) ou um app da sua lista
de ignorados estava em primeiro plano, incluindo o app do qual você acabou de sair. Veja *Ajustes →
Histórico* e a [página de segurança](/security#what-is-not-recorded) (em inglês).

**O Touch ID não é oferecido.** No momento não há nenhum sensor de Touch ID acessível (tampa fechada,
sem teclado com Touch ID). O Keepit mantém o ajuste e pede a impressão digital assim que houver um
sensor disponível.

**O status do backup diz que a pasta não está disponível.** A pasta foi movida, renomeada, ejetada ou
(iCloud Drive) removida do armazenamento local. Monte ou recupere a pasta, e a próxima cópia será
gravada. Ou use *Escolher…* para indicar uma pasta nova: ela começa uma série nova, e os arquivos
antigos ficam onde estão.

**Um arquivo de backup não abre.** *Senha incorreta* significa que a etiqueta de autenticação do
arquivo não conferiu: verifique se você está usando a senha do Mac que *gravou* o arquivo (depois de
uma troca de senha, as cópias antigas continuam abrindo com a antiga) ou a frase de recuperação dele.
*Este backup requer o Keepit 3.0 ou mais recente* significa que o arquivo foi gravado por uma versão
mais nova do que a que está tentando abri-lo.

**O Homebrew se recusa a instalar por cima de um app existente.** Encerre o Keepit e mova
`/Applications/Keepit.app` para o Lixo antes, ou acrescente `--force`.

Ainda com problemas? [GitHub Issues](https://github.com/andrey-insarov/Keepit/issues) · admin@keep.it.com

### Resumo dos atalhos

| Teclas | Ação |
|------|--------|
| `⌥M` | Menu de histórico; digite para buscar |
| `⌥T` | Menu de modelos |
| `⌃⌥1` … `⌃⌥0` | Colar um dos itens de 1 a 10 (no menu e em qualquer lugar) |
| `⇧` no menu | Menu estendido: todas as ações de cada item |
| `⌥⇧V` | Colar o item anterior / alternar |
| `⌃⌥V` | Colar a área de transferência como texto simples |
| `⌃⌥U` `⌃⌥L` `⌃⌥T` `⌃⌥S` | MAIÚSCULAS / minúsculas / Iniciais Maiúsculas / primeira letra maiúscula |
| `⌃⌥W` `⌃⌥J` | Sem espaços nas pontas / em uma única linha |
| `⌃⌥K` `⌃⌥D` `⌃⌥Y` `⌃⌥X` | Tachado / sublinhado / sublinhado ondulado / remover decorações |
| `⌃⌥A` | Adicionar a área de transferência aos Modelos |
| `⌃⌥⌫` | Apagar o item mais recente |
| `⌥N` · `⌥V` · `⌥⇧N` | Fila de colagem: iniciar / parar · colar o próximo · colar todo o restante |
| `⌥E` `⌥S` `⌥C` `⌥P` `⌥L` `⌥Q` | Visualizador · Ajustes · Limpar histórico · Pausar gravação · Bloquear · Encerrar |
| `⌘F` no Visualizador | Buscar |
| `⌘,` | Ajustes |

### Resumo dos marcadores

| Marcador | Resultado |
|-------------|--------|
| `{date}` `{time}` `{datetime}` | Data / hora / ambas, no formato do sistema |
| `{date:yyyy-MM-dd}` `{time:HH:mm}` | Formato personalizado (padrões de data do Unicode) |
| `{date:long}` `{time:short}` `{datetime:full}` | Estilo com nome: `short` `medium` `long` `full` |
| `{date+7d}` `{date-1m:MMMM}` `{time+1h}` `{datetime-1d:long}` `{date+1y-2d}` | Deslocamento (`d` `w` `m` `y` `h`; até quatro em sequência) |
| `{weekday}` `{month}` `{year}` | Nome do dia, nome do mês, ano |
| `{iso}` `{unix}` | Data e hora em ISO 8601, hora Unix |
| `{clipboard}` `{clipboard:2}` | A área de transferência (item 1) ou o item N |
| `{clipboard\|upper}` `\|lower` `\|title` `\|trim` `\|oneline` `\|url` | Filtros, que podem ser encadeados |
| `{input:Name}` `{input:Name=Default}` | Pedir um valor antes de colar |
| `{choice:Label=A\|B\|C}` | Pedir a escolha de uma opção |
| `{cursor}` | Posição do cursor depois de colar |
| `{user}` `{username}` `{host}` | Nome completo, nome da conta, nome do computador |
| `{uuid}` `{random:1-100}` | UUID novo, número aleatório em um intervalo |
| `{{` `}}` | Chaves literais |
