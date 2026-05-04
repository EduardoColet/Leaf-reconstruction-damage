import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class TutorialPage extends StatefulWidget {
  const TutorialPage({super.key});

  @override
  State<TutorialPage> createState() => _TutorialPageState();
}

class _TutorialPageState extends State<TutorialPage> {
  final _controller = PageController();
  int _index = 0;

  static const List<_TutorialStep> _steps = [
    _TutorialStep(
      icon: Icons.eco,
      title: 'Bem-vindo ao LeafScope',
      description:
          'O LeafScope mede e quantifica automaticamente o dano foliar a partir de uma '
          'foto, processando tudo localmente no seu dispositivo. Sem servidores, sem '
          'conexão necessária.',
    ),
    _TutorialStep(
      icon: Icons.camera_alt_outlined,
      title: '1. Capture a folha',
      description:
          'Toque em "Analisar Folha" para tirar uma foto ou selecionar uma imagem da '
          'galeria. Para melhores resultados, use um fundo contrastante (papel branco '
          'ou superfície lisa) e iluminação uniforme, evitando sombras fortes.',
    ),
    _TutorialStep(
      icon: Icons.auto_awesome_outlined,
      title: '2. Análise automática',
      description:
          'O aplicativo segmenta a folha, detecta seu contorno e aplica o algoritmo '
          'de Convex Hull para reconstruir a forma original. Buracos internos também '
          'são identificados, sem precisar ajustar nada manualmente.',
    ),
    _TutorialStep(
      icon: Icons.insert_chart_outlined,
      title: '3. Veja o resultado',
      description:
          'Você verá a imagem original, a folha segmentada e a reconstrução por '
          'Convex Hull lado a lado, junto com o percentual de dano e um indicador de '
          'severidade (leve, moderado, severo ou crítico).',
    ),
    _TutorialStep(
      icon: Icons.straighten,
      title: '4. Calibração de escala (opcional)',
      description:
          'Se quiser exibir as áreas em cm² em vez de pixels², toque em dois pontos '
          'da imagem original e informe a distância real entre eles. O app converte '
          'automaticamente todas as medições.',
    ),
    _TutorialStep(
      icon: Icons.history,
      title: '5. Histórico e exportação',
      description:
          'Toda análise é salva automaticamente no Histórico, acessível a partir da '
          'tela inicial. Você também pode exportar o resultado completo como PDF '
          'para registro ou compartilhamento.',
    ),
  ];

  bool get _isLast => _index == _steps.length - 1;

  void _next() {
    if (_isLast) {
      Modular.to.pop();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Como usar'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Modular.to.pop(),
        ),
        actions: [
          if (!_isLast)
            TextButton(
              onPressed: () => Modular.to.pop(),
              child: const Text(
                'Pular',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _steps.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => _StepView(step: _steps[i]),
              ),
            ),
            _Indicators(count: _steps.length, current: _index),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isLast ? 'Começar a usar' : 'Próximo',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialStep {
  final IconData icon;
  final String title;
  final String description;

  const _TutorialStep({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class _StepView extends StatelessWidget {
  final _TutorialStep step;
  const _StepView({required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              step.icon,
              size: 80,
              color: const Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            step.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Indicators extends StatelessWidget {
  final int count;
  final int current;
  const _Indicators({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF4CAF50) : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
