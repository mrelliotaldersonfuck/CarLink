# Testar a correção do ícone — build 45 ou superior

## Primeiro: recuperar o catálogo

1. No TestFlight, instale o build novo, com número pelo menos 45. Confira o número em **Conexão** no app.
2. Abra o CarLink no iPhone e conecte o CarPlay com o carro estacionado.
3. Procure **CarLink** na tela inicial da central e abra-o.
4. No iPhone, toque **Conexão → Diagnóstico → Registrar estado agora** e depois **Compartilhar diagnóstico**.

O cabeçalho deve informar **Categoria declarada no build: audio** e **Experimento: window-45**. Os eventos devem registrar a conexão da cena de templates quando o app for aberto na central. A assinatura real também é conferida no Codemagic antes do envio.

Se não encontrar o ícone após atualizar, verifique no iPhone **Ajustes → Geral → CarPlay → seu carro → Personalizar** se CarLink está disponível para adicionar. Reconecte depois da alteração. Se continuar ausente, compartilhe o diagnóstico e informe o número instalado; isso requer investigar além da categoria.

## Depois: janela e vídeo

Abra **Conexão → Experimento de janela · 45**. O app mantém a tentativa de uma janela própria, mas restaurar o ícone não concede essa janela.

- Toque **Atualizar cenas e diagnóstico**, depois **1. Mostrar tela verde na central**. Procure **JANELA CARLINK 45** na central.
- Se a janela estiver conectada e ativa, confirme **Veículo estacionado · habilitar testes** e toque **2. Reproduzir vídeo local na janela**. Procure a barra branca em movimento sobre três faixas coloridas, repetindo em oito segundos. Não depende de internet.
- Só após confirmar a superfície, use **3. Abrir YouTube na janela** e toque em reproduzir no player da central. O YouTube exige internet e permissão de incorporação do vídeo.
- Registre separadamente o resultado visual usando os botões do app e compartilhe o diagnóstico.

Se a janela não chegar, o comando registra que o iOS não entregou a cena. Isso não é sucesso de vídeo. supportsVideoPlayback falso continua descrevendo a capacidade nativa da sessão. Layer pronto ou contador avançando não comprovam imagem na central.

O teste HLS da Apple e o campo YouTube do iPhone são separados dos players da janela. Os eventos recentes são preservados após reiniciar, mas os estados atuais podem não representar uma execução anterior.
