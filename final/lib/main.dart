import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance App',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AttendancePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  _AttendancePageState createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  // --- SERVER ADDRESS ---
  // This is now correctly set to your computer's IP address.
  final String _apiUrl = 'http://192.168.188.127:5000/mark_attendance';

  bool _isLoading = false;
  Uint8List? _resultImageBytes;
  List<String> _presentStudents = [];
  String _statusMessage = 'Please select an image to mark attendance.';

  // Function to pick an image from gallery or camera
  Future<void> _pickAndProcessImage(ImageSource source) async {
    // Make sure the server is reachable before trying to pick an image
    setState(() {
      _statusMessage = 'Connecting to server...';
    });

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);

    if (pickedFile == null) {
      setState(() {
         _statusMessage = 'No image selected. Please try again.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _resultImageBytes = null;
      _presentStudents = [];
      _statusMessage = 'Uploading and processing...';
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse(_apiUrl));
      request.files.add(
        await http.MultipartFile.fromPath('file', pickedFile.path),
      );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          _presentStudents = List<String>.from(data['present_students'] ?? []);
          _resultImageBytes = base64Decode(data['annotated_image']);
          _statusMessage = 'Attendance marked successfully!';
        });
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        setState(() {
          _statusMessage = 'Server Error: ${errorData['error'] ?? response.reasonPhrase}';
        });
      }
    } catch (e) {
      // Handle network errors (timeout, no connection, wrong IP)
      setState(() {
        _statusMessage = 'Connection Failed. Please check:\n1. Your phone is on the same Wi-Fi as the server.\n2. The IP address is correct.\n3. The server is running.';
        print('Error details: $e');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Attendance System'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, width: 2),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade50,
              ),
              child: Center(
                child: _isLoading
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(_statusMessage, textAlign: TextAlign.center),
                        ],
                      )
                    : _resultImageBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(_resultImageBytes!, fit: BoxFit.contain),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              _statusMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _pickAndProcessImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _pickAndProcessImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Present Students (${_presentStudents.length})',
              style: Theme.of(context).textTheme.headline6,
            ),
            const Divider(),
            _presentStudents.isEmpty && !_isLoading
                ? const Center(child: Text('No students identified yet.'))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _presentStudents.length,
                    itemBuilder: (context, index) {
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Text((index + 1).toString())),
                          title: Text(_presentStudents[index]),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}

