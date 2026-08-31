# DeskWeave

**Transforme um tablet Android em uma tela estendida sem fio para o Mac.**

DeskWeave é um par experimental de aplicativos nativos e open source. O app do
macOS cria uma tela virtual, captura e codifica a imagem em H.264 de baixa
latência e transmite pela rede Wi‑Fi local. O app Android decodifica o vídeo por
hardware e o apresenta em tela cheia.

> [!IMPORTANT]
> O DeskWeave utiliza a API privada `CGVirtualDisplay`, pois a Apple não oferece
> uma API pública para criar uma tela virtual. Uma atualização do macOS pode
> interromper o funcionamento e o app não é adequado para a Mac App Store.

> [!WARNING]
> O protocolo atual não possui criptografia nem autenticação. Use somente em
> uma rede privada confiável e nunca exponha a porta TCP `5901` à internet.

[Read in English](README.md)

## Recursos

- desktop estendido real, não apenas espelhamento;
- tela virtual de 1792 × 1120 em até 60 fps;
- codificação H.264 por hardware com VideoToolbox;
- decodificação H.264 por hardware com MediaCodec;
- fila limitada para reduzir latência e recuperação por quadro-chave;
- descoberta automática dos endereços IPv4 locais;
- sem conta, nuvem, analytics ou telemetria.

## Requisitos

- Mac Apple Silicon com macOS 15 ou superior;
- tablet com Android 8 / API 26 ou superior;
- os dois dispositivos na mesma rede Wi‑Fi privada;
- permissão de Gravação da Tela e Rede Local no Mac.

## Compilação

No Mac:

```zsh
cd macOS/DeskWeaveMac
./build-app.sh
```

No Android:

```zsh
cd android/DeskWeaveAndroid
./gradlew assembleDebug
```

Consulte [BUILDING.md](docs/BUILDING.md) para os requisitos completos.

## Utilização

1. Abra o DeskWeave no Mac e clique em **Create second display**.
2. Autorize Gravação da Tela quando solicitado.
3. Abra o DeskWeave no tablet.
4. Digite um dos endereços exibidos no Mac, incluindo `:5901`.
5. Toque em **Connect**.
6. Organize a nova tela em **Ajustes do Sistema → Monitores**.

## Limitações

- esta versão pública oferece somente Wi‑Fi;
- sem áudio ou controle pelo toque;
- sem criptografia, autenticação ou pareamento;
- a tela virtual desaparece ao encerrar o app do Mac;
- utiliza API privada do macOS;
- o build local possui assinatura ad-hoc e não é notarizado.

Contribuições são bem-vindas. Leia [CONTRIBUTING.md](CONTRIBUTING.md) e
[SECURITY.md](SECURITY.md). O projeto utiliza a [licença MIT](LICENSE).
