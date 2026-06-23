import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DeveloperDetailsScreen extends StatelessWidget {
  const DeveloperDetailsScreen({Key? key}) : super(key: key);

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'About Developer',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Background Gradient decoration
          Container(
            height: 300,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark 
                    ? [const Color(0xFF2C3E50), const Color(0xFF000000)]
                    : [const Color(0xFF4E6AF3), const Color(0xFF2AB673)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Developer Profile Card
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    shadowColor: Colors.black.withOpacity(0.2),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                      child: Column(
                        children: [
                          // Profile Image with styled container border
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4E6AF3), Color(0xFF2AB673)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4E6AF3).withOpacity(0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const CircleAvatar(
                              radius: 54,
                              backgroundImage: NetworkImage(
                                'https://avatars.githubusercontent.com/u/103583078?s=400&u=80572f8430b374171aaa46ee2d9c67c3b62c3b65&v=4',
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Navin Kumar',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Flutter Developer',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: (isDark ? const Color(0xFF4E6AF3) : const Color(0xFF2AB673)).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.bolt,
                                  color: isDark ? const Color(0xFF4E6AF3) : const Color(0xFF2AB673),
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'SpeedShare Creator',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? const Color(0xFF4E6AF3) : const Color(0xFF2AB673),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 16),
                          // Email action card
                          InkWell(
                            onTap: () => _launchUrl('mailto:kumarnavinverma7@gmail.com'),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey[900] : Colors.grey[100],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4E6AF3).withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.email_outlined,
                                      color: Color(0xFF4E6AF3),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Email Me',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'kumarnavinverma7@gmail.com',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Social Connections Header
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0, bottom: 12),
                      child: Text(
                        'Connect With Me',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.grey[800],
                        ),
                      ),
                    ),
                  ),
                  // Social tiles
                  _buildSocialCard(
                    title: 'GitHub Profile',
                    subtitle: '@navin280123',
                    icon: Icons.code_rounded,
                    url: 'https://github.com/navin280123',
                    color: const Color(0xFF24292E),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildSocialCard(
                    title: 'LinkedIn Network',
                    subtitle: 'Navin Kumar Verma',
                    icon: Icons.business_center_rounded,
                    url: 'https://www.linkedin.com/in/navin-kumar-verma/',
                    color: const Color(0xFF0A66C2),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildSocialCard(
                    title: 'Instagram',
                    subtitle: '@navin.2801',
                    icon: Icons.camera_alt_rounded,
                    url: 'https://www.instagram.com/navin.2801/',
                    color: const Color(0xFFE1306C),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String url,
    required Color color,
    required bool isDark,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _launchUrl(url),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
