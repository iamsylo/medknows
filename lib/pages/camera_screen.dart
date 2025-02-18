import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:math' as math;  // Add this import
import 'dart:typed_data';
import '../utils/medicine_labels.dart';
import 'package:image_picker/image_picker.dart';  // Add this import at the top
import '../widgets/medicine_details_card.dart';  // Add this import
import '../pages/medicines.dart';  // Add this import

// Add this global key to access CameraScreen state
final GlobalKey<_CameraScreenState> cameraScreenKey = GlobalKey<_CameraScreenState>();

// Add this extension method at the top of the file
extension ListReshape on Uint8List {
  Uint8List reshape(List<int> shape) {
    return this;
  }
}

class CameraScreen extends StatefulWidget {
  CameraScreen({Key? key}) : super(key: key ?? cameraScreenKey);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? cameras;
  int selectedCameraIndex = 0;
  XFile? capturedImage;  // Add this line
  Interpreter? _interpreter;
  List<String>? _labels;
  String? _recognizedMedicine;
  double? _confidence;
  final ImagePicker _picker = ImagePicker();  // Add this property
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Delay initialization to ensure widget is mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeAll();
      }
    });
  }

  Future<void> _initializeAll() async {
    try {
      await Future.wait([
        initializeCamera(),
        loadModel(),
      ]);
      
      _labels = MedicineLabels.getLabels();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
      print('All components initialized successfully');
    } catch (e) {
      print('Initialization error: $e');
    }
  }

  Future<void> initializeCamera() async {
    try {
      cameras = await availableCameras();
      _controller = CameraController(
        cameras![selectedCameraIndex], 
        ResolutionPreset.medium
      );
      await _controller!.initialize();
      if (mounted) setState(() {});
      print('Camera initialized');
    } catch (e) {
      print('Camera initialization error: $e');
      rethrow;
    }
  }

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/final_model.tflite',
        options: InterpreterOptions()
          ..threads = 4
          ..useNnApiForAndroid = true
      );
      print('Model loaded successfully');
      
      var inputShape = _interpreter!.getInputTensor(0).shape;
      var outputShape = _interpreter!.getOutputTensor(0).shape;
      var inputType = _interpreter!.getInputTensor(0).type;
      var outputType = _interpreter!.getOutputTensor(0).type;
      
      print('Input shape: $inputShape, type: $inputType');
      print('Output shape: $outputShape, type: $outputType');
      
    } catch (e) {
      print('Model loading error: $e');
      rethrow;
    }
  }

  Future<void> analyzeImage(String imagePath) async {
    if (!_isInitialized || _interpreter == null || _labels == null) {
      print('System not fully initialized');
      return;
    }

    setState(() {
      _recognizedMedicine = 'Processing...';
      _confidence = null;
    });

    try {
      // Load and preprocess image
      final image = await File(imagePath).readAsBytes();
      final img.Image? decodedImage = img.decodeImage(image);
      
      if (decodedImage == null) throw Exception('Failed to decode image');
      
      final resizedImage = img.copyResize(
        decodedImage,
        width: 224,
        height: 224,
        interpolation: img.Interpolation.linear,
      );

      // Get input and output shapes
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      print('Input shape: $inputShape');
      print('Output shape: $outputShape');

      // Create input tensor buffer
      final inputBuffer = Uint8List(inputShape.reduce((a, b) => a * b));
      var pixelIndex = 0;

      // Fill input buffer with pixel values (no normalization for uint8)
      for (var y = 0; y < 224; y++) {
        for (var x = 0; x < 224; x++) {
          final pixel = resizedImage.getPixel(x, y);
          inputBuffer[pixelIndex++] = img.getRed(pixel);
          inputBuffer[pixelIndex++] = img.getGreen(pixel);
          inputBuffer[pixelIndex++] = img.getBlue(pixel);
        }
      }

      // Create 2D output tensor buffer [1][19]
      final outputBuffer = List.generate(
        outputShape[0],
        (_) => List<int>.filled(outputShape[1], 0),
      );

      try {
        // Run inference with properly shaped tensors
        _interpreter!.run(inputBuffer, outputBuffer);
        
        // Get predictions from first batch
        final predictions = outputBuffer[0];
        print('Raw output: $predictions');

        // Find highest confidence class
        int maxIndex = 0;
        int maxValue = predictions[0];
        
        for (int i = 1; i < predictions.length; i++) {
          if (predictions[i] > maxValue) {
            maxIndex = i;
            maxValue = predictions[i];
          }
        }

        // Convert to percentage (uint8 range: 0-255)
        double confidence = (maxValue / 255.0) * 100;
        print('Detected class: ${_labels![maxIndex]} with confidence: $confidence%');

        if (mounted) {
          setState(() {
            _recognizedMedicine = confidence >= 90.0 
                ? _labels![maxIndex]
                : 'Try again';
            _confidence = confidence;
          });
        }

      } catch (e) {
        print('Inference error: $e');
        throw Exception('Inference failed: $e');
      }

    } catch (e) {
      print('Analysis error: $e');
      if (mounted) {
        setState(() {
          _recognizedMedicine = 'Error analyzing image';
          _confidence = null;
        });
      }
    }
  }

  // Modify the existing takePicture method
  Future<void> takePicture() async {
    // Add additional safety checks
    if (!mounted || 
        _controller == null || 
        !_controller!.value.isInitialized || 
        capturedImage != null ||
        _controller!.value.isTakingPicture) {
      return;
    }
    
    try {
      final XFile image = await _controller!.takePicture();
      if (!mounted) return;
      
      setState(() {
        capturedImage = image;
      });
      
      await analyzeImage(image.path);
      
    } catch (e) {
      print('Error capturing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture image: ${e.toString()}')),
        );
      }
    }
  }

  // Add this method
  Future<void> pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        capturedImage = image;
      });
      await analyzeImage(image.path);
    }
  }

  Future<void> switchCamera() async {
    if (cameras == null || cameras!.isEmpty) return;
    
    selectedCameraIndex = selectedCameraIndex == 0 ? 1 : 0;
    
    await _controller?.dispose();
    
    _controller = CameraController(
      cameras![selectedCameraIndex], 
      ResolutionPreset.medium
    );

    try {
      await _controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      print('Error switching camera: $e');
    }
  }

  void retakePhoto() {
    setState(() {
      capturedImage = null;
    });
  }

  @override
  void dispose() {
    _interpreter?.close();
    _controller?.dispose();
    super.dispose();
  }

  // Add this public method to check camera state
  bool get isCameraReady => 
    mounted && 
    _controller != null && 
    _controller!.value.isInitialized &&
    !_controller!.value.isTakingPicture;

  void _showMedicineDetails(String medicineName) {
    // Find the medicine details from the medicines list
    final medicineDetails = medicines.firstWhere(
      (medicine) => medicine['name'].toLowerCase() == medicineName.toLowerCase(),
      orElse: () => {
        'name': medicineName,
        'genericName': 'Not found',
        'description': 'Medicine information not available',
        'categories': <String>[],
        'image': 'assets/images/medicines/medicine.png',
        'dosage': 'Not available',
        'directions of use': 'Not available',
        'administration': 'Not available',
        'contraindication': 'Not available',
      },
    );

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return MedicineDetailsCard(
          image: medicineDetails['image'],
          name: medicineDetails['name'],
          genericName: medicineDetails['genericName'],
          description: medicineDetails['description'],
          categories: List<String>.from(medicineDetails['categories']),
          dosage: medicineDetails['dosage'],
          directionsOfUse: medicineDetails['directions of use'],
          administration: medicineDetails['administration'],
          contraindication: medicineDetails['contraindication'],
          onClose: () => Navigator.of(context).pop(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!mounted || !_isInitialized || _controller == null || !_controller!.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Camera Preview',
            style: TextStyle(
              color: Colors.blue.withOpacity(1),
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.withOpacity(1)),
                ),
              SizedBox(height: 16),
              Text('Initializing camera and AI model...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          capturedImage == null ? 'Camera Preview' : 'Image Preview',
          style: TextStyle(
            color:Colors.blue.withOpacity(1),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        iconTheme: IconThemeData(
          color:Colors.blue.withOpacity(1),
        ),
        actions: [
          if (capturedImage == null)
            IconButton(
              icon: Icon(Icons.photo_library, color: Colors.blue.withOpacity(1)),
              onPressed: pickImage,
            ),
          if (capturedImage == null)
            IconButton(
              icon: Icon(Icons.flip_camera_ios, color:Colors.blue.withOpacity(1)),
              onPressed: cameras != null && cameras!.length > 1 
                  ? () => switchCamera()  // Update this line
                  : null,
            ),
          if (capturedImage != null)
            IconButton(
              icon: Icon(Icons.refresh, color:Colors.blue.withOpacity(1)),
              onPressed: retakePhoto,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              child: capturedImage == null
                  ? (_controller?.value.isInitialized ?? false)
                      ? CameraPreview(_controller!)
                      : Center(child: CircularProgressIndicator())
                  : Image.file(
                      File(capturedImage!.path),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(child: Text('Error loading image'));
                      },
                    ),
            ),
          ),
          if (capturedImage != null)
            Container(
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              color: Colors.blue.withOpacity(0.1),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Detected Medicine:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _recognizedMedicine ?? 'Processing...',
                          style: TextStyle(
                            fontSize: 16,
                            color: (_confidence ?? 0) >= 90.0 ? Colors.blue : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (_confidence != null && _confidence! >= 90.0)  // Only show confidence if above threshold
                    SizedBox(height: 8),
                  if (_confidence != null && _confidence! >= 90.0)  // Only show confidence if above threshold
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Confidence:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_confidence!.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          Expanded(
            flex: 1,
            child: Container(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    capturedImage == null 
                        ? 'Click the shutter button to take a photo or use gallery icon to upload'
                        : 'Click retake to capture again or continue with this photo',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (capturedImage != null && 
                      _recognizedMedicine != null && 
                      (_confidence ?? 0) >= 90.0)  // Only show button for high-confidence detections
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: ElevatedButton(
                        onPressed: () => _showMedicineDetails(_recognizedMedicine!),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'View Medicine Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
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