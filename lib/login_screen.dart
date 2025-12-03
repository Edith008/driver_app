import 'package:flutter/material.dart';
import 'home_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
	return Scaffold(
	  backgroundColor: const Color(0xFF126ABC),
	  body: SingleChildScrollView(
		child: Padding(
		  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 50),
		  child: Column(
			mainAxisAlignment: MainAxisAlignment.center,
			children: [
			  SizedBox(
          height: 300,
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
          ),
        ),
			  const SizedBox(height: 40),
			  Container(
				padding: const EdgeInsets.all(30),
				decoration: BoxDecoration(
				  color: Colors.white.withOpacity(0.5),
				  borderRadius: BorderRadius.circular(8),
				),
				child: Column(
				  children: [
					TextField(
				decoration: InputDecoration(
				  hintText: 'Nombre',
				  filled: true,
				  fillColor: Colors.white,
				  border: OutlineInputBorder(
					borderRadius: BorderRadius.circular(12),
					borderSide: BorderSide.none,
				  ),
				  prefixIcon: const Icon(Icons.person),
				),
			  ),
			  const SizedBox(height: 20),
			  TextField(
				obscureText: true,
				decoration: InputDecoration(
				  hintText: 'Contraseña',
				  filled: true,
				  fillColor: Colors.white,
				  border: OutlineInputBorder(
					borderRadius: BorderRadius.circular(12),
					borderSide: BorderSide.none,
				  ),
				  prefixIcon: const Icon(Icons.lock),
				),
			  ),
			  const SizedBox(height: 30),
			  SizedBox(
				width: double.infinity,
				child: ElevatedButton(
				  onPressed: () {
					Navigator.pushReplacement(
					  context,
					  MaterialPageRoute(
						builder: (context) => const HomeScreen(),
					  ),
					);
				  },
				  style: ElevatedButton.styleFrom(
					backgroundColor: const Color(0xFF126ABC),
					foregroundColor: Colors.white,
					padding: const EdgeInsets.symmetric(vertical: 14),
					shape: RoundedRectangleBorder(
					  borderRadius: BorderRadius.circular(12),
					),
				  ),
				  child: const Text(
					'Iniciar sesión',
					style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
				  ),
				),
			  ),
				  ],
				),
			  ),
			],
		  ),
		),
	  ),
	);
  }
}