# CarLink 0.6.0 — correção do ícone, base 45

Este pacote corrige a categoria solicitada pelo build 44. Agora usa **CarPlay Audio somente**, como o build 43 que conectou na central do usuário. Bundle **com.carlink.CarLink**, iOS mínimo **18.0**, versão **0.6.0**, próximo build **45 ou superior**.

## Publicar

Substitua os arquivos do repositório pelo conteúdo desta pasta. codemagic.yaml, project.yml, CarLink/, Packages/ e scripts/ ficam na raiz. No Codemagic, selecione **CarLink TestFlight** e clique **Start build**.

Preservados: workflow **carlink-validate**, integração **CarLink**, grupo **carlink**, Apple ID **6819000403**, chave secreta já cadastrada e assinatura automática. O pacote não contém credenciais.

## Correção

O build 44 solicitava vídeo somente. A Apple documenta que apps dessa categoria aparecem apenas em sessões com suporte a vídeo. O teste anterior do usuário informou suporte falso; a ausência do ícone relatada é consistente com essa regra.

Este pacote volta à categoria áudio para recuperar o catálogo na central. Não combina áudio e vídeo. O verificador do IPA exige áudio no perfil e na assinatura e rejeita a assinatura de vídeo do pacote anterior, incluindo a combinação de categorias.

## O que permanece experimental

A declaração da cena própria e os testes de tela verde, vídeo local H.264 e YouTube independente permanecem disponíveis em **Conexão → Experimento de janela · 45**. O retorno do ícone é um resultado separado da criação da janela ou da reprodução de vídeo. A categoria áudio não garante acesso à cena própria e o sistema pode continuar sem entregá-la.

O player local gera um teste de oito segundos sem internet e sem áudio. O teste YouTube precisa de internet e toque no player da central. A reprodução pela janela exige confirmação manual de veículo estacionado, sem medição de velocidade, e para quando a cena fica inativa ou desconecta.

Não há transcodificação, relay CarPlay, métodos privados substituídos, extração de streams ou remoção de DRM. A biblioteca e o teste HLS nativo continuam como comparação.

Leia [PUBLICAR.md](PUBLICAR.md), [TESTE-45.md](TESTE-45.md) e [VALIDATION.md](VALIDATION.md). TESTE-42.md, TESTE-43.md, TESTE-44.md e FIX-1.md são históricos.

Fonte oficial: [categorias CarPlay no iOS 27.2](https://developer.apple.com/forums/thread/851377).
