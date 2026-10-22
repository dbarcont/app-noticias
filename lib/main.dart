import 'package:flutter/material.dart';

void main() {
  runApp(const NoticiasApp());
}

// Modelo de una noticia (más adelante vendrá de WordPress)
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

// Datos de ejemplo, solo para probar el diseño
const List<Noticia> noticiasEjemplo = [
  Noticia(
    titulo: 'Primera noticia de ejemplo',
    resumen: 'Este es un resumen breve de la noticia para ver cómo se ve la lista en pantalla.',
    categoria: 'Local',
    fecha: '22 oct 2026',
  ),
  Noticia(
    titulo: 'Noticia con video',
    resumen: 'Esta noticia tendrá un video de YouTube incrustado en la pantalla de detalle.',
    categoria: 'Economía',
    fecha: '21 oct 2026',
    tieneVideo: true,
  ),
  Noticia(
    titulo: 'Otra noticia de prueba',
    resumen: 'Aquí irá el texto completo de la noticia cuando conectemos el contenido real.',
    categoria: 'Deportes',
    fecha: '20 oct 2026',
  ),
];

class NoticiasApp extends StatelessWidget {
  const NoticiasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Noticias',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const ListaNoticiasPage(),
    );
  }
}

class ListaNoticiasPage extends StatelessWidget {
  const ListaNoticiasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Noticias')),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: noticiasEjemplo.length,
        itemBuilder: (context, index) {
          final noticia = noticiasEjemplo[index];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(
                noticia.titulo,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(noticia.resumen),
                    const SizedBox(height: 8),
                    Text(
                      '${noticia.categoria} · ${noticia.fecha}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              trailing: noticia.tieneVideo
                  ? const Icon(Icons.play_circle_outline)
                  : null,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DetalleNoticiaPage(noticia: noticia),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class DetalleNoticiaPage extends StatelessWidget {
  final Noticia noticia;

  const DetalleNoticiaPage({super.key, required this.noticia});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(noticia.categoria)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              noticia.titulo,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              noticia.fecha,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (noticia.tieneVideo)
              Container(
                height: 200,
                width: double.infinity,
                color: Colors.black12,
                alignment: Alignment.center,
                child: const Text('Aquí irá el video de YouTube'),
              ),
            if (noticia.tieneVideo) const SizedBox(height: 16),
            Text(
              noticia.resumen,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}