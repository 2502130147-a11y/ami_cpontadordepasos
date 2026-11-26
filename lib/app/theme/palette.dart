import 'package:flutter/material.dart';

/// Paleta "Amatista": lilas suaves combinados con morados profundos.
abstract final class Palette {
  // Fondos y superficies
  static const mist = Color(0xFFF7F2FC); // fondo general (lavanda muy claro)
  static const lilacSoft = Color(0xFFEDE1F8); // superficies suaves
  static const lilacLine = Color(0xFFDCC8F0); // bordes y pistas

  // Lilas
  static const lilac = Color(0xFFC8A2E8);
  static const orchid = Color(0xFFB07CD8);

  // Morados
  static const violet = Color(0xFF8E44AD);
  static const purple = Color(0xFF6A1B9A);
  static const plum = Color(0xFF3E0F5C);

  // Texto
  static const ink = Color(0xFF2B1240);
  static const inkMuted = Color(0xFF7D6A8F);

  // Estados
  static const success = Color(0xFF2EA77A);
  static const warning = Color(0xFFE59A3C);
  static const danger = Color(0xFFD94C6A);

  static const hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [plum, purple, orchid],
    stops: [0.0, 0.55, 1.0],
  );

  static const button = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [purple, violet],
  );

  static const lilacButton = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [lilac, orchid],
  );

  // Ilustraciones de la mascota (estilo anime)
  static const mascotAvatar = 'assets/images/mascota_avatar.png';
  static const mascotStronger = 'assets/images/mascota_stronger.png';

  static const night = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [plum, Color(0xFF52187A), purple],
  );
}
