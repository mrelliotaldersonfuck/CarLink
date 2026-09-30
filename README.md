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

## Upload pelo GitHub.com

Abra o repositório `CarLink`, use **Add file → Upload files** e envie o conteúdo desta pasta preservando a estrutura. Faça o commit na branch `main`.

Depois vá em **Actions → Build CarLink**. O workflow também será executado automaticamente em novos pushes na `main`.

## Artefatos

- `CarLink-unsigned-ipa`: IPA não assinada.
- `CarLink-build-log`: log da compilação.

## CarPlay Video

Esta fase não inclui um entitlement CarPlay Video concedido pela Apple. Não foi colocado um entitlement falso. Quando tivermos uma equipe Apple Developer com a capacidade autorizada para o App ID do CarLink, a assinatura e a configuração correspondente poderão ser adicionadas ao pipeline.


## Menu de serviços
A tela inicial do CarLink agora oferece atalhos para YouTube, Netflix, Apple TV, Prime Video, Disney+, Google e um Navegador geral. Cada atalho abre o endereço no WKWebView do app.

## CarPlay
A camada CarPlay foi preparada com o mesmo conjunto de serviços usando templates nativos. A disponibilidade efetiva do app e de conteúdo web/vídeo no CarPlay depende das capacidades e entitlements autorizados pela Apple.


### Browser mode
CarLink uses a desktop Safari-like User-Agent by default to request desktop web experiences where supported. This does not bypass site DRM or service restrictions.


## Netflix media attempt 0.3.1

This build keeps the existing desktop Safari-like User-Agent and adds a targeted WebKit user script: when `ManagedMediaSource` exists but `MediaSource` does not, CarLink exposes the existing managed implementation under the `MediaSource` name before page scripts run. This is an experimental compatibility attempt and does not add DRM capabilities that WebKit does not provide.
