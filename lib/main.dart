import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Love and Forgiveness Game',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
        useMaterial3: true,
      ),
      home: const GamePage(),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  int currentScene = 0;

  final List<Map<String, dynamic>> scenes = [
    {
      'text': 'Welcome to the Love and Forgiveness Game!\n\nYou are about to embark on a journey that explores the themes of love and forgiveness. Make choices that reflect your understanding of these concepts.\n\nReady to start?',
      'choices': [
        {'text': 'Yes, let\'s begin!', 'next': 1},
      ],
    },
    {
      'text': 'Scene 1: You have a close friend who has betrayed your trust by spreading a rumor about you. How do you respond?\n\nA) Confront them angrily and end the friendship.\nB) Talk to them calmly and try to understand their side.',
      'choices': [
        {'text': 'A) Confront angrily', 'next': 2},
        {'text': 'B) Talk calmly', 'next': 3},
      ],
    },
    {
      'text': 'You chose to confront angrily. The friendship ends, but you feel bitter. Later, you learn the rumor was a misunderstanding.\n\nThe path of anger leads to isolation. Remember, forgiveness can heal wounds.',
      'choices': [
        {'text': 'Restart', 'next': 0},
      ],
    },
    {
      'text': 'You chose to talk calmly. Your friend apologizes, and you forgive them. The friendship grows stronger.\n\nLove involves understanding and forgiveness.',
      'choices': [
        {'text': 'Continue', 'next': 4},
      ],
    },
    {
      'text': 'Final Scene: In life, love and forgiveness are intertwined. By choosing forgiveness, you open your heart to deeper connections.\n\nThank you for playing! Remember to practice love and forgiveness in your life.',
      'choices': [
        {'text': 'Play Again', 'next': 0},
      ],
    },
  ];

  void chooseChoice(int next) {
    setState(() {
      currentScene = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scene = scenes[currentScene];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Love and Forgiveness Game'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  scene['text'],
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ...scene['choices'].map<Widget>((choice) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ElevatedButton(
                  onPressed: () => chooseChoice(choice['next']),
                  child: Text(choice['text']),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
