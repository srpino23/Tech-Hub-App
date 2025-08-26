class ApiResponse<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  ApiResponse._({
    this.data,
    this.error,
    required this.isSuccess,
  });

  factory ApiResponse.success(T data) {
    return ApiResponse._(
      data: data,
      isSuccess: true,
    );
  }

  factory ApiResponse.error(String error) {
    return ApiResponse._(
      error: error,
      isSuccess: false,
    );
  }

  bool get hasData => isSuccess && data != null;

  bool get hasError => !isSuccess && error != null;
}

class ReportResponse {
  final String? id;
  final String? userId;
  final String? status;
  final List<dynamic>? supplies;
  final String? toDo;
  final String? typeOfWork;
  final String? startTime;
  final String? endTime;
  final String? location;
  final String? connectivity;
  final String? db;
  final String? buffers;
  final String? bufferColor;
  final String? hairColor;
  final String? ap;
  final String? st;
  final String? ccq;
  final List<String>? imagesUrl;
  final DateTime? date;

  ReportResponse({
    this.id,
    this.userId,
    this.status,
    this.supplies,
    this.toDo,
    this.typeOfWork,
    this.startTime,
    this.endTime,
    this.location,
    this.connectivity,
    this.db,
    this.buffers,
    this.bufferColor,
    this.hairColor,
    this.ap,
    this.st,
    this.ccq,
    this.imagesUrl,
    this.date,
  });

  factory ReportResponse.fromJson(Map<String, dynamic> json) {
    return ReportResponse(
      id: json['_id']?.toString(),
      userId: json['userId']?.toString(),
      status: json['status']?.toString(),
      supplies: json['supplies'] as List<dynamic>?,
      toDo: json['toDo']?.toString(),
      typeOfWork: json['typeOfWork']?.toString(),
      startTime: json['startTime']?.toString(),
      endTime: json['endTime']?.toString(),
      location: json['location']?.toString(),
      connectivity: json['connectivity']?.toString(),
      db: json['db']?.toString(),
      buffers: json['buffers']?.toString(),
      bufferColor: json['bufferColor']?.toString(),
      hairColor: json['hairColor']?.toString(),
      ap: json['ap']?.toString(),
      st: json['st']?.toString(),
      ccq: json['ccq']?.toString(),
      imagesUrl: (json['imagesUrl'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      date: json['date'] != null ? DateTime.parse(json['date'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      'status': status,
      'supplies': supplies,
      'toDo': toDo,
      'typeOfWork': typeOfWork,
      'startTime': startTime,
      'endTime': endTime,
      'location': location,
      'connectivity': connectivity,
      'db': db,
      'buffers': buffers,
      'bufferColor': bufferColor,
      'hairColor': hairColor,
      'ap': ap,
      'st': st,
      'ccq': ccq,
      'imagesUrl': imagesUrl,
      'date': date?.toIso8601String(),
    };
  }
}