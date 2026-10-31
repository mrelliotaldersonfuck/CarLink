> Documento histórico. Para o pacote atual, use TESTE-45.md.

# Teste do CarLink 0.6.0 — build 42 ou superior

**Histórico do pacote anterior:** estas instruções descrevem a categoria Video do pacote base 42. A entrega atual é um comparativo com Audio; siga [TESTE-43.md](TESTE-43.md).

Esta entrega corrige a base oficial e adiciona um teste do YouTube no iPhone. Ainda não comprova vídeo na sua central.

## Publicar

Publique o conteúdo desta pasta na raiz do GitHub e inicie **CarLink TestFlight** no Codemagic. O workflow mantém o ID `carlink-validate`, a integração `CarLink`, o grupo `carlink`, o bundle `com.carlink.CarLink` e o Apple ID `6819000403`. O próximo número é consultado automaticamente; o mínimo agora é 42. Não publique duas execuções ao mesmo tempo.

## Mudança visível importante

O app assinado passa a solicitar **somente `com.apple.developer.carplay-video`**, seguindo o guia de outubro de 2026 e o esclarecimento da Apple para 27.2. O perfil pode autorizar capacidades adicionais; a assinatura do executável não combina Audio e Video.

Como seu teste anterior retornou suporte a vídeo falso, o ícone deste build pode ficar oculto na central. Isso é um resultado esperado da categoria Video nesse caso, não comprova falha de instalação ou de assinatura. O aplicativo e os testes continuam disponíveis no iPhone. A reprodução de áudio da mídia não depende de solicitar a categoria CarPlay Audio.

## A — mídia e saída nativas

Com o veículo estacionado:

1. Abra **Conexão → Reproduzir teste HLS da Apple**.
2. Confira primeiro se o vídeo aparece no próprio iPhone.
3. No player, use o seletor de saída se houver uma rota de vídeo da central.
4. Se o ícone CarLink aparecer na central, teste também iniciar o mesmo vídeo pela biblioteca da central.
5. Volte à aba Conexão. Observe separadamente: suporte de vídeo, mídia pronta, dimensões, tempo e saída externa AVPlayer.
6. Registre **Vi a imagem na central** ou **Não vi a imagem na central**. Toque em **Registrar estado agora** e compartilhe o diagnóstico.

Se apenas o áudio chegar ao carro, registre que a imagem não ficou visível. O nome CarPlay na saída de áudio não comprova saída de vídeo. Tempo avançando e dimensões conhecidas também não comprovam pixels na central.

## B — player YouTube

1. Abra a aba **YouTube** no iPhone.
2. Use **Exemplo** ou cole um link público de vídeo e toque em **Carregar vídeo**.
3. Toque no botão de reprodução dentro do próprio player. A reprodução automática não está habilitada.
4. Confirme a imagem no iPhone. Use os controles do YouTube para tela cheia, quando necessário.
5. Teste a rota de vídeo disponível no seletor de saída e confirme visualmente o resultado na central.
6. Registre o resultado na aba Conexão e compartilhe o diagnóstico.

O player oficial recebe a identificação do bundle pelo Referer/origem e usa a IFrame Player API. Não extrai endereços internos do YouTube, não transforma a página em uma URL AVPlayer, não converte o conteúdo em HLS e não coloca uma janela WebKit arbitrária na central. A saída AirPlay desse player para sua central permanece experimental.

Os eventos do YouTube mostram apenas o estado informado pelo player incorporado. A flag `isExternalPlaybackActive` pertence ao AVPlayer nativo e **não mede** a saída do WebKit/YouTube. Vídeos privados, removidos ou que não permitem incorporação podem falhar; o diagnóstico registra o código sem guardar a URL completa.

## Como interpretar

| Resultado | Próximo ponto a investigar |
|---|---|
| HLS falha também no iPhone | Acesso à mídia, rede ou player. |
| HLS toca no iPhone; suporte CarPlay falso | Compatibilidade/negociação da sessão. |
| HLS chega à central; YouTube não | Caminho de saída do player YouTube/WebKit. |
| Ambos ficam visíveis na central | Validar outros vídeos e continuidade da reprodução. |
| Ícone fica oculto após atualizar | Conferir suporte da sessão e a regra da categoria Video. |

Esses resultados não provam a função interna alterada no iOS. Se precisar comparar com o comportamento anterior, o build 41 pode ser selecionado em Builds anteriores no TestFlight enquanto estiver disponível.

## Fontes da implementação

- [Atualização dos entitlements para 27.2 — engenheiro da Apple](https://developer.apple.com/forums/thread/851377).
- [Acionamento e fallback de vídeo — engenheiro da Apple](https://developer.apple.com/forums/thread/831710).
- [Política LongFormVideo e configuração inicial — Apple](https://developer.apple.com/documentation/avfaudio/avaudiosession/routesharingpolicy-swift.enum/longformvideo).
- [API do player incorporado — YouTube](https://developers.google.com/youtube/iframe_api_reference).
- [Identificação do app e Referer — YouTube](https://developers.google.com/youtube/terms/required-minimum-functionality).
