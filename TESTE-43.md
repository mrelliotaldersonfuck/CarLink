> Documento histórico. Para o pacote atual, use TESTE-45.md.

# Build comparativo: categoria CarPlay áudio

O pacote anterior (base 42) solicitava somente `com.apple.developer.carplay-video`. O usuário relatou que o ícone deixou de aparecer na central. Isso é coerente com a regra da categoria Video: aparecer apenas quando a sessão oferece suporte a vídeo. O log do build 41 já informava suporte falso.

Esta entrega solicita **somente `com.apple.developer.carplay-audio`**, para testar a apresentação do catálogo misto. A Apple esclarece que Audio atende serviços de áudio ou mistos de áudio e vídeo, enquanto Video se aplica à experiência voltada principalmente a vídeos e depende do suporte na sessão. Os dois não devem ser combinados conforme a atualização para 27.2.

[Resposta de engenheiro da Apple](https://developer.apple.com/forums/thread/851377).

## O que muda

- Categoria solicitada: Audio, sem Video no executável.
- O perfil pode continuar autorizando ambos. O verificador exige Audio e rejeita Video na assinatura final.
- Número de build automático, no mínimo 43.
- A tela Conexão e o diagnóstico identificam este teste como categoria áudio.

O player YouTube, o teste HLS, a preferência `.video` nos itens, a política `LongFormVideo` e o workflow de publicação permanecem. Não foi alterado nenhum componente de protocolo da central. O objetivo desta comparação é observar a presença do ícone e a conexão da cena do app.

## Publicar e testar

1. Coloque o conteúdo desta pasta na raiz do repositório e inicie **CarLink TestFlight** no Codemagic, como antes. Integração e credenciais não mudam.
2. Instale o novo build no TestFlight e abra o CarLink no iPhone.
3. Com o carro estacionado, desconecte e reconecte o CarPlay.
4. Confira o ícone na central. Se necessário, confira também Ajustes → Geral → CarPlay → seu carro → Personalizar, verificando se CarLink está habilitado.
5. Abra o app pela central e confira a biblioteca.
6. Execute o teste HLS. Na aba Conexão, registre separadamente se viu imagem na central, toque em Registrar estado agora e compartilhe o diagnóstico.
7. Depois teste YouTube → Exemplo no iPhone e a rota de saída disponível. O estado do AVPlayer não mede a saída YouTube/WebKit.

## Como interpretar

O ícone voltar confirma a apresentação do app nessa categoria; não confirma reprodução de vídeo. Se `supportsVideoPlayback` continuar falso, permanece pendente a negociação/capacidade de saída de vídeo. A mudança do entitlement não demonstra que a central passou a oferecer essa capacidade.

Se o ícone não voltar, o próximo dado útil é o número do build instalado e o diagnóstico do iPhone, junto com a presença ou ausência do app na tela Personalizar do CarPlay. A capacidade concedida na conta, o perfil que a autoriza e o entitlement efetivamente solicitado na assinatura são verificações distintas.

Este pacote é fonte para o próximo teste. Compilação, assinatura e upload reais serão feitos pelo Codemagic; a presença física na central precisa ser confirmada no aparelho.
