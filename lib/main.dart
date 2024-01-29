import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(camera: cameras.first));
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;

  const MyApp({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(camera: camera),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final CameraDescription camera;

  const MyHomePage({super.key, required this.camera});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  XFile? _imageFile;
  String _recognizedText = 'Voici votre texte';
  bool _isCameraPreviewShown = true;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.camera, ResolutionPreset.medium);
    _initializeControllerFuture = _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        _isCameraPreviewShown = true;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    try {
      await _initializeControllerFuture;
      final imageFile = await _controller.takePicture();
      setState(() {
        _imageFile = imageFile;
        _recognizedText = '';
        _isCameraPreviewShown = false; // Stop showing the camera preview
      });
    } catch (e) {
      print(e);
    }
  }

  Future<void> requestCameraPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
        Permission.storage,
      ].request();
      final cameraPermissionStatus = statuses[Permission.camera];
      if (cameraPermissionStatus != PermissionStatus.granted) {
        throw Exception('Camera permission not granted');
      }
    }
  }

  Future<void> _recognizeText() async {
    if (_imageFile != null) {
      final inputImage = InputImage.fromFilePath(_imageFile!.path);
      final textDetector = GoogleMlKit.vision.textRecognizer();
      final RecognizedText recognizedText =
          await textDetector.processImage(inputImage);
      await textDetector.close();

      setState(() {
        _recognizedText = recognizedText.text;
      });
    } else {
      print('test');
    }
  }

  Widget _buildCameraPreview() {
    if (_controller.value.isInitialized) {
      return CameraPreview(_controller);
    } else {
      return const Center(child: CircularProgressIndicator());
    }
  }

  Widget _buildImageCard() {
    Widget imageDisplay = _isCameraPreviewShown
        ? _buildCameraPreview()
        : Image.file(File(_imageFile!.path));

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9, // 90% of screen width
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: imageDisplay,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ImgToText')),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildImageCard(),
            if (_imageFile != null && !_isCameraPreviewShown)
              Column(
                children: [
                  ElevatedButton(
                    onPressed: _recognizeText,
                    child: const Text('Transcrire le texte'),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      _recognizedText,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _takePicture,
            tooltip: 'Prendre une photo',
            child: const Icon(Icons.camera_alt),
          ),
          SizedBox(width: 16),
          FloatingActionButton(
            onPressed: () {
              setState(() {
                _imageFile = null;
                _recognizedText = 'Voici votre texte';
                _isCameraPreviewShown = true;
              });
            },
            tooltip: 'Réinitialiser',
            child: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}
