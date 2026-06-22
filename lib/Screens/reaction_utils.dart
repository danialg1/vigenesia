import 'package:flutter/material.dart';

class ReactionUtils {
  static const Map<String, String> reactionEmojis = {
    'like': '👍',
    'love': '❤️',
    'haha': '😂',
    'wow': '😲',
    'sad': '😢',
    'angry': '😡',
  };

  static const Map<String, Color> reactionColors = {
    'like': Colors.blue,
    'love': Colors.red,
    'haha': Colors.orange,
    'wow': Colors.amber,
    'sad': Colors.blueGrey,
    'angry': Colors.redAccent,
  };

  static Widget getReactionIcon(String? reaction, {double size = 20}) {
    if (reaction == null || !reactionEmojis.containsKey(reaction)) {
      return Icon(Icons.thumb_up_alt_outlined, size: size, color: Colors.grey);
    }
    if (reaction == 'like') {
      return Icon(Icons.thumb_up, size: size, color: Colors.blue);
    }
    return Text(
      reactionEmojis[reaction]!,
      style: TextStyle(fontSize: size),
    );
  }

  static String getReactionText(String? reaction) {
    if (reaction == null || !reactionEmojis.containsKey(reaction)) return "Suka";
    switch (reaction) {
      case 'like': return "Suka";
      case 'love': return "Super";
      case 'haha': return "Haha";
      case 'wow': return "Wow";
      case 'sad': return "Sedih";
      case 'angry': return "Marah";
      default: return "Suka";
    }
  }

  static Future<String?> showReactionPicker(BuildContext context, Offset buttonPosition) {
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black12,
      builder: (context) {
        return Stack(
          children: [
            Positioned(
              left: 20,
              right: 20,
              top: buttonPosition.dy > 100 ? buttonPosition.dy - 70 : buttonPosition.dy + 30,
              child: Center(
                child: Material(
                  color: Colors.white,
                  elevation: 8,
                  borderRadius: BorderRadius.circular(30),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: reactionEmojis.keys.map((key) {
                        return GestureDetector(
                          onTap: () => Navigator.pop(context, key),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Transform.scale(
                              scale: 1.5,
                              child: Text(reactionEmojis[key]!),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
