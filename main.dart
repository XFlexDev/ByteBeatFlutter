import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:raw_sound/raw_sound_player.dart';

void main() {
  runApp(const BytebeatApp());
}

class BytebeatApp extends StatelessWidget {
  const BytebeatApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyan,
          brightness: Brightness.dark,
        ),
      ),
      home: const ContentView(),
    );
  }
}

class ContentView extends StatefulWidget {
  const ContentView({super.key});
  @override
  State<ContentView> createState() => _ContentViewState();
}

class _ContentViewState extends State<ContentView> {
  final _formulaController = TextEditingController(text: "t*(((t>>12)|(t>>8))&63& (t>>4))");
  bool _isPlaying = false;
  double _sampleRate = 8000;
  String _mode = 'Bytebeat';
  RawSoundPlayer? _player;
  Timer? _timer;
  int _currentT = 0;

  final List<Map<String, String>> _presets = [
    {'name': 'Classic Bytebeat', 'mode': 'Bytebeat', 'formula': 't*(((t>>12)|(t>>8))&63&(t>>4))'},
    {'name': 'Signed Noise', 'mode': 'Signed Bytebeat', 'formula': '(t>>5|(t>>2))&t//(t>>12)'},
    {'name': 'Floatbeat Meltdown', 'mode': 'Floatbeat', 'formula': 'sin(t/50)*cos(t/20)'},
    {'name': 'Funcbeat Glitch', 'mode': 'Funcbeat', 'formula': 'tan(t/100)&(t>>4)'}
  ];

  @override
  void dispose() {
    _stopAudio();
    _formulaController.dispose();
    super.dispose();
  }

  void _startAudio() async {
    _player = RawSoundPlayer();
    final isFloat = _mode == 'Floatbeat' || _mode == 'Funcbeat';
    
    await _player!.initialize(
      bufferSize: 4096,
      nChannels: 1,
      sampleRate: _sampleRate.toInt(),
      pcmType: isFloat ? RawSoundPcmType.float32 : RawSoundPcmType.int8,
    );
    
    final evaluator = BytebeatEvaluator(_formulaController.text);
    _currentT = 0;
    _isPlaying = true;
    setState(() {});

    await _player!.play();

    _timer = Timer.periodic(const Duration(milliseconds: 40), (timer) async {
      if (!_isPlaying) return;
      final int samplesNeeded = (_sampleRate * 0.04).toInt();
      
      if (isFloat) {
        final buffer = Float32List(samplesNeeded);
        for (int i = 0; i < samplesNeeded; i++) {
          double val = evaluator.evaluate(_currentT);
          if (_mode == 'Funcbeat') {
            buffer[i] = (val.toInt() & 0xFF) / 128.0 - 1.0;
          } else {
            buffer[i] = val.clamp(-1.0, 1.0);
          }
          _currentT++;
        }
        await _player!.feed(buffer.buffer.asUint8List());
      } else {
        final buffer = Uint8List(samplesNeeded);
        for (int i = 0; i < samplesNeeded; i++) {
          int val = evaluator.evaluate(_currentT).toInt();
          if (_mode == 'Signed Bytebeat') {
            buffer[i] = (val & 0xFF);
          } else {
            buffer[i] = (val & 0xFF);
          }
          _currentT++;
        }
        await _player!.feed(buffer);
      }
    });
  }

  void _stopAudio() async {
    _isPlaying = false;
    _timer?.cancel();
    if (_player != null) {
      await _player!.stop();
      await _player!.release();
      _player = null;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bytebeat Studio")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _formulaController,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
                decoration: InputDecoration(
                  labelText: "Formula",
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text("Mode", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _mode,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: ['Bytebeat', 'Signed Bytebeat', 'Floatbeat', 'Funcbeat']
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _mode = val);
              },
            ),
            const SizedBox(height: 16),
            const Text("Sample Rate", style: TextStyle(fontWeight: FontWeight.bold)),
            Slider(
              value: _sampleRate,
              min: 4000,
              max: 44100,
              divisions: 8,
              label: "${_sampleRate.toInt()} Hz",
              onChanged: (val) => setState(() => _sampleRate = val),
            ),
            const SizedBox(height: 16),
            const Text("Presets", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _presets.map((p) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ActionChip(
                      label: Text(p['name']!),
                      onPressed: () {
                        setState(() {
                          _mode = p['mode']!;
                          _formulaController.text = p['formula']!;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isPlaying ? Colors.red.shade800 : Colors.cyan.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isPlaying ? _stopAudio : _startAudio,
                child: Text(_isPlaying ? "STOP" : "PLAY", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BytebeatEvaluator {
  final List<String> tokens = [];
  BytebeatEvaluator(String formula) {
    _parse(formula);
  }

  void _parse(String formula) {
    final List<String> output = [];
    final List<String> stack = [];
    final Map<String, int> precedence = {
      "|": 1, "^": 2, "&": 3,
      "<<": 4, ">>": 4,
      "+": 5, "-": 5,
      "*": 6, "/": 6, "%": 6
    };
    final List<String> tokensList = [];
    final chars = formula.replaceAll(" ", "").split("");
    int idx = 0;
    while (idx < chars.length) {
      final ch = chars[idx];
      if (RegExp(r'[0-9.]').hasMatch(ch)) {
        String numStr = "";
        while (idx < chars.length && RegExp(r'[0-9.]').hasMatch(chars[idx])) {
          numStr += chars[idx];
          idx++;
        }
        tokensList.add(numStr);
        continue;
      } else if (ch == "t") {
        tokensList.add("t");
        idx++;
      } else if (ch == "(" || ch == ")") {
        tokensList.add(ch);
        idx++;
      } else if (ch == "<" || ch == ">") {
        if (idx + 1 < chars.length && chars[idx + 1] == ch) {
          tokensList.add(ch + ch);
          idx += 2;
        } else {
          tokensList.add(ch);
          idx++;
        }
      } else if (idx + 2 < chars.length && chars.sublist(idx, idx + 3).join() == "sin") {
        tokensList.add("sin");
        idx += 3;
      } else if (idx + 2 < chars.length && chars.sublist(idx, idx + 3).join() == "cos") {
        tokensList.add("cos");
        idx += 3;
      } else if (idx + 2 < chars.length && chars.sublist(idx, idx + 3).join() == "tan") {
        tokensList.add("tan");
        idx += 3;
      } else {
        tokensList.add(ch);
        idx++;
      }
    }
    for (final c in tokensList) {
      if (double.tryParse(c) != null || c == "t") {
        output.add(c);
      } else if (c == "sin" || c == "cos" || c == "tan" || c == "(") {
        stack.add(c);
      } else if (c == ")") {
        while (stack.isNotEmpty && stack.last != "(") {
          output.add(stack.removeLast());
        }
        if (stack.isNotEmpty) stack.removeLast();
        if (stack.isNotEmpty && (stack.last == "sin" || stack.last == "cos" || stack.last == "tan")) {
          output.add(stack.removeLast());
        }
      } else if (precedence.containsKey(c)) {
        while (stack.isNotEmpty && precedence.containsKey(stack.last) && precedence[stack.last]! >= precedence[c]!) {
          output.add(stack.removeLast());
        }
        stack.add(c);
      }
    }
    while (stack.isNotEmpty) {
      output.add(stack.removeLast());
    }
    tokens.addAll(output);
  }

  double evaluate(int t) {
    final List<double> stack = [];
    for (final token in tokens) {
      if (token == "t") {
        stack.add(t.toDouble());
      } else if (double.tryParse(token) != null) {
        stack.add(double.parse(token));
      } else if (token == "sin" || token == "cos" || token == "tan") {
        if (stack.isEmpty) continue;
        final a = stack.removeLast();
        if (token == "sin") stack.add(math.sin(a));
        if (token == "cos") stack.add(math.cos(a));
        if (token == "tan") stack.add(math.tan(a));
      } else {
        if (stack.length < 2) continue;
        final b = stack.removeLast();
        final a = stack.removeLast();
        switch (token) {
          case "+": stack.add(a + b); break;
          case "-": stack.add(a - b); break;
          case "*": stack.add(a * b); break;
          case "/": stack.add(b == 0 ? 0 : a / b); break;
          case "%": stack.add(b == 0 ? 0 : a % b); break;
          case "&": stack.add((a.toInt() & b.toInt()).toDouble()); break;
          case "|": stack.add((a.toInt() | b.toInt()).toDouble()); break;
          case "^": stack.add((a.toInt() ^ b.toInt()).toDouble()); break;
          case "<<": stack.add((a.toInt() << (b.toInt() & 31)).toDouble()); break;
          case ">>": stack.add((a.toInt() >> (b.toInt() & 31)).toDouble()); break;
        }
      }
    }
    return stack.isNotEmpty ? stack.last : 0.0;
  }
}
