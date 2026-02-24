import 'package:flutter/material.dart';

// ================= MODEL =================
class TipItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String videoId;

  TipItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.videoId,
  });
}

// ================= VIDEO PAGE =================
class TutorialVideoPage extends StatelessWidget {
  final TipItem tip;
  
  const TutorialVideoPage({super.key, required this.tip});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          tip.title,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          // Video Player Area
          Expanded(
            child: Container(
              color: Colors.grey[900],
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.play_circle_filled,
                      color: Colors.white,
                      size: 80,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Video Tutorial: ${tip.title}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Video player would appear here",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Video Details
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tip.subtitle,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                Text(
                  "This video tutorial will teach you essential techniques for ${tip.title.toLowerCase()}. Follow along with the instructor to master this skill.",
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tip.color,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      "SAVE FOR PRACTICE",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================= MAIN TIPS SCREEN =================
class TipsScreen extends StatelessWidget {
  TipsScreen({super.key});

  final List<TipItem> tips = [
    TipItem(
      title: "Escape Holds",
      subtitle: "Release from grabs",
      icon: Icons.arrow_upward,
      color: const Color(0xFFFF7A7A),
      videoId: "escape_holds_101",
    ),
    TipItem(
      title: "Strike Points",
      subtitle: "Vulnerable areas",
      icon: Icons.flash_on,
      color: const Color(0xFFFFC83D),
      videoId: "strike_points_101",
    ),
    TipItem(
      title: "Ground Defense",
      subtitle: "Get back on feet",
      icon: Icons.directions_walk,
      color: const Color(0xFF6EDDD0),
      videoId: "ground_defense_101",
    ),
    TipItem(
      title: "Weapon Defense",
      subtitle: "Against attackers",
      icon: Icons.shield_outlined,
      color: const Color(0xFF7B5CE6),
      videoId: "weapon_defense_101",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: Column(
        children: [
          // ================= HEADER =================
          Container(
            height: 190,
            width: double.infinity,
            color: const Color(0xFF7B5CE6),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Safety Tips & Self-Defense",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ================= CONTENT =================
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Text(
                        "Self-Defense Training",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(),
                      Chip(
                        label: Text("Beginner"),
                        backgroundColor: Color(0xFFEDE9FE),
                      )
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Master essential techniques with video tutorials",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),

                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: tips.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.78,
                    ),
                    itemBuilder: (context, index) {
                      return TipCard(
                        item: tips[index],
                        onTap: () {
                          // Navigate to video page when card is tapped
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TutorialVideoPage(tip: tips[index]),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= TIP CARD (Now tappable) =================
class TipCard extends StatelessWidget {
  final TipItem item;
  final VoidCallback? onTap;
  
  const TipCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: item.color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.25),
              child: Icon(item.icon, color: Colors.white),
            ),
            const SizedBox(height: 12),

            // Text Content
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Watch Tutorial Button
            Row(
              children: const [
                Icon(Icons.play_circle_fill,
                    color: Colors.white, size: 18),
                SizedBox(width: 6),
                Text(
                  "Watch tutorial",
                  style: TextStyle(color: Colors.white),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}