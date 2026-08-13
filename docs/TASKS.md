# TASKS — copyMemory

Checklist de implementação alinhado ao [PRD](PRD.md). Fases 1–4 = MVP. Fase 5 = polimento + roadmap (atalho global e persistência, fora do MVP nas seções 1.5/1.6 e RNF10).

## Como usar

1. Peça ao Cursor **uma task por ID** (ex.: “implemente a 1.3”).
2. Ao concluir, marque `[x]` e avise qual item foi finalizado (ver `.cursorrules`).
3. Não pule dependências: cada task lista o que precisa estar pronto.

Arquivos novos em `copyMemory/` entram no target automaticamente (`PBXFileSystemSynchronizedRootGroup`). Deployment target atual: macOS 26.4 — usar `MenuBarExtra` e `@Observable`.

---

## Fase 1: Setup da Barra de Menus e ciclo de vida básico

Partir do template `WindowGroup` + `ContentView` e chegar a um agent app clicável, sem Dock.

### 1.1 — Estrutura de pastas

- [x] **Fazer:** criar os diretórios `copyMemory/Models/`, `copyMemory/Services/`, `copyMemory/Store/` e `copyMemory/Views/` (PRD §2.8). Se o Git não versionar pastas vazias, adicionar um `.gitkeep` em cada uma.
- **Arquivos:** `copyMemory/Models/`, `copyMemory/Services/`, `copyMemory/Store/`, `copyMemory/Views/`
- **Depende de:** —
- **Aceite:** as quatro pastas existem no disco; o Xcode as lista no target `copyMemory`.

### 1.2 — App agent (sem Dock)

- [x] **Fazer:** definir `INFOPLIST_KEY_LSUIElement = YES` nas configurações Debug e Release do target `copyMemory` em `copyMemory.xcodeproj/project.pbxproj` (RNF08).
- **Arquivos:** `copyMemory.xcodeproj/project.pbxproj`
- **Depende de:** —
- **Aceite:** a chave aparece nos dois blocos do target do app; após build, o processo não mostra ícone no Dock.

### 1.3 — MenuBarExtra no lugar do WindowGroup

- [x] **Fazer:** em `copyMemoryApp.swift`, substituir o `WindowGroup` por `MenuBarExtra` com ícone SF Symbol `doc.on.clipboard` e `.menuBarExtraStyle(.window)` (o estilo `.menu` não comporta `TextField` bem na Fase 3). Sem `WindowGroup` principal.
- **Arquivos:** `copyMemory/copyMemoryApp.swift`
- **Depende de:** 1.2
- **Aceite:** o app compila; a cena principal é só o extra da barra de menus.

### 1.4 — Placeholder ClipboardMenuView

- [x] **Fazer:** criar `Views/ClipboardMenuView.swift` com conteúdo estático mínimo (título “copyMemory”) e usá-lo como body do `MenuBarExtra`.
- **Arquivos:** `copyMemory/Views/ClipboardMenuView.swift`, `copyMemory/copyMemoryApp.swift`
- **Depende de:** 1.1, 1.3
- **Aceite:** clicar no ícone da menu bar abre um painel mostrando o placeholder.

### 1.5 — Remover ContentView do fluxo de produção

- [ ] **Fazer:** remover `copyMemory/ContentView.swift` (ou deixá-lo de fora de qualquer `Scene`). O app não deve mais apresentar “Hello, world!”.
- **Arquivos:** `copyMemory/ContentView.swift`, `copyMemory/copyMemoryApp.swift`
- **Depende de:** 1.4
- **Aceite:** nenhum `Scene` referencia `ContentView`; o arquivo do template não faz parte do fluxo padrão.

### 1.6 — Item Sair

- [x] **Fazer:** no painel do menu, adicionar `Divider` + botão **Sair** que chama `NSApplication.shared.terminate(nil)`. Agent apps não têm janela para fechar pelo Dock.
- **Arquivos:** `copyMemory/Views/ClipboardMenuView.swift`
- **Depende de:** 1.4
- **Aceite:** Sair encerra o processo; o ícone some da menu bar.

### 1.7 — Aceite manual do ciclo de vida

- [x] **Fazer:** build + run e validar presença mínima (RNF08). Não requer código novo se 1.2–1.6 estiverem corretos.
- **Arquivos:** —
- **Depende de:** 1.2, 1.3, 1.4, 1.5, 1.6
- **Aceite:** (1) sem ícone no Dock; (2) ícone `doc.on.clipboard` na menu bar; (3) clique abre o painel; (4) Sair encerra o app.

---

## Fase 2: Monitoramento do NSPasteboard e armazenamento em memória

Camada Monitor + Store, ainda sem UI rica. A flag de escrita própria entra como esqueleto (uso completo na 4.2).

### 2.1 — Modelo ClipboardItem

- [x] **Fazer:** criar `ClipboardContentType` (`text` / `image`) e `struct ClipboardItem: Identifiable, Equatable` conforme PRD §2.3 (`id`, `type`, `text`, `imageData`, `thumbnail`, `createdAt`, `contentHash`).
- **Arquivos:** `copyMemory/Models/ClipboardItem.swift`
- **Depende de:** 1.1
- **Aceite:** o tipo compila; itens de texto têm `imageData`/`thumbnail` nulos; itens de imagem têm thumbnail previsto no modelo.

### 2.2 — contentHash

- [x] **Fazer:** função pura que gera `contentHash` — texto = digest da string; imagem = digest dos bytes relevantes (payload usado na comparação, não o thumbnail).
- **Arquivos:** `copyMemory/Models/ClipboardItem.swift` (ou helper no mesmo módulo)
- **Depende de:** 2.1
- **Aceite:** duas strings iguais produzem o mesmo hash; bytes de imagem iguais idem; conteúdos distintos, hashes distintos.

### 2.3 — ClipboardMonitor (polling)

- [x] **Fazer:** criar `ClipboardMonitor` com `Timer.publish(every: 0.5, on: .main, in: .common)`, leitura de `NSPasteboard.general.changeCount`, isolamento `MainActor`, e cancelamento de `AnyCancellable` no `deinit` (PRD §2.6, RNF01). Sem trabalho pesado quando o `changeCount` não muda.
- **Arquivos:** `copyMemory/Services/ClipboardMonitor.swift`
- **Depende de:** 1.1
- **Aceite:** o monitor inicia/para sem leak de subscription; ticks a ~2 Hz; ignora ticks sem mudança de `changeCount`.

### 2.4 — Captura de texto

- [x] **Fazer:** quando o `changeCount` mudar, ler tipos string da pasteboard (`string(forType:)` / tipos string suportados) e emitir um `ClipboardItem` de texto com hash (RF02).
- **Arquivos:** `copyMemory/Services/ClipboardMonitor.swift`
- **Depende de:** 2.1, 2.2, 2.3
- **Aceite:** copiar texto em outro app produz um item com `type == .text` e `text` preenchido.

### 2.5 — Captura de imagem e thumbnail

- [x] **Fazer:** ler representação de imagem (`NSImage` / TIFF/PNG). Gerar `thumbnail` com lado máximo ≤ 256 px (RNF04). Guardar payload necessário para re-copiar em `imageData`.
- **Arquivos:** `copyMemory/Services/ClipboardMonitor.swift` (helper de downscale se fizer sentido)
- **Depende de:** 2.1, 2.2, 2.3
- **Aceite:** copiar uma imagem produz item com `type == .image`, `thumbnail` não nulo e maior lado do thumbnail ≤ 256 px.

### 2.6 — Conteúdo misto: preferir imagem

- [x] **Fazer:** se a mesma mudança expuser texto e imagem utilizável, criar **um** item de imagem e ignorar o texto (PRD §5.6).
- **Arquivos:** `copyMemory/Services/ClipboardMonitor.swift`
- **Depende de:** 2.4, 2.5
- **Aceite:** um `changeCount` nunca gera dois itens; imagem tem prioridade sobre texto.

### 2.7 — Tipos não suportados e vazio

- [x] **Fazer:** pasteboard vazia ou tipos não suportados (arquivos, RTF-only, etc.) não crasham e não inserem item (RNF07).
- **Arquivos:** `copyMemory/Services/ClipboardMonitor.swift`
- **Depende de:** 2.4, 2.5
- **Aceite:** copiar um tipo fora do escopo deixa o histórico inalterado; o app continua rodando.

### 2.8 — ClipboardStore (histórico em RAM)

- [x] **Fazer:** criar `ClipboardStore` `@Observable` com `items` (mais recente primeiro), constante `maxItems = 50`, insert no topo e trim FIFO dos mais antigos (RF03, RF10 — só RAM).
- **Arquivos:** `copyMemory/Store/ClipboardStore.swift`
- **Depende de:** 2.1
- **Aceite:** o 51º insert remove o item mais antigo; a ordem é recência decrescente.

### 2.9 — Dedupe consecutivo

- [x] **Fazer:** se o `contentHash` do novo item for igual ao do item no topo, não inserir (RF04).
- **Arquivos:** `copyMemory/Store/ClipboardStore.swift`
- **Depende de:** 2.2, 2.8
- **Aceite:** duas cópias consecutivas do mesmo conteúdo resultam em um único item no topo.

### 2.10 — Esqueleto de escrita própria

- [x] **Fazer:** expor no monitor/store `isWritingOwnContent` (ou último `changeCount` próprio) e, quando a flag estiver ativa, atualizar o `changeCount` interno sem emitir item (RF07). Ainda sem `select` — só o gancho.
- **Arquivos:** `copyMemory/Services/ClipboardMonitor.swift`, `copyMemory/Store/ClipboardStore.swift`
- **Depende de:** 2.3, 2.8
- **Aceite:** API existe e um write simulado com a flag ligada não chama insert.

### 2.11 — Ligar monitor ao store no launch

- [x] **Fazer:** instanciar `ClipboardStore` no `copyMemoryApp`, iniciar o monitor na subida do processo e encaminhar itens capturados para `store.insert`. Cancelar ao encerrar.
- **Arquivos:** `copyMemory/copyMemoryApp.swift`, `copyMemory/Store/ClipboardStore.swift`
- **Depende de:** 2.3, 2.8, 2.9, 2.10
- **Aceite:** com o app rodando, copiar texto/imagem em outro app aumenta `store.items` em ≤ 1 s (critério de aceite MVP 1, ainda sem UI de lista).

### 2.12 — Testes unitários do domínio

- [x] **Fazer:** testes em `copyMemoryTests` para hash, dedupe consecutivo, trim em 50 e preferência de imagem no conteúdo misto. Remover os placeholders `testExample` / `testPerformanceExample`.
- **Arquivos:** `copyMemoryTests/copyMemoryTests.swift` (ou arquivos de teste por tipo)
- **Depende de:** 2.2, 2.6, 2.8, 2.9
- **Aceite:** `Cmd+U` no target de testes passa; os quatro comportamentos estão cobertos.

---

## Fase 3: Interface do Histórico em SwiftUI (Lista, Busca)

Só apresentação. Clique ainda não copia de volta (Fase 4).

### 3.1 — Layout do menu (busca + lista)

- [x] **Fazer:** em `ClipboardMenuView`, composição de cima para baixo: campo de busca, lista de itens, empty state quando aplicável (PRD §6.2). Largura estreita adequada à menu bar. Sem cards, stats ou configurações.
- **Arquivos:** `copyMemory/Views/ClipboardMenuView.swift`
- **Depende de:** 1.4, 1.6
- **Aceite:** o painel mostra a hierarquia busca → lista; o botão Sair permanece acessível (rodapé).

### 3.2 — Campo de busca

- [x] **Fazer:** `TextField` com placeholder “Buscar…”; o texto da query atualiza o filtro a cada keystroke (PRD §6.4).
- **Arquivos:** `copyMemory/Views/ClipboardMenuView.swift`
- **Depende de:** 3.1
- **Aceite:** digitar no campo altera a query imediatamente; placeholder visível quando vazio.

### 3.3 — Row de texto

- [x] **Fazer:** criar `ClipboardItemRow` para `type == .text`: 1–2 linhas, truncamento com reticências (~80–120 caracteres), tipografia densa (RF09).
- **Arquivos:** `copyMemory/Views/ClipboardItemRow.swift`
- **Depende de:** 2.1, 3.1
- **Aceite:** texto longo aparece truncado; a célula cabe na largura do menu.

### 3.4 — Row de imagem

- [x] **Fazer:** na mesma `ClipboardItemRow`, ramo de imagem: thumbnail à esquerda com aspect-fit (sem quebrar layout em panorâmicas/altas) + label curta (“Imagem” ou dimensões) (PRD §5.5, §6.3).
- **Arquivos:** `copyMemory/Views/ClipboardItemRow.swift`
- **Depende de:** 2.5, 3.3
- **Aceite:** thumbnail visível, proporcional, sem estourar a altura da row.

### 3.5 — Empty states

- [x] **Fazer:** criar `EmptyClipboardView` com mensagens distintas: histórico vazio → “Nenhuma cópia ainda”; filtro sem matches → “Nenhum item encontrado” (RF08).
- **Arquivos:** `copyMemory/Views/EmptyClipboardView.swift`, `copyMemory/Views/ClipboardMenuView.swift`
- **Depende de:** 3.1, 3.2
- **Aceite:** as duas mensagens não se confundem; a lista some quando o empty state aparece.

### 3.6 — Filtro no store (RF05)

- [x] **Fazer:** no `ClipboardStore`, filtro case-insensitive por substring em `text`. Itens só-imagem aparecem apenas quando a query está vazia; se houver texto associado, participam da busca.
- **Arquivos:** `copyMemory/Store/ClipboardStore.swift`
- **Depende de:** 2.8, 3.2
- **Aceite:** query “abc” oculta textos que não contêm “abc” e oculta imagens sem texto; query vazia mostra todos.

### 3.7 — Injetar o store na UI

- [x] **Fazer:** criar o `ClipboardStore` no `App` e injetá-lo no `MenuBarExtra` (`@Observable` / environment). A lista observa `items` filtrados.
- **Arquivos:** `copyMemory/copyMemoryApp.swift`, `copyMemory/Views/ClipboardMenuView.swift`
- **Depende de:** 2.11, 3.1, 3.6
- **Aceite:** copiar texto/imagem atualiza a lista no painel aberto (ou no próximo open) sem recarregar o app.

### 3.8 — Previews SwiftUI

- [x] **Fazer:** `#Preview` para row de texto, row de imagem, empty (os dois modos) e lista com itens mock.
- **Arquivos:** `copyMemory/Views/ClipboardItemRow.swift`, `copyMemory/Views/EmptyClipboardView.swift`, `copyMemory/Views/ClipboardMenuView.swift`
- **Depende de:** 3.3, 3.4, 3.5
- **Aceite:** os previews renderizam no canvas do Xcode sem o app em runtime.

### 3.9 — Visual nativo light/dark

- [x] **Fazer:** tipografia e espaçamento utilitários; cores do sistema (sem paleta custom); hover/highlight nativo da lista (PRD §6.7). Sem decoração excessiva.
- **Arquivos:** `copyMemory/Views/*.swift`
- **Depende de:** 3.1, 3.3, 3.4
- **Aceite:** o painel é legível em light e dark; densidade próxima de um menu macOS nativo.

---

## Fase 4: Integração (ação de colar/copiar ao selecionar um item)

Ação primária: clique → re-copiar para a pasteboard → fechar o menu. O MVP **não** cola no app em foco (sem Accessibility).

### 4.1 — select(_:) escreve na pasteboard

- [x] **Fazer:** `ClipboardStore.select(_ item:)` faz `NSPasteboard.general.clearContents()` e grava string ou imagem conforme o tipo (RF06). Latência percebida &lt; 100 ms (RNF02).
- **Arquivos:** `copyMemory/Store/ClipboardStore.swift`
- **Depende de:** 2.8, 2.10
- **Aceite:** após `select` de texto, `string(forType: .string)` é o texto do item; após `select` de imagem, a pasteboard contém a imagem.

### 4.2 — Proteção contra loop de re-cópia

- [x] **Fazer:** marcar escrita própria **antes** do write; depois sincronizar o `changeCount` observado e não reinserir o item (RF07, PRD §5.3). Completar o esqueleto da 2.10.
- **Arquivos:** `copyMemory/Store/ClipboardStore.swift`, `copyMemory/Services/ClipboardMonitor.swift`
- **Depende de:** 2.10, 4.1
- **Aceite:** selecionar um item não duplica o topo do histórico; recopiar o mesmo conteúdo duas vezes seguidas (pelo usuário, fora do app) continua caindo na 2.9.

### 4.3 — Dismiss do MenuBarExtra

- [x] **Fazer:** fechar o painel após o select. Preferir binding `isPresented` do `MenuBarExtra`; se a API não dismissar de forma estável, bridge AppKit mínimo (PRD §5.4). O menu **não** pode permanecer aberto.
- **Arquivos:** `copyMemory/Views/ClipboardMenuView.swift`, `copyMemory/Services/MenuBarExtraDismisser.swift` (bridge AppKit: `MenuBarExtra` ainda não tem `isPresented` estável no Xcode 26)
- **Depende de:** 1.3
- **Aceite:** após a ação de select, o painel some; o ícone permanece na menu bar.

### 4.4 — Clique na row dispara select + dismiss

- [x] **Fazer:** toque/clique em `ClipboardItemRow` chama `select` e dispara o dismiss da 4.3 (RF06).
- **Arquivos:** `copyMemory/Views/ClipboardItemRow.swift`, `copyMemory/Views/ClipboardMenuView.swift`
- **Depende de:** 4.1, 4.2, 4.3
- **Aceite:** um clique em texto ou imagem copia o conteúdo e fecha o menu; Cmd+V no app de destino cola o item.

### 4.5 — Teclado no painel aberto

- [x] **Fazer:** se o `MenuBarExtra` permitir foco: setas navegam a lista e Return seleciona o item focado (mesmo comportamento do clique). Se não permitir, **não** forçar hack frágil — documentar a limitação nesta task (marcar o checkbox e anotar o resultado abaixo).
- **Arquivos:** `copyMemory/Views/ClipboardMenuView.swift`, `docs/TASKS.md` (nota de limitação, se houver)
- **Depende de:** 4.4
- **Aceite:** ou setas+Return funcionam, ou a limitação está registrada aqui; o mouse continua sendo o caminho garantido do MVP.

> Limitação de teclado (preencher na implementação): o estilo `.window` permite foco no `TextField`. Setas e Return funcionam com o campo de busca focado (padrão de paleta: filtrar, navegar, confirmar). Não foi necessário hack; mouse continua sendo o caminho garantido do MVP.

### 4.6 — Aceite manual do MVP (PRD §3.1)

- [x] **Fazer:** validar os seis critérios abaixo. Sem código novo se 4.1–4.4 estiverem corretos.
- **Arquivos:** —
- **Depende de:** 2.11, 3.7, 4.4, 4.2
- **Aceite:**
  1. Copiar texto em outro app → item no topo em ≤ 1 s.
  2. Copiar imagem → thumbnail na lista.
  3. Digitar na busca reduz a lista aos textos correspondentes.
  4. Clicar item de texto → pasteboard contém esse texto; menu fecha.
  5. Clicar item de imagem → pasteboard contém a imagem; menu fecha.
  6. Recopiar o mesmo texto duas vezes seguidas → um único item no topo.

---

## Fase 5: Polimento, atalho global de teclado e persistência

Itens Should / roadmap. Persistência **opcional e desligada por padrão**, para não violar RNF10 no caminho feliz do MVP. Colagem automática no app em foco (Accessibility) continua fora de escopo.

### 5.1 — Remover item individual

- [x] **Fazer:** ação para remover um item do histórico em memória (swipe, botão no hover, ou menu de contexto) (RF11).
- **Arquivos:** `copyMemory/Store/ClipboardStore.swift`, `copyMemory/Views/ClipboardItemRow.swift`, `copyMemory/Views/ClipboardMenuView.swift`
- **Depende de:** 3.7
- **Aceite:** remover um item some da lista; os demais permanecem na ordem.

### 5.2 — Limpar todo o histórico

- [x] **Fazer:** ação “Limpar histórico” no painel (junto ao Sair). Confirmação leve se fizer sentido; senão ação direta por ser só RAM (RF11).
- **Arquivos:** `copyMemory/Store/ClipboardStore.swift`, `copyMemory/Views/ClipboardMenuView.swift`
- **Depende de:** 2.8, 3.5
- **Aceite:** a lista fica vazia e o empty state “Nenhuma cópia ainda” reaparece.

### 5.3 — Atalho global para abrir o menu

- [x] **Fazer:** hotkey global que **abre** o `MenuBarExtra` (não cola via Accessibility). Registrar/desregistrar no ciclo de vida do app; documentar o atalho padrão escolhido.
- **Arquivos:** `copyMemory/Services/` (ex.: `HotKeyService.swift`), `copyMemory/copyMemoryApp.swift`
- **Depende de:** 1.3, 4.3
- **Aceite:** com o app em background, o atalho abre o painel; o app continua sem Dock.

> Atalho padrão (5.3): **⌥⌘V** (Option+Command+V). Abre o painel do `MenuBarExtra` via Carbon `RegisterEventHotKey` (sem permissão de Accessibility). Não cola no app em foco.

### 5.4 — Persistência opcional (default desligada)

- [x] **Fazer:** persistência opcional do histórico via JSON + `FileManager` em Application Support (não UserDefaults para imagens). Flag default **off**. Com a flag off, nenhum I/O de histórico (RNF10 / RNF06).
- **Arquivos:** `copyMemory/Services/` (ex.: `ClipboardPersistence.swift`), `copyMemory/Store/ClipboardStore.swift`
- **Depende de:** 2.8, 2.1
- **Aceite:** flag off → encerrar e reabrir = histórico vazio; flag on → itens sobrevivem ao restart.

### 5.5 — Downscale do payload de imagens grandes

- [x] **Fazer:** além do thumbnail da 2.5, redimensionar/comprimir o `imageData` reutilizável quando a captura for muito grande (RNF03, RNF04, PRD §5.2). Manter qualidade suficiente para Cmd+V útil.
- **Arquivos:** `copyMemory/Services/ClipboardMonitor.swift` (ou helper de imagem)
- **Depende de:** 2.5
- **Aceite:** screenshots grandes não mantêm resolução nativa × 50 itens; re-copiar ainda produz imagem utilizável.

### 5.6 — Copy do empty state (sessão)

- [x] **Fazer:** empty state (e/ou linha discreta no painel) deixa claro que o histórico é só da sessão e some ao sair — salvo se a flag da 5.4 estiver ligada.
- **Arquivos:** `copyMemory/Views/EmptyClipboardView.swift`
- **Depende de:** 3.5
- **Aceite:** o usuário entende o ciclo de vida dos dados sem alerta alarmista (PRD §6.8).

### 5.7 — Revisão de CPU idle e memória

- [x] **Fazer:** com o app em idle (sem mudanças de pasteboard), confirmar timer leve e CPU desprezível (RNF01, RNF05). Confirmar teto de 50 itens e thumbnails. Ajustar se o Instruments mostrar trabalho no tick sem `changeCount` novo.
- **Arquivos:** `copyMemory/Services/ClipboardMonitor.swift`, `copyMemory/Store/ClipboardStore.swift` (só se houver ajuste)
- **Depende de:** 2.3, 2.8, 5.5
- **Aceite:** idle ≈ só o timer de 0,5 s; histórico limitado a 50; sem I/O de rede.

> Revisão idle (5.7): `pollPasteboard` retorna no primeiro `guard` quando `changeCount` não muda — o tick só lê um `Int`. Teto de 50 itens mantido; thumbnail ≤ 256 px; payload de imagem limitado a 1920 px / JPEG quando grande. Sem I/O de rede. Com persistência desligada, nenhum I/O de histórico.

---

## Referências

- PRD: [docs/PRD.md](PRD.md)
- Diretrizes: [`.cursorrules`](../.cursorrules)
- Entry point: [`copyMemory/copyMemoryApp.swift`](../copyMemory/copyMemoryApp.swift)
