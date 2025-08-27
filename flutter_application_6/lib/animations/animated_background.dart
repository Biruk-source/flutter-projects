// @dart=2.17

import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedBackground extends StatefulWidget {
  final double touchX;
  final double touchY;
  final bool isTouched;

  const AnimatedBackground({
    super.key,
    required this.touchX,
    required this.touchY,
    required this.isTouched,
  });

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  final random = math.Random();
  final List<Offset> dotPositions = [];
  final List<double> dotSpeeds = [];
  final List<String> foodEmojis = [];
  final int numDots = 15;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < numDots; i++) {
      dotPositions
          .add(Offset(random.nextDouble() * 1000, random.nextDouble() * 1000));
      dotSpeeds.add(random.nextDouble() * 2 + 1);
      foodEmojis.add(_getRandomFoodEmoji());
    }
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getRandomFoodEmoji() {
    final foodEmojiList = [
  '🍔', // Hamburger
  '🍟', // French Fries
  '🍕', // Pizza
  '🌭', // Hot Dog
  '🍗', // Chicken Drumstick
  '🍖', // Meat on Bone
  '🍤', // Fried Shrimp
  '🍣', // Sushi (fast snack!)
  '🍱', // Bento Box
  '🍙', // Rice Ball
  '🍘', // Rice Cracker
  '🍥', // Fish Cake
  '🍜', // Ramen
  '🍝', // Spaghetti
  '🍛', // Curry Rice
  '🍲', // Hot Pot
  '🍳', // Fried Egg (fast breakfast)
  '🥓', // Bacon
  '🥚', // Egg
  '🍞', // Bread
  '🥐', // Croissant
  '🥖', // Baguette
  '🥞', // Pancakes
  '🧀', // Cheese
  '🥪', // Sandwich
  '🌮', // Taco
  '🌯', // Burrito
  '🥙', // Stuffed Flatbread
  '🍿', // Popcorn
  '🥨', // Pretzel
  '🍩', // Donut
  '🍪', // Cookie
  '🍫', // Chocolate Bar
  '🍬', // Candy
  '🍭', // Lollipop
  '🍮', // Custard
  '🍦', // Soft Serve Ice Cream
  '🍨', // Ice Cream
  '🍧', // Shaved Ice
  '🎂', // Cake
  '🥧', // Pie
  '🧁', // Cupcake
  '🍰', // Shortcake
  '🍉', // Watermelon (snack fruit)
  '🍊', // Orange
  '🍋', // Lemon
  '🍌', // Banana
  '🍍', // Pineapple
  '🍎', // Red Apple
  '🍏', // Green Apple
  '🍐', // Pear
  '🍑', // Peach
  '🍒', // Cherries
  '🍓', // Strawberry
  '🍇', // Grapes
  '🥝', // Kiwi
  '🍅', // Tomato (technically a snack!)
  '🥑', // Avocado
  '🥕', // Carrot (snack stick)
  '🥔', // Potato (think fries or chips)
  '🍠', // Roasted Sweet Potato
  '🥜', // Peanuts
  '🌰', // Chestnut
  '🥥', // Coconut
  '🥐', // Croissant (again, because snacks!)
  '🥯', // Bagel
  '🥙', // Stuffed Flatbread (repeat for variety)
  '🍔', // Hamburger (doubling up on classics)
  '🍟', // French Fries (more fries!)
  '🍕', // Pizza (can’t have too much)
  '🍗', // Chicken Drumstick (more chicken!)
  '🍔', // Another Burger
  '🍟', // More Fries
  '🍕', // More Pizza
  '🌭', // Hot Dog (again!)
  '🍿', // Popcorn (snack staple)
  '🍩', // Donut (sweet snack)
  '🍪', // Cookie (more sweets)
  '🍫', // Chocolate Bar (again)
  '🍬', // Candy (can’t stop)
  '🍭', // Lollipop (sweet treat)
  '🍦', // Soft Serve (cool snack)
  '🧂', // Salt (for fries or popcorn)
  '🥤', // Soda (fast food drink)
  '🍹', // Cocktail (adult snack vibe)
  '🍺', // Beer (pairs with snacks)
  '🥃', // Whiskey (adult twist)
  '☕', // Coffee (quick pick-me-up)
  '🍵', // Tea (if that’s your snack vibe)
  '🥛', // Milk (for cookies)
  '🧃', // Juice Box
  '🍯', // Honey (sweet snack topping)
  '🥄', // Spoon (for ice cream or custard)
  '🍴', // Fork (for cake or pie)
  '🥢', // Chopsticks (for sushi or ramen)
  '🍽️', // Plate (for all this food!)
];
    return foodEmojiList[random.nextInt(foodEmojiList.length)];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return CustomPaint(
          painter: _BackgroundPainter(
            animation: _animationController,
            dotPositions: dotPositions,
            dotSpeeds: dotSpeeds,
            foodEmojis: foodEmojis,
            touchX: widget.touchX,
            touchY: widget.touchY,
            isTouched: widget.isTouched,
            context: context,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  final Animation<double> animation;
  final List<Offset> dotPositions;
  final List<double> dotSpeeds;
  final List<String> foodEmojis;
  final double touchX;
  final double touchY;
  final bool isTouched;
  final BuildContext context;

  _BackgroundPainter({
    required this.animation,
    required this.dotPositions,
    required this.dotSpeeds,
    required this.foodEmojis,
    required this.touchX,
    required this.touchY,
    required this.isTouched,
    required this.context,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Dynamic Gradient Background
    final baseGradientPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color.fromARGB(255, 148, 184, 239).withOpacity(0.8),
          Colors.purple.shade900.withOpacity(0.8),
        ],
        begin: Alignment(
          animation.value * 2 - 1,
          animation.value * 2 - 1,
        ),
        end: Alignment(
          2 - animation.value * 2,
          2 - animation.value * 2,
        ),
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      baseGradientPaint,
    );

    // Glowing Lines Effect
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 0.5;

    for (int i = 0; i < 20; i++) {
      final offset = (animation.value * size.width) % (size.width / 20);
      canvas.drawLine(
        Offset(i * (size.width / 20) - offset, 0),
        Offset(i * (size.width / 20) - offset, size.height),
        linePaint,
      );
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < dotPositions.length; i++) {
      var position = dotPositions[i];
      final speed = dotSpeeds[i];
      final emoji = foodEmojis[i];

      // Apply burst effect when touched
      if (isTouched) {
        final dx = position.dx - touchX;
        final dy = position.dy - touchY;
        final distance = math.sqrt(dx * dx + dy * dy);
        const maxDistance = 200.0;

        if (distance < maxDistance) {
          final angle = math.atan2(dy, dx);
          final force = (1 - distance / maxDistance) * 20;
          position = Offset(
            position.dx + math.cos(angle) * force,
            position.dy + math.sin(angle) * force,
          );
        }
      }

      // Add glow effect
      final glowPaint = Paint()
        ..color = Colors.white.withOpacity(0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
      canvas.drawCircle(position, 20, glowPaint);

      // Draw emoji with wave effect
      final wave = math.sin(animation.value * math.pi * 2 + i * 0.5) * 5;
      textPainter.text = TextSpan(
        text: emoji,
        style: TextStyle(
          fontSize: 24 + wave,
          shadows: [
            Shadow(
              color: Colors.white.withOpacity(0.5),
              blurRadius: 8,
            ),
          ],
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        position.translate(-textPainter.width / 2, -textPainter.height / 2),
      );

      // Update positions with continuous movement
      position = Offset(
        (position.dx + math.cos(animation.value * math.pi * 2) * speed) %
            size.width,
        (position.dy + math.sin(animation.value * math.pi * 2) * speed) %
            size.height,
      );
      dotPositions[i] = position;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
