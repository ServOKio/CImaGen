import 'package:flutter/material.dart';

import 'Animations.dart';

class OCPreview extends StatefulWidget{

  const OCPreview({ super.key });

  @override
  State<OCPreview> createState() => _OCPreviewState();
}

class _OCPreviewState extends State<OCPreview> {
  bool loaded = false;

  final Map<String, List<List<String>>> initial = {
    // 1 - tags
    // 2 - human promt
    'Playing a sport': [
      [
        'clothing, clothed, pose,\noutside, tree, volleyball, ball, sport, playing sports',
        'motion lines'
      ]
    ],
    'Wearing a really fancy dress': [
      [
        'standing, portain,\nclothing, clothed, black black jacket, black necktie, white shirt,\ninside, oval office, white house, court room, courtroom',
        'public'
      ]
    ],
    'Dancing': [
      [
        'public, outside, low-angle view, blue sky, people (breakdance:1.1)\nclothing, clothed,\npose, dancing, backwards baseball cap,\ncamera view, camera hud, fisheye'
        'close-up'
      ]
    ],
    'As a villain': [
      [
        'inside, resident evil, biohazard symbol,\nclothing, clothed, white coat, gun, belt,\nstanding,\nsmirk, grin, teeth, evil grin,\nholding object, glass container, scientific experiment [wire]'
      ]
    ],
    'As a superhero': [
      [
        'outside, full-length portrait,\npose, hand up, smirk, looking at viewer,\nclothing, clothed, cloak, \nsuperhero, energy ball'
      ]
    ],
    'If they were a nerd': [
      [
        'glasses, looking down, window, clothing, clothed, school uniform, white shirt,\ntable, writing, paper,\nslim',
        'muscular, manly'
      ]
    ],
    // 'Confessing to their crush',
    // 'Wearing something dump',
    // 'Getting electrocuted',
    // 'As an old man/woman',
    // 'As a baby',
    // 'Killing someone',
    // 'In a clown costume',
    // 'Wearing what you wearing',
    // 'Getting married',
    // 'If they were kawaii',
    'Dressed as a queen/king': [
      [
        'clothing, clothed, crown,\nsitting [leg up]\ninside, dark, pillar, throne, armchair, plant',
        'curtains'
      ]
    ],
    // 'As a bad girl/boy',
    // 'As a spoiled brat',
    // 'Drawing something',
    // 'Singing',
    // 'With their family',
    'Dressed as a maid': [
      [
        'simple background, white background, pose, motion lines, rain,\nclothing, clothed, sunglasses, maid, maid uniform,\ngun, holding object, holding weapon'
      ]
    ],
    // 'With their exact apposite',
    'As your pet/a pet': [
      [
        'smile, sitting (feral) collar,\ninside, wooden floor, high-angle view [front view]'
      ]
    ],
    // 'Acting in your favorite manner',
    // 'Eating their favorite food',
    // 'As a ghost',
    // 'Gender swap',
    // 'As a monster',
    // 'If they were a meme',
    // 'Dressed as a barbie',
    // 'That looks like you',
    // 'As an alien',
    // 'As a goth',
    // 'Wearing cute outfit',
    // 'Playing a instrument',
    // 'As a pop-star',
    // 'Teasing their friend',
    // 'Pranking someone',
    // 'Being a jerk',
    // 'Bullying someone',
    // 'Making their rival jealous',
    // 'Dieting',
    // 'In their school uniform',
    // 'At work',
    // 'At hogwarts',
    // 'Watching their favorite movie',
    // 'In a creepy outfit',
    // 'In prison',
    // 'Dressed for a party',
    // 'In your halloween costume',
    // 'In space',
    // 'Being lazy',
    // 'Wearing makeup',
    // 'As a vampire',
    // 'As a witch',
    // 'As an elf',
    // 'If they were fat',
    // 'In an victorian outfit',
    // 'In an outfit they would never wear',
    // 'With long hair/short hair',
    // 'With flowers in their hair',
    // 'Reading a really good book',
    // 'Sleeping in an odd position',
    // 'In way to big clothes',
    // 'In a dress',
    // 'Chibi',
    // 'With glasses',
    // 'With your worst feat',
    // 'Pajamas',
    // 'Doing something they wouldn\'t normally doing',
    // 'Building a snowman',
    // 'Flustered or embarrassed',
    // 'Cooking',
    // 'Bored',
    // 'In a summer outfit',
    // 'In a winter outfit',
    // 'In a autumn outfit',
    // 'In a spring outfit',
    // 'As a pokemon trainer',
    // 'With wings',
    // 'Crying',
    // 'Flirting/being flirted with',
    // 'In a costume',
    // 'In a formal outfit',
    // 'With a new color palette',
    // 'As a mythical creature',
    // 'Doing their hobby',
    // 'Eating',
    // 'In their swimsuit',
    // 'In a really bad disguise',
    // 'With a new body type',
    // 'Cyberpunk',
    // 'Riding a motorcycle',
    // 'Riding a bike',
    // 'Wearing a silly hat',
    // 'With a weapon',
    // 'Hurt',
    // 'As a cyborg',
    // 'In armor',
    // 'Sick',
    // 'Nude'
  };

  @override
  Widget build(BuildContext context) {
    AppBar appBar = AppBar(
        title: ShowUp(
          delay: 100,
          child: Text('OC Preview', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600, fontFamily: 'Montserrat')),
        ),
        backgroundColor: const Color(0xaa000000),
        elevation: 0,
        actions: [
          IconButton(
              onPressed: () {},
              icon: Icon(Icons.file_open)
          ),
          IconButton(
              onPressed: () {},
              icon: Icon(Icons.save)
          )
        ]
    );

    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: appBar,
        backgroundColor: Color(0xFFecebe9),
        body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [

                ],
              )
          )
        )
    );
  }
}