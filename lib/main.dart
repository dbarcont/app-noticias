import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

// ===============================================================
// CONFIGURACIÓN
// ===============================================================

// Dirección de tu sitio WordPress, sin barra al final.
// (Debe ser la carpeta donde responde /wp-json/wp/v2/posts)
const String sitioWordpress = 'https://tabacojujuy.com.ar/2024';
// const String sitioWordpress = 'https://itservices.net.ar/prensa';

// ===============================================================
// MODELO
// ===============================================================

class Noticia {
  final int id;
  final String titulo;
  final String resumen;
  final String contenidoHtml;
  final String categoria;
  final DateTime fecha;
  final String? imagenUrl;
  final bool tieneVideo;

  const Noticia({
    required this.id,
    required this.titulo,
    required this.resumen,
    required this.contenidoHtml,
    required this.categoria,
    required this.fecha,
    required this.imagenUrl,
    required this.tieneVideo,
  });

  // Convierte una entrada de WordPress (JSON) en una Noticia
  factory Noticia.fromJson(Map<String, dynamic> json) {
    final embebido = json['_embedded'] as Map<String, dynamic>?;

    // Imagen destacada
    String? imagen;
    final medios = embebido?['wp:featuredmedia'];
    if (medios is List && medios.isNotEmpty) {
      final primero = medios.first;
      if (primero is Map<String, dynamic>) {
        imagen = primero['source_url'] as String?;
      }
    }

    // Categoría (la primera que tenga la entrada)
    String categoria = 'General';
    final terminos = embebido?['wp:term'];
    if (terminos is List && terminos.isNotEmpty) {
      final cats = terminos.first;
      if (cats is List && cats.isNotEmpty) {
        final primera = cats.first;
        if (primera is Map<String, dynamic>) {
          categoria = limpiarHtml(primera['name'] as String? ?? 'General');
        }
      }
    }

    final contenido = (json['content']?['rendered'] as String?) ?? '';

    return Noticia(
      id: json['id'] as int,
      titulo: limpiarHtml((json['title']?['rendered'] as String?) ?? ''),
      resumen: limpiarHtml((json['excerpt']?['rendered'] as String?) ?? ''),
      contenidoHtml: contenido,
      categoria: categoria,
      fecha: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      imagenUrl: imagen,
      tieneVideo: contenido.contains('youtube.com') ||
          contenido.contains('youtu.be'),
    );
  }

  // Para guardar la noticia en el teléfono
  Map<String, dynamic> toMap() => {
        'id': id,
        'titulo': titulo,
        'resumen': resumen,
        'contenidoHtml': contenidoHtml,
        'categoria': categoria,
        'fecha': fecha.toIso8601String(),
        'imagenUrl': imagenUrl,
        'tieneVideo': tieneVideo,
      };

  // Para recuperar una noticia guardada en el teléfono
  factory Noticia.fromMap(Map<String, dynamic> m) => Noticia(
        id: m['id'] as int,
        titulo: m['titulo'] as String? ?? '',
        resumen: m['resumen'] as String? ?? '',
        contenidoHtml: m['contenidoHtml'] as String? ?? '',
        categoria: m['categoria'] as String? ?? 'General',
        fecha: DateTime.tryParse(m['fecha'] as String? ?? '') ?? DateTime.now(),
        imagenUrl: m['imagenUrl'] as String?,
        tieneVideo: m['tieneVideo'] as bool? ?? false,
      );
}

// WordPress entrega títulos y resúmenes con etiquetas y símbolos HTML
// (por ejemplo &#8217;). Esta función los convierte en texto normal.
String limpiarHtml(String texto) {
  return (html_parser.parse(texto).documentElement?.text ?? '').trim();
}

String formatearFecha(DateTime f) {
  const meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];
  return '${f.day} ${meses[f.month - 1]} ${f.year}';
}

String fechaHoy() {
  const dias = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves',
    'Viernes', 'Sábado', 'Domingo',
  ];
  const meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];
  final h = DateTime.now();
  return '${dias[h.weekday - 1]} ${h.day} de ${meses[h.month - 1]}';
}

// ===============================================================
// CARGA DE DATOS DESDE WORDPRESS
// ===============================================================

Future<List<Noticia>> _pedirNoticias(Map<String, String> parametros) async {
  final url = Uri.parse('$sitioWordpress/wp-json/wp/v2/posts').replace(
    queryParameters: {'_embed': '1', 'per_page': '20', ...parametros},
  );
  final respuesta = await http.get(url);

  if (respuesta.statusCode != 200) {
    throw Exception('Error ${respuesta.statusCode} al cargar las noticias');
  }

  final datos = jsonDecode(respuesta.body) as List<dynamic>;
  return datos
      .map((e) => Noticia.fromJson(e as Map<String, dynamic>))
      .toList();
}

// Las últimas noticias publicadas
Future<List<Noticia>> cargarNoticias() => _pedirNoticias({});

// Búsqueda en todo el sitio (la hace el propio WordPress)
Future<List<Noticia>> buscarNoticias(String termino) =>
    _pedirNoticias({'search': termino});

// ===============================================================
// NOTICIAS GUARDADAS (se conservan en el teléfono)
// ===============================================================

class GestorGuardadas extends ChangeNotifier {
  static const _clave = 'noticias_guardadas';
  final List<Noticia> _guardadas = [];

  List<Noticia> get guardadas => List.unmodifiable(_guardadas);

  bool esGuardada(int id) => _guardadas.any((n) => n.id == id);

  Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lista = prefs.getStringList(_clave) ?? [];
      _guardadas
        ..clear()
        ..addAll(
          lista.map(
            (t) => Noticia.fromMap(jsonDecode(t) as Map<String, dynamic>),
          ),
        );
      notifyListeners();
    } catch (_) {
      // Si algo falla al leer, se empieza sin noticias guardadas
    }
  }

  Future<void> alternar(Noticia noticia) async {
    if (esGuardada(noticia.id)) {
      _guardadas.removeWhere((n) => n.id == noticia.id);
    } else {
      _guardadas.insert(0, noticia);
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _clave,
        _guardadas.map((n) => jsonEncode(n.toMap())).toList(),
      );
    } catch (_) {
      // Si no se puede guardar en disco, la noticia queda solo en memoria
    }
  }
}

final GestorGuardadas gestorGuardadas = GestorGuardadas();

// ===============================================================
// APP
// ===============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await gestorGuardadas.cargar();
  runApp(const NoticiasApp());
}

class NoticiasApp extends StatelessWidget {
  const NoticiasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Noticias',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const PrincipalPage(),
    );
  }
}

void abrirDetalle(BuildContext context, Noticia noticia) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => DetalleNoticiaPage(noticia: noticia)),
  );
}

// ===============================================================
// PANTALLA PRINCIPAL (barra inferior con las tres pestañas)
// ===============================================================

class PrincipalPage extends StatefulWidget {
  const PrincipalPage({super.key});

  @override
  State<PrincipalPage> createState() => _PrincipalPageState();
}

class _PrincipalPageState extends State<PrincipalPage> {
  List<Noticia> todas = [];
  bool cargando = true;
  bool hayError = false;
  int pestana = 0;

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    try {
      final resultado = await cargarNoticias();
      if (!mounted) return;
      setState(() {
        todas = resultado;
        hayError = false;
        cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        hayError = todas.isEmpty;
        cargando = false;
      });
    }
  }

  void reintentar() {
    setState(() {
      cargando = true;
      hayError = false;
    });
    cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: pestana,
          children: [
            HoyTab(
              todas: todas,
              cargando: cargando,
              hayError: hayError,
              onReintentar: reintentar,
              onRefrescar: cargar,
            ),
            const GuardadasTab(),
            const BuscarTab(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: pestana,
        onDestinationSelected: (i) => setState(() => pestana = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.newspaper), label: 'Hoy'),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border),
            selectedIcon: Icon(Icons.bookmark),
            label: 'Guardadas',
          ),
          NavigationDestination(icon: Icon(Icons.search), label: 'Buscar'),
        ],
      ),
    );
  }
}

// ===============================================================
// PESTAÑA "HOY"
// ===============================================================

class HoyTab extends StatefulWidget {
  final List<Noticia> todas;
  final bool cargando;
  final bool hayError;
  final VoidCallback onReintentar;
  final Future<void> Function() onRefrescar;

  const HoyTab({
    super.key,
    required this.todas,
    required this.cargando,
    required this.hayError,
    required this.onReintentar,
    required this.onRefrescar,
  });

  @override
  State<HoyTab> createState() => _HoyTabState();
}

class _HoyTabState extends State<HoyTab> {
  String categoriaSeleccionada = 'Todas';

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    if (widget.cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.hayError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 48),
              const SizedBox(height: 12),
              const Text('No se pudieron cargar las noticias'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: widget.onReintentar,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    // Las categorías salen de las propias noticias cargadas
    final todas = widget.todas;
    final categorias = ['Todas', ...{for (final n in todas) n.categoria}];
    final seleccionada = categorias.contains(categoriaSeleccionada)
        ? categoriaSeleccionada
        : 'Todas';
    final noticias = seleccionada == 'Todas'
        ? todas
        : todas.where((n) => n.categoria == seleccionada).toList();

    return RefreshIndicator(
      onRefresh: widget.onRefrescar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            'Noticias',
            style: tema.textTheme.displaySmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            fechaHoy(),
            style: tema.textTheme.titleLarge?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 16),

          // Categorías
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categorias.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final cat = categorias[i];
                return ChoiceChip(
                  label: Text(cat),
                  selected: cat == seleccionada,
                  onSelected: (_) =>
                      setState(() => categoriaSeleccionada = cat),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Destacadas',
            style: tema.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: tema.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),

          if (noticias.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No hay noticias en esta categoría')),
            )
          else ...[
            TarjetaGrande(noticia: noticias.first),
            for (final n in noticias.skip(1)) TarjetaCompacta(noticia: n),
          ],
        ],
      ),
    );
  }
}

// ===============================================================
// PESTAÑA "GUARDADAS"
// ===============================================================

class GuardadasTab extends StatelessWidget {
  const GuardadasTab({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return ListenableBuilder(
      listenable: gestorGuardadas,
      builder: (context, _) {
        final guardadas = gestorGuardadas.guardadas;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(
              'Guardadas',
              style: tema.textTheme.displaySmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            if (guardadas.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(Icons.bookmark_border, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'Todavía no guardaste noticias',
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Toca el marcador de una noticia para guardarla.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              for (final n in guardadas) TarjetaCompacta(noticia: n),
          ],
        );
      },
    );
  }
}

// ===============================================================
// PESTAÑA "BUSCAR"
// ===============================================================

class BuscarTab extends StatefulWidget {
  const BuscarTab({super.key});

  @override
  State<BuscarTab> createState() => _BuscarTabState();
}

class _BuscarTabState extends State<BuscarTab> {
  final TextEditingController controlador = TextEditingController();
  List<Noticia> resultados = [];
  bool buscando = false;
  bool hayError = false;
  String ultimaBusqueda = '';

  @override
  void dispose() {
    controlador.dispose();
    super.dispose();
  }

  Future<void> buscar(String texto) async {
    final termino = texto.trim();

    if (termino.isEmpty) {
      setState(() {
        resultados = [];
        ultimaBusqueda = '';
        hayError = false;
      });
      return;
    }

    setState(() {
      buscando = true;
      hayError = false;
      ultimaBusqueda = termino;
    });

    try {
      final encontrados = await buscarNoticias(termino);
      if (!mounted) return;
      setState(() {
        resultados = encontrados;
        buscando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        hayError = true;
        buscando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final Widget contenido;

    if (buscando) {
      contenido = const Center(child: CircularProgressIndicator());
    } else if (hayError) {
      contenido = const Center(
        child: Text('No se pudo realizar la búsqueda. Revisa tu conexión.'),
      );
    } else if (ultimaBusqueda.isEmpty) {
      contenido = const Center(
        child: Text('Escribe una palabra y pulsa el botón de buscar.'),
      );
    } else if (resultados.isEmpty) {
      contenido = Center(
        child: Text('No hay resultados para “$ultimaBusqueda”'),
      );
    } else {
      contenido = ListView(
        children: [for (final n in resultados) TarjetaCompacta(noticia: n)],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Buscar',
            style: tema.textTheme.displaySmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controlador,
            textInputAction: TextInputAction.search,
            onSubmitted: buscar,
            decoration: InputDecoration(
              hintText: 'Buscar noticias',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  controlador.clear();
                  buscar('');
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: contenido),
        ],
      ),
    );
  }
}

// ===============================================================
// COMPONENTES
// ===============================================================

// Cuadro de color que se muestra si la noticia no tiene imagen
class ImagenPlaceholder extends StatelessWidget {
  final double height;
  final double width;

  const ImagenPlaceholder({
    super.key,
    required this.height,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade200, Colors.indigo.shade400],
        ),
      ),
      child: const Icon(Icons.image, color: Colors.white70, size: 40),
    );
  }
}

// Imagen real de la noticia (o el cuadro de color si no hay o falla)
class ImagenNoticia extends StatelessWidget {
  final String? url;
  final double height;
  final double width;

  const ImagenNoticia({
    super.key,
    required this.url,
    required this.height,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final direccion = url;
    final placeholder = ImagenPlaceholder(height: height, width: width);
    if (direccion == null) return placeholder;

    return Image.network(
      direccion,
      height: height,
      width: width,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => placeholder,
    );
  }
}

// Botón de marcador para guardar o quitar una noticia
class BotonGuardar extends StatelessWidget {
  final Noticia noticia;

  const BotonGuardar({super.key, required this.noticia});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: gestorGuardadas,
      builder: (context, _) {
        final guardada = gestorGuardadas.esGuardada(noticia.id);
        return IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: guardada ? 'Quitar de guardadas' : 'Guardar',
          icon: Icon(guardada ? Icons.bookmark : Icons.bookmark_border),
          onPressed: () => gestorGuardadas.alternar(noticia),
        );
      },
    );
  }
}

class TarjetaGrande extends StatelessWidget {
  final Noticia noticia;

  const TarjetaGrande({super.key, required this.noticia});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => abrirDetalle(context, noticia),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ImagenNoticia(
                  url: noticia.imagenUrl,
                  height: 220,
                  width: double.infinity,
                ),
                if (noticia.tieneVideo)
                  const Positioned(
                    right: 12,
                    top: 12,
                    child: Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    noticia.categoria.toUpperCase(),
                    style: tema.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: tema.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      noticia.titulo,
                      style: tema.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatearFecha(noticia.fecha),
                          style: tema.textTheme.bodySmall,
                        ),
                      ),
                      BotonGuardar(noticia: noticia),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TarjetaCompacta extends StatelessWidget {
  final Noticia noticia;

  const TarjetaCompacta({super.key, required this.noticia});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => abrirDetalle(context, noticia),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      noticia.categoria.toUpperCase(),
                      style: tema.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: tema.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      noticia.titulo,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            formatearFecha(noticia.fecha),
                            style: tema.textTheme.bodySmall,
                          ),
                        ),
                        BotonGuardar(noticia: noticia),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ImagenNoticia(
                  url: noticia.imagenUrl,
                  height: 90,
                  width: 90,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===============================================================
// PANTALLA DE DETALLE
// ===============================================================

class DetalleNoticiaPage extends StatelessWidget {
  final Noticia noticia;

  const DetalleNoticiaPage({super.key, required this.noticia});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final videoId =
        noticia.tieneVideo ? extraerYoutubeId(noticia.contenidoHtml) : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(noticia.categoria),
        actions: [BotonGuardar(noticia: noticia)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (noticia.imagenUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ImagenNoticia(
                  url: noticia.imagenUrl,
                  height: 220,
                  width: double.infinity,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(noticia.titulo, style: tema.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              formatearFecha(noticia.fecha),
              style: tema.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (videoId != null) ...[
              ReproductorYoutube(key: ValueKey(videoId), videoId: videoId),
              const SizedBox(height: 16),
            ],
            ...construirContenido(context, noticia.contenidoHtml),
          ],
        ),
      ),
    );
  }
}

// ===============================================================
// CONTENIDO DE LA NOTICIA (HTML de WordPress -> widgets de Flutter)
// ===============================================================

String textoDe(dom.Node nodo) => nodo.text ?? '';

List<Widget> construirContenido(BuildContext context, String htmlTexto) {
  final tema = Theme.of(context);
  final documento = html_parser.parse(htmlTexto);
  final widgets = <Widget>[];

  const bloques = ['p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'li', 'blockquote'];
  const titulos = ['h1', 'h2', 'h3', 'h4', 'h5', 'h6'];

  void agregarTexto(String texto, {bool titulo = false}) {
    final limpio = texto.trim();
    if (limpio.isEmpty) return;
    // Los enlaces de YouTube no se muestran como texto: van en el reproductor
    if (limpio.startsWith('http') &&
        (limpio.contains('youtube.com') || limpio.contains('youtu.be'))) {
      return;
    }
    widgets.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          limpio,
          style: titulo
              ? tema.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)
              : tema.textTheme.bodyLarge,
        ),
      ),
    );
  }

  void agregarImagen(String? direccion) {
    if (direccion == null || direccion.isEmpty) return;
    widgets.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            direccion,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  void procesar(dom.Node nodo) {
    if (nodo is dom.Text) {
      agregarTexto(textoDe(nodo));
      return;
    }
    if (nodo is dom.Element) {
      final etiqueta = nodo.localName ?? '';
      if (etiqueta == 'script' || etiqueta == 'style' || etiqueta == 'iframe') {
        return;
      }
      if (etiqueta == 'img') {
        agregarImagen(nodo.attributes['src']);
        return;
      }
      if (bloques.contains(etiqueta)) {
        for (final img in nodo.getElementsByTagName('img')) {
          agregarImagen(img.attributes['src']);
        }
        final texto = textoDe(nodo);
        agregarTexto(
          etiqueta == 'li' ? '• $texto' : texto,
          titulo: titulos.contains(etiqueta),
        );
        return;
      }
    }
    for (final hijo in nodo.nodes) {
      procesar(hijo);
    }
  }

  procesar(documento.body ?? documento);
  return widgets;
}

// ===============================================================
// VIDEO DE YOUTUBE
// ===============================================================

// Busca en el HTML de la noticia un enlace de YouTube y devuelve el ID
// del video (los 11 caracteres). Reconoce enlaces de tipo watch?v=,
// youtu.be/, embed/, shorts/ y live/.
String? extraerYoutubeId(String texto) {
  final patron = RegExp(
    r'(?:youtube(?:-nocookie)?\.com/(?:watch\?(?:[^"\s<]*&(?:amp;)?)?v=|embed/|shorts/|live/)|youtu\.be/)([A-Za-z0-9_-]{11})',
  );
  return patron.firstMatch(texto)?.group(1);
}

class ReproductorYoutube extends StatefulWidget {
  final String videoId;

  const ReproductorYoutube({super.key, required this.videoId});

  @override
  State<ReproductorYoutube> createState() => _ReproductorYoutubeState();
}

class _ReproductorYoutubeState extends State<ReproductorYoutube> {
  late final YoutubePlayerController controlador;

  @override
  void initState() {
    super.initState();
    controlador = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: false,
        strictRelatedVideos: true,
        interfaceLanguage: 'es',
        captionLanguage: 'es',
      ),
    );
  }

  @override
  void dispose() {
    controlador.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: YoutubePlayer(controller: controlador, aspectRatio: 16 / 9),
    );
  }
}