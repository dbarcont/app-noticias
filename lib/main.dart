import 'package:flutter/material.dart';

void main() {
  runApp(const NoticiasApp());
}

// ---------------------------------------------------------------
// MODELO Y DATOS DE EJEMPLO (más adelante vendrán de WordPress)
// ---------------------------------------------------------------

class Noticia {
  final String titulo;
  final String resumen;
  final String categoria;
  final String fecha;
  final bool tieneVideo;

  const Noticia({
    required this.titulo,
    required this.resumen,
    required this.categoria,
    required this.fecha,
    this.tieneVideo = false,
  });
}

const List<String> categorias = [
  'Todas',
  'Local',
  'Economía',
  'Deportes',
  'Tecnología',
  'Cultura',
];

const List<Noticia> noticiasEjemplo = [
  Noticia(
    titulo: 'Primera noticia destacada de ejemplo para ver la tarjeta grande',
    resumen:
        'Este es el texto de la noticia. Cuando conectemos WordPress, aquí aparecerá el contenido real con su imagen destacada.',
    categoria: 'Local',
    fecha: '22 oct 2026',
  ),
  Noticia(
    titulo: 'Noticia con video incrustado de YouTube',
    resumen:
        'Esta noticia tendrá un video en la pantalla de detalle, reproducido con el reproductor oficial.',
    categoria: 'Economía',
    fecha: '21 oct 2026',
    tieneVideo: true,
  ),
  Noticia(
    titulo: 'Resultados de la última fecha del torneo',
    resumen: 'Texto de ejemplo para la categoría de deportes.',
    categoria: 'Deportes',
    fecha: '21 oct 2026',
  ),
  Noticia(
    titulo: 'Nueva herramienta digital para pequeños comercios',
    resumen: 'Texto de ejemplo para la categoría de tecnología.',
    categoria: 'Tecnología',
    fecha: '20 oct 2026',
    tieneVideo: true,
  ),
  Noticia(
    titulo: 'Agenda cultural de la semana',
    resumen: 'Texto de ejemplo para la categoría de cultura.',
    categoria: 'Cultura',
    fecha: '20 oct 2026',
  ),
  Noticia(
    titulo: 'Cambios en el transporte urbano a partir de noviembre',
    resumen: 'Otro texto de ejemplo para la categoría local.',
    categoria: 'Local',
    fecha: '19 oct 2026',
  ),
];

// ---------------------------------------------------------------
// APP
// ---------------------------------------------------------------

class NoticiasApp extends StatelessWidget {
  const NoticiasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Noticias',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const InicioPage(),
    );
  }
}

void abrirDetalle(BuildContext context, Noticia noticia) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => DetalleNoticiaPage(noticia: noticia)),
  );
}

// ---------------------------------------------------------------
// PANTALLA PRINCIPAL
// ---------------------------------------------------------------

class InicioPage extends StatefulWidget {
  const InicioPage({super.key});

  @override
  State<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends State<InicioPage> {
  String categoriaSeleccionada = 'Todas';
  int pestana = 0;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    final noticias = categoriaSeleccionada == 'Todas'
        ? noticiasEjemplo
        : noticiasEjemplo
            .where((n) => n.categoria == categoriaSeleccionada)
            .toList();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // Título y fecha
            Text(
              'Noticias',
              style: tema.textTheme.displaySmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              'Jueves 22 de octubre',
              style: tema.textTheme.titleLarge?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Categorías (se desplazan hacia los lados)
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categorias.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final cat = categorias[i];
                  return ChoiceChip(
                    label: Text(cat),
                    selected: cat == categoriaSeleccionada,
                    onSelected: (_) =>
                        setState(() => categoriaSeleccionada = cat),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Sección destacadas
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

// ---------------------------------------------------------------
// COMPONENTES
// ---------------------------------------------------------------

// Cuadro de color que hace de imagen hasta que conectemos las reales
class ImagenPlaceholder extends StatelessWidget {
  final double? height;
  final double? width;

  const ImagenPlaceholder({super.key, this.height, this.width});

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

// Tarjeta grande: imagen arriba, categoría y título debajo
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
                const ImagenPlaceholder(height: 220, width: double.infinity),
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
              padding: const EdgeInsets.all(16),
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
                  Text(
                    noticia.titulo,
                    style: tema.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(noticia.fecha, style: tema.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Tarjeta compacta: texto a la izquierda, imagen pequeña a la derecha
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
                    const SizedBox(height: 6),
                    Text(noticia.fecha, style: tema.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: const ImagenPlaceholder(height: 90, width: 90),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// PANTALLA DE DETALLE
// ---------------------------------------------------------------

class DetalleNoticiaPage extends StatelessWidget {
  final Noticia noticia;

  const DetalleNoticiaPage({super.key, required this.noticia});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(noticia.categoria)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(noticia.titulo, style: tema.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(noticia.fecha, style: tema.textTheme.bodySmall),
            const SizedBox(height: 16),
            if (noticia.tieneVideo) ...[
              Container(
                height: 200,
                width: double.infinity,
                color: Colors.black12,
                alignment: Alignment.center,
                child: const Text('Aquí irá el video de YouTube'),
              ),
              const SizedBox(height: 16),
            ],
            Text(noticia.resumen, style: tema.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}