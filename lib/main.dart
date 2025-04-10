import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart' as record;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';

void main() {
  runApp(const MacRecorderApp());
}

class MacRecorderApp extends StatelessWidget {
  const MacRecorderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mac Audio Recorder',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final TranscriptionService _transcriptionService = TranscriptionService();
  bool _isRecording = false;
  String? _currentRecordingPath;
  List<String> _recordings = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRecordings();
  }

  Future<void> _loadRecordings() async {
    try {
      final recordings = await _audioRecorder.getRecordings();
      setState(() {
        _recordings = recordings;
      });
    } catch (e) {
      _showSnackBar('Error loading recordings: $e');
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // Stop recording
      try {
        await _audioRecorder.stopRecording();
        setState(() {
          _isRecording = false;
        });
        _showSnackBar('Recording saved');
        _loadRecordings();
      } catch (e) {
        _showSnackBar('Error stopping recording: $e');
      }
    } else {
      // Start recording
      try {
        final path = await _audioRecorder.startRecording();
        setState(() {
          _isRecording = true;
          _currentRecordingPath = path;
        });
        _showSnackBar('Recording started');
      } catch (e) {
        _showSnackBar('Error starting recording: $e');
      }
    }
  }

  Future<void> _transcribeRecording(String filePath) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _transcriptionService.transcribeAudio(filePath);
      _showSnackBar('Transcription complete');
      _loadRecordings(); // Refresh list to show new transcription files
    } catch (e) {
      _showSnackBar('Error during transcription: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _getFileName(String path) {
    return path.split('/').last;
  }

  bool _isAudioFile(String path) {
    return path.toLowerCase().endsWith('.m4a');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mac Audio Recorder'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Recording status and controls
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8.0),
            ),
            margin: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isRecording ? Icons.mic : Icons.mic_off,
                      color: _isRecording ? Colors.red : Colors.grey,
                      size: 48.0,
                    ),
                    const SizedBox(width: 16.0),
                    Text(
                      _isRecording ? 'Recording...' : 'Not Recording',
                      style: const TextStyle(
                        fontSize: 24.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _toggleRecording,
                      icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                      label: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isRecording ? Colors.red : Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 12.0,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () {
                              // Show dialog to select file for transcription
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Select Recording to Transcribe'),
                                  content: SizedBox(
                                    width: double.maxFinite,
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: _recordings.length,
                                      itemBuilder: (context, index) {
                                        final path = _recordings[index];
                                        if (!_isAudioFile(path)) return const SizedBox.shrink();
                                        
                                        return ListTile(
                                          title: Text(_getFileName(path)),
                                          onTap: () {
                                            Navigator.pop(context);
                                            _transcribeRecording(path);
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                  ],
                                ),
                              );
                            },
                      icon: const Icon(Icons.translate),
                      label: const Text('Transcribe Recording'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 12.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Recordings list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _recordings.length,
                    itemBuilder: (context, index) {
                      final path = _recordings[index];
                      final fileName = _getFileName(path);
                      final isAudio = _isAudioFile(path);
                      final isTranscription = fileName.startsWith('transcribed_');

                      return ListTile(
                        leading: Icon(
                          isAudio ? Icons.audio_file : Icons.text_snippet,
                          color: isAudio ? Colors.blue : Colors.green,
                        ),
                        title: Text(fileName),
                        subtitle: Text(isAudio
                            ? 'Audio Recording'
                            : isTranscription
                                ? 'Transcription'
                                : 'File'),
                        onTap: () async {
                          // Open file in default application
                          try {
                            await Process.run('open', [path]);
                          } catch (e) {
                            _showSnackBar('Error opening file: $e');
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadRecordings,
        tooltip: 'Refresh',
        child: const Icon(Icons.refresh),
      ),
    );
  }
  
  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }
}
class AudioRecorder {
  final recorder = record.AudioRecorder();
  final String _directoryName = 'macrecorder';
  
  Future<String> get _directoryPath async {
    final homeDir = Platform.environment['HOME'] ?? '/Users/${Platform.environment['USER']}';
    final directory = Directory('$homeDir/Documents/$_directoryName');
    
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    
    return directory.path;
  }
  
  Future<String> startRecording() async {
    // Request permission
    if (!await recorder.hasPermission()) {
      throw Exception('Microphone permission not granted');
    }
    
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final path = '${await _directoryPath}/recording_$timestamp.m4a';
    
    await recorder.start(
      const record.RecordConfig(
        encoder: record.AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );
    
    return path;
  }
  
  Future<void> stopRecording() async {
    if (await recorder.isRecording()) {
      await recorder.stop();
    }
  }
  
  Future<List<String>> getRecordings() async {
    final directory = Directory(await _directoryPath);
    
    if (!await directory.exists()) {
      return [];
    }
    
    final files = await directory.list().toList();
    return files.map((file) => file.path).toList()..sort((a, b) => b.compareTo(a));
  }
  
  void dispose() {
    recorder.dispose();
  }
}

class TranscriptionService {
  Future<String> transcribeAudio(String audioFilePath) async {
    final file = File(audioFilePath);
    if (!await file.exists()) {
      throw Exception('Audio file not found');
    }
    
    // Mock transcription text
    final mockTranscript = '''
Mock transcription for: ${file.path.split('/').last}
Generated at: ${DateTime.now()}
This is a placeholder transcription. In a real implementation, 
this would contain the actual transcribed text from your audio file.
''';
    
    // Save mock transcription to file
    await _saveTranscription(audioFilePath, mockTranscript);
    
    return mockTranscript;
  }
  
  Future<void> _saveTranscription(String audioFilePath, String transcriptText) async {
    try {
      final fileName = audioFilePath.split('/').last;
      final timestamp = fileName.split('_')[1].split('.')[0]; // Extract timestamp
      final directoryPath = audioFilePath.substring(0, audioFilePath.lastIndexOf('/'));
      
      final transcriptionPath = '$directoryPath/transcribed_$timestamp.txt';
      final file = File(transcriptionPath);
      await file.writeAsString(transcriptText);
    } catch (e) {
      throw Exception('Failed to save transcription: $e');
    }
  }
}
