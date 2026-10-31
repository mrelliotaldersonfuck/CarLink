# Publicar a correção 45

1. Substitua os arquivos do GitHub pelo conteúdo atualizado desta pasta, mantendo codemagic.yaml na raiz.
2. Preserve a integração **CarLink**, grupo **carlink** e variável secreta CERTIFICATE_PRIVATE_KEY já existentes no Codemagic.
3. Selecione a branch atualizada e **CarLink TestFlight**, ID **carlink-validate**.
4. Clique **Start build**. A execução consulta o próximo número, testa, gera o projeto, prepara a assinatura, compila, verifica o IPA e envia ao TestFlight.
5. Confira o resultado em **Publishing → App Store Connect** e aguarde o processamento da Apple.

O próximo build será maior que o último publicado na versão 0.6.0, com mínimo **45**. O contador interno do Codemagic não determina a versão. CARLINK_BUILD_NUMBER é opcional e precisa ser pelo menos 45 e maior que o número consultado na Apple. Não publique dois builds simultaneamente.

Bundle **com.carlink.CarLink**, Apple ID **6819000403**, Xcode **27.1**. A assinatura usa fetch-signing-files --type IOS_APP_STORE --create e não exige importar perfis manualmente antes da execução.

## Entitlement

O executável solicita **com.apple.developer.carplay-audio** somente. O perfil pode conceder também vídeo; o verificador não rejeita um perfil mais amplo, mas rejeita vídeo na assinatura do executável. Isso impede repetir a configuração do build 44.

A publicação é somente no TestFlight, sem submissão de produção à App Store. Nenhum upload real foi executado no ambiente de preparação. A aceitação de recursos experimentais para distribuição externa depende da revisão aplicável da Apple.

Após instalar, siga [TESTE-45.md](TESTE-45.md). O primeiro resultado procurado é o retorno do ícone e do catálogo; vídeo continua sendo uma investigação separada.
