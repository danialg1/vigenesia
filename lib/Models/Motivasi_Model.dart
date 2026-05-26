// To parse this JSON data, do
//
//     final motivasiModel = motivasiModelFromJson(jsonString);

import 'dart:convert';

List<MotivasiModel> motivasiModelFromJson(String str) =>
    List<MotivasiModel>.from(
        json.decode(str).map((x) => MotivasiModel.fromJson(x)));

String motivasiModelToJson(List<MotivasiModel> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

class MotivasiModel {
  MotivasiModel({
    this.id,
    this.isiMotivasi,
    this.idKategori,
    this.tanggalInput,
    this.tanggalUpdate,
    this.iduser,
    this.namaUser,
    this.totalLikes,
  });

  String? id;
  String? isiMotivasi;
  String? idKategori;
  DateTime? tanggalInput;
  String? tanggalUpdate;
  String? iduser;
  String? namaUser;
  String? totalLikes;

  factory MotivasiModel.fromJson(Map<String, dynamic> json) => MotivasiModel(
        id: json["id"]?.toString(),
        isiMotivasi: json["isi_motivasi"]?.toString(),
        idKategori: json["id_kategori"]?.toString(),
        tanggalInput: json["tanggal_input"] != null
            ? DateTime.tryParse(json["tanggal_input"].toString())
            : null,
        tanggalUpdate: json["tanggal_update"]?.toString(),
        iduser: json["iduser"]?.toString(),
        namaUser: json["nama_user"]?.toString(),
        totalLikes: json["total_likes"]?.toString() ?? '0',
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "isi_motivasi": isiMotivasi,
        "id_kategori": idKategori,
        "tanggal_input":
            "${tanggalInput?.year.toString().padLeft(4, '0')}-${tanggalInput?.month.toString().padLeft(2, '0')}-${tanggalInput?.day.toString().padLeft(2, '0')}",
        "tanggal_update": tanggalUpdate,
        "iduser": iduser,
        "nama_user": namaUser,
        "total_likes": totalLikes,
      };
}
