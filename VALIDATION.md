# Verificação — correção 45

Preparação em 31/10/2026, Windows sem Xcode/Swift.

## Verificado localmente

- Manifestos XML, configuração YAML e sintaxe Swift.
- Entitlement do fonte exatamente áudio somente; Info.plist identifica categoria audio e experimento window-45.
- Número mínimo atualizado para 45; fonte do build 44 preservado em pasta separada.
- Sete testes Python de numeração e seis testes Python da checagem de assinatura com ferramentas simuladas.
- O verificador rejeita a assinatura vídeo somente que ocultou o ícone, além de categorias combinadas, áudio ausente, perfil expirado e cena experimental ausente.
- Workflow, integração, grupo, bundle e Apple ID preservados; destino TestFlight somente.

## Execução preparada no Codemagic

Compilar o encoder de vídeo no Mac e decodificar 120 frames, executar os XCTest do núcleo, compilar iOS, arquivar, exportar, conferir assinatura real e enviar ao TestFlight.

## Pendente

Compilação iOS, teste AVFoundation, XCTest, assinatura, upload e execução no veículo não foram executados aqui. Voltar à categoria áudio busca recuperar a presença do catálogo observada no build 43; não demonstra reprodução de vídeo nem admissão da janela própria em 27.2.
