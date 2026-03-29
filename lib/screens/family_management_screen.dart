import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';

class FamilyManagementScreen extends StatefulWidget {
  const FamilyManagementScreen({super.key});

  @override
  State<FamilyManagementScreen> createState() => _FamilyManagementScreenState();
}

class _FamilyManagementScreenState extends State<FamilyManagementScreen> {
  final TextEditingController _householdController = TextEditingController();
  bool _isLoading = false;
  List<RecordModel> _familyMembers = [];
  String _errorMessage = '';
  late AppState _appState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _appState = Provider.of<AppState>(context, listen: false);
        _fetchFamilyMembers();
      }
    });
  }

  @override
  void dispose() {
    _householdController.dispose();
    super.dispose();
  }

  Future<void> _fetchFamilyMembers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final members = await _appState.getFamilyMembers();
      if (mounted) {
        setState(() {
          _familyMembers = members;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erro ao buscar membros: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeMember(String memberId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover da Família?'),
        content: const Text('Esta pessoa não poderá mais compartilhar itens.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remover', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final success = await _appState.removeFamilyMember(memberId);
    
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Membro removido.'), backgroundColor: Colors.green),
        );
        _fetchFamilyMembers();
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao remover.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Família'),
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Para compartilhar compras, vocês devem usar o mesmo Código da Família.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Seu Código da Família', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                appState.currentHouseholdId,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: appState.currentHouseholdId));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Código copiado!')),
                                );
                              },
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                const Text('Entrar em uma Família:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _householdController,
                        decoration: const InputDecoration(
                          labelText: 'Código...',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.group),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final code = _householdController.text.trim();
                        if (code.isNotEmpty) {
                          FocusScope.of(context).unfocus();
                          setState(() => _isLoading = true);
                          final success = await appState.joinHousehold(code);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(success ? 'Bem-vindo à Família!' : 'Erro ao entrar.'),
                                backgroundColor: success ? Colors.green : Colors.red,
                              ),
                            );
                            if (success) {
                              _householdController.clear();
                              _fetchFamilyMembers();
                            } else {
                              setState(() => _isLoading = false);
                            }
                          }
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: const Text('Participar'),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                const Text('Membros da Família', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const Divider(),
                
                if (_isLoading)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ))
                else if (_errorMessage.isNotEmpty)
                  Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
                else if (_familyMembers.isEmpty)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Ninguém na sua família.'),
                  ))
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _familyMembers.length,
                    itemBuilder: (context, index) {
                      final member = _familyMembers[index];
                      final isMe = member.id == appState.userCode;
                      final email = member.getStringValue('email');
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isMe ? Theme.of(context).colorScheme.primary : Colors.grey,
                          child: const Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(email.isNotEmpty ? email : 'Usuário Anônimo'),
                        subtitle: Text(isMe ? 'Você' : member.id),
                        trailing: isMe ? null : IconButton(
                          icon: const Icon(Icons.person_remove, color: Colors.red),
                          onPressed: () => _removeMember(member.id),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
