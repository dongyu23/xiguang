class FreqWordsResult {
  const FreqWordsResult(this.words);

  final List<FreqWord> words;
}

class FreqWord {
  const FreqWord({required this.text, required this.count});

  final String text;
  final int count;
}
