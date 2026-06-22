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
    this.foto,
    this.profesi,
    this.totalLikes,
    this.isLiked,
    this.totalComments,
    this.userReaction,
    this.reactionCounts,
  });

  String? id;
  String? isiMotivasi;
  String? idKategori;
  DateTime? tanggalInput;
  String? tanggalUpdate;
  String? iduser;
  String? namaUser;
  String? foto; // EPIC 1: Profile picture from user table
  String? profesi;
  String? totalLikes;
  bool? isLiked;
  String? totalComments;
  String? userReaction;
  Map<String, int>? reactionCounts;

  factory MotivasiModel.fromJson(Map<String, dynamic> json) {
    Map<String, int> counts = {};
    if (json["reaction_counts"] != null && json["reaction_counts"] is Map) {
      json["reaction_counts"].forEach((key, value) {
        counts[key.toString()] = int.tryParse(value.toString()) ?? 0;
      });
    }

    return MotivasiModel(
        id: json["id"]?.toString(),
        isiMotivasi: json["isi_motivasi"]?.toString(),
        idKategori: json["id_kategori"]?.toString(),
        tanggalInput: json["tanggal_input"] != null
            ? DateTime.tryParse(json["tanggal_input"].toString())
            : null,
        tanggalUpdate: json["tanggal_update"]?.toString(),
        iduser: json["iduser"]?.toString(),
        namaUser: json["nama_user"]?.toString(),
        foto: json["foto"]?.toString(), // EPIC 1: Profile picture
        profesi: json["profesi"]?.toString(),
        totalLikes: json["total_likes"]?.toString() ?? '0',
        isLiked: json["is_liked"] == true ||
                 json["is_liked"] == "true" ||
                 json["is_liked"] == 1 ||
                 json["is_liked"] == "1",
        totalComments: json["total_comments"]?.toString() ?? '0',
        userReaction: json["user_reaction"]?.toString(),
        reactionCounts: counts,
      );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "isi_motivasi": isiMotivasi,
        "id_kategori": idKategori,
        "tanggal_input":
            "${tanggalInput?.year.toString().padLeft(4, '0')}-${tanggalInput?.month.toString().padLeft(2, '0')}-${tanggalInput?.day.toString().padLeft(2, '0')}",
        "tanggal_update": tanggalUpdate,
        "iduser": iduser,
        "nama_user": namaUser,
        "foto": foto,
        "profesi": profesi,
        "total_likes": totalLikes,
        "is_liked": isLiked,
        "total_comments": totalComments,
        "user_reaction": userReaction,
        "reaction_counts": reactionCounts,
      };
}

// EPIC 3: Notification Model
class NotificationModel {
  NotificationModel({
    this.id,
    this.userId,
    this.actorId,
    this.type,
    this.postId,
    this.commentId,
    this.isRead,
    this.createdAt,
    this.actorNama,
    this.actorFoto,
    this.message,
    this.postContent,
  });

  String? id;
  String? userId;
  String? actorId;
  String? type;
  String? postId;
  String? commentId;
  bool? isRead;
  DateTime? createdAt;
  String? actorNama;
  String? actorFoto;
  String? message;
  String? postContent;

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      NotificationModel(
        id: json["id"]?.toString(),
        userId: json["user_id"]?.toString(),
        actorId: json["actor_id"]?.toString(),
        type: json["type"]?.toString(),
        postId: json["post_id"]?.toString(),
        commentId: json["comment_id"]?.toString(),
        isRead: json["is_read"] == true || json["is_read"] == 1,
        createdAt: json["created_at"] != null
            ? DateTime.tryParse(json["created_at"].toString())
            : null,
        actorNama: json["actor_nama"]?.toString(),
        actorFoto: json["actor_foto"]?.toString(),
        message: json["message"]?.toString(),
        postContent: json["post_content"]?.toString(),
      );
}

// EPIC 2: User Model for Follow screen
class UserModel {
  UserModel({
    this.id,
    this.nama,
    this.email,
    this.profesi,
    this.foto,
    this.isFollowing,
    this.followerCount,
  });

  String? id;
  String? nama;
  String? email;
  String? profesi;
  String? foto;
  bool? isFollowing;
  int? followerCount;

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json["id"]?.toString(),
        nama: json["nama"]?.toString(),
        email: json["email"]?.toString(),
        profesi: json["profesi"]?.toString(),
        foto: json["foto"]?.toString(),
        isFollowing: json["is_following"] == true || json["is_following"] == 1,
        followerCount: int.tryParse(json["follower_count"]?.toString() ?? '0') ?? 0,
      );
}

// EPIC 4: Comment Model with parent_id for nested replies
class CommentModel {
  CommentModel({
    this.id,
    this.idMotivasi,
    this.iduser,
    this.isiKomentar,
    this.parentId,
    this.tanggalInput,
    this.namaUser,
    this.foto,
  });

  String? id;
  String? idMotivasi;
  String? iduser;
  String? isiKomentar;
  String? parentId; // EPIC 4: For nested replies
  DateTime? tanggalInput;
  String? namaUser;
  String? foto;

  factory CommentModel.fromJson(Map<String, dynamic> json) => CommentModel(
        id: json["id"]?.toString(),
        idMotivasi: json["id_motivasi"]?.toString(),
        iduser: json["iduser"]?.toString(),
        isiKomentar: json["isi_komentar"]?.toString(),
        parentId: json["parent_id"]?.toString(), // EPIC 4: Parent comment ID
        tanggalInput: json["tanggal_input"] != null
            ? DateTime.tryParse(json["tanggal_input"].toString())
            : null,
        namaUser: json["nama_user"]?.toString(),
        foto: json["foto"]?.toString(),
      );
}
