import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Record extends StatefulWidget {
  final String storeId;
  final String userId;

  const Record({
    super.key,
    required this.storeId,
    required this.userId,
  });

  @override
  State<Record> createState() => _RecordState();
}

class _RecordState extends State<Record> {
  // Servicios y controladores
  final _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ImagePicker _picker = ImagePicker();
  final supabase = Supabase.instance.client;
  final TextEditingController _commentsController = TextEditingController();

  // Estado local
  String? _audioPath;
  File? _imageFile;
  XFile? _attachedFile;
  String? _attachedFileName;
  XFile? _audioXFile;

  bool isRecording = false;
  bool isPlaying = false;
  Duration _recordingDuration = Duration.zero;
  Duration _audioDuration = Duration.zero;
  late final String reporteId;
  final _uuid = const Uuid();

  final Map<String, bool> _observations = {
    'Tienda cerrada': false,
    'Productos dañados': false,
    'Productos no disponibles': false,
    'Atención': false,
  };

  @override
  void initState() {
    super.initState();
    reporteId = _uuid.v4();
    _setupAudioPlayer();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _commentsController.dispose();
    _cleanupAudioFile();
    super.dispose();
  }

  // Configuración del reproductor
  void _setupAudioPlayer() {
    _audioPlayer.playerStateStream.listen((state) {
      setState(() => isPlaying = state.playing);
    });
    _audioPlayer.durationStream.listen((duration) {
      setState(() => _audioDuration = duration ?? Duration.zero);
    });
  }

  // Limpieza de archivo de audio temporal (solo móvil/desktop)
  Future<void> _cleanupAudioFile() async {
    if (_audioPath != null && !kIsWeb) {
      try {
        final f = File(_audioPath!);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  // Conversión a WAV (solo móvil/desktop)
  Future<String> _convertToWav(String inputPath) async {
    final tmpDir = await getTemporaryDirectory();
    final outputPath = '${tmpDir.path}/${_uuid.v4()}.wav';
    final cmd = '-y -i "$inputPath" -ar 44100 -ac 1 "$outputPath"';
    await FFmpegKit.execute(cmd);
    return outputPath;
  }

  // Selección de imagen
  Future<void> _pickImageFromGallery() async {
    try {
      final img = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (img != null) setState(() => _imageFile = File(img.path));
    } catch (e) {
      _showError('Error al seleccionar imagen: $e');
    }
  }

  // Selección de documento genérico
  Future<void> _pickDocument() async {
    try {
      final type = XTypeGroup(
        label: 'docs',
        extensions: ['pdf', 'doc', 'docx', 'txt', 'csv', 'xlsx'],
      );
      final file = await openFile(acceptedTypeGroups: [type]);
      if (file != null) {
        setState(() {
          _attachedFile = file;
          _attachedFileName = file.name;
        });
      }
    } catch (e) {
      _showError('Error al adjuntar archivo: $e');
    }
  }

  // Selección de audio desde almacenamiento con web-fix y conversión móvil
  Future<void> _pickAudioFile() async {
    try {
      final type = XTypeGroup(
        label: 'audio',
        extensions: ['wav', 'mp3', 'm4a', 'aac', 'ogg'],
      );
      final file = await openFile(acceptedTypeGroups: [type]);
      if (file == null) return;
      _audioXFile = file;

      if (kIsWeb) {
        final decodedUri = Uri.decodeFull(file.path);
        await _audioPlayer.setUrl(decodedUri);
        setState(() {
          _audioPath = decodedUri;
          _audioDuration = _audioPlayer.duration ?? Duration.zero;
        });
      } else {
        final inputPath = file.path;
        final wavPath = inputPath.toLowerCase().endsWith('.wav')
            ? inputPath
            : await _convertToWav(inputPath);
        await _audioPlayer.setFilePath(wavPath);
        setState(() {
          _audioPath = wavPath;
          _audioDuration = _audioPlayer.duration ?? Duration.zero;
        });
      }
    } catch (e) {
      _showError('Error al adjuntar audio: $e');
    }
  }

  // Grabación de audio
  Future<void> _startRecording() async {
    if (!await _audioRecorder.hasPermission()) {
      _showError('No tienes permisos para grabar audio');
      return;
    }
    final dir = await getTemporaryDirectory();
    final rawPath = '${dir.path}/${_uuid.v4()}.wav';
    await _audioRecorder.start(
      RecordConfig(
        encoder: AudioEncoder.wav,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: rawPath,
    );
    setState(() {
      isRecording = true;
      _audioPath = rawPath;
    });
    _updateRecordingTimer();
  }

  // Detener grabación y (en móvil) convertir a WAV
  Future<void> _stopRecording() async {
    await _audioRecorder.stop();
    setState(() => isRecording = false);
    if (_audioPath != null && !kIsWeb) {
      final wav = await _convertToWav(_audioPath!);
      await _audioPlayer.setFilePath(wav);
      setState(() {
        _audioPath = wav;
        _audioDuration = _audioPlayer.duration ?? Duration.zero;
      });
    } else if (_audioPath != null && kIsWeb) {
      await _audioPlayer.setUrl(_audioPath!);
    }
  }

  // Timer de grabación
  void _updateRecordingTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!isRecording) return;
      setState(() => _recordingDuration += const Duration(seconds: 1));
      _updateRecordingTimer();
    });
  }

  // Reproducir / pausar audio
  Future<void> _playPauseAudio() async {
    if (_audioPath == null) return;
    isPlaying ? await _audioPlayer.pause() : await _audioPlayer.play();
  }

  // Envío del reporte
  Future<void> _submitReport() async {
    if (_imageFile == null &&
        _audioPath == null &&
        _attachedFile == null) {
      _showError('Debes agregar imagen, audio o un archivo');
      return;
    }
    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    String? imageUrl, audioUrl, fileUrl, resumen;

    // Subir imagen
    if (_imageFile != null) {
      final b = await _imageFile!.readAsBytes();
      final name =
          '${widget.userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supabase.storage
          .from('tuali-plus-images')
          .uploadBinary(name, b, fileOptions: const FileOptions(contentType: 'image/jpeg'));
      imageUrl = supabase.storage.from('tuali-plus-images').getPublicUrl(name);
    }

    // Subir y clasificar audio
    if (_audioPath != null) {
      try {
        // 1. Leer bytes
        Uint8List bytes;
        if (kIsWeb && _audioXFile != null) {
          bytes = await _audioXFile!.readAsBytes();
        } else {
          bytes = await File(_audioPath!).readAsBytes();
        }

        // 2. Generar nombre único y subir
        final fileName =
            '${widget.userId}_${DateTime.now().millisecondsSinceEpoch}.wav';
        final uploadedPath = await supabase.storage
            .from('tuali-plus-audios')
            .uploadBinary(
              fileName,
              bytes,
              fileOptions:
                  const FileOptions(contentType: 'audio/wav', upsert: false),
            );
        audioUrl = supabase.storage
            .from('tuali-plus-audios')
            .getPublicUrl(uploadedPath);

        // 3. Clasificación de audio
        final resp = await http.post(
          Uri.parse('http://localhost:3001/audio-clasificar'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'audioUrl': audioUrl,
            'punto_id': widget.storeId,
          }),
        );
        if (resp.statusCode == 200) {
          final Map<String, dynamic> data =
              json.decode(resp.body) as Map<String, dynamic>;
          resumen = data['texto'] as String;
        }
      } catch (e) {
        _showError('Error subiendo o clasificando audio: $e');
      }
    }

    // Subir documento genérico
    if (_attachedFile != null) {
      final b = await File(_attachedFile!.path).readAsBytes();
      final name =
          '${widget.userId}_${DateTime.now().millisecondsSinceEpoch}_${_attachedFileName}';
      await supabase.storage
          .from('tuali-plus-files')
          .uploadBinary(name, b, fileOptions: FileOptions(contentType: _attachedFile!.mimeType));
      fileUrl = supabase
          .storage.from('tuali-plus-files')
          .getPublicUrl(name);
    }

    // Insertar en DB
    await supabase.from('reportes').insert({
      'id': reporteId,
      'punto_de_venta_id': widget.storeId,
      'usuario_id': widget.userId,
      'image_url': imageUrl,
      'audio_url': audioUrl,
      'observations': _observations,
      'comments': _commentsController.text,
      'resumen': resumen,
    });

    // Cerrar indicador de carga
    Navigator.of(context).pop();

    // Mostrar pop-up de éxito
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('¡Éxito!'),
        content: const Text('Tu reporte se ha enviado correctamente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    // (Opcional) Limpiar campos o navegar
  }

  // Helpers
  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reporte ${reporteId.substring(0, 8)}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Foto del establecimiento
            const Text(
              'Foto del establecimiento',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_imageFile == null)
              Row(children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final img = await _picker.pickImage(source: ImageSource.camera);
                    if (img != null) setState(() => _imageFile = File(img.path));
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Cámara'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _pickImageFromGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galería'),
                ),
              ])
            else
              Stack(alignment: Alignment.topRight, children: [
                Image.file(_imageFile!, height: 200, fit: BoxFit.cover),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => setState(() => _imageFile = null),
                ),
              ]),

            const SizedBox(height: 24),

            // Reporte de audio
            const Text(
              'Reporte de audio',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  border: Border.all(), borderRadius: BorderRadius.circular(8)),
              child: Column(children: [
                if (_audioPath == null && !isRecording) ...[
                  Row(children: [
                    ElevatedButton.icon(
                      onPressed: _startRecording,
                      icon: const Icon(Icons.mic),
                      label: const Text('Grabar'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _pickAudioFile,
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Adjuntar'),
                    ),
                  ]),
                ] else if (isRecording) ...[
                  Text('Grabando... ${_formatDuration(_recordingDuration)}'),
                  ElevatedButton.icon(
                    onPressed: _stopRecording,
                    icon: const Icon(Icons.stop),
                    label: const Text('Detener'),
                  ),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Duración: ${_audioDuration.inSeconds}s'),
                      IconButton(
                        icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                        onPressed: _playPauseAudio,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => setState(() => _audioPath = null),
                      ),
                    ],
                  ),
                ]
              ]),
            ),

            const SizedBox(height: 24),

            // Adjuntar archivo genérico
            const Text(
              'Adjuntar archivo',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(children: [
              ElevatedButton.icon(
                onPressed: _pickDocument,
                icon: const Icon(Icons.attach_file),
                label: const Text('Seleccionar'),
              ),
              const SizedBox(width: 12),
              if (_attachedFileName != null)
                Expanded(
                  child: Text(_attachedFileName!, overflow: TextOverflow.ellipsis),
                ),
              if (_attachedFileName != null)
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => setState(() {
                    _attachedFile = null;
                    _attachedFileName = null;
                  }),
                ),
            ]),

            const SizedBox(height: 24),

            // Observaciones
            const Text(
              'Observaciones',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ..._observations.entries.map((e) {
              return CheckboxListTile(
                title: Text(e.key),
                value: e.value,
                onChanged: (v) => setState(() => _observations[e.key] = v!),
              );
            }).toList(),

            const SizedBox(height: 16),

            // Comentarios adicionales
            const Text(
              'Comentarios adicionales',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentsController,
              maxLines: 3,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),

            const SizedBox(height: 24),

            // Botón Enviar
            Center(
              child: ElevatedButton.icon(
                onPressed: _submitReport,
                icon: const Icon(Icons.send),
                label: const Text('Enviar reporte'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
