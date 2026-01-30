import 'dart:convert';

import 'package:dio/dio.dart';

class TokenizerModule {
  String CLIP_BASE = "openai/clip-vit-base-patch32";
  String CLIP_LARGE = "openai/clip-vit-large-patch14";
  String CLIP_BIGG = "laion/CLIP-ViT-bigG-14-laion2B-39B-b160k";
  String T5_XXL = "google-t5/t5-small";

  Map<String, String> diffusionModels = {
    'SD1': "runwayml/stable-diffusion-v1-5",
    'SD2': "stabilityai/stable-diffusion-2-1",
    'SDXL': "stabilityai/stable-diffusion-xl-base-1.0",
    'SD3': "stabilityai/stable-diffusion-3.5-large",
    'Flux': "black-forest-labs/FLUX.1-schnell",
    'Pixart': "PixArt-alpha/PixArt-XL-2",
  };

  late Tokenizer tokenizer;
  final dio = Dio();

  Future<String> fetch_from_pretrained(String name) async {
    String url = 'https://huggingface.co/$name/resolve/main/tokenizer.json';

    Response response = await dio.getUri(Uri.parse(url));
    return response.data;
  }

  Future<Tokenizer> from_pretrained(String name) async {
    String json = await fetch_from_pretrained(name);
    Tokenizer t = Tokenizer(json, name);
    await t.init();
    return t;
  }

  Future<List<Tokenizer>> from_hf_model(String name) async {
    if (name == "stabilityai/sdxl-turbo") {
      return [
        await from_pretrained(CLIP_LARGE),
        await from_pretrained(CLIP_BIGG),
      ];
    } else if (name == "stabilityai/stable-diffusion-xl-base-1.0") {
      return [
        await from_pretrained(CLIP_LARGE),
        await from_pretrained(CLIP_BIGG),
      ];
    } else if (name == "stabilityai/stable-diffusion-3.5-large") {
      return [
        await from_pretrained(CLIP_LARGE),
        await from_pretrained(CLIP_BIGG),
        await from_pretrained(T5_XXL),
      ];
    } else if (name == "stabilityai/stable-diffusion-3.5-medium") {
      return [
        await from_pretrained(CLIP_LARGE),
        await from_pretrained(CLIP_BIGG),
        await from_pretrained(T5_XXL),
      ];
    } else if (name == "stabilityai/stable-diffusion-2-1") {
      return [await from_pretrained(CLIP_BASE)];
    } else if (name == "runwayml/stable-diffusion-v1-5") {
      return [await from_pretrained(CLIP_BASE)];
    } else if (name == "PixArt-alpha/PixArt-XL-2") {
      return [await from_pretrained(T5_XXL)];
    } else if (name == "black-forest-labs/FLUX.1-schnell") {
      return [
        await from_pretrained(CLIP_LARGE),
        await from_pretrained(T5_XXL),
      ];
    } else {
      throw Exception('Invalid model $name');
    }
  }

  Map<String, Tokenizer> tokenizers = {};
  List<Tokenizer> allTokenizers = [];

  Future<Tokenizer> getTokenizer(String name) async {
    if (tokenizers.containsKey(name)) {
      return tokenizers[name]!;
    }

    allTokenizers = await from_hf_model(name);

    for (var tokenizer in allTokenizers) {
      tokenizers[name] = tokenizer;
    }
    return tokenizers[name]!;
  }


  Future<List<Map<String, dynamic>>> tokenize(String hf_model, String input) async {
    if (input.trim() == '') {
      return [];
    }

    await getTokenizer(hf_model);

    List<Map<String, dynamic>> results = allTokenizers.map((tokenizer) {
      var encoding = tokenizer.encode(input);

      return {
        'prompt': input.trim(),
        'name': tokenizer.name,
        'tokens': encoding['tokens'],
        'input_ids': encoding['input_ids'],
      };
    }).toList(growable: false);
    return results;
  }
}

class Tokenizer{
  String json = '';
  String name = '';
  Tokenizer(this.json, this.name);

  static const startOfText = "<|startoftext|>";
  static const endOfText = "<|endoftext|>";
  Map<String, String> specialTokens = {
    startOfText: startOfText,
    endOfText: endOfText,
  };

  Map<String, String> cache = {
    startOfText: startOfText,
    endOfText: endOfText,
  };

  late RegExp pat;

  Map<String, int> encoder = {};
  Map<String, int> bpeRanks = {};
  Map<int, String> byteEncoder = {};

  init() async{
    var jsonData = jsonDecode(json);
    byteEncoder = bytesToUnicode();
    bpeRanks = <String, int>{};
    pat = RegExp(
      r"'s|'t|'re|'ve|'m|'ll|'d| ?\p{L}+| ?\p{N}+| ?[^\s\p{L}\p{N}]+|\s+(?!\S)|\s+",
      unicode: true,
      caseSensitive: false,
    );

    List<String> lines = List<String>.from(jsonData['model']['merges']);
    final res = createVocabAndBpe(lines);
    encoder = createEncoder(res[0] as List<String>);
    bpeRanks = res[1] as Map<String, int>;
  }

  String basicClean(String text) {
    final textCleaned = _unescapeHtml(text);
    return textCleaned.trim();
  }

  String _unescapeHtml(String text) {
    String textCleaned = text.replaceAll('&amp;', '&');
    textCleaned = textCleaned.replaceAll('&lt;', '<');
    textCleaned = textCleaned.replaceAll('&gt;', '>');
    textCleaned = textCleaned.replaceAll('&quot;', '"');
    textCleaned = textCleaned.replaceAll('&#x27;', "'");
    textCleaned = textCleaned.replaceAll('&#x60;', '`');
    return textCleaned.replaceAll('&#39;', "'");
  }

  String whitespaceClean(String text) {
    final String textCleaned = text.replaceAll(RegExp(r'\s+'), ' ');
    return textCleaned.trim();
  }

  Map<String, dynamic> encode(String text){
    final bpeTokens = <int>[];
    final tokens = <String>[];

    final textCleaned = whitespaceClean(basicClean(text)).toLowerCase();
    for (final token in pat.allMatches(textCleaned).map((m) => m.group(0)!)) {
      String utf8Bytes = token.trim().runes.map((r) => byteEncoder[r]!).join();
      final bpeToken = bpe(utf8Bytes).split(' ');
      tokens.addAll(bpeToken);
      bpeTokens.addAll(bpeToken.map((t) => encoder[t]!));
    }
    return {
      'tokens': tokens,// [encoder["<|startoftext|>"]!] + bpeTokens + [encoder["<|endoftext|>"]!],
      'input_ids': bpeTokens
    };
  }

  String bpe(String token) {
    if (cache.containsKey(token)) {
      return cache[token]!;
    }
    List<String> wordList = token.split('')
      ..removeLast()
      ..add('${token[token.length - 1]}</w>');

    Set<List<String>> pairs = getPairs(wordList);
    if (pairs.isEmpty) {
      return '$token</w>';
    }

    while (true) {
      List<List<String>> minPairs = [];
      double minRank = double.infinity;

      for (final List<String> pair in pairs) {
        final String joinedPair = pair.join();
        final num rank = bpeRanks.containsKey(joinedPair)
            ? bpeRanks[joinedPair]!
            : double.infinity;

        if (rank < minRank) {
          minPairs = [pair];
          minRank = rank.toDouble();
        } else if (rank == minRank) {
          minPairs.add(pair);
        }
      }

      final List<String> bigram = minPairs.first;
      if (!bpeRanks.containsKey(bigram.join())) {
        break;
      }
      final List<String> newWord = [];
      int i = 0;
      while (i < wordList.length) {
        final j = wordList.indexOf(bigram[0], i);
        if (j == -1) {
          newWord.addAll(wordList.sublist(i));
          break;
        }
        newWord.addAll(wordList.sublist(i, j));
        i = j;

        if (wordList[i] == bigram[0] &&
            i < wordList.length - 1 &&
            wordList[i + 1] == bigram[1]) {
          newWord.add(bigram[0] + bigram[1]);
          i += 2;
        } else {
          newWord.add(wordList[i]);
          i++;
        }
      }
      wordList = newWord;

      if (wordList.length == 1) {
        break;
      } else {
        pairs = getPairs(wordList);
      }
    }
    final String word = wordList.join(' ');
    cache[token] = word;
    return word;
  }

  Map<String, int> createEncoder(List<String> vocab) {
    final Map<String, int> encoder = {};
    for (int i = 0; i < vocab.length; i++) {
      encoder[vocab[i]] = i;
    }
    return encoder;
  }

  List<dynamic> createVocabAndBpe(List<String> merges) {
    final List<List<String>> merged =
    merges.map((merge) => merge.split(' ')).toList();
    var vocab = [
      ...bytesToUnicode().values,
    ];
    vocab = [...vocab, ...vocab.map((v) => '$v</w>')];
    for (final merge in merged) {
      vocab.add(
        merge.join(),
      );
    }
    vocab.addAll(["<|startoftext|>", "<|endoftext|>"]);

    final bpe = createBpeRanks(merged);
    return [vocab, bpe];
  }

  Map<String, int> createBpeRanks(List<List<String>> merges) {
    final Map<String, int> bpeRanks = {};
    for (int i = 0; i < merges.length; i++) {
      final String key = merges[i].join();
      bpeRanks[key] = i;
    }
    return bpeRanks;
  }

  Map<int, String> bytesToUnicode() {
    final bs = List<int>.from(List.generate(95, (i) => '!'.codeUnitAt(0) + i))
        .followedBy(List.generate(174 - 161 + 1, (i) => '¡'.codeUnitAt(0) + i))
        .followedBy(List.generate(255 - 174 + 1, (i) => '®'.codeUnitAt(0) + i))
        .toList();

    final cs = List<int>.from(bs);
    var n = 0;
    for (var b = 0; b < 256; b++) {
      if (!bs.contains(b)) {
        bs.add(b);
        cs.add(256 + n);
        n = n + 1;
      }
    }

    final List<String> tmp = cs.map((x) => String.fromCharCode(x)).toList();

    final result = <int, String>{};
    for (var i = 0; i < bs.length; i++) {
      result[bs[i]] = tmp[i];
    }
    return result;
  }

  Set<List<String>> getPairs(List<String> wordList) {
    /// A private function that generates all possible pairs of adjacent characters in a given list of characters.
    final pairs = <List<String>>{};
    var prevChar = wordList[0];
    for (var i = 1; i < wordList.length; i++) {
      final char = wordList[i];
      pairs.add([prevChar, char]);
      prevChar = char;
    }
    return pairs.toSet();
  }
}

class Token{

}

enum Model {
  sd1,
  sd2,
  sdxl,
  sd3,
  flux,
  pixart
}