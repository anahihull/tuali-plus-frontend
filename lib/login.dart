import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signup.dart';

class Login extends StatefulWidget {
  const Login({Key? key}) : super(key: key);

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _empleadoController = TextEditingController();
  final _passwordController = TextEditingController();
  final supabase = Supabase.instance.client;

  bool _loading = false;
  String? _error;

  /// 1) Obtiene el email a partir del empleado_id desde la tabla 'perfiles'
  Future<String?> _getEmailFromEmpleadoId(String empleadoId) async {
    final res = await supabase
        .from('perfiles')
        .select('email')
        .eq('empleado_id', empleadoId)
        .maybeSingle();

    // Si no hay fila, retornamos null
    if (res == null) {
      return null;
    }

    final data = res as Map<String, dynamic>;
    return data['email'] as String?;
  }

  /// 2) Inicia sesión usando empleado_id y contraseña
  Future<void> _loginWithEmpleadoId() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final empleadoId = _empleadoController.text.trim();
    final password = _passwordController.text;

    try {
      // 2.1) Obtener email
      final email = await _getEmailFromEmpleadoId(empleadoId);
      if (email == null) {
        setState(() {
          _error = 'Empleado no encontrado o sin permiso de lectura';
          _loading = false;
        });
        return;
      }

      // 2.2) Intentar login con email recuperado
      final res = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.user == null) {
        setState(() {
          _error = 'Credenciales incorrectas o usuario no encontrado';
          _loading = false;
        });
        return;
      }

      // 2.4) Login exitoso → navegamos al dashboard
      Navigator.pushReplacementNamed(context, '/dashboard');
    } catch (e) {
      setState(() {
        _error = 'Ocurrió un error inesperado: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _empleadoController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                const Text(
                  'Tuali++',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _empleadoController,
                  decoration: const InputDecoration(labelText: 'Empleado ID'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '¿Olvidaste tu contraseña?',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _loginWithEmpleadoId,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Iniciar Sesión',
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignUp()),
                    );
                  },
                  child: const Text.rich(
                    TextSpan(
                      text: '¿No tienes cuenta? ',
                      children: [
                        TextSpan(
                          text: 'Crear una',
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      style: TextStyle(color: Colors.black87),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
