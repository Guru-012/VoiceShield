import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'real_call_screen.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  // ================================================================
  // CALL HISTORY
  // ================================================================

  final List<Map<String, dynamic>> _callHistory = [
    {
      'name': 'Person B',
      'type': 'Outgoing',
      'time': 'Today, 5:10 PM',
      'duration': '02:34',
      'status': 'Completed',
    },
    {
      'name': 'Person B',
      'type': 'Incoming',
      'time': 'Today, 3:42 PM',
      'duration': '05:12',
      'status': 'Completed',
    },
    {
      'name': 'Person B',
      'type': 'Outgoing',
      'time': 'Yesterday, 8:21 PM',
      'duration': '01:48',
      'status': 'Completed',
    },
  ];

  // ================================================================
  // PERSON A CALL
  // ================================================================

  void _callPersonB() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RealCallScreen(
          clientId: 'person_a',
          role: 'A',
        ),
      ),
    );
  }

  // ================================================================
  // PERSON B TEST SCREEN
  // ================================================================

  void _openPersonB() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RealCallScreen(
          clientId: 'person_b',
          role: 'B',
        ),
      ),
    );
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        centerTitle: true,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shield_outlined,
              color: AppTheme.cyanAccent,
            ),
            SizedBox(width: 8),
            Text('VoiceShield Calls'),
          ],
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            // ======================================================
            // PERSON A
            // ======================================================

            Card(
              color: AppTheme.cardSurface,

              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(18),

                side: BorderSide(
                  color: AppTheme.cyanAccent
                      .withValues(alpha: 0.7),

                  width: 1.5,
                ),
              ),

              child: Padding(
                padding: const EdgeInsets.all(20),

                child: Column(
                  children: [

                    Container(
                      width: 80,
                      height: 80,

                      decoration: BoxDecoration(
                        shape: BoxShape.circle,

                        color: AppTheme.cyanAccent
                            .withValues(alpha: 0.12),
                      ),

                      child: const Icon(
                        Icons.person,
                        size: 45,
                        color:
                            AppTheme.cyanAccent,
                      ),
                    ),

                    const SizedBox(height: 14),

                    const Text(
                      'Person A',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    const Text(
                      'Caller',
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            AppTheme.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 52,

                      child: ElevatedButton.icon(
                        onPressed:
                            _callPersonB,

                        icon: const Icon(
                          Icons.call,
                          size: 22,
                        ),

                        label: const Text(
                          'CALL PERSON B',

                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              AppTheme.cyanAccent,

                          foregroundColor:
                              Colors.black,

                          elevation: 0,

                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            // ======================================================
            // PERSON B TEST / SECOND DEVICE
            // ======================================================

            Card(
              color: AppTheme.cardSurface,

              child: Padding(
                padding:
                    const EdgeInsets.all(18),

                child: Column(
                  children: [

                    const Icon(
                      Icons.phone_callback,
                      size: 40,
                      color:
                          AppTheme.safeGreen,
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      'Person B Device',

                      style: TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      'Use this on the second device to wait for Person A.',

                      textAlign:
                          TextAlign.center,

                      style: TextStyle(
                        fontSize: 12,
                        color:
                            AppTheme.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 15),

                    SizedBox(
                      width: double.infinity,
                      height: 48,

                      child:
                          OutlinedButton.icon(
                        onPressed:
                            _openPersonB,

                        icon: const Icon(
                          Icons.phone_in_talk,
                        ),

                        label: const Text(
                          'OPEN PERSON B',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ======================================================
            // HISTORY
            // ======================================================

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,

              children: [
                Text(
                  'Call History',

                  style:
                      Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            fontSize: 18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                ),

                Text(
                  '${_callHistory.length} calls',

                  style: const TextStyle(
                    color:
                        AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (_callHistory.isEmpty)
              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.all(25),

                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.call,
                          size: 40,
                          color:
                              AppTheme.textSecondary,
                        ),

                        const SizedBox(
                          height: 10,
                        ),

                        Text(
                          'No calls yet',
                          style:
                              Theme.of(context)
                                  .textTheme
                                  .bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,

                physics:
                    const NeverScrollableScrollPhysics(),

                itemCount:
                    _callHistory.length,

                itemBuilder:
                    (context, index) {

                  final call =
                      _callHistory[index];

                  final bool isIncoming =
                      call['type'] ==
                          'Incoming';

                  return Card(
                    margin:
                        const EdgeInsets.only(
                      bottom: 10,
                    ),

                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),

                      leading: Container(
                        width: 45,
                        height: 45,

                        decoration:
                            BoxDecoration(
                          shape:
                              BoxShape.circle,

                          color: isIncoming
                              ? AppTheme.safeGreen
                                  .withValues(
                                  alpha: 0.15,
                                )
                              : AppTheme.cyanAccent
                                  .withValues(
                                  alpha: 0.15,
                                ),
                        ),

                        child: Icon(
                          isIncoming
                              ? Icons.call_received
                              : Icons.call_made,

                          color: isIncoming
                              ? AppTheme.safeGreen
                              : AppTheme.cyanAccent,
                        ),
                      ),

                      title: Text(
                        call['name'],
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      subtitle: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,

                        children: [
                          const SizedBox(
                              height: 3),

                          Text(
                            '${call['type']} • ${call['time']}',
                            style:
                                const TextStyle(
                              fontSize: 12,
                            ),
                          ),

                          const SizedBox(
                              height: 2),

                          Text(
                            'Duration: ${call['duration']}',
                            style:
                                const TextStyle(
                              fontSize: 11,
                              color: AppTheme
                                  .textSecondary,
                            ),
                          ),
                        ],
                      ),

                      trailing:
                          const Icon(
                        Icons.chevron_right,
                        color: AppTheme
                            .textSecondary,
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}