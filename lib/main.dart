import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() {
  runApp(const RakhiApp());
}

class RakhiApp extends StatelessWidget {
  const RakhiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Happy Rakshabandhan!',
      debugShowCheckedModeBanner: false,
      // Enables mouse drag support for Web / Desktop computers
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        },
      ),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFD1DC),
          primary: const Color(0xFFFF8DA1),
          secondary: const Color(0xFFA8E6CF),
          surface: const Color(0xFFFFFDD0),
        ),
        textTheme: GoogleFonts.fredokaTextTheme(),
      ),
      home: const RakhiHomePage(),
    );
  }
}

class RakhiHomePage extends StatefulWidget {
  const RakhiHomePage({super.key});

  @override
  State<RakhiHomePage> createState() => _RakhiHomePageState();
}

class _RakhiHomePageState extends State<RakhiHomePage> with TickerProviderStateMixin {
  // Audio Player State
  final AudioPlayer _bgAudioPlayer = AudioPlayer();
  final AudioPlayer _sfxAudioPlayer = AudioPlayer();
  bool _isPlayingMusic = false;
  bool _wasPlayingBeforeMic = false;
  bool _hasEnteredSite = false;
  // Runaway Button State
  double? _noBtnTop;
  double? _noBtnLeft;
  final Random _random = Random();

  // Page Step Controller (6 Modules)
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Landing Page Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Gatekeeper Speech State
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isProcessingPhrase = false;
  int _phraseCount = 0;
  String _speechStatus = "Tap the mic and say: 'Yash is best brother'";
  bool _isUnlocked = false;

  // CAPTCHA State
  final Set<int> _selectedCaptchaIndices = {};
  bool _isCaptchaVerified = false;
  late List<Map<String, dynamic>> _captchaItems;


  // Confetti Controller
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _confettiController = ConfettiController(duration: const Duration(seconds: 5));
    _captchaItems = _generateCaptchaItems();

    _bgAudioPlayer.setReleaseMode(ReleaseMode.loop);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bgAudioPlayer.dispose();
    _sfxAudioPlayer.dispose();
    _confettiController.dispose();
    _pulseController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // --- AUDIO LOGIC ---
  void _playClickSound() async {
    try {
      await _sfxAudioPlayer.play(AssetSource('audio/click.mp3'));
    } catch (e) {
      debugPrint("SFX Error: $e");
    }
  }

  void _enterSiteAndStartAudio() async {
    _playClickSound();
    setState(() => _hasEnteredSite = true);

    try {
      await _bgAudioPlayer.play(AssetSource('audio/background.mp3'));
      setState(() => _isPlayingMusic = true);
    } catch (e) {
      debugPrint("Audio Unlock Error: $e");
    }
  }

  void _toggleMusic() async {
    _playClickSound();
    try {
      if (_isPlayingMusic) {
        await _bgAudioPlayer.pause();
        setState(() => _isPlayingMusic = false);
      } else {
        await _bgAudioPlayer.play(AssetSource('audio/background.mp3'));
        setState(() => _isPlayingMusic = true);
      }
    } catch (e) {
      debugPrint("Audio Toggle Error: $e");
    }
  }

  void _autoAdvanceStep() {
    if (_currentStep < 5) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  // --- Speech Gatekeeper Logic ---
  void _listen() async {
    if (!_isListening) {
      if (_isPlayingMusic) {
        _wasPlayingBeforeMic = true;
        await _bgAudioPlayer.pause();
        setState(() => _isPlayingMusic = false);
      } else {
        _wasPlayingBeforeMic = false;
      }

      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            _stopListeningAndResumeAudio();
          }
        },
        onError: (val) => _stopListeningAndResumeAudio(),
      );

      if (available) {
        setState(() {
          _isListening = true;
          _isProcessingPhrase = false;
          _speechStatus = "Listening... Speak clearly!";
        });

        _speech.listen(
          listenOptions: SpeechListenOptions(
            listenMode: ListenMode.confirmation,
            partialResults: true,
          ),
          onResult: (val) {
            String recognized = val.recognizedWords.toLowerCase();

            if (recognized.contains("yash is best brother") && !_isProcessingPhrase) {
              _isProcessingPhrase = true;

              setState(() {
                _phraseCount++;
                if (_phraseCount >= 3) {
                  _isUnlocked = true;
                  _speechStatus = "Unlocked! Moving to next module... 🎉";
                } else {
                  _speechStatus = "Praise recorded! Need ${3 - _phraseCount} more!";
                }
              });

              _speech.stop();
              _stopListeningAndResumeAudio();

              if (_isUnlocked) {
                Future.delayed(const Duration(seconds: 1), () => _autoAdvanceStep());
              }
            } else if (!_isProcessingPhrase) {
              setState(() {
                _speechStatus = "Listening: \"${val.recognizedWords}\"";
              });
            }
          },
        );
      } else {
        _stopListeningAndResumeAudio();
      }
    } else {
      _speech.stop();
      _stopListeningAndResumeAudio();
    }
  }

  void _stopListeningAndResumeAudio() async {
    setState(() => _isListening = false);

    if (_wasPlayingBeforeMic) {
      try {
        await _bgAudioPlayer.resume();
        setState(() => _isPlayingMusic = true);
      } catch (e) {
        debugPrint("Error resuming audio: $e");
      }
    }
  }

  // --- CAPTCHA Logic ---
  List<Map<String, dynamic>> _generateCaptchaItems() {
    final List<Map<String, dynamic>> items = [
      {'path': 'assets/images/yash1.JPG', 'isYash': true},
      {'path': 'assets/images/yash2.JPG', 'isYash': true},
      {'path': 'assets/images/yash3.JPG', 'isYash': true},
      {'path': 'assets/images/decoy1.jpg', 'isYash': false},
      {'path': 'assets/images/decoy2.jpg', 'isYash': false},
      {'path': 'assets/images/decoy3.jpg', 'isYash': false},
    ];
    items.shuffle(_random);
    return items;
  }

  // --- Runaway Button Logic ---
  void _teleportNoButton(Size containerSize) {
    final double maxX = max(10.0, containerSize.width - 110);
    final double maxY = max(10.0, containerSize.height - 50);

    setState(() {
      _noBtnLeft = _random.nextDouble() * maxX;
      _noBtnTop = _random.nextDouble() * maxY;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDD0),
      body: Stack(
        children: [
          if (!_hasEnteredSite)
            _buildLandingScreen()
          else
            SafeArea(
              child: Column(
                children: [
                  _buildHeaderProgress(),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (index) => setState(() => _currentStep = index),
                      children: [
                        _buildHeroSection(),
                        _buildGatekeeperSection(),
                        _buildTimelineAndTriviaSection(),
                        _buildCaptchaSection(),
                        _buildToranMemoriesSection(), // Module 5 (Toran Photo Garland)
                        _buildRunawayButtonSection(), // Module 6
                      ],
                    ),
                  ),
                ],
              ),
            ),

          if (_hasEnteredSite)
            Positioned(
              top: 15,
              right: 15,
              child: FloatingActionButton.small(
                backgroundColor: const Color(0xFFA8E6CF),
                onPressed: _toggleMusic,
                child: Icon(
                  _isPlayingMusic ? Icons.volume_up : Icons.volume_off,
                  color: const Color(0xFF212121),
                ),
              ),
            ),

          // Confetti Overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Color(0xFFFF8DA1),
                Color(0xFFA8E6CF),
                Colors.amber,
                Colors.purple,
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- LANDING SCREEN ---
  Widget _buildLandingScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("🐼", style: TextStyle(fontSize: 90)),
            const SizedBox(height: 20),
            Text(
              "Rakshabandhan Special",
              style: GoogleFonts.fredoka(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFD81B60),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "A gift portal made exclusively for the best sister.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Color(0x99000000)),
            ),
            const SizedBox(height: 50),
            ScaleTransition(
              scale: _pulseAnimation,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8DA1),
                  elevation: 12,
                  shadowColor: const Color(0xFFFF8DA1).withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 22),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                onPressed: _enterSiteAndStartAudio,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Click to Get Rakhi Gift 🎁",
                      style: GoogleFonts.fredoka(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HEADER PROGRESS BAR (6 STEPS) ---
  Widget _buildHeaderProgress() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Step ${_currentStep + 1} of 6",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD81B60)),
              ),
              Text(
                "${((_currentStep + 1) / 6 * 100).toInt()}% Completed",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_currentStep + 1) / 6,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
            backgroundColor: const Color(0xFFFFD1DC),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF8DA1)),
          ),
        ],
      ),
    );
  }

  // --- MODULE 1: HERO SECTION ---
  Widget _buildHeroSection() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("🐼", style: TextStyle(fontSize: 80)),
            const SizedBox(height: 20),
            Text(
              "Happy Rakshabandhan, Sister!",
              textAlign: TextAlign.center,
              style: GoogleFonts.fredoka(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFD81B60),
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              "Welcome to the high-tech sibling portal. Complete each module to unlock your gift.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA8E6CF),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              onPressed: () {
                _playClickSound();
                _autoAdvanceStep();
              },
              child: const Text(
                "Start Verification ➔",
                style: TextStyle(fontSize: 18, color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- MODULE 2: GATEKEEPER SECTION ---
  Widget _buildGatekeeperSection() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "🔒 The Loyalty Test",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                _isUnlocked
                    ? "Access Granted!"
                    : "Say 'Yash is best brother' 3 times to proceed.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                "Praise Counter: $_phraseCount / 3",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF8DA1),
                ),
              ),
              const SizedBox(height: 15),
              AvatarGlowWrapper(
                isGlowing: _isListening,
                child: FloatingActionButton(
                  backgroundColor: const Color(0xFFA8E6CF),
                  onPressed: _isUnlocked ? null : _listen,
                  child: Icon(_isListening ? Icons.mic : Icons.mic_none),
                ),
              ),
              const SizedBox(height: 15),
              Text(
                _speechStatus,
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF616161),
                ),
              ),
              const SizedBox(height: 20),

              // TESTING BYPASS BUTTON
              // TextButton.icon(
              //   style: TextButton.styleFrom(foregroundColor: Colors.grey),
              //   icon: const Icon(Icons.bug_report, size: 16),
              //   label: const Text(
              //     "⚡ Skip for Testing",
              //     style: TextStyle(fontSize: 12, decoration: TextDecoration.underline),
              //   ),
              //   onPressed: () {
              //     _playClickSound();
              //     setState(() {
              //       _phraseCount = 3;
              //       _isUnlocked = true;
              //       _speechStatus = "Bypassed via Debug! Moving forward... 🚀";
              //     });
              //     Future.delayed(
              //       const Duration(milliseconds: 500),
              //           () => _autoAdvanceStep(),
              //     );
              //   },
              // ),
            ],
          ),
        ),
      ),
    );
  }

  // --- MODULE 3: TIMELINE & TRIVIA ---
  Widget _buildTimelineAndTriviaSection() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              "📸 Memory Cards",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FlipCard(
                  frontText: "Childhood Memory 1 🐼",
                  backText: "Remember when we fought over the remote?",
                ),
                SizedBox(width: 15),
                FlipCard(
                  frontText: "Childhood Memory 2 🐼",
                  backText: "You ran with broom & knife behind us.",
                ),
              ],
            ),
            const SizedBox(height: 30),
            const Text(
              "🧠 Sister Trivia Quiz",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD1DC),
              ),
              onPressed: () {
                _playClickSound();
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Question 1 🐼"),
                    content: const Text("Who is the funniest sibling?"),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Correct! (Obviously Yash) 🐼"),
                            ),
                          );
                          Future.delayed(const Duration(seconds: 1), () => _autoAdvanceStep());
                        },
                        child: const Text("Yash"),
                      ),
                    ],
                  ),
                );
              },
              child: const Text("Take Quiz"),
            ),
          ],
        ),
      ),
    );
  }

  // --- MODULE 4: CAPTCHA MODULE ---
  Widget _buildCaptchaSection() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "Verify You Are A Good Sister:\nSelect all pictures of 'Best Brother'",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: _captchaItems.length,
                    itemBuilder: (context, index) {
                      final bool isSelected = _selectedCaptchaIndices.contains(index);
                      final String imagePath = _captchaItems[index]['path'] as String;

                      return GestureDetector(
                        onTap: () {
                          _playClickSound();
                          setState(() {
                            if (isSelected) {
                              _selectedCaptchaIndices.remove(index);
                            } else {
                              _selectedCaptchaIndices.add(index);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          clipBehavior: Clip.hardEdge,
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFFFD1DC) : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? const Color(0xFFD81B60) : Colors.grey.shade300,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Image.asset(
                                  imagePath,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: const Color(0xFFEFEFEF),
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.all(4),
                                      child: Text(
                                        "🖼️\n${imagePath.split('/').last}",
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF9E9E9E),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              if (isSelected)
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: CircleAvatar(
                                    radius: 10,
                                    backgroundColor: const Color(0xFFD81B60),
                                    child: const Icon(Icons.check, size: 14, color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isCaptchaVerified
                            ? const Color(0xFFA8E6CF)
                            : const Color(0xFFFF8DA1),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        _playClickSound();
                        final Set<int> yashIndices = {
                          for (int i = 0; i < _captchaItems.length; i++)
                            if (_captchaItems[i]['isYash'] == true) i
                        };
                        final bool isCorrect =
                            _selectedCaptchaIndices.length == yashIndices.length &&
                                _selectedCaptchaIndices.containsAll(yashIndices);

                        if (isCorrect) {
                          setState(() => _isCaptchaVerified = true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("CAPTCHA Verified! Moving to photo memories... 🎉"),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          Future.delayed(const Duration(seconds: 1), () => _autoAdvanceStep());
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Nope! Select only the real pictures of Yash 🐼"),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      child: Text(
                        _isCaptchaVerified ? "Verified ✅" : "Verify Selection",
                        style: TextStyle(
                          color: _isCaptchaVerified ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- MODULE 5: TORAN MEMORIES SECTION ---
  Widget _buildToranMemoriesSection() {
    final List<Map<String, String>> photoList = [
      {'path': 'assets/images/photo1.JPG', 'caption': 'Bigger in age but Smaller in Height 😂'},
      {'path': 'assets/images/photo2.JPG', 'caption': 'The Best Siblings Trio ✨'},
      {'path': 'assets/images/photo3.jpg', 'caption': 'Rakshabandhan 2K23 🤌'},
      {'path': 'assets/images/photo4.jpg', 'caption': 'Chocolate barfi 😋'},
      {'path': 'assets/images/photo5.jpg', 'caption': 'Me: Ghosting 👻 in your photos'},
      {'path': 'assets/images/photo6.jpg', 'caption': '1000s of photos 🖼 in 1 outfit '},
      {'path': 'assets/images/photo7.jpg', 'caption': 'Dhoti Outfit 💃'},
      {'path': 'assets/images/photo8.jpg', 'caption': 'Rakshabandhan 2K24 🧿'},
      {'path': 'assets/images/photo9.JPG', 'caption': 'Our sleepy 😪 Ghar ke yuva 🤪'},
      {'path': 'assets/images/photo10.JPG', 'caption': 'Hinch levi 6 ne mare garbe ghumvu 6, dholidaaa... 💃'},

    ];

    return ToranPhotoGallery(
      photos: photoList,
      onComplete: () {
        _playClickSound();
        _autoAdvanceStep();
      },
    );
  }

  // --- MODULE 6: RUNAWAY BUTTON & OVERRIDE TRAP MODAL ---
  // --- MODULE 6: RUNAWAY BUTTON & OVERRIDE TRAP MODAL ---
  Widget _buildRunawayButtonSection() {
    const double areaHeight = 240.0;
    const double buttonWidth = 90.0;
    const double buttonHeight = 45.0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Will it be ok if I don't give a Rakshabandhan gift?",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final containerSize = Size(constraints.maxWidth, areaHeight);

                // Set initial centered position next to the YES button
                _noBtnTop ??= (areaHeight / 2) - (buttonHeight / 2);
                _noBtnLeft ??= (constraints.maxWidth / 2) + 15;

                return Container(
                  height: areaHeight,
                  width: double.infinity,
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCE4EC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFD1DC), width: 2),
                  ),
                  child: Stack(
                    children: [
                      // YES BUTTON (Shifted slightly left to make room for NO button)
                      Positioned(
                        top: (areaHeight / 2) - (buttonHeight / 2),
                        left: (constraints.maxWidth / 2) - buttonWidth - 15,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFA8E6CF),
                            fixedSize: const Size(buttonWidth, buttonHeight),
                          ),
                          onPressed: () => _showOverrideTrapModal(),
                          child: const Text("Yes", style: TextStyle(color: Colors.black)),
                        ),
                      ),

                      // TELEPORTING NO BUTTON (Starts neatly aligned next to YES)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 120),
                        curve: Curves.easeOut,
                        top: _noBtnTop!.clamp(10.0, areaHeight - buttonHeight - 10.0),
                        left: _noBtnLeft!.clamp(10.0, max(10.0, constraints.maxWidth - buttonWidth - 10.0)),
                        child: MouseRegion(
                          onEnter: (_) => _teleportNoButton(containerSize),
                          onHover: (_) => _teleportNoButton(containerSize),
                          child: GestureDetector(
                            onTap: () => _teleportNoButton(containerSize),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF5252),
                                fixedSize: const Size(buttonWidth, buttonHeight),
                              ),
                              onPressed: () => _teleportNoButton(containerSize),
                              child: const Text("No", style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Generates a fresh "(a × b) + (c ÷ d) - e = ?" style question with a clean
  // integer answer, so the human-verification quiz is different every time.
  Map<String, dynamic> _generateMathQuestion() {
    final int a = 5 + _random.nextInt(11); // 5-15
    final int b = 5 + _random.nextInt(11); // 5-15
    final int divisor = 2 + _random.nextInt(11); // 2-12
    final int multiplier = 2 + _random.nextInt(9); // 2-10
    final int dividend = divisor * multiplier; // ensures a clean division
    final int subtractor = 5 + _random.nextInt(16); // 5-20

    final int answer = (a * b) + multiplier - subtractor;
    final String question = "($a × $b) + ($dividend ÷ $divisor) - $subtractor = ?";

    return {'question': question, 'answer': answer};
  }

  // --- OVERRIDE TRAP MODAL ---
  void _showOverrideTrapModal() {
    _playClickSound();
    double progressValue = 0.0;
    String percentageDisplay = "0%";
    bool isLoadingComplete = false;

    bool showMathQuiz = false;
    final TextEditingController answerController = TextEditingController();
    String mathErrorMessage = "";

    // A new random question is generated every time this modal is opened.
    final Map<String, dynamic> mathQuestion = _generateMathQuestion();
    final String mathQuestionText = mathQuestion['question'] as String;
    final int mathCorrectAnswer = mathQuestion['answer'] as int;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void startSlowLoadingAnimation() async {
              // Phase 1: 1% to 99% (Steady crawl)
              for (int i = 1; i <= 99; i++) {
                await Future.delayed(const Duration(milliseconds: 150));
                if (!context.mounted) return;
                setModalState(() {
                  progressValue = i / 100.0;
                  percentageDisplay = "$i%";
                });
              }

              // Phase 2: 99.1% to 99.9% (Single decimals - slowing down)
              for (int i = 1; i <= 9; i++) {
                await Future.delayed(const Duration(milliseconds: 1200));
                if (!context.mounted) return;
                final double val = 99.0 + (i / 10.0);
                setModalState(() {
                  progressValue = val / 100.0;
                  percentageDisplay = "${val.toStringAsFixed(1)}%";
                });
              }

              // Phase 3: 99.91% to 99.99% (Double decimals - painful crawl)
              for (int i = 1; i <= 9; i++) {
                await Future.delayed(const Duration(milliseconds: 1600));
                if (!context.mounted) return;
                final double val = 99.90 + (i / 100.0);
                setModalState(() {
                  progressValue = val / 100.0;
                  percentageDisplay = "${val.toStringAsFixed(2)}%";
                });
              }

              // Brief pause at 99.99% before hitting 100%
              await Future.delayed(const Duration(seconds: 4));
              if (!context.mounted) return;

              // Phase 4: Finally 100%!
              setModalState(() {
                progressValue = 1.0;
                percentageDisplay = "100%";
                isLoadingComplete = true;
                showMathQuiz = true;
              });
            }

            if (progressValue == 0.0 && !isLoadingComplete) {
              startSlowLoadingAnimation();
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                showMathQuiz ? "🧮 Human Verification Required" : "Whatever! 🤷‍♂️",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!showMathQuiz) ...[
                      const Text(
                        "Did you really think I won't give you a gift? There is a Gift for You!",
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      LinearProgressIndicator(
                        value: progressValue,
                        minHeight: 12,
                        borderRadius: BorderRadius.circular(6),
                        backgroundColor: const Color(0xFFEEEEEE),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF8DA1)),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Gift is loading... ($percentageDisplay)",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFFD81B60),
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        "Please do not close or refresh this page...",
                        style: TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
                      ),
                    ] else ...[
                      const Text(
                        "Solve the question to claim gift:\n(Take your time! 🐼)",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFDD0),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFA8E6CF)),
                        ),
                        child: Text(
                          mathQuestionText,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: answerController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: "Enter answer",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                      if (mathErrorMessage.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          mathErrorMessage,
                          style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 13),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              actions: [
                if (showMathQuiz)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA8E6CF)),
                    onPressed: () {
                      _playClickSound();
                      if (answerController.text.trim() == mathCorrectAnswer.toString()) {
                        Navigator.pop(context);
                        _triggerAnnoyingConfirmationDialogs(1);
                      } else {
                        setModalState(() {
                          mathErrorMessage = "Incorrect answer! Think carefully 🤔";
                        });
                      }
                    },
                    child: const Text("Submit Answer", style: TextStyle(color: Colors.black)),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // --- ANNOYING CONFIRMATION SEQUENCE ---
  void _triggerAnnoyingConfirmationDialogs(int step) {
    _playClickSound();
    String title = "";
    if (step == 1) title = "Are you sure?";
    if (step == 2) title = "Are you REALLY sure?";
    if (step == 3) title = "Final answer?";

    if (step <= 3) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(title),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _triggerAnnoyingConfirmationDialogs(step + 1);
              },
              child: const Text("Yes!"),
            ),
          ],
        ),
      );
    } else {
      _confettiController.play();
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("CONGRATULATIONS! 🎁"),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("🐼", style: TextStyle(fontSize: 80)),
              SizedBox(height: 15),
              Text(
                "Your gift is ready.",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                "REDEMPTION METHOD:\nPlease go ask Father for your gift.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFD32F2F)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Thanks... I guess? 😂"),
            ),
          ],
        ),
      );
    }
  }
}

// ==========================================
// TORAN PHOTO GALLERY MODULE (Hanging String)
// ==========================================
class ToranPhotoGallery extends StatefulWidget {
  final List<Map<String, String>> photos;
  final VoidCallback onComplete;

  const ToranPhotoGallery({
    super.key,
    required this.photos,
    required this.onComplete,
  });

  @override
  State<ToranPhotoGallery> createState() => _ToranPhotoGalleryState();
}

class _ToranPhotoGalleryState extends State<ToranPhotoGallery>
    with SingleTickerProviderStateMixin {
  final PageController _photoPageController = PageController(viewportFraction: 0.85);
  int _activePhotoIndex = 0;
  late AnimationController _swayController;

  @override
  void initState() {
    super.initState();
    _swayController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _photoPageController.dispose();
    _swayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Text(
          "🌸 Memory Toran 🌸",
          style: GoogleFonts.fredoka(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFD81B60),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          "Use arrows or click & drag to view photos",
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 10),

        // TOP TORAN GARLAND STRING WITH LEAVES
        SizedBox(
          height: 30,
          width: double.infinity,
          child: CustomPaint(
            painter: ToranStringPainter(),
          ),
        ),

        // SWINGING PHOTO CAROUSEL WITH DESKTOP ARROWS
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              PageView.builder(
                controller: _photoPageController,
                itemCount: widget.photos.length,
                onPageChanged: (idx) => setState(() => _activePhotoIndex = idx),
                itemBuilder: (context, index) {
                  return AnimatedBuilder(
                    animation: _swayController,
                    builder: (context, child) {
                      final double angle = sin(_swayController.value * pi * 2) *
                          (index % 2 == 0 ? 0.04 : -0.04);

                      return Transform.rotate(
                        angle: angle,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Hanging Thread Line & Clip
                              Container(
                                width: 2,
                                height: 24,
                                color: const Color(0xFF8D6E63),
                              ),
                              Container(
                                width: 16,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD7CCC8),
                                  borderRadius: BorderRadius.circular(2),
                                  border: Border.all(color: const Color(0xFF5D4037)),
                                ),
                              ),
                              const SizedBox(height: 2),

                              // POLAROID CARD FRAME
                              Container(
                                width: 330,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.12),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.asset(
                                        widget.photos[index]['path']!,
                                        height: 270,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            height: 270,
                                            color: const Color(0xFFFFD1DC),
                                            child: const Center(
                                              child: Text(
                                                "🖼️ Photo Here\n(Add to assets/images)",
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFFD81B60),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      widget.photos[index]['caption']!,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.caveat(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),

              // LEFT DESKTOP ARROW
              if (_activePhotoIndex > 0)
                Positioned(
                  left: 10,
                  child: IconButton.filledTonal(
                    color: const Color(0xFFFFD1DC),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFD81B60)),
                    onPressed: () {
                      _photoPageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                ),

              // RIGHT DESKTOP ARROW
              if (_activePhotoIndex < widget.photos.length - 1)
                Positioned(
                  right: 10,
                  child: IconButton.filledTonal(
                    color: const Color(0xFFFFD1DC),
                    icon: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFD81B60)),
                    onPressed: () {
                      _photoPageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),

        // CAROUSEL INDICATOR DOTS
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.photos.length,
                (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _activePhotoIndex == i ? 12 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _activePhotoIndex == i
                    ? const Color(0xFFD81B60)
                    : const Color(0xFFFFD1DC),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // CONTINUE BUTTON
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA8E6CF),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            ),
            onPressed: widget.onComplete,
            child: const Text(
              "Continue to Finale ➔",
              style: TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

// CUSTOM PAINTER FOR DECORATIVE TORAN STRING WITH MANGO LEAVES
class ToranStringPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFFFFB74D)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final leafPaint = Paint()
      ..color = const Color(0xFF81C784)
      ..style = PaintingStyle.fill;

    final marigoldPaint = Paint()
      ..color = const Color(0xFFFF9800)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 5)
      ..quadraticBezierTo(size.width * 0.5, 25, size.width, 5);

    canvas.drawPath(path, linePaint);

    const int count = 9;
    for (int i = 0; i <= count; i++) {
      final double x = (size.width / count) * i;
      final double y = 5 + sin(i / count * pi) * 15;

      canvas.drawCircle(Offset(x, y), 5, marigoldPaint);

      final leafPath = Path()
        ..moveTo(x, y + 2)
        ..quadraticBezierTo(x - 6, y + 12, x, y + 18)
        ..quadraticBezierTo(x + 6, y + 12, x, y + 2)
        ..close();

      canvas.drawPath(leafPath, leafPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- HELPER COMPONENTS ---
class FlipCard extends StatefulWidget {
  final String frontText;
  final String backText;

  const FlipCard({super.key, required this.frontText, required this.backText});

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard> {
  bool _showFront = true;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _showFront = !_showFront),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: _showFront ? const Color(0xFFA8E6CF) : const Color(0xFFFFD1DC),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(12),
        alignment: Alignment.center,
        child: Text(
          _showFront ? widget.frontText : widget.backText,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class AvatarGlowWrapper extends StatelessWidget {
  final Widget child;
  final bool isGlowing;

  const AvatarGlowWrapper({super.key, required this.child, required this.isGlowing});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: isGlowing
            ? [
          const BoxShadow(
            color: Color(0xFFFF8DA1),
            spreadRadius: 8,
            blurRadius: 10,
          )
        ]
            : [],
      ),
      child: child,
    );
  }
}