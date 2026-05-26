// To parse this JSON data, do
//
//     final loginModels = loginModelsFromJson(jsonString);

import 'dart:convert';

LoginModels loginModelsFromJson(String str) =>
    LoginModels.fromJson(json.decode(str));

String loginModelsToJson(LoginModels data) => json.encode(data.toJson());

class LoginModels {
  LoginModels({
    this.isActive,
    this.message,
    this.data,
  });

  bool? isActive;
  String? message;
  Data? data;

  factory LoginModels.fromJson(Map<String, dynamic> json) => LoginModels(
        isActive: json["is_active"]?.toString() == "1" || json["is_active"] == true,
        message: json["message"]?.toString(),
        data: json["data"] != null ? Data.fromJson(json["data"]) : null,
      );

  Map<String, dynamic> toJson() => {
        "is_active": isActive,
        "message": message,
        "data": data?.toJson(),
      };
}

class Data {
  Data({
    this.id,
    this.nama,
    this.profesi,
    this.email,
    this.password,
    this.roleId,
    this.isActive,
    this.tanggalInput,
    this.modified,
  });

  String? id;
  String? nama;
  String? profesi;
  String? email;
  String? password;
  String? roleId;
  String? isActive;
  DateTime? tanggalInput;
  String? modified;

  factory Data.fromJson(Map<String, dynamic> json) => Data(
        id: json["id"]?.toString(),
        nama: json["nama"]?.toString(),
        profesi: json["profesi"]?.toString(),
        email: json["email"]?.toString(),
        password: json["password"]?.toString(),
        roleId: json["role_id"]?.toString(),
        isActive: json["is_active"]?.toString(),
        tanggalInput: json["tanggal_input"] != null
            ? DateTime.tryParse(json["tanggal_input"].toString())
            : null,
        modified: json["modified"]?.toString(),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "nama": nama,
        "profesi": profesi,
        "email": email,
        "password": password,
        "role_id": roleId,
        "is_active": isActive,
        "tanggal_input":
            "${tanggalInput?.year.toString().padLeft(4, '0')}-${tanggalInput?.month.toString().padLeft(2, '0')}-${tanggalInput?.day.toString().padLeft(2, '0')}",
        "modified": modified,
      };
}
