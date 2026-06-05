import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SecureWindow.setEnabled(true);
  runApp(const MyApp());
}

class SecureWindow {
  static const MethodChannel _channel = MethodChannel(
    'safelogin/secure_window',
  );

  static Future<void> setEnabled(bool enabled) async {
    await _channel.invokeMethod<void>('setSecure', enabled);
  }

  static Future<bool> detectFakeLocation() async {
    return await _channel.invokeMethod<bool>('detectFakeLocation') ?? false;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String usuarioSistema = 'admin';
  static const String contrasenaSistema = '1234';

  final TextEditingController _usuarioController = TextEditingController();
  final TextEditingController _contrasenaController = TextEditingController();

  bool accesoBloqueado = false;
  bool cargando = true;
  String mensajeBloqueo = 'Acceso bloqueado por ubicacion falsa';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      verificarFakeGPS();
    });
  }

  Future<void> verificarFakeGPS() async {
    final PermissionStatus status = await _solicitarPermisoUbicacion();

    if (status.isGranted) {
      try {
        final bool isFake = await SecureWindow.detectFakeLocation();

        debugPrint('--- DEBUG GPS --- Es falso?: $isFake');

        if (!mounted) return;
        setState(() {
          accesoBloqueado = isFake;
          cargando = false;
        });
      } catch (e) {
        debugPrint('Error en verificacion: $e');
        if (!mounted) return;
        setState(() {
          cargando = false;
        });
      }
    } else {
      if (!mounted) return;
      setState(() {
        accesoBloqueado = true;
        cargando = false;
        mensajeBloqueo =
            'Se requieren permisos de ubicacion para asegurar el entorno.';
      });
    }
  }

  Future<PermissionStatus> _solicitarPermisoUbicacion() async {
    final PermissionStatus status = await Permission.locationWhenInUse.status;

    if (status.isGranted) {
      return status;
    }

    return Permission.locationWhenInUse.request();
  }

  void _iniciarSesion() {
    final String usuario = _usuarioController.text.trim();
    final String contrasena = _contrasenaController.text;

    if (usuario == usuarioSistema && contrasena == contrasenaSistema) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const HomeScreen(usuario: usuarioSistema),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Usuario o contrasena incorrectos')),
    );
  }

  @override
  void dispose() {
    _usuarioController.dispose();
    _contrasenaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text(
                'Validando entorno seguro...',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (accesoBloqueado) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.gpp_bad, size: 80, color: Colors.red),
                const SizedBox(height: 20),
                Text(
                  mensajeBloqueo,
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Login Seguro')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              TextField(
                controller: _usuarioController,
                decoration: const InputDecoration(
                  labelText: 'Usuario',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _contrasenaController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contrasena',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _iniciarSesion(),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _iniciarSesion,
                child: const Text('Ingresar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.usuario});

  final String usuario;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Duration tiempoInactividad = Duration(seconds: 10);

  Timer? _temporizadorInactividad;
  int _contador = 0;

  @override
  void initState() {
    super.initState();
    _reiniciarTemporizador();
  }

  void _reiniciarTemporizador() {
    _temporizadorInactividad?.cancel();
    _temporizadorInactividad = Timer(tiempoInactividad, _cerrarSesion);
  }

  void _registrarActividad([Object? _]) {
    _reiniciarTemporizador();
  }

  void _sumarPulsacion() {
    _registrarActividad();
    setState(() {
      _contador++;
    });
  }

  void _cerrarSesion() {
    if (!mounted) return;

    _temporizadorInactividad?.cancel();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );

    messenger.showSnackBar(
      const SnackBar(content: Text('Sesion cerrada por inactividad')),
    );
  }

  @override
  void dispose() {
    _temporizadorInactividad?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _registrarActividad,
      onPointerMove: _registrarActividad,
      onPointerSignal: _registrarActividad,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pantalla principal'),
          actions: [
            IconButton(
              tooltip: 'Cerrar sesion',
              onPressed: _cerrarSesion,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Bienvenido, ${widget.usuario}',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Text(
                  'Haz pulsado este boton $_contador veces',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _sumarPulsacion,
                  icon: const Icon(Icons.touch_app),
                  label: const Text('Pulsar boton'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
