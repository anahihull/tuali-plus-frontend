import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


class Record extends StatefulWidget {
  final String storeId;
  final String userId;

  const Record({super.key, required this.storeId, required this.userId});

  @override
  State<Record> createState() => _RecordState();
}

class _RecordState extends State<Record> {
  final _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _commentsController = TextEditingController();

  String? _audioPath;
  File? _imageFile;
  bool isRecording = false;
  bool isPlaying = false;
  Duration _recordingDuration = Duration.zero;
  Duration _audioDuration = Duration.zero;
  late final String reporteId;

  // Observaciones generales
  final Map<String, bool> _observations = {
    'Tienda cerrada': false,
    'Productos dañados': false,
    'Productos no disponibles': false,
    'Atención': false,
  };

  @override
  void initState() {
    super.initState();
    reporteId = const Uuid().v4();
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    _audioPlayer.playerStateStream.listen((state) {
      setState(() {
        isPlaying = state.playing;
      });
    });

    _audioPlayer.durationStream.listen((duration) {
      setState(() {
        _audioDuration = duration ?? Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _commentsController.dispose();
    _cleanupAudioFile();
    super.dispose();
  }

  Future<void> _cleanupAudioFile() async {
    if (_audioPath != null) {
      try {
        final file = File(_audioPath!);
        if (await file.exists()) await file.delete();
      } catch (e) {
        debugPrint('Error cleaning up audio file: $e');
      }
    }
  }

  Future<void> _takePicture() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
        });
      }
    } catch (e) {
      _showError('Error al tomar la foto: $e');
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        final now = DateTime.now();
        final formattedDate = '${now.year}-${now.month}-${now.day}_${now.hour}-${now.minute}-${now.second}';
        final path = '${directory.path}/$formattedDate.wav';

        await _audioRecorder.start(
          RecordConfig(
            encoder: AudioEncoder.wav,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: path,
        );

        setState(() {
          isRecording = true;
          _audioPath = path;
          _recordingDuration = Duration.zero;
        });

        // Actualizar duración cada segundo
        _startRecordingTimer();
      } else {
        _showError('No tienes permisos para grabar audio');
      }
    } catch (e) {
      _showError('Error al comenzar grabación: $e');
    }
  }

  void _startRecordingTimer() {
    if (isRecording) {
      Future.delayed(const Duration(seconds: 1), () {
        if (isRecording) {
          setState(() {
            _recordingDuration = Duration(seconds: _recordingDuration.inSeconds + 1);
          });
          _startRecordingTimer();
        }
      });
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _audioRecorder.stop();
      setState(() {
        isRecording = false;
      });
    } catch (e) {
      _showError('Error al detener grabación: $e');
    }
  }

  Future<void> _playRecording() async {
    try {
      if (_audioPath != null) {
        if (isPlaying) {
          await _audioPlayer.pause();
        } else {
          await _audioPlayer.setFilePath(_audioPath!);
          await _audioPlayer.play();
        }
      }
    } catch (e) {
      _showError('Error al reproducir: $e');
    }
  }

  Future<void> _submitReport() async {
  try {
    // Validar que tenga al menos una foto o audio
    if (_imageFile == null && _audioPath == null) {
      _showError('Debes agregar al menos una foto o grabación de audio');
      return;
    }

    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    String? imageUrl;
    String? audioUrl;
    String? resumen;

    // Subir imagen si existe
    if (_imageFile != null) {
      final imageBytes = await _imageFile!.readAsBytes();
      final imageName = '${widget.userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      await supabase.storage.from('tuali-plus-images').uploadBinary(
        imageName,
        imageBytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );
      
      imageUrl = supabase.storage.from('tuali-plus-images').getPublicUrl(imageName);
    }

    // Subir audio si existe
    if (_audioPath != null) {
      final audioFile = File(_audioPath!);
      final audioBytes = await audioFile.readAsBytes();
      final audioName = '${widget.userId}_${DateTime.now().millisecondsSinceEpoch}.wav';

      await supabase.storage.from('tuali-plus-audios').uploadBinary(
        audioName,
        audioBytes,
        fileOptions: const FileOptions(contentType: 'audio/wav'),
      );

      audioUrl = supabase.storage.from('tuali-plus-audios').getPublicUrl(audioName);

      // Llamar al endpoint de clasificación de audio
      try {
        debugPrint('🔄 Enviando audio para clasificación...');
        final response = await http.post(
          Uri.parse('http://localhost:3001/audio-clasificar'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'audioUrl': audioUrl,
            'punto_id': widget.storeId,
          }),
        );

        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          resumen = responseData['texto'];
          debugPrint('✅ Clasificación completada: ${resumen?.substring(0, 50)}...');
        } else {
          debugPrint('⚠️ Error en clasificación: ${response.statusCode}');
          // Continuar sin resumen si falla la clasificación
        }
      } catch (e) {
        debugPrint('❌ Error al clasificar audio: $e');
        // Continuar sin resumen si falla la clasificación
      }
    }

      // Guardar reporte en la base de datos
      await supabase.from('reportes').insert({
        'id': reporteId,
        'punto_de_venta_id': widget.storeId,
        'usuario_id': widget.userId,
        'image_url': imageUrl,
        'audio_url': audioUrl,
        'observations': _observations,
        'comments': _commentsController.text,
        'resumen': resumen
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reporte enviado correctamente'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      _showError('Error al enviar el reporte: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Reporte${reporteId.substring(0, 1).toUpperCase()}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.menu, color: Colors.white, size: 16),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sección de foto
            _buildPhotoSection(),
            const SizedBox(height: 30),
            
            // Sección de audio
            _buildAudioSection(),
            const SizedBox(height: 30),
            
            // Observaciones generales
            _buildObservationsSection(),
            const SizedBox(height: 20),
            
            // Comentarios adicionales
            _buildCommentsSection(),
            const SizedBox(height: 30),
            
            // Botón enviar reporte
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      children: [
        if (_imageFile == null) ...[
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt_outlined, size: 48, color: Colors.grey[600]),
                const SizedBox(height: 8),
                const Text(
                  'Toma una foto del establecimiento',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Asegúrate que no esté borrosa',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _takePicture,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Tomar foto'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ] else ...[
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: FileImage(_imageFile!),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _takePicture,
                icon: const Icon(Icons.edit),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: () {
                  setState(() {
                    _imageFile = null;
                  });
                },
                icon: const Icon(Icons.delete, color: Colors.red),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildAudioSection() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            children: [
              if (_audioPath == null && !isRecording) ...[
                Icon(Icons.mic_outlined, size: 48, color: Colors.grey[600]),
                const SizedBox(height: 8),
                const Text(
                  'Graba tu reporte en audio',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Asegúrate decir palabras clave sobre el estatus',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _startRecording,
                  icon: const Icon(Icons.mic),
                  label: const Text('Iniciar grabación'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ] else if (isRecording) ...[
                const Text(
                  'Grabando...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatDuration(_recordingDuration),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: _stopRecording,
                        icon: const Icon(Icons.pause, color: Colors.white, size: 32),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: _stopRecording,
                        icon: const Icon(Icons.stop, size: 32),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const Text(
                  'Grabación lista',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tiempo de grabación:',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  _formatDuration(_recordingDuration),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _playRecording,
                    icon: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Escuchar audio',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _startRecording,
                      icon: const Icon(Icons.edit),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _audioPath = null;
                          _recordingDuration = Duration.zero;
                        });
                      },
                      icon: const Icon(Icons.delete, color: Colors.red),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildObservationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Observaciones generales',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Selecciona todas las que apliquen',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        ..._observations.keys.map((observation) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Checkbox(
                  value: _observations[observation],
                  onChanged: (value) {
                    setState(() {
                      _observations[observation] = value ?? false;
                    });
                  },
                  activeColor: Colors.orange,
                ),
                Text(observation),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildCommentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Comentarios adicionales',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _commentsController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Escribe aquí tus comentarios...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _submitReport,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Enviar reporte',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward),
          ],
        ),
      ),
    );
  }
}
