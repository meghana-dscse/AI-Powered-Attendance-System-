import 'dart:convert';
import 'dart:io'; // Required for using the 'File' type
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

// A simple class to hold student data. This makes the code cleaner.
class Student {
  final String rollNo;
  final String name;

  Student({required this.rollNo, required this.name});

  // A factory constructor to create a Student from JSON
  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      rollNo: json['roll_no'].toString(), // Ensure rollNo is treated as a string
      name: json['name'] as String,
    );
  }

  // Needed to compare students to find who is absent
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Student &&
          runtimeType == other.runtimeType &&
          rollNo == other.rollNo;

  @override
  int get hashCode => rollNo.hashCode;
}

void main() {
  runApp(const AttendifyApp());
}

class AttendifyApp extends StatelessWidget {
  const AttendifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendify',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 1,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
              color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      // The app now starts at the LoginPage
      home: const LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- NEW: Login Page Widget ---
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController(text: 'teacher');
  final _passwordController = TextEditingController(text: 'password');
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Simple hardcoded login logic for demonstration
      Future.delayed(const Duration(seconds: 1), () {
        if (_usernameController.text == 'teacher' && _passwordController.text == 'password') {
          // Use pushReplacement to prevent the user from going back to the login screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AttendancePage()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid username or password.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Icon(Icons.school, size: 80, color: Colors.indigo),
                const SizedBox(height: 16),
                const Text(
                  'Welcome to Attendify',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please sign in to continue',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) => value!.isEmpty ? 'Please enter a username' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (value) => value!.isEmpty ? 'Please enter a password' : null,
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                        child: const Text('Login'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  _AttendancePageState createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final String _apiUrl = 'http://192.168.188.127:5000';
  bool _isLoading = false;
  Uint8List? _resultImageBytes;
  List<Student> _presentStudents = [];
  List<Student> _absentStudents = [];
  String _statusMessage = 'Please select an image to mark attendance.';

  Future<void> _pickAndProcessImage(ImageSource source) async {
    setState(() {
      _isLoading = true;
      _resultImageBytes = null;
      _presentStudents = [];
      _absentStudents = [];
      _statusMessage = 'Uploading and processing...';
    });

    try {
      final picker = ImagePicker();
      final pickedFile =
          await picker.pickImage(source: source, imageQuality: 70);
      if (pickedFile == null) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'No image selected.';
        });
        return;
      }
      var request =
          http.MultipartRequest('POST', Uri.parse('$_apiUrl/mark_attendance'));
      request.files
          .add(await http.MultipartFile.fromPath('file', pickedFile.path));
      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<Student> allStudents = (data['all_students'] as List)
            .map((s) => Student.fromJson(s))
            .toList();
        final List<Student> presentStudents = (data['present_students'] as List)
            .map((s) => Student.fromJson(s))
            .toList();
        final Set<Student> presentStudentsSet = presentStudents.toSet();
        final List<Student> absentStudents =
            allStudents.where((s) => !presentStudentsSet.contains(s)).toList();

        setState(() {
          _presentStudents = presentStudents;
          _absentStudents = absentStudents;
          _resultImageBytes = base64Decode(data['annotated_image']);
          _statusMessage = 'Attendance marked successfully!';
        });
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        setState(() {
          _statusMessage =
              'Server Error: ${errorData['error'] ?? response.reasonPhrase}';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage =
            'Connection Failed. Please check server status and IP address.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToAddStudentPage() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => AddStudentPage(apiUrl: _apiUrl)),
    ).then((value) {
      // This refreshes the main page when you come back, in case a new student was added.
      setState(() {
         _statusMessage = "Select an image to see updated student lists.";
         _resultImageBytes = null;
         _presentStudents = [];
         _absentStudents = [];
      });
    });
  }

  void _logout() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendify'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade100,
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _resultImageBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(11.0),
                          child: Image.memory(_resultImageBytes!, fit: BoxFit.cover),
                        )
                      : Center(
                          child: Text(_statusMessage, textAlign: TextAlign.center),
                        ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickAndProcessImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                ),
                ElevatedButton.icon(
                  onPressed: () => _pickAndProcessImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Present Students (${_presentStudents.length})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            _presentStudents.isEmpty && !_isLoading
                ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: Text('No students identified yet.')))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _presentStudents.length,
                    itemBuilder: (context, index) {
                      final student = _presentStudents[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green[100],
                            child: const Icon(Icons.check_circle, color: Colors.green),
                          ),
                          title: Text(student.name),
                          subtitle: Text('Roll No: ${student.rollNo}'),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 24),
            Text(
              'Absent Students (${_absentStudents.length})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            _absentStudents.isEmpty && _presentStudents.isNotEmpty && !_isLoading
                ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: Text('All registered students are present.')))
                : _absentStudents.isEmpty && _presentStudents.isEmpty && !_isLoading
                  ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: Text('No attendance data yet.')))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _absentStudents.length,
                      itemBuilder: (context, index) {
                        final student = _absentStudents[index];
                        return Card(
                          color: Colors.red[50],
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.red[100],
                              child: const Icon(Icons.person_off, color: Colors.red),
                            ),
                            title: Text(student.name),
                            subtitle: Text('Roll No: ${student.rollNo}'),
                          ),
                        );
                      },
                    ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddStudentPage,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Student'),
        backgroundColor: Colors.indigo,
      ),
    );
  }
}

class AddStudentPage extends StatefulWidget {
  final String apiUrl;
  const AddStudentPage({super.key, required this.apiUrl});

  @override
  _AddStudentPageState createState() => _AddStudentPageState();
}

class _AddStudentPageState extends State<AddStudentPage> {
  final _formKey = GlobalKey<FormState>();
  final _rollNoController = TextEditingController();
  final _nameController = TextEditingController();
  File? _studentImage;
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile != null) {
      setState(() {
        _studentImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitStudent() async {
    if (_formKey.currentState!.validate() && _studentImage != null) {
      setState(() {
        _isUploading = true;
      });

      try {
        var request = http.MultipartRequest(
            'POST', Uri.parse('${widget.apiUrl}/add_student'));
        request.fields['roll_no'] = _rollNoController.text;
        request.fields['name'] = _nameController.text;
        request.files.add(
            await http.MultipartFile.fromPath('file', _studentImage!.path));

        final streamedResponse =
            await request.send().timeout(const Duration(seconds: 30));
        final response = await http.Response.fromStream(streamedResponse);
        final data = json.decode(response.body);

        if (response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(data['success']), backgroundColor: Colors.green),
          );
          if (mounted) Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error: ${data['error']}'),
                backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to connect to server.'),
              backgroundColor: Colors.red),
        );
      } finally {
        setState(() {
          _isUploading = false;
        });
      }
    } else if (_studentImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select an image.'),
            backgroundColor: Colors.orange),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register New Student'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade100,
                  ),
                  child: _studentImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.file(_studentImage!, fit: BoxFit.cover),
                        )
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo,
                                  size: 50, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Tap to select a photo'),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _rollNoController,
                decoration: const InputDecoration(
                    labelText: 'Roll Number', border: OutlineInputBorder()),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a roll number' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                    labelText: 'Full Name', border: OutlineInputBorder()),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 32),
              _isUploading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      onPressed: _submitStudent,
                      icon: const Icon(Icons.app_registration),
                      label: const Text('Register Student'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}