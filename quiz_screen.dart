import 'package:flutter/material.dart';
import 'summary_screen.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class QuizScreen extends StatefulWidget {
  final int numberOfQuestions;
  final String category;
  final String difficulty;
  final String type;

  QuizScreen({
    required this.numberOfQuestions,
    required this.category,
    required this.difficulty,
    required this.type,
  });

  @override
  QuizScreenState createState() => QuizScreenState();
}

class QuizScreenState extends State<QuizScreen> {
  List<Map<String, dynamic>> questions = [];
  int currentQuestionIndex = 0;
  int score = 0;
  int remainingTime = 15;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    fetchQuestions();
  }

  Future<void> fetchQuestions() async {
    try {
      final url =
          'https://opentdb.com/api.php?amount=${widget.numberOfQuestions}&category=${widget.category}&difficulty=${widget.difficulty}&type=${widget.type}';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['results'] as List;
        if (data.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No questions available for the selected options.')),
          );
          return;
        }

        setState(() {
          questions = data.map((question) {
            final incorrectAnswers =
                (question['incorrect_answers'] as List).cast<String>();
            final correctAnswer = question['correct_answer'] as String;
            final allAnswers = [...incorrectAnswers, correctAnswer]..shuffle();

            return {
              'question': question['question'],
              'correct_answer': correctAnswer,
              'all_answers': allAnswers,
            };
          }).toList();
        });
        startTimer();
      } else {
        throw Exception('Failed to load questions');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading questions: $e')),
      );
    }
  }

  void startTimer() {
    timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (remainingTime > 0) {
        setState(() {
          remainingTime--;
        });
      } else {
        nextQuestion();
      }
    });
  }

  void stopTimer() {
    timer?.cancel();
  }

  void nextQuestion([bool answered = false]) {
    stopTimer();
    if (!answered) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Time's up! Correct answer: ${questions[currentQuestionIndex]['correct_answer']}",
          ),
        ),
      );
    }

    setState(() {
      if (currentQuestionIndex < questions.length - 1) {
        currentQuestionIndex++;
        remainingTime = 15;
        startTimer();
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SummaryScreen(
              score: score,
              totalQuestions: widget.numberOfQuestions,
            ),
          ),
        );
      }
    });
  }

  void answerQuestion(String answer) {
    stopTimer();
    if (answer == questions[currentQuestionIndex]['correct_answer']) {
      setState(() {
        score++;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Correct!')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Incorrect! Correct answer: ${questions[currentQuestionIndex]['correct_answer']}',
          ),
        ),
      );
    }
    nextQuestion(true);
  }

  @override
  void dispose() {
    stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentQuestion = questions[currentQuestionIndex];

    return Scaffold(
      appBar: AppBar(title: Text('Quiz')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: (currentQuestionIndex + 1) / questions.length,
            ),
            SizedBox(height: 16),
            Text(
              'Question ${currentQuestionIndex + 1} of ${questions.length}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    currentQuestion['question'],
                    style: TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
            ...currentQuestion['all_answers'].map<Widget>((answer) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: ElevatedButton(
                  onPressed: () => answerQuestion(answer),
                  child: Text(answer),
                ),
              );
            }).toList(),
            Spacer(),
            Text(
              'Time remaining: $remainingTime seconds',
              style: TextStyle(fontSize: 16, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}
