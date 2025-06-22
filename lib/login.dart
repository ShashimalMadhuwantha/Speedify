import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'sprinter_dashboard.dart';
import 'SprinterSignUp.dart';

class SprinterLogin extends StatefulWidget {
  @override
  _SprinterLoginState createState() => _SprinterLoginState();
}

class _SprinterLoginState extends State<SprinterLogin> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _loading = false;
  String _error = '';

  Future<void> _loginSprinter() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final querySnapshot = await _firestore
          .collection('sprinters')
          .where('email', isEqualTo: _emailController.text.trim())
          .where('password', isEqualTo: _passwordController.text.trim())
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _error = 'Invalid email or password';
        });
      } else {
        final sprinterDoc = querySnapshot.docs.first;
        final sprinterId = sprinterDoc.id;

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Login successful!"),
          backgroundColor: Colors.green,
        ));

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SprinterDashboard(sprinterId: sprinterId),
          ),
        );
      }
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 40),
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 25,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Vector Illustration - replace with your own SVG or image asset
                    Container(
                        height: 150,
                        child: Image.network(
                          'https://cdn-icons-png.flaticon.com/512/295/295128.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    Text(
                      'Speedify',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: blueColor,
                        letterSpacing: 2,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Login to your account',
                      style: TextStyle(
                        fontSize: 18,
                        color: blueColor.withOpacity(0.8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 30),

                    if (_error.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: Text(
                          _error,
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),

                    _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      validatorMsg: 'Please enter your email',
                    ),
                    SizedBox(height: 20),
                    _buildTextField(
                      controller: _passwordController,
                      label: 'Password',
                      obscureText: true,
                      validatorMsg: 'Please enter your password',
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
                                  _loginSprinter();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: blueColor,
                                foregroundColor: white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                elevation: 7,
                                shadowColor: blueColor.withOpacity(0.5),
                              ),
                              child: Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                    SizedBox(height: 25),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            color: blueColor.withOpacity(0.8),
                            fontSize: 15,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => SprinterSignUp()),
                            );
                          },
                          child: Text(
                            'Sign Up',
                            style: TextStyle(
                              color: blueColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

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
        labelStyle: TextStyle(
          color: Color(0xFF1565C0),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        filled: true,
        fillColor: Colors.blue.shade50,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.blue.shade100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Color(0xFF1565C0), width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      ),
    );
  }
}
