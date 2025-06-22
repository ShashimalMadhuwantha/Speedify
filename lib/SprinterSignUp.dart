import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'login.dart';

class SprinterSignUp extends StatefulWidget {
  @override
  _SprinterSignUpState createState() => _SprinterSignUpState();
}

class _SprinterSignUpState extends State<SprinterSignUp> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _loading = false;
  String _error = '';

  Future<void> _addSprinterData() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      await _firestore.collection('sprinters').add({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'password': _passwordController.text.trim(),
        'createdAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Sprinter added successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      _formKey.currentState?.reset();

      // Redirect to login page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SprinterLogin()),
      );
    } catch (e) {
      setState(() {
        _error = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final blueColor = Color(0xFF1565C0);
    final lightBlue = Color(0xFFBBDEFB);
    final white = Colors.white;

    return Scaffold(
      backgroundColor: lightBlue,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
          child: Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: blueColor.withOpacity(0.2),
                  blurRadius: 15,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🌐 Signup Image
                  Image.network(
                    'https://cdn-icons-png.flaticon.com/512/1157/1157109.png',
                    height: 120,
                  ),
                  SizedBox(height: 20),

                  // 📝 App Title
                  Text(
                    'Speedify',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: blueColor,
                      letterSpacing: 1.5,
                    ),
                  ),
                  SizedBox(height: 10),

                  // ✨ Subtitle
                  Text(
                    'Create your Sprinter account',
                    style: TextStyle(
                      fontSize: 16,
                      color: blueColor.withOpacity(0.7),
                    ),
                  ),
                  SizedBox(height: 30),

                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error,
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  // 🔤 Form fields
                  _buildTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    validatorMsg: 'Enter your name',
                  ),
                  SizedBox(height: 15),

                  _buildTextField(
                    controller: _emailController,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    validatorMsg: 'Enter a valid email',
                  ),
                  SizedBox(height: 15),

                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    keyboardType: TextInputType.phone,
                    validatorMsg: 'Enter your phone number',
                  ),
                  SizedBox(height: 15),

                  _buildTextField(
                    controller: _passwordController,
                    label: 'Password',
                    obscureText: true,
                    validatorMsg: 'Minimum 6 characters required',
                    minLength: 6,
                  ),
                  SizedBox(height: 30),

                  _loading
                      ? CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(blueColor),
                      )
                      : SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              _addSprinterData();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: blueColor,
                            foregroundColor: white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 5,
                          ),
                          child: Text(
                            'Sign Up',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🔧 Custom TextField Builder
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? validatorMsg,
    bool obscureText = false,
    int? minLength,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return validatorMsg;
        }
        if (minLength != null && value.length < minLength) {
          return validatorMsg;
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.blue[900]),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.blue.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      ),
    );
  }
}
