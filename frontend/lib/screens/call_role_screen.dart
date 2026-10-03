import 'package:flutter/material.dart';

import 'real_call_screen.dart';

class CallRoleScreen extends StatelessWidget {
  const CallRoleScreen({super.key});

  // ============================================================
  // OPEN PERSON A
  // ============================================================

  void _selectPersonA(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const RealCallScreen(
          clientId: 'person_a',
          role: 'A',
        ),
      ),
    );
  }

  // ============================================================
  // OPEN PERSON B
  // ============================================================

  void _selectPersonB(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const RealCallScreen(
          clientId: 'person_b',
          role: 'B',
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080D1A),

      appBar: AppBar(
        backgroundColor: const Color(0xFF080D1A),
        elevation: 0,

        centerTitle: true,

        title: const Text(
          'VoiceShield Call',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),

          child: Column(
            children: [
              const SizedBox(height: 30),

              // ==================================================
              // SHIELD ICON
              // ==================================================

              Container(
                width: 100,
                height: 100,

                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  color: Colors.cyanAccent.withValues(
                    alpha: 0.12,
                  ),

                  border: Border.all(
                    color: Colors.cyanAccent.withValues(
                      alpha: 0.5,
                    ),
                    width: 2,
                  ),
                ),

                child: const Icon(
                  Icons.shield,
                  color: Colors.cyanAccent,
                  size: 55,
                ),
              ),

              const SizedBox(height: 30),

              // ==================================================
              // TITLE
              // ==================================================

              const Text(
                'Choose Your Role',
                textAlign: TextAlign.center,

                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Select which person this device will represent during the VoiceShield call.',
                textAlign: TextAlign.center,

                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 40),

              // ==================================================
              // PERSON A
              // ==================================================

              _roleCard(
                context: context,

                title: 'PERSON A',

                subtitle:
                    'Caller / Sender',

                description:
                    'This device will act as Person A and can initiate the call to Person B.',

                icon: Icons.person,

                iconColor: Colors.cyanAccent,

                clientId: 'person_a',

                onTap: () {
                  _selectPersonA(context);
                },
              ),

              const SizedBox(height: 20),

              // ==================================================
              // PERSON B
              // ==================================================

              _roleCard(
                context: context,

                title: 'PERSON B',

                subtitle:
                    'Receiver / Listener',

                description:
                    'This device will act as Person B and wait for Person A to initiate the call.',

                icon: Icons.person_outline,

                iconColor: Colors.orangeAccent,

                clientId: 'person_b',

                onTap: () {
                  _selectPersonB(context);
                },
              ),

              const SizedBox(height: 35),

              // ==================================================
              // INFO
              // ==================================================

              Container(
                width: double.infinity,

                padding: const EdgeInsets.all(18),

                decoration: BoxDecoration(
                  color: const Color(0xFF111827),

                  borderRadius:
                      BorderRadius.circular(16),

                  border: Border.all(
                    color: Colors.white12,
                  ),
                ),

                child: const Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.cyanAccent,
                      size: 22,
                    ),

                    SizedBox(width: 12),

                    Expanded(
                      child: Text(
                        'For testing, run Person A and Person B on separate devices or terminals. Each device must use a different client ID.',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ROLE CARD
  // ============================================================

  Widget _roleCard({
    required BuildContext context,

    required String title,

    required String subtitle,

    required String description,

    required IconData icon,

    required Color iconColor,

    required String clientId,

    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,

      borderRadius:
          BorderRadius.circular(22),

      child: Container(
        width: double.infinity,

        padding: const EdgeInsets.all(22),

        decoration: BoxDecoration(
          color: const Color(0xFF131D33),

          borderRadius:
              BorderRadius.circular(22),

          border: Border.all(
            color: iconColor.withValues(
              alpha: 0.5,
            ),

            width: 1.5,
          ),
        ),

        child: Column(
          children: [
            // ==================================================
            // ICON
            // ==================================================

            Container(
              width: 75,
              height: 75,

              decoration: BoxDecoration(
                shape: BoxShape.circle,

                color: iconColor.withValues(
                  alpha: 0.12,
                ),
              ),

              child: Icon(
                icon,

                color: iconColor,

                size: 40,
              ),
            ),

            const SizedBox(height: 18),

            // ==================================================
            // TITLE
            // ==================================================

            Text(
              title,

              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 5),

            // ==================================================
            // SUBTITLE
            // ==================================================

            Text(
              subtitle,

              style: TextStyle(
                color: iconColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 12),

            // ==================================================
            // DESCRIPTION
            // ==================================================

            Text(
              description,

              textAlign: TextAlign.center,

              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 15),

            // ==================================================
            // CLIENT ID
            // ==================================================

            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 7,
              ),

              decoration: BoxDecoration(
                color: Colors.black26,

                borderRadius:
                    BorderRadius.circular(10),
              ),

              child: Text(
                'Client ID: $clientId',

                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),

            const SizedBox(height: 18),

            // ==================================================
            // CONTINUE BUTTON
            // ==================================================

            SizedBox(
              width: double.infinity,
              height: 50,

              child: ElevatedButton.icon(
                onPressed: onTap,

                icon: Icon(
                  Icons.arrow_forward,
                  color: Colors.black,
                ),

                label: Text(
                  'CONTINUE AS $title',

                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),

                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      iconColor,

                  elevation: 0,

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(13),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}