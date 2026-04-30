import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const AIOSApp());

class AIOSApp extends StatelessWidget {
  const AIOSApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'AIOS',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        home: const MainScreen(),
      );
}

class _Msg {
  final String role;
  final String text;
  final String? toolName;
  final String? toolArgs;
  final String? toolResult;
  _Msg(this.role, this.text, {this.toolName, this.toolArgs, this.toolResult});
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  static const _ch = MethodChannel('com.agent.aios/runtime');
  static const _tokenCh = EventChannel('com.agent.aios/tokens');
  static const _agentCh = EventChannel('com.agent.aios/agent');

  final _inputCtl = TextEditingController();
  final _scrollCtl = ScrollController();

  bool _modelLoaded = false;
  bool _loading = false;
  bool _generating = false;
  bool _agentMode = true;
  String _modelInfo = '';
  List<Map<String, String>> _models = [];

  StreamSubscription? _tokenSub;
  StreamSubscription? _agentSub;
  final List<_Msg> _msgs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _log('App: ${state.name}');
  }

  Future<void> _init() async {
    await _refreshModels();
    if (!mounted) return;
    final loaded = await _ch.invokeMethod<bool>('isModelLoaded');
    if (!mounted) return;
    setState(() => _modelLoaded = loaded ?? false);
    _log('Ready. ${_models.length} model(s). Mode: ${_agentMode ? "Agent" : "Chat"}');
  }

  Future<void> _refreshModels() async {
    try {
      final raw = await _ch.invokeMethod<List>('listModels');
      if (raw == null) return;
      final models = <Map<String, String>>[];
      for (final item in raw.cast<String>()) {
        final parts = item.split('|');
        models.add({
          'source': parts[0],
          'name': parts[1],
          'size': parts[2],
          'path': parts[3],
        });
      }
      if (!mounted) return;
      setState(() => _models = models);
    } catch (e) {
      _log('Refresh error: $e');
    }
  }

  Future<void> _loadModel(String path) async {
    setState(() => _loading = true);
    _log('Loading: ${path.split('/').last}');
    try {
      final ok = await _ch.invokeMethod<bool>('loadModel', {
        'path': path,
        'contextSize': 1024,
      });
      if (ok == true) {
        final info = await _ch.invokeMethod<String>('getModelInfo');
        setState(() { _modelLoaded = true; _modelInfo = info ?? ''; });
        _log('Loaded: $info');
      } else {
        _log('Load failed.');
      }
    } catch (e) {
      _log('Load error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _generate(String prompt) async {
    if (prompt.trim().isEmpty) return;

    if (_agentMode) {
      await _runAgent(prompt);
      return;
    }

    setState(() {
      _msgs.add(_Msg('user', prompt));
      _msgs.add(_Msg('ai', ''));
      _generating = true;
    });
    _inputCtl.clear();
    _scroll();

    final aiIdx = _msgs.length - 1;
    final buffer = StringBuffer();
    final sw = Stopwatch()..start();

    _tokenSub = _tokenCh.receiveBroadcastStream().listen(
      (event) {
        if (event is String && event.isNotEmpty) {
          buffer.write(event);
          setState(() => _msgs[aiIdx] = _Msg('ai', buffer.toString()));
          _scroll();
        }
      },
      onError: (e) => _log('Stream error: $e'),
    );

    try {
      final count = await _ch.invokeMethod<int>('generateStream', {
        'prompt': prompt,
        'maxTokens': 128,
      });
      sw.stop();
      await _tokenSub?.cancel();
      _tokenSub = null;
      final elapsed = sw.elapsedMilliseconds;
      final tps = (count ?? 0) * 1000 / (elapsed > 0 ? elapsed : 1);
      setState(() {
        _msgs[aiIdx] = _Msg('ai',
          '${buffer.toString()}\n\n[$count tokens \u00B7 ${elapsed}ms \u00B7 ${tps.toStringAsFixed(1)} tok/s]');
        _generating = false;
      });
    } catch (e) {
      _tokenSub?.cancel();
      _tokenSub = null;
      _log('Gen error: $e');
      setState(() => _generating = false);
    }
    _scroll();
  }

  Future<void> _runAgent(String prompt) async {
    setState(() {
      _msgs.add(_Msg('user', prompt));
      _generating = true;
    });
    _inputCtl.clear();
    _scroll();

    _agentSub = _agentCh.receiveBroadcastStream().listen(
      (event) {
        if (event is String) {
          try {
            final step = jsonDecode(event) as Map<String, dynamic>;
            final type = step['type'] as String? ?? '';
            final content = step['content'] as String? ?? '';
            final toolName = step['toolName'] as String?;
            final toolArgs = step['toolArgs'] as String?;
            final toolResult = step['toolResult'] as String?;

            setState(() {
              if (type == 'thought') {
                _msgs.add(_Msg('agent_think', content));
              } else if (type == 'action') {
                _msgs.add(_Msg('agent_action', content,
                    toolName: toolName, toolArgs: toolArgs));
              } else if (type == 'observation') {
                _msgs.add(_Msg('agent_obs', content,
                    toolName: toolName, toolResult: toolResult));
              } else if (type == 'answer') {
                _msgs.add(_Msg('ai', content));
              }
            });
            _scroll();
          } catch (_) {}
        }
      },
      onError: (e) => _log('Agent stream error: $e'),
    );

    try {
      final result = await _ch.invokeMethod<String>('runAgent', {
        'prompt': prompt,
        'maxIterations': 5,
      });
      await _agentSub?.cancel();
      _agentSub = null;
      setState(() => _generating = false);
      _log('Agent done');
    } catch (e) {
      _agentSub?.cancel();
      _agentSub = null;
      _log('Agent error: $e');
      setState(() => _generating = false);
    }
    _scroll();
  }

  void _log(String t) { if (!mounted) return; setState(() => _msgs.add(_Msg('sys', t))); _scroll(); }
  void _scroll() => Future.delayed(const Duration(milliseconds: 100), () {
    if (_scrollCtl.hasClients) _scrollCtl.animateTo(_scrollCtl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  });
  String _fmt(String sizeStr) {
    final b = int.tryParse(sizeStr) ?? 0;
    return b < 1048576 ? '${(b / 1024).toStringAsFixed(0)}KB' : '${(b / 1048576).toStringAsFixed(1)}MB';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tokenSub?.cancel();
    _agentSub?.cancel();
    _inputCtl.dispose();
    _scrollCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(children: [
        const Text('AIOS'),
        const SizedBox(width: 8),
        Container(width: 8, height: 8, decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _generating ? Colors.orange : _modelLoaded ? Colors.green : Colors.grey,
        )),
        const SizedBox(width: 4),
        Text(_generating ? 'Running' : _modelLoaded ? 'Ready' : 'Idle',
          style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _agentMode ? Colors.purple.shade100 : Colors.blue.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(_agentMode ? 'Agent' : 'Chat',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
              color: _agentMode ? Colors.purple.shade700 : Colors.blue.shade700)),
        ),
      ]),
      actions: [
        IconButton(icon: Icon(_agentMode ? Icons.smart_toy : Icons.chat,
          color: _agentMode ? Colors.purple : Colors.blue),
          tooltip: _agentMode ? 'Switch to Chat' : 'Switch to Agent',
          onPressed: () {
            setState(() => _agentMode = !_agentMode);
            _log('Mode: ${_agentMode ? "Agent" : "Chat"}');
          },
        ),
        IconButton(icon: const Icon(Icons.folder_open), tooltip: 'Load Model', onPressed: _showModelPicker),
        IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: _refreshModels),
      ],
    ),
    body: Column(children: [
      if (!_modelLoaded && !_loading) _banner(Colors.orange, 'Tap \U0001F4C2 to load a GGUF model'),
      if (_loading) _banner(Colors.blue, 'Loading model...'),
      if (_modelInfo.isNotEmpty) _banner(Colors.green, _modelInfo),
      Expanded(child: ListView.builder(
        controller: _scrollCtl, padding: const EdgeInsets.all(12),
        itemCount: _msgs.length,
        itemBuilder: (_, i) => _msgBubble(_msgs[i]),
      )),
      if (_generating) const Padding(padding: EdgeInsets.all(8),
        child: Row(children: [SizedBox(width:14, height:14, child:CircularProgressIndicator(strokeWidth:2)), SizedBox(width:8), Text('Agent thinking...')])),
      SafeArea(child: Padding(padding: const EdgeInsets.all(8),
        child: Row(children: [
          Expanded(child: TextField(controller: _inputCtl, enabled: _modelLoaded && !_generating,
            decoration: InputDecoration(hintText: _agentMode ? 'Ask the agent...' : 'Prompt...',
              border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal:12, vertical:10)),
            onSubmitted: _modelLoaded ? _generate : null)),
          const SizedBox(width: 8),
          IconButton(onPressed: _modelLoaded && !_generating ? () => _generate(_inputCtl.text) : null,
            icon: const Icon(Icons.send), style: IconButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white)),
        ]))),
    ]),
  );

  Widget _banner(MaterialColor c, String t) => Container(
    width: double.infinity, padding: const EdgeInsets.all(10), color: c.shade100,
    child: Text(t, style: TextStyle(fontSize: 12, color: c.shade900)),
  );

  Widget _msgBubble(_Msg m) {
    final isSys = m.role == 'sys';
    final isUser = m.role == 'user';
    final isThink = m.role == 'agent_think';
    final isAction = m.role == 'agent_action';
    final isObs = m.role == 'agent_obs';

    if (isAction) {
      return _toolCallCard(m);
    }
    if (isObs) {
      return _toolResultCard(m);
    }

    Color bgColor;
    Alignment align;
    TextStyle? textStyle;

    if (isSys) {
      bgColor = Colors.grey.shade200;
      align = Alignment.centerLeft;
      textStyle = TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.grey.shade600);
    } else if (isUser) {
      bgColor = Colors.indigo.shade100;
      align = Alignment.centerRight;
      textStyle = const TextStyle(fontSize: 13);
    } else if (isThink) {
      bgColor = Colors.purple.shade50;
      align = Alignment.centerLeft;
      textStyle = TextStyle(fontSize: 12, color: Colors.purple.shade700, fontStyle: FontStyle.italic);
    } else {
      bgColor = Colors.grey.shade100;
      align = Alignment.centerLeft;
      textStyle = const TextStyle(fontSize: 13);
    }

    return Padding(padding: const EdgeInsets.only(bottom: 6),
      child: Align(alignment: align,
        child: Container(constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
          child: isSys || isThink
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(isThink ? Icons.psychology : Icons.info_outline, size: 14,
                  color: isThink ? Colors.purple.shade400 : Colors.grey.shade500),
                const SizedBox(width: 6),
                Flexible(child: Text(m.text, style: textStyle)),
              ])
            : SelectableText(m.text, style: textStyle))));
  }

  Widget _toolCallCard(_Msg m) => Padding(padding: const EdgeInsets.only(bottom: 6),
    child: Align(alignment: Alignment.centerLeft,
      child: Container(constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.build, size: 16, color: Colors.orange.shade700),
          const SizedBox(width: 6),
          Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Tool: ${m.toolName}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
            if (m.toolArgs != null && m.toolArgs!.isNotEmpty)
              Text(m.toolArgs!, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.orange.shade600)),
          ])),
        ]))));

  Widget _toolResultCard(_Msg m) => Padding(padding: const EdgeInsets.only(bottom: 6),
    child: Align(alignment: Alignment.centerLeft,
      child: Container(constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
          const SizedBox(width: 6),
          Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Result: ${m.toolName}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
            Text(m.toolResult ?? m.text, style: TextStyle(fontSize: 11, color: Colors.green.shade800)),
          ])),
        ]))));

  void _showModelPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
          child: Column(children: [
            Padding(padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Icon(Icons.folder_open),
                const SizedBox(width: 8),
                const Text('Available Models', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.refresh), onPressed: () async {
                  await _refreshModels();
                  setSheetState(() {});
                }),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ]),
            ),
            const Divider(height: 1),
            Expanded(child: _models.isEmpty
              ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No GGUF files found', style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('adb push model.gguf /data/data/com.agent.aios/files/models/', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ]))
              : ListView(padding: const EdgeInsets.all(12), children: _models.map((m) {
                  return Card(child: ListTile(
                    leading: const Icon(Icons.phone_android, color: Colors.indigo),
                    title: Text(m['name'] ?? '', style: const TextStyle(fontSize: 12)),
                    subtitle: Text('${_fmt(m['size'] ?? '0')} \u00B7 Internal'),
                    trailing: IconButton(
                      icon: const Icon(Icons.play_arrow, color: Colors.indigo),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _loadModel(m['path']!);
                      },
                    ),
                  ));
                }).toList(),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
