import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

import 'package:another_flushbar/flushbar.dart';
import 'package:dio/dio.dart';

import '../Constant/const.dart';


class EditPage extends StatefulWidget {
  final String? id;
  final String? isiMotivasi;
  const EditPage({Key? key, this.id, this.isiMotivasi}) : super(key: key);

  @override
  _EditPageState createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  var dio = Dio(BaseOptions(headers: {'ngrok-skip-browser-warning': '69420'}));
  Future<dynamic> putPost(String isiMotivasi, String ids) async {
    try {
      Map<String, dynamic> data = {"isi_motivasi": isiMotivasi, "id": ids};
      var response = await dio.put('$url/motivasi_update.php',
          data: data,
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
          ));

      debugPrint("---> ${response.data} + ${response.statusCode}");
      return response.data;
    } catch (e) {
      debugPrint("Update error: $e");
      return null;
    }
  }

  TextEditingController isiMotivasiC = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit"),
      ),
      body: SafeArea(
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("${widget.isiMotivasi}"),
                const SizedBox(
                  height: 20,
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width / 1.4,
                  child: FormBuilderTextField(
                    name: "isiMotivasi",
                    controller: isiMotivasiC,
                    decoration: const InputDecoration(
                      labelText: "New Data",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.only(left: 10),
                    ),
                  ),
                ),
                ElevatedButton(
                    onPressed: () {
                      putPost(isiMotivasiC.text, widget.id.toString())
                          .then((value) => {
                                if (value != null)
                                  {
                                    Navigator.pop(context),
                                    Flushbar(
                                      message: "Berhasil Update & Refresh dlu",
                                      duration: const Duration(seconds: 5),
                                      backgroundColor: Colors.green,
                                      flushbarPosition: FlushbarPosition.TOP,
                                    ).show(context)
                                  }
                              });
                    },
                    child: const Text("Submit"))
              ],
            ),
          ),
        ),
      ),
    );
  }
}
