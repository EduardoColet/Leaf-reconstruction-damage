# LeafScope — Documentação completa das mudanças

> Este documento descreve, passo a passo, tudo o que foi feito no app LeafScope durante a migração do pipeline de processamento de imagem do pacote `image` (Dart puro) para `opencv_dart` (bindings nativos do OpenCV4 via FFI). Ele mistura explicações técnicas com analogias para que tanto desenvolvedores quanto pessoas sem familiaridade com processamento de imagens consigam entender o que mudou e *por quê*.

---

## 1. Contexto: o que o app faz

O **LeafScope** mede o quanto uma folha de planta foi "comida" ou danificada. O usuário tira uma foto da folha sobre um fundo neutro (papel branco, mesa, etc.) e o app responde com um número: "essa folha tem 23% de dano". O cálculo todo acontece **dentro do celular** — não há servidor, não há internet, não há inteligência artificial. É processamento clássico de imagem, o que torna o app rápido, privado e funcional sem conexão.

A ideia central é geométrica: se você conseguir desenhar a "forma original" da folha (como ela seria sem nenhum dano) e comparar com a folha real, a diferença é o dano. Para reconstruir essa forma original o app usa um algoritmo chamado **Convex Hull** (envoltória convexa).

### O que é Convex Hull, em palavras simples

Imagine que você crava pregos em uma tábua nos pontos de borda da folha e estica um elástico ao redor de todos eles. O formato que o elástico toma — esticado e sem dobrar para dentro — é o convex hull. É o **menor polígono convexo** que envolve todos os pontos. Para uma folha mordiscada nas bordas, o convex hull "preenche" as mordidas e gera uma aproximação razoável de como a folha era inteira.

Áreas:

- `area_total` = área do polígono do convex hull (folha "reconstruída")
- `area_real` = área da folha que ainda está visível
- `dano = area_total - area_real`
- `dano_percentual = dano / area_total × 100`

---

## 2. A grande migração: de `image` para `opencv_dart`

### Como estava antes

O pipeline original usava o pacote [`image`](https://pub.dev/packages/image), uma biblioteca **escrita 100% em Dart puro** (a linguagem do Flutter). Vantagem: roda em qualquer plataforma sem código nativo. Desvantagem: o pacote é muito básico — ele sabe ler/salvar PNG, redimensionar, aplicar blur, mas **não tem nenhuma das operações sofisticadas** que o pipeline precisa: conversão HSV, threshold de Otsu, operações morfológicas, detecção de contornos, convex hull, etc.

Resultado: o arquivo original `image_processing_datasource.dart` tinha **620 linhas** porque tudo isso foi implementado **na mão**, em Dart puro:

- Conversão RGB → HSV pixel a pixel
- Erosão/dilatação morfológica em loops aninhados
- Algoritmo de busca em largura (BFS) para encontrar componentes conectados
- Algoritmo de Graham Scan implementado do zero para o convex hull
- Cálculo de área via fórmula do shoelace
- Bresenham para desenhar linhas
- Scanline polygon fill

Funcionava, mas era frágil, lento e difícil de defender academicamente — o orientador (Prof. Rafael Rieder) pediu para usar **uma biblioteca consolidada de visão computacional**.

### Por que `opencv_dart`?

**OpenCV** (Open Source Computer Vision Library) é a biblioteca de visão computacional mais usada do mundo, escrita em C++ e otimizada há mais de 20 anos. Ela tem implementações testadíssimas de tudo que o LeafScope precisa: `cv.cvtColor`, `cv.threshold`, `cv.morphologyEx`, `cv.findContours`, `cv.convexHull`, `cv.contourArea`, `cv.drawContours`, etc.

O pacote [`opencv_dart`](https://pub.dev/packages/opencv_dart) é um *binding* — uma "ponte" — que permite o Flutter chamar essas funções nativas em C++. Ele faz isso através de **FFI** (*Foreign Function Interface*), um mecanismo do Dart que permite executar código de bibliotecas em C/C++ diretamente. Quando você escreve `cv.findContours(...)` em Dart, o `opencv_dart` traduz isso em uma chamada de função nativa que executa código C++ compilado.

### Vantagens da migração

1. **Robustez**: as 620 linhas viraram cerca de 270, e a lógica complexa é executada por código testado e usado em milhões de aplicações reais
2. **Velocidade**: C++ otimizado é muito mais rápido que loops em Dart interpretado/compilado AOT
3. **Defesa acadêmica**: poder dizer "o pipeline usa OpenCV" é incomparavelmente mais forte do que "implementei tudo na mão" em um TCC
4. **Funcionalidades extras**: agora dá para usar coisas como `RETR_CCOMP` (hierarquia de contornos) e `convexityDefects` que seriam pesadelos de implementar manualmente

### Custo: dependências nativas

Como `opencv_dart` chama código C++, ele **só funciona em plataformas que suportam FFI** — Android, iOS, Windows, Linux, macOS. **Não funciona em Flutter Web**, porque o navegador não consegue executar bibliotecas nativas (web roda sobre JavaScript/WebAssembly e não tem `dart:ffi`). Esse detalhe causou um problema que vamos resolver mais adiante.

Outra exigência: no Android, o `opencv_dart` precisa de **API mínima 24** (Android 7.0 Nougat). O projeto usava o padrão do Flutter (~21), então tivemos que **bumpar o `minSdk` para 24** em `android/app/build.gradle.kts`.

---

## 3. Arquitetura preservada: por que tudo continua igual

O LeafScope segue **Clean Architecture**, um padrão de organização de código que separa responsabilidades em camadas:

```
View (UI)
   ↓ chama
BLoC (gerenciador de estado)
   ↓ chama
Service (regras de negócio)
   ↓ chama
Repository (interface abstrata de dados)
   ↓ chama
DataSource (implementação concreta)
```

Cada camada **só conhece a camada imediatamente abaixo** (e através de uma interface, não da implementação). Isso permite trocar a implementação de baixo sem afetar nada acima. É exatamente o que aconteceu na migração: substituímos o **DataSource inteiro** (a camada mais baixa, que faz o processamento real) e **nenhuma outra camada precisou mudar**:

- `analysis_repository.dart` — não mexido
- `analysis_service.dart` — não mexido
- `analysis_bloc.dart` / events / states — não mexidos
- Módulos `home`, `capture`, `history`, `test_gallery` — não mexidos
- Injeção de dependência (`injection_container.dart`) — não mexida

Isso é a *prova prática* de por que arquitetura em camadas vale a pena: uma mudança massiva (trocar a biblioteca de processamento) ficou contida em **um único arquivo**.

---

## 4. O pipeline novo, etapa por etapa

O processamento todo está em `lib/modules/analysis/datasource/image_processing_datasource_native.dart`, na função top-level `_runOpenCvPipeline`. Vou explicar cada etapa.

### Etapa 1 — Decodificar a imagem

```dart
originalBgr = cv.imdecode(imageBytes, cv.IMREAD_COLOR);
```

A foto chega como uma sequência de bytes (`Uint8List`) — basicamente um arquivo JPEG/PNG na memória. `imdecode` lê esses bytes e devolve uma **Mat** (matriz), a estrutura de dados central do OpenCV. Uma Mat é uma matriz de pixels onde cada pixel tem 3 valores: azul, verde e vermelho (BGR — note que OpenCV usa essa ordem invertida em vez de RGB, por razões históricas).

**Analogia:** decodificar é como abrir um arquivo `.zip` — você sai da forma comprimida (bytes) para a forma editável (matriz de pixels).

### Etapa 2 — Redimensionar

```dart
resized = cv.resize(originalBgr, (dstW, dstH));
```

Se a foto tem mais de 800 pixels de largura, ela é reduzida para 800 mantendo a proporção. Por quê? Performance: processar uma imagem de 4000×3000 pixels (12 milhões de pixels) é 25× mais lento do que processar 800×600 (480 mil pixels), e para detectar uma folha **a precisão extra é desnecessária**. Você não precisa enxergar fios de cabelo na superfície da folha para saber se ela tem 30% ou 50% de dano.

### Etapa 3 — Converter BGR para HSV

```dart
hsv = cv.cvtColor(resized, cv.COLOR_BGR2HSV);
```

Aqui mora um conceito importante. O computador "vê" cores como combinações de **vermelho + verde + azul** (RGB ou BGR), mas isso é péssimo para *encontrar* algo verde, porque "verde" não é só "muito no canal verde" — depende de iluminação, sombra, etc.

**HSV** (Hue, Saturation, Value) é um espaço de cor mais intuitivo:

- **H (matiz)**: a cor pura (0° = vermelho, 60° = amarelo, 120° = verde, 240° = azul, 360° = vermelho de novo). É um círculo.
- **S (saturação)**: o quanto a cor é "pura" vs "lavada/cinza" (0 = cinza, 255 = cor vibrante)
- **V (valor)**: o quanto é claro ou escuro (0 = preto, 255 = brilhante)

**Por que isso importa**: em HSV, "verde" é simplesmente "H entre tal e tal valor" — independente de a folha estar à sombra (V baixo) ou ao sol (V alto). Em RGB, uma folha sob sombra tem valores totalmente diferentes de uma folha ensolarada, mesmo sendo a mesma cor "verde".

**Detalhe técnico**: o OpenCV usa **H em escala 0–179** (não 0–359°), porque cabe em 1 byte. Verde fica em torno de H = 60.

### Etapa 4 — Threshold por faixa de verde

```dart
mask = cv.inRangebyScalar(
  hsv,
  cv.Scalar(30, 40, 40),     // limites mínimos: H=30, S=40, V=40
  cv.Scalar(90, 255, 255),   // limites máximos: H=90, S=255, V=255
);
```

`inRange` percorre cada pixel da imagem HSV e marca como **branco (255)** se os 3 canais estão dentro da faixa, ou **preto (0)** se não estão. O resultado é uma **máscara binária** — uma imagem só de preto e branco — onde branco = "isso parece verde" (provavelmente folha) e preto = "isso é fundo".

A faixa escolhida:

- H ∈ [30, 90] → cobre desde verde-amarelado até verde-azulado (na escala 0–179 do OpenCV)
- S ≥ 40 → exclui cinzas (pixels muito dessaturados, que são fundo neutro)
- V ≥ 40 → exclui pixels muito escuros (sombras profundas, regiões fora de foco)

**Analogia:** é como passar um destacador amarelo só nas partes verdes da foto.

### Etapa 5 — Limpeza morfológica

```dart
kernelClose = cv.getStructuringElement(cv.MORPH_RECT, (3, 3));
kernelOpen  = cv.getStructuringElement(cv.MORPH_RECT, (3, 3));
closed  = cv.morphologyEx(mask, cv.MORPH_CLOSE, kernelClose);
cleaned = cv.morphologyEx(closed, cv.MORPH_OPEN, kernelOpen);
```

**Operações morfológicas** são manipulações geométricas em máscaras binárias. As duas que importam aqui:

- **Closing** (`MORPH_CLOSE`): primeiro dilata (engorda regiões brancas), depois erode (afina). O efeito líquido é **fechar pequenos buracos** dentro de regiões brancas e suavizar bordas. Se o threshold deixou alguns "furinhos" em pixels da folha por causa de veias mais escuras, o closing tampa.
- **Opening** (`MORPH_OPEN`): primeiro erode, depois dilata. O efeito líquido é **remover pequenas manchas brancas isoladas** ("sal e pimenta"). Se o fundo tinha algumas folhinhas pequenas ou ruído verde, o opening apaga.

O **kernel** é uma pequena matriz (aqui 3×3) que define a "vizinhança" usada nessas operações. Quanto maior o kernel, mais agressivo o efeito.

**Decisão importante**: o kernel do CLOSE é **3×3** (não 5×5 como antes). Isso é deliberado e crítico — explico no item 5 (bug do `contourArea`).

### Etapa 6 — Encontrar a folha (maior contorno)

```dart
final (externalContours, externalHierarchy) =
    cv.findContours(cleaned, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_SIMPLE);
```

`findContours` percorre a máscara e identifica **contornos** — sequências de pontos que formam o limite de cada região branca. Pense nisso como pegar o contorno de cada "ilha branca" no mapa.

- `RETR_EXTERNAL` = só me devolva os contornos **externos** (ignore buracos dentro deles, por enquanto)
- `CHAIN_APPROX_SIMPLE` = não me devolva todos os pontos do contorno; comprima trechos retos guardando só os vértices (economiza memória)

Como pode haver várias regiões verdes na imagem (folhinhas no fundo, cabo de tesoura verde, etc.), pegamos a **maior** delas — aquela com a maior área é, presumidamente, a folha de interesse:

```dart
for (int i = 0; i < externalContours.length; i++) {
  final c = externalContours[i];
  final a = cv.contourArea(c);
  if (a > leafOuterArea) {
    leafOuterArea = a;
    leafIdx = i;
  }
}
```

Aqui `cv.contourArea` calcula a área do polígono usando a **fórmula do shoelace** (cadarço de sapato) — uma fórmula matemática que dá a área de qualquer polígono dadas as coordenadas dos seus vértices.

### Etapa 7 — Construir uma máscara só da folha selecionada

```dart
final leafMask = cv.Mat.zeros(cleaned.rows, cleaned.cols, cv.MatType.CV_8UC1);
cv.drawContours(leafMask, leafAsVecVecForMask, 0, cv.Scalar.all(255), thickness: -1);
final intersected = cv.bitwiseAND(leafMask, cleaned);
cleaned.dispose();
cleaned = intersected.clone();
```

Esse é um passo novo, adicionado para resolver o bug dos buracos (próxima seção). O que ele faz:

1. Cria uma nova Mat preta do mesmo tamanho
2. Desenha o contorno da folha nela, **preenchido com branco** (`thickness: -1` significa "preenchido")
3. Faz um **AND lógico** entre essa máscara e a `cleaned` original

O resultado: uma máscara que é branca **apenas dentro do contorno externo da folha selecionada**, e preta nos buracos internos da folha *e* fora da folha. Qualquer outro objeto verde que tivesse passado pelo threshold é descartado.

**Por que `bitwiseAND`?** AND bit a bit significa "branco só onde **as duas** máscaras são brancas". Como `leafMask` é toda preta fora da folha, qualquer ruído verde fora dela é zerado. E como `cleaned` tem buracos pretos onde está o dano interno, esses buracos continuam pretos.

### Etapa 8 — Calcular a área real (corretamente)

```dart
final realArea = cv.countNonZero(cleaned).toDouble();
```

`countNonZero` simplesmente conta quantos pixels brancos existem na máscara. Como a máscara agora representa exatamente "pixels visíveis da folha, sem buracos", esse número é **o que de fato está verde na imagem**. Esse era o bug crítico — explico na próxima seção.

### Etapa 9 — Convex Hull

```dart
hullMat = cv.convexHull(leafContour);
hullPoints = cv.VecPoint.fromMat(hullMat);
final totalArea = cv.contourArea(hullPoints);
```

`convexHull` recebe os pontos do contorno externo da folha e devolve os pontos do polígono do convex hull (o "elástico esticado"). O algoritmo interno do OpenCV é o de **Sklansky** ou variante, executado em O(n log n). Em seguida calculamos a área desse polígono — essa é a `area_total`, ou seja, a área da folha **como ela seria se estivesse inteira**.

### Etapa 10 — Detectar buracos internos

```dart
final (ccompContours, ccompHierarchy) =
    cv.findContours(cleaned, cv.RETR_CCOMP, cv.CHAIN_APPROX_SIMPLE);

for (int i = 0; i < ccompContours.length; i++) {
  final parent = ccompHierarchy[i].val4;
  if (parent == -1) continue;
  // ... este é um buraco
  holeArea += cv.contourArea(ccompContours[i]);
}
```

Segunda passagem do `findContours`, agora com `RETR_CCOMP`. Isso devolve uma **hierarquia de 2 níveis**:

- Nível 0: contornos externos (a folha em si)
- Nível 1: contornos *dentro* dos externos (os buracos)

A hierarquia vem como `Vec4i` para cada contorno, com 4 valores: `[next, prev, first_child, parent]`. Para saber se um contorno é um buraco, basta checar se ele tem **um pai** (`parent != -1`). Se sim, é um buraco interno.

Cada buraco identificado contribui sua área para `holeArea` — métrica separada que aparece nas Métricas para o usuário ver.

### Etapa 11 — Gerar as imagens de saída

**Imagem segmentada** (mostra só a folha, fundo preto):

```dart
segmentedMat = cv.bitwiseAND(resized, resized, mask: cleaned);
```

`bitwiseAND` da imagem original consigo mesma usando a máscara da folha como filtro: onde a máscara é branca, mantém a cor original; onde é preta, fica preto. Resultado: a folha com cores originais sobre fundo preto.

**Imagem reconstruída** (mostra a folha, os buracos pintados, e o hull desenhado):

```dart
reconstructedMat = resized.clone();
// 1. Pinta cada buraco em laranja
cv.drawContours(reconstructedMat, holeAsVecVec, 0, cv.Scalar.fromRgb(255, 140, 0), thickness: -1);
// 2. Desenha contorno verde da folha real
cv.drawContours(reconstructedMat, leafAsVecVec, 0, cv.Scalar.fromRgb(0, 200, 0), thickness: 2);
// 3. Desenha polígono vermelho do convex hull
cv.polylines(reconstructedMat, hullAsVecVec, true, cv.Scalar.fromRgb(255, 0, 0), thickness: 2);
```

A ordem importa: primeiro os buracos preenchidos (no fundo), depois o contorno verde da folha (em cima dos buracos), depois o hull vermelho (em cima de tudo). O `thickness: -1` no `drawContours` é o código para "preenchido" (em vez de só a borda).

Por fim, encodamos as duas imagens como PNG via `cv.imencode('.png', ...)` que devolve os bytes prontos para serem exibidos pelo `Image.memory` do Flutter.

---

## 5. O bug do `contourArea` e por que `countNonZero` resolveu

Esse é o ponto mais importante tecnicamente — e é o que explica por que os buracos internos não eram detectados na versão anterior.

### Como estava errado

A versão original calculava:

```dart
final realArea = cv.contourArea(leafContour);
```

Onde `leafContour` é o contorno **externo** da folha. O problema é que `cv.contourArea` recebe uma sequência de pontos (vértices de um polígono) e calcula a área desse polígono usando a fórmula do shoelace. Ela **não tem como saber** se há buracos dentro do polígono, porque ela só recebe os pontos da borda externa — os buracos não estão nesses pontos.

**Exemplo numérico**: imagine uma folha com:

- Borda externa que delimita uma área de 1000 px²
- Dois buracos internos com 60 px² e 90 px² (total 150 px² de furos)
- Verdadeira área visível da folha: 1000 - 150 = **850 px²**

Com `contourArea(leafContour)`:

- `realArea = 1000` ❌ (errado — está contando os buracos como se fossem folha)
- `damagedArea = totalArea - realArea` só conta as **mordidas nas bordas**, ignorando os 150 px² dos furos

Resultado prático: o número de "% de dano" subestimava o dano real, porque pulava completamente os furos no meio da folha.

### Por que `countNonZero` é a solução canônica

`cv.countNonZero(mask)` percorre todos os pixels de uma máscara binária e conta quantos são diferentes de zero (brancos). Ela não opera sobre vértices de polígono — opera sobre **pixels**. Se um pixel é branco, conta. Se é preto (porque tem um buraco ali), não conta. **Simples e exato.**

A combinação que aplicamos:

1. Construímos uma máscara da folha selecionada (`drawContours` preenchido)
2. Fazemos `bitwiseAND` com a máscara morfológica (que tem buracos pretos no lugar do dano interno)
3. Resultado: máscara branca *exatamente* nos pixels visíveis da folha
4. `countNonZero` dessa máscara = **área real verdadeira**

### O outro problema: closing apagava buracos pequenos

Antes, o kernel do `MORPH_CLOSE` era 5×5. Closing **fecha buracos** com diâmetro até aproximadamente o tamanho do kernel. Então:

- Buraco com 4 pixels de diâmetro → fechado pelo CLOSE → invisível para o `findContours` → não conta
- Buraco com 8 pixels de diâmetro → sobrevive → detectado

Reduzimos para **3×3**, que ainda é suficiente para suavizar ruído de uma ou duas-pixel mas preserva quase qualquer buraco real visível pelo usuário.

### Resultado depois da correção

- `realArea` = pixels verdadeiramente visíveis da folha (sem buracos)
- `damagedArea = totalArea - realArea` agora inclui **automaticamente** tanto o dano nas bordas quanto os buracos internos (porque `realArea` ficou menor)
- `holeArea` continua existindo como métrica separada para o usuário ver "quanto do dano é furo interno e quanto é mordida na borda"
- Os buracos são **desenhados em laranja** na imagem reconstruída para feedback visual

---

## 6. Por que o processamento roda em um Isolate

```dart
final result = await Isolate.run(() => _runOpenCvPipeline(imageBytes));
```

### O problema: a UI pode travar

Flutter, como a maioria dos frameworks de UI, executa código em uma **única thread principal** (a UI thread). Tudo acontece nela: desenhar a tela a 60 frames por segundo, responder a toques, animar transições. Se você fizer uma operação demorada (digamos, 800 ms para processar uma imagem) **na UI thread**, a tela congela durante esses 800 ms — botões não respondem, animações travam, o usuário acha que o app crashou.

### A solução: outro "trabalhador"

Um **Isolate** é o equivalente Dart de uma thread separada — mas com uma diferença crucial: isolates **não compartilham memória**. Cada isolate tem seu próprio espaço de memória, e a comunicação entre eles acontece por troca de mensagens (que são copiadas, não referenciadas).

`Isolate.run` (introduzido em Dart 3) é a forma mais simples: ele cria um isolate temporário, executa a função, devolve o resultado, e descarta o isolate. A função top-level `_runOpenCvPipeline` é executada lá dentro, enquanto a UI thread fica livre para mostrar o spinner de loading.

### Detalhe técnico: por que Mat objects não cruzam isolates

As Mat do OpenCV são alocadas em **memória nativa** (fora do heap do Dart, gerenciada pelo C++). O Dart não consegue serializar essas estruturas para enviar entre isolates, então o que cruza a fronteira são **apenas valores primitivos**: bytes (`Uint8List`), números, strings, listas, mapas.

Por isso o pipeline foi desenhado assim:

1. Isolate principal (UI) envia para o isolate de trabalho: `Uint8List` da imagem
2. Isolate de trabalho cria as Mat, executa todo o pipeline OpenCV, e ao final **encoda as imagens de volta para PNG bytes**
3. Devolve um objeto `_PipelineResult` com: `segmentedBytes`, `reconstructedBytes` (ambos `Uint8List`) e os números (`realArea`, `totalArea`, `holeArea`)
4. O isolate principal recebe esses dados sendable, monta o `LeafAnalysisModel` e atualiza a UI

Todas as Mat criadas dentro do isolate são liberadas em blocos `try/finally` para **evitar vazamentos de memória nativa via FFI**. Isso é crucial: como o Dart Garbage Collector não conhece a memória nativa, se você esquecer de chamar `.dispose()` em uma Mat, esses bytes ficam alocados para sempre (até o app fechar). Em loops de processamento isso vira um crash por falta de memória.

---

## 7. O problema do Web e a separação em 3 arquivos

Quando tentamos rodar o app no Chrome, ele compilou mas deu erro:

> *Dart library 'dart:ffi' is not available on this platform*

Isso aconteceu porque o `opencv_dart` importa `dart:ffi` para chamar o código nativo, e **Flutter Web não tem `dart:ffi`** — o navegador não consegue executar bibliotecas C++.

### A solução: conditional imports

Dart suporta uma sintaxe especial chamada **conditional imports** que permite importar diferentes arquivos dependendo da plataforma:

```dart
// image_processing_datasource.dart (barrel)
export 'image_processing_datasource_base.dart';
export 'image_processing_datasource_stub.dart'
    if (dart.library.io) 'image_processing_datasource_native.dart';
```

Como ler isso:

- Sempre exporta o `_base.dart` (interface abstrata, sem nada nativo)
- Se a plataforma tem `dart:io` disponível (= Android, iOS, Windows, Linux, macOS), exporta o `_native.dart` (implementação OpenCV)
- Caso contrário (= Web), exporta o `_stub.dart` (uma implementação que retorna erro amigável)

A construção `dart.library.io` é uma **condição de compilação**: o compilador Dart decide qual arquivo incluir no momento de buildar, então no Web o arquivo `_native.dart` **nem é compilado** — `opencv_dart` e `dart:ffi` simplesmente não fazem parte do bundle web.

### Os 3 arquivos novos

1. **`image_processing_datasource_base.dart`** — só a interface abstrata `ImageProcessingDatasource`. Sem importar nada nativo.

2. **`image_processing_datasource_native.dart`** — implementação real com `opencv_dart`, `Isolate.run`, todo o pipeline. **Nunca é tocada no Web.**

3. **`image_processing_datasource_stub.dart`** — implementação fallback que retorna `Left(ImageProcessingFailure('OpenCV nativo não está disponível no Flutter Web. Use Android, Windows ou Linux.'))`. É o que aparece naquela tela de erro amigável quando se roda no Chrome.

A camada Repository, Service, BLoC, etc. continuam recebendo a mesma interface `ImageProcessingDatasource` — elas nem sabem qual implementação é. Polimorfismo puro.

---

## 8. Outras mudanças menores mas relevantes

### Enum `SeverityLevel`

Em `lib/core/models/leaf_analysis_model.dart` adicionamos:

```dart
enum SeverityLevel { low, medium, high, critical }
```

e um getter computado:

```dart
SeverityLevel get severityLevel {
  if (damagePercentage <= 10) return SeverityLevel.low;
  if (damagePercentage <= 30) return SeverityLevel.medium;
  if (damagePercentage <= 60) return SeverityLevel.high;
  return SeverityLevel.critical;
}
```

Isso permite que widgets e outras camadas raciocinem em termos de níveis discretos (`if (level == SeverityLevel.critical)`) em vez de comparar `double` diretamente. **Não alteramos o construtor nem os campos**, então a persistência no Hive (banco local) continua funcionando sem migração — esse era um requisito implícito porque o histórico já está salvo no dispositivo.

### `damageLabel` reorganizado

Em `lib/core/utils/image_utils.dart` o helper `damageLabel(double)` agora delega para `severityLabel(SeverityLevel)` que faz um `switch` no enum. Mantém compatibilidade com o widget de resultado (que ainda passa `double`), mas internamente usa o enum.

### Layout das imagens

Em `lib/modules/analysis/view/widgets/analysis_result_widget.dart`, o `_ImageComparisonRow` que mostrava as 3 imagens em uma `Row` (cada uma com `Expanded` + `AspectRatio(1)` + `BoxFit.cover`) foi trocado por uma `Column` empilhando as 3 em **largura cheia** com `BoxFit.fitWidth`. Cada `_ImageTile` agora usa `LayoutBuilder` para descobrir a largura disponível e renderizar a imagem com essa largura, mantendo a proporção original — exatamente o mesmo tratamento que a imagem de calibração de escala já recebia. O label foi promovido para cima da imagem com fonte maior porque agora há espaço.

### `pubspec.yaml`

Removida a linha `image: ^4.2.0` e adicionada `opencv_dart: ^1.4.5`. O pacote `image` não é mais necessário porque `opencv_dart` cobre todas as operações.

### `build.gradle.kts`

`minSdk = flutter.minSdkVersion` virou `minSdk = 24`. Sem isso, o `opencv_dart` não builda no Android.

---

## 9. Resumo: arquivos tocados

| Arquivo | O que mudou |
|---|---|
| `pubspec.yaml` | Removido `image`, adicionado `opencv_dart` |
| `android/app/build.gradle.kts` | `minSdk = 24` |
| `lib/core/models/leaf_analysis_model.dart` | Adicionado `enum SeverityLevel` + getter |
| `lib/core/utils/image_utils.dart` | `damageLabel` reorganizado em torno do enum |
| `lib/modules/analysis/datasource/image_processing_datasource.dart` | Virou um *barrel* com conditional export |
| `lib/modules/analysis/datasource/image_processing_datasource_base.dart` | **Novo** — interface abstrata |
| `lib/modules/analysis/datasource/image_processing_datasource_native.dart` | **Novo** — pipeline OpenCV com Isolate |
| `lib/modules/analysis/datasource/image_processing_datasource_stub.dart` | **Novo** — fallback para Web |
| `lib/modules/analysis/view/widgets/analysis_result_widget.dart` | Imagens agora empilhadas em largura cheia |

---

## 10. Em uma frase

Trocamos o coração de processamento do app por uma biblioteca consolidada (OpenCV via `opencv_dart`), mantemos a arquitetura intacta porque a substituição ficou contida em uma camada (DataSource), corrigimos um bug fundamental no cálculo de área (usar `countNonZero` em uma máscara binária em vez de `contourArea` em um polígono que não conhece os buracos internos), passamos o processamento pesado para um Isolate para não travar a UI, criamos um fallback educado para Web (que não suporta FFI nativo), e melhoramos a visualização para mostrar as 3 imagens grandes em vez de miniaturas.
