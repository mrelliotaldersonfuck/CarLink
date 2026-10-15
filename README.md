# CarLink

CarLink é um projeto experimental de navegador iOS com uma camada separada para futura integração com CarPlay Video Apps.

## Fase 0.1

- Navegador `WKWebView` no iPhone.
- Página inicial em YouTube.
- Campo de endereço, voltar, avançar e recarregar.
- Cena CarPlay separada para prototipagem da integração.
- Build automática no GitHub Actions em um runner macOS.
- Geração de uma IPA **não assinada** para posterior assinatura/sideload.

## Estrutura

```text
CarLink/
├── .github/workflows/ios-build.yml
├── CarLink/
│   ├── Browser/
│   │   ├── BrowserView.swift
│   │   ├── BrowserViewModel.swift
│   │   └── WebView.swift
│   ├── CarPlay/
│   │   └── CarPlaySceneDelegate.swift
│   ├── Resources/
│   │   ├── ENTITLEMENT-NEXT-STEP.txt
│   │   └── Info.plist
│   ├── Shared/
│   │   ├── AppConfig.swift
│   │   └── AppDelegate.swift
│   └── CarLink.entitlements
├── Scripts/package-unsigned-ipa.sh
├── .gitignore
├── project.yml
└── README.md
```

## Build (Codemagic → TestFlight)

Suba o conteúdo desta pasta para o repositório `CarLink` no GitHub (preservando
a estrutura) e faça o commit na `main`. A build roda no **Codemagic** pelo
workflow `codemagic.yaml` (`carlink-testflight`): XcodeGen gera o projeto,
assina com os arquivos do App Store Connect e envia para o TestFlight.

## CarPlay Video

Esta fase não inclui um entitlement CarPlay Video concedido pela Apple. Não foi colocado um entitlement falso. Quando tivermos uma equipe Apple Developer com a capacidade autorizada para o App ID do CarLink, a assinatura e a configuração correspondente poderão ser adicionadas ao pipeline.


## Menu de serviços
A tela inicial do CarLink agora oferece atalhos para YouTube, Netflix, Apple TV, Prime Video, Disney+, Google e um Navegador geral. Cada atalho abre o endereço no WKWebView do app.

## CarPlay
A camada CarPlay foi preparada com o mesmo conjunto de serviços usando templates nativos. A disponibilidade efetiva do app e de conteúdo web/vídeo no CarPlay depende das capacidades e entitlements autorizados pela Apple.


### Browser mode
CarLink uses a desktop Safari-like User-Agent by default to request desktop web experiences where supported. This does not bypass site DRM or service restrictions.


## Netflix media update 0.3.8

This build keeps the existing desktop Safari-like User-Agent, preserves a single persistent `WKWebView` instance for browser session/cookie/playback state, enables inline/AirPlay/Picture-in-Picture media configuration before creating the web view, and removes the experimental script that mapped `MediaSource` to `ManagedMediaSource`.


### Desktop page mode
The browser configures `WKWebpagePreferences.preferredContentMode = .desktop` for the default page and each top-level navigation, in addition to the desktop Safari user agent.

## Netflix persistence update 0.3.9

This build strengthens the Netflix WebKit experiment by promoting the browser to one app-wide persistent `WKWebView` backed by a shared `WKProcessPool` and the default persistent `WKWebsiteDataStore`. The goal is to keep Netflix cookies, SPA state and FairPlay/EME playback state alive across SwiftUI view recreation and service navigation. It also keeps desktop page mode and the desktop Safari-like User-Agent by default, while continuing to avoid any `MediaSource`/`ManagedMediaSource` API replacement.



## Netflix WebKit compatibility update 0.4.0

Earlier testing showed that Netflix reached the watch page with the desktop Safari identity, but `MediaSource` was absent while `ManagedMediaSource` was available. This build keeps the app-wide persistent `WKWebView` from 0.3.9 and restores a minimal WebKit compatibility bridge: when, and only when, `window.MediaSource` is missing and `window.ManagedMediaSource` exists, CarLink exposes `ManagedMediaSource` through `window.MediaSource` before page scripts run. This is intended to let Netflix create its player under the desktop Safari identity without replacing a native `MediaSource` implementation when one is already present.


## Netflix foreground/media update 0.4.1

This build keeps the 0.4.0 MediaSource bridge and adds a conservative foreground compatibility layer at document start. Earlier iPhone testing showed `document.hidden=true`, `visibilityState=hidden` and `hasFocus=false` while no media elements were created. This build exposes the page to scripts as visible/focused and prepares dynamically created video/audio tags for inline playback, while preserving the app-wide persistent WKWebView, desktop content mode and desktop Safari-like User-Agent.

## Netflix iPad desktop environment update 0.4.2

This build keeps the 0.4.1 persistent WKWebView, foreground compatibility layer and MediaSource bridge, then changes the default desktop identity to the iPadOS desktop-style Safari User-Agent. It also presents tablet-sized screen/viewport metrics to page scripts at document start so Netflix no longer sees a Mac Safari identity combined with a narrow iPhone viewport. This is intended to test the closest configurable environment to iPad Safari desktop mode while still running inside CarLink on iPhone.


## Netflix Mac identity + tablet metrics update 0.4.3

The 0.4.2 iPadOS-style User-Agent was rejected by Netflix and redirected to `/unsupported`. This build keeps the useful tablet viewport/screen compatibility layer from 0.4.2, but restores the full macOS Safari desktop User-Agent that previously reached Netflix `/watch`. The goal is to combine the accepted desktop identity with the larger tablet-style viewport, persistent WKWebView, visible/focused document layer, MediaSource bridge, and iPhone media playback configuration.


## 0.4.4 Clean CarPlay Audio

This build removes the in-app diagnostics/log screen, disables WebView inspection for release builds, and declares the CarPlay Audio entitlement in `CarLink/CarLink.entitlements`. The app still requires the matching Apple Developer managed capability and a provisioning profile containing `com.apple.developer.carplay-audio` before TestFlight/App Store distribution.


## App ID / Bundle Identifier

Configured bundle identifier: `com.carlink.CarLink`. Use the same App ID in Apple Developer and regenerate the provisioning profile with the CarPlay Audio entitlement enabled.


## 0.4.5 — CarPlay Video / HLS Test (build 13)

- Added **Apple-documented** `com.apple.developer.carplay-video` entitlement in
  addition to the existing `com.apple.developer.carplay-audio` entitlement.
- Added native sample HLS playback via `AVPlayer`, AirPlay enabled, and Now Playing
  metadata. It uses a public Apple developer test stream, not Netflix DRM.
- Added the **Vídeo teste** tile on iPhone and on CarPlay. On iOS 27, CarPlay
  checks `CPSessionConfiguration.supportsVideoPlayback` and offers a video
  playback-configured `CPListItem` only in compatible vehicles.
- Video availability follows the car's parked/driving policy. If video becomes
  unavailable, the system may use audio-only playback.
- Pins Codemagic to **Xcode 27.1** for new CarPlay APIs, preserves the prior
  TestFlight signing workflow, and verifies the video entitlement in the App Store
  provisioning profile when it is present in the standard build paths.
- It is **not** generic website mirroring and does not make Netflix work.

**Before building:** Enable the CarPlay Video managed capability on Apple Developer
for `com.carlink.CarLink`, regenerate its App Store distribution provisioning
profile, then upload this project to GitHub and start a new Codemagic build.
The `fetch-signing-files --create` option can reuse existing profiles; if an
old profile is selected, revoke/delete and recreate the *old provisioning
profile* (not the distribution certificate) from Apple Developer.

**Note:** This ZIP is a source package for Codemagic; an IPA cannot be generated
or tested against the Apple iOS SDK on a Linux machine.


## 0.4.6 — Navegador próprio + UI responsiva (build 14)

Foco: um navegador de verdade no iPhone, tela inicial sem scroll e CarPlay responsivo.

### iPhone
- **Tela inicial adaptativa:** grade que calcula colunas/linhas pelo tamanho da
  tela e encaixa todos os atalhos **sem scroll**, em retrato e paisagem. Tema
  escuro. Campo de busca que abre o navegador já pesquisando no Google ou indo
  direto ao endereço.
- **Navegador próprio, responsivo e com abas:**
  - Barra de endereço que foca e abre o teclado ao tocar; busca ou URL.
  - Barra de progresso real (KVO de `estimatedProgress`), voltar/avançar,
    recarregar/parar, favoritar, alternar iPhone/desktop e gerenciador de abas.
  - **Player do próprio site:** `isElementFullscreenEnabled = true` +
    `allowsInlineMediaPlayback` fazem o YouTube (e outros) abrirem em tela cheia
    no player da própria página, com **seletor de qualidade**, em vez do player
    nativo do iOS. Identidade móvel por padrão (layout responsivo), com botão
    para alternar para desktop por aba.
  - **Botão AirPlay** na barra para enviar o vídeo ao painel do carro.
  - Sessão persistente (cookies/login) via `WKProcessPool` + data store padrão.
  - Ponte de compatibilidade do Netflix reduzida e restrita a `netflix.com`.

### CarPlay (templates oficiais)
- **Ícones que se adaptam a cada tela:** SF Symbols renderizados na escala do
  `carTraitCollection`, com variantes claro/escuro, e reconstruídos quando o
  tema do carro muda.
- **Recentes e Favoritos** espelham o que você navega no iPhone (loja
  compartilhada), para retomar no carro.
- **Sem alertas vazios:** cada toque leva a uma lista ou a um aviso legível.
- **Vídeos:** quando o veículo informa `supportsVideoPlayback` (iOS 27), um item
  de vídeo HLS toca no painel via AVPlayer/AirPlay (apenas estacionado).

### Por que o navegador não roda na tela do carro
O CarPlay só renderiza os templates do sistema (grade, lista, Tocando Agora);
não existe API pública para exibir um `WKWebView` ou vídeo web na tela do carro.
Apps que fazem isso usam caminhos fora das regras da Apple, que não passam pela
assinatura/TestFlight deste pipeline. Por isso o navegador fica no iPhone e o
vídeo chega ao painel por **AirPlay** (o caminho oficial do iOS 27).

### Assinatura / entitlements
`CarLink.entitlements` pede só **CarPlay Audio** por enquanto, para a build
passar com seu perfil atual. Quando a Apple aprovar **CarPlay Video**, siga
`CarLink/Resources/ENTITLEMENT-NEXT-STEP.txt` para religar o entitlement.

### Codemagic
`xcode: "27.0"` (versão disponível no Codemagic; 27.1 ainda não existe lá). A
checagem de entitlement virou informativa e não quebra mais a build.
