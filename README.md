# CarLink 0.6.0

Base nova do CarLink preparada para GitHub -> Codemagic -> TestFlight.

## O que esta versão inclui

- Bundle ID `com.carlink.CarLink`.
- CarPlay Audio + CarPlay Video entitlements.
- `UIBackgroundModes = audio` para reprodução em background.
- `AVAudioSession` em `.playback / .moviePlayback`.
- Um único `AVPlayer` compartilhado pelo app.
- Publicação de Now Playing + controles play/pause do sistema.
- Navegador WKWebView no iPhone.
- Detector de `<video>` que aceita apenas URLs HTTP/HTTPS expostas pela página.
- Botão Preparar para enviar uma mídia compatível ao `AVPlayer`.
- Seletor nativo AirPlay/CarPlay (`AVRoutePickerView`) com rótulo "Ver no carro".
- Interface CarPlay baseada em `CPInterfaceController`/templates.
- Em iOS 27, `CPPlaybackConfiguration(preferredPresentation: .video)` para conteúdo preparado.
- Build do Codemagic com incremento automático a partir do último build do TestFlight.
- Verificação do provisioning profile para CarPlay Audio e Video antes do build.

## Importante sobre sites

O detector não quebra DRM nem extrai manifests privados. Ele só usa uma URL de mídia quando a própria página expõe um `video.currentSrc` ou `video.src` HTTP/HTTPS reproduzível pelo AVPlayer. Sites que usam MSE/blob/DRM podem não fornecer um stream utilizável por este mecanismo.

## Codemagic

O workflow espera:

- integração App Store Connect chamada `CarLink`;
- grupo de variáveis `carlink`;
- `CERTIFICATE_PRIVATE_KEY` dentro desse grupo;
- App Store Apple ID `6819000403`;
- Bundle ID `com.carlink.CarLink` com CarPlay Audio e CarPlay Video habilitados no Apple Developer.

O workflow usa Xcode 27.1.
