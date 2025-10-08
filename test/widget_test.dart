import 'package:flutter_test/flutter_test.dart';
import 'package:easycatalog/main.dart';

void main() {
  testWidgets('La app inicia y muestra EasyCatalog', (WidgetTester tester) async {
    // Arranca la app real que definiste en lib/main.dart
    await tester.pumpWidget(const EasyCatalogApp());

    // Verifica que se renderiza el título en AppBar o la pantalla inicial
    expect(find.text('EasyCatalog'), findsOneWidget);
  });
}
