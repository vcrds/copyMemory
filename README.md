# copyMemory

Gerenciador de área de transferência para macOS. Fica só na barra de menus, guarda o que você copia (texto e imagens) e devolve o item para a área de transferência com um clique.

O macOS guarda apenas a cópia mais recente. O copyMemory mantém um histórico curto para você reutilizar links, trechos de código, mensagens e imagens sem abrir um app pesado.

- Sem ícone no Dock.
- Sem janela permanente.
- Sem rede, conta ou telemetria.
- O histórico fica só na memória, a menos que você peça para mantê-lo.

Requer **macOS 26.4** ou superior.

## Instalar

### Pelo DMG (uso diário)

1. Baixe `copyMemory-<versão>.dmg` na [página de releases](https://github.com/vinicdev/copyMemory/releases).
2. Abra o DMG e arraste **copyMemory** para a pasta **Aplicativos**.
3. Abra o app em Aplicativos. O ícone de prancheta (`doc.on.clipboard`) aparece na barra de menus. Não há ícone no Dock.

O binário publicado é assinado localmente, sem conta de desenvolvedor Apple. Na primeira abertura o macOS pode bloquear o app:

1. Clique com o botão direito em **copyMemory** em Aplicativos e escolha **Abrir**.
2. Confirme em **Abrir** no alerta.
3. Se o sistema disser que o app está danificado ou de um desenvolvedor não identificado, abra **Ajustes do Sistema → Privacidade e Segurança** e clique em **Abrir Mesmo Assim**.

Se o bloqueio continuar, remova a quarentena no Terminal e abra de novo:

```bash
xattr -dr com.apple.quarantine /Applications/copyMemory.app
```

Para sair, abra o painel e clique em **Sair**. Fechar a janela do DMG não encerra o app.

### A partir do código

1. Instale o [Xcode](https://developer.apple.com/xcode/) compatível com o macOS 26.4.
2. Clone o repositório e abra o projeto:

```bash
git clone https://github.com/vinicdev/copyMemory.git
cd copyMemory
open copyMemory.xcodeproj
```

3. Selecione o scheme **copyMemory** e o destino **My Mac**.
4. Rode com **⌘R**.

Para gerar o instalador localmente (compila em Release e grava `dist/copyMemory.dmg`):

```bash
./scripts/create-dmg.sh
```

Na primeira execução o script pode pedir permissão para o Terminal controlar o Finder. Aceite para montar a janela de arrastar para Aplicativos.

## Usar

1. Copie texto ou uma imagem em qualquer app, como de costume (**⌘C**).
2. Abra o copyMemory pelo ícone da barra de menus ou pelo atalho **⌥⌘V** (Option + Command + V).
3. Clique no item, ou selecione-o com as setas e confirme com **Return**.
4. O painel fecha e o conteúdo volta para a área de transferência.
5. Cole no app de destino com **⌘V**.

O atalho só abre o painel. Ele não cola no app que está em foco.

### Busca

O campo **Buscar…** filtra o histórico a cada tecla, sem diferenciar maiúsculas e minúsculas. Imagens sem texto associado aparecem só quando a busca está vazia.

### Remover e limpar

- Passe o mouse sobre um item e clique no **×**, ou use o menu de contexto **Remover**.
- **Limpar histórico** pede confirmação e apaga a lista inteira.
- **Sair** encerra o processo e tira o ícone da barra de menus.

### Histórico entre aberturas

Por padrão o histórico existe só enquanto o app está aberto. Ao sair, ele some.

Marque **Manter histórico ao sair** para gravar os itens neste Mac. Desmarcar a opção apaga o arquivo salvo. O arquivo fica em:

```text
~/Library/Application Support/com.vinicius.copyMemory/history.json
```

## O que entra no histórico

| Conteúdo | Comportamento |
| --- | --- |
| Texto | Preview de até duas linhas. |
| Imagem | Miniatura e o rótulo **Imagem**. |
| Texto e imagem na mesma cópia | Só a imagem é guardada. |
| A mesma cópia duas vezes seguidas | Um único item no topo. |
| Arquivos, áudio e formatos ricos isolados | Ignorados. |

O histórico guarda no máximo **50** itens. O mais antigo sai quando o limite é atingido. Imagens muito grandes são reduzidas (lado maior até 1920 px) para não ocupar memória à toa; imagens pequenas permanecem como foram copiadas.

## Privacidade

Com **Manter histórico ao sair** desligado, nada do histórico é escrito em disco. O app não envia dados pela rede. Com a opção ligada, texto e imagens ficam no arquivo JSON da sua conta de usuário, só neste Mac.

## Limitações

- Não cola automaticamente no app em foco.
- Não sincroniza entre dispositivos.
- Não há pin, favoritos nem atalho configurável (o atalho fixo é **⌥⌘V**).
- O painel precisa estar aberto, com o campo de busca em foco, para as setas e o Return selecionarem um item. O clique sempre funciona.

## Para quem desenvolve

App nativo em Swift e SwiftUI (`MenuBarExtra`), estado com `@Observable` e monitoramento de `NSPasteboard.general` a cada 0,5 s. Bundle ID: `com.vinicius.copyMemory`. Versão de marketing atual: **1.0**.

```text
copyMemory/
  copyMemoryApp.swift          entrada; MenuBarExtra
  Models/ClipboardItem.swift   texto ou imagem
  Services/                    monitor, atalho, imagens, persistência
  Store/ClipboardStore.swift   histórico, busca, re-cópia
  Views/                       painel, linhas e estado vazio
```

Testes de domínio: scheme de testes no Xcode (**⌘U**).

Um push de tag `v*` (por exemplo `v1.0.0`) dispara o workflow de release, que compila, gera o DMG e publica o arquivo na release do GitHub.

Detalhes de produto e o checklist de implementação estão em [`docs/PRD.md`](docs/PRD.md) e [`docs/TASKS.md`](docs/TASKS.md).
