class DataHelpers {
  // Función unificada para extraer nombres de usuario
  static String extractUserName(Map<String, dynamic> user) {
    final name = user['name']?.toString().trim() ?? '';
    final surname = user['surname']?.toString().trim() ?? '';

    if (name.isNotEmpty && surname.isNotEmpty) {
      return '$name $surname';
    } else if (name.isNotEmpty) {
      return name;
    } else if (surname.isNotEmpty) {
      return surname;
    }

    final fullName = user['fullName']?.toString().trim();
    if (fullName?.isNotEmpty == true) {
      return fullName!;
    }

    return 'Usuario desconocido';
  }

  // Función unificada para obtener nombre de usuario por ID
  static String getUserNameById(String userId, List<Map<String, dynamic>> users) {
    if (users.isEmpty) return 'Cargando...';

    final user = users.firstWhere(
      (user) =>
          user['_id']?.toString() == userId ||
          user['userId']?.toString() == userId,
      orElse: () => <String, dynamic>{},
    );

    return user.isNotEmpty ? extractUserName(user) : 'Usuario desconocido';
  }

  // Función unificada para obtener nombre de material por ID
  static String getMaterialNameById(String materialId, List<Map<String, dynamic>> inventory) {
    if (inventory.isEmpty) return 'Cargando...';

    final material = inventory.firstWhere(
      (material) => material['_id']?.toString() == materialId,
      orElse: () => <String, dynamic>{},
    );

    return material.isNotEmpty 
      ? material['name']?.toString() ?? 'Material desconocido'
      : 'Material desconocido';
  }

  // Función unificada para formatear fechas
  static String formatDate(dynamic dateValue) {
    if (dateValue == null) return 'Sin fecha';
    
    try {
      DateTime date;
      if (dateValue is DateTime) {
        date = dateValue;
      } else if (dateValue is Map && dateValue['\$date'] != null) {
        date = DateTime.parse(dateValue['\$date']);
      } else if (dateValue is String) {
        date = DateTime.parse(dateValue);
      } else {
        return 'Sin fecha';
      }

      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Hoy';
      } else if (difference.inDays == 1) {
        return 'Ayer';
      } else if (difference.inDays < 7) {
        return 'Hace ${difference.inDays} días';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Sin fecha';
    }
  }

  // Función unificada para formatear tiempo
  static String formatTime(dynamic timeValue) {
    if (timeValue == null) return 'N/A';
    
    try {
      DateTime time;
      if (timeValue is DateTime) {
        time = timeValue;
      } else if (timeValue is String) {
        time = DateTime.parse(timeValue);
      } else if (timeValue is Map && timeValue['\$date'] != null) {
        time = DateTime.parse(timeValue['\$date']);
      } else {
        return 'N/A';
      }

      final dateStr = '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}/${time.year}';
      final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      return '$dateStr $timeStr';
    } catch (e) {
      return 'N/A';
    }
  }

  // Función unificada para traducir estados
  static String translateStatus(String? status) {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'in_progress':
        return 'En Proceso';
      case 'completed':
        return 'Completada';
      default:
        return 'Desconocido';
    }
  }

  // Función unificada para obtener texto de ubicación
  static String? getLocationText(dynamic location) {
    if (location == null) return null;

    final locationStr = location.toString();
    if (locationStr.contains(',') && locationStr.contains('-')) {
      final parts = locationStr.split(',');
      if (parts.length == 2) {
        try {
          final lat = double.parse(parts[0].trim());
          final lng = double.parse(parts[1].trim());
          return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
        } catch (e) {
          return locationStr;
        }
      }
    }
    return locationStr;
  }

  // Función unificada para validar coordenadas
  static bool hasLocationCoordinates(String? location) {
    if (location == null) return false;

    final locationStr = location.toString();
    if (locationStr.contains(',') && locationStr.contains('-')) {
      final parts = locationStr.split(',');
      if (parts.length == 2) {
        try {
          final lat = double.parse(parts[0].trim());
          final lng = double.parse(parts[1].trim());
          return lat.abs() > 0.0001 && lng.abs() > 0.0001;
        } catch (e) {
          return false;
        }
      }
    }
    return false;
  }

  // Función para calcular el tiempo total trabajado
  static String calculateWorkingTime(dynamic startTime, dynamic endTime) {
    if (startTime == null || endTime == null) return 'N/A';

    try {
      DateTime start;
      DateTime end;

      // Parsear startTime
      if (startTime is DateTime) {
        start = startTime;
      } else if (startTime is String) {
        start = DateTime.parse(startTime);
      } else if (startTime is Map && startTime['\$date'] != null) {
        start = DateTime.parse(startTime['\$date']);
      } else {
        return 'N/A';
      }

      // Parsear endTime
      if (endTime is DateTime) {
        end = endTime;
      } else if (endTime is String) {
        end = DateTime.parse(endTime);
      } else if (endTime is Map && endTime['\$date'] != null) {
        end = DateTime.parse(endTime['\$date']);
      } else {
        return 'N/A';
      }

      final duration = end.difference(start);
      
      if (duration.isNegative) return 'N/A';

      // Formatear según la duración
      if (duration.inDays > 0) {
        final days = duration.inDays;
        final hours = duration.inHours % 24;
        
        if (days == 1) {
          return hours > 0 
            ? '1 día, $hours ${hours == 1 ? 'hora' : 'horas'}'
            : '1 día';
        } else {
          return hours > 0 
            ? '$days días, $hours ${hours == 1 ? 'hora' : 'horas'}'
            : '$days días';
        }
      } else if (duration.inHours > 0) {
        final hours = duration.inHours;
        final minutes = duration.inMinutes % 60;
        
        if (minutes > 0) {
          return '$hours ${hours == 1 ? 'hora' : 'horas'}, $minutes ${minutes == 1 ? 'minuto' : 'minutos'}';
        } else {
          return '$hours ${hours == 1 ? 'hora' : 'horas'}';
        }
      } else if (duration.inMinutes > 0) {
        final minutes = duration.inMinutes;
        return '$minutes ${minutes == 1 ? 'minuto' : 'minutos'}';
      } else {
        final seconds = duration.inSeconds;
        return '$seconds ${seconds == 1 ? 'segundo' : 'segundos'}';
      }
    } catch (e) {
      return 'N/A';
    }
  }
}