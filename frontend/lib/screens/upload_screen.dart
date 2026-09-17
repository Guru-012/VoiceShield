import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';
import 'analysis_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  PlatformFile? _selectedFile;
  Uint8List? _fileBytes;
  String? _errorMessage;

  Future<void> _pickAudioFile() async {
    try {
      setState(() => _errorMessage = null);
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wav', 'mp3', 'm4a', 'aac', 'ogg', 'flac'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedFile = file;
          _fileBytes = file.bytes;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking file: ${e.toString()}';
      });
    }
  }

  void _startAnalysis() {
    if (_selectedFile == null || _fileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an audio file first.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnalysisScreen(
          audioBytes: _fileBytes!,
          filename: _selectedFile!.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileSizeKb = _selectedFile != null
        ? (_selectedFile!.size / 1024).toStringAsFixed(1)
        : '0';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Audio File'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Select Voice Recording',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose a voice clip (.wav, .mp3, .m4a) to analyze for synthetic voice cloning and scam indicators.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 32),

            // Dropzone / File Picker Card
            InkWell(
              onTap: _pickAudioFile,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                decoration: BoxDecoration(
                  color: AppTheme.cardSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _selectedFile != null ? AppTheme.cyanAccent : AppTheme.cardBorder,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _selectedFile != null ? Icons.audio_file : Icons.cloud_upload_outlined,
                      size: 64,
                      color: _selectedFile != null ? AppTheme.cyanAccent : AppTheme.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _selectedFile != null ? _selectedFile!.name : 'Tap to Browse Audio File',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _selectedFile != null ? AppTheme.textPrimary : AppTheme.cyanAccent,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedFile != null
                          ? 'Size: $fileSizeKb KB'
                          : 'Supports WAV, MP3, M4A, AAC (Max 25MB)',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppTheme.dangerRed, fontSize: 13),
              ),
            ],

            const SizedBox(height: 32),

            // Analyze Action Button
            ElevatedButton.icon(
              onPressed: _selectedFile != null ? _startAnalysis : null,
              icon: const Icon(Icons.shield_outlined),
              label: const Text('Analyze Voice File'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
            ),

            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _pickAudioFile,
              child: Text(_selectedFile != null ? 'Choose Different File' : 'Browse File'),
            ),
          ],
        ),
      ),
    );
  }
}
