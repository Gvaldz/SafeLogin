import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'auth_service.dart';
import 'profile_screen.dart';
import 'remote_delete_fcm_service.dart';
import 'sensitive_data_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SecureWindow.setEnabled(true);
  await RemoteDeleteFcmService.instance.initialize();
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
  final TextEditingController _usuarioController = TextEditingController();
  final TextEditingController _contrasenaController = TextEditingController();

  bool accesoBloqueado = false;
  bool cargando = true;
  bool autenticando = false;
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

  Future<void> _iniciarSesion() async {
    if (autenticando) {
      return;
    }

    setState(() => autenticando = true);

    final AuthResult resultado = await AuthService.instance.login(
      _usuarioController.text,
      _contrasenaController.text,
    );

    if (!mounted) return;

    if (!resultado.success) {
      setState(() => autenticando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resultado.errorMessage ?? 'Error de autenticacion')),
      );
      return;
    }

    final String userId = resultado.userId!;

    try {
      await SensitiveDataStore.instance.seedForUser(userId);
      await RemoteDeleteFcmService.instance.bindCurrentUser(userId);
    } catch (error) {
      debugPrint('Error al preparar almacenamiento seguro: $error');

      if (!mounted) return;
      setState(() => autenticando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo preparar el almacenamiento seguro'),
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => HomeScreen(usuario: userId),
      ),
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
                onPressed: autenticando ? null : _iniciarSesion,
                child: autenticando
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Ingresar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.usuario,
    this.storage,
    this.remoteDeleteService,
  });

  final String usuario;
  final SensitiveDataRepository? storage;
  final RemoteDeleteFcmService? remoteDeleteService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const Duration tiempoInactividad = Duration(seconds: 120);

  Timer? _temporizadorInactividad;
  late final SensitiveDataRepository _storage;
  late final RemoteDeleteFcmService _remoteDeleteService;
  SensitiveDataSnapshot? _sensitiveData;
  String? _fcmToken;
  String? _lastRemoteDeleteAt;
  bool _cargandoDatosSensibles = true;
  int _contador = 0;

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? SensitiveDataStore.instance;
    _remoteDeleteService =
        widget.remoteDeleteService ?? RemoteDeleteFcmService.instance;
    WidgetsBinding.instance.addObserver(this);
    _remoteDeleteService.lastRemoteDelete.addListener(
      _actualizarDatosSensibles,
    );
    _reiniciarTemporizador();
    _cargarDatosSensibles();
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cargarDatosSensibles();
    }
  }

  Future<void> _cargarDatosSensibles() async {
    final SensitiveDataSnapshot sensitiveData = await _storage
        .readSensitiveData();
    final String? fcmToken = await _storage.readFcmToken();
    final String? lastRemoteDeleteAt = await _storage.readLastRemoteDeleteAt();

    if (!mounted) return;
    setState(() {
      _sensitiveData = sensitiveData;
      _fcmToken = fcmToken;
      _lastRemoteDeleteAt = lastRemoteDeleteAt;
      _cargandoDatosSensibles = false;
    });
  }

  void _actualizarDatosSensibles() {
    _cargarDatosSensibles();

    final RemoteDeleteResult? result =
        _remoteDeleteService.lastRemoteDelete.value;

    if (result != null && result.applied && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos sensibles eliminados remotamente')),
      );
    }
  }

  Future<void> _copiarFcmToken() async {
    final String? token = _fcmToken;

    if (token == null || token.isEmpty) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: token));

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Token FCM copiado')));
  }

  void _cerrarSesion() {
    if (!mounted) return;

    _temporizadorInactividad?.cancel();
    AuthService.instance.logout();
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
    WidgetsBinding.instance.removeObserver(this);
    _remoteDeleteService.lastRemoteDelete.removeListener(
      _actualizarDatosSensibles,
    );
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
              tooltip: 'Ver perfil',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ProfileScreen(usuario: widget.usuario),
                  ),
                );
              },
              icon: const Icon(Icons.person),
            ),
            IconButton(
              tooltip: 'Cerrar sesion',
              onPressed: _cerrarSesion,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
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
                const SizedBox(height: 28),
                _buildSensitiveDataPanel(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSensitiveDataPanel(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: _cargandoDatosSensibles
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.security, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Almacenamiento seguro',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final SensitiveFieldDefinition field
                    in SensitiveDataStore.sensitiveFields)
                  _SensitiveFieldRow(
                    label: field.label,
                    value: _maskedValue(_sensitiveData?.valueFor(field.key)),
                  ),
                const Divider(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _fcmToken == null || _fcmToken!.isEmpty
                            ? 'FCM pendiente de configuracion'
                            : 'FCM ${_tokenPreview(_fcmToken!)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copiar token FCM',
                      onPressed: _fcmToken == null || _fcmToken!.isEmpty
                          ? null
                          : _copiarFcmToken,
                      icon: const Icon(Icons.copy),
                    ),
                  ],
                ),
                if (_lastRemoteDeleteAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Ultimo borrado remoto: $_lastRemoteDeleteAt',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
    );
  }

  String _maskedValue(String? value) {
    if (value == null || value.isEmpty) {
      return 'Eliminado';
    }

    final String suffix = value.length <= 4
        ? value
        : value.substring(value.length - 4);

    return 'Guardado ****$suffix';
  }

  String _tokenPreview(String token) {
    if (token.length <= 24) {
      return token;
    }

    return '${token.substring(0, 12)}...${token.substring(token.length - 8)}';
  }
}

class _SensitiveFieldRow extends StatelessWidget {
  const _SensitiveFieldRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final bool deleted = value == 'Eliminado';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            deleted ? Icons.delete_outline : Icons.check_circle_outline,
            color: deleted ? Colors.red : Colors.green,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
