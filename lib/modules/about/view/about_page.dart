import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const String _developerName = 'Eduardo Colet';
  static const String _developerEmail =
      'eduardocolet5@gmail.com ou 195296@upf.br';
  static const String _advisorName = 'Prof. Rafael Rieder';
  static const String _advisorEmail = 'rieder@upf.br';

  static const String _institution =
      'Universidade de Passo Fundo (UPF) — Curso de Ciência da Computação';
  static const String _appVersion = '0.1.0';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Sobre'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Modular.to.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _AppHeader(),
          const SizedBox(height: 24),
          const _SectionCard(
            icon: Icons.description_outlined,
            title: 'Sobre o aplicativo',
            child: Text(
              'O LeafScope ajuda agricultores, técnicos e pesquisadores a medir '
              'rapidamente o quanto uma folha foi danificada — seja por insetos, '
              'doenças ou outros fatores. Basta tirar uma foto da folha e o '
              'aplicativo calcula automaticamente o percentual de área afetada, '
              'sem precisar de internet ou qualquer equipamento especial. '
              'Tudo é feito direto no seu celular.',
              style: TextStyle(fontSize: 14, height: 1.6),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.person_outline,
            title: 'Desenvolvedor',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  icon: Icons.badge_outlined,
                  label: 'Nome',
                  value: _developerName,
                ),
                _InfoRow(
                  icon: Icons.email_outlined,
                  label: 'E-mail',
                  value: _developerEmail,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.school_outlined,
            title: 'Orientação',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  icon: Icons.badge_outlined,
                  label: 'Orientador',
                  value: _advisorName,
                ),
                _InfoRow(
                  icon: Icons.email_outlined,
                  label: 'E-mail',
                  value: _advisorEmail,
                ),
                _InfoRow(
                  icon: Icons.account_balance_outlined,
                  label: 'Instituição',
                  value: _institution,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.info_outline,
            title: 'Versão',
            child: Text(_appVersion, style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(height: 32),
          Text(
            '© ${DateTime.now().year} — Trabalho de Conclusão de Curso',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(Icons.eco, size: 56, color: Color(0xFF4CAF50)),
        ),
        const SizedBox(height: 12),
        const Text(
          'LeafScope',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Quantificação de dano foliar',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF4CAF50), size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(value, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
