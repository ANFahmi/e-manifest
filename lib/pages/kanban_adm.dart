import 'package:flutter/material.dart';
import 'package:emanifest/drawer/custom_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:emanifest/services/auth_service.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'history_combin_kanban.dart';
import 'dn_list.dart';

class KanbanAdm extends StatefulWidget {
  @override
  _KanbanAdmPageState createState() => _KanbanAdmPageState();
}

class _KanbanAdmPageState extends State<KanbanAdm> {
  bool isFlashOn = false;
  bool _isSubmitting = false;
  bool _isLoading = false;
  List<dynamic> _historyKanban = [];
  final TextEditingController _customerKanbanController = TextEditingController();
  final TextEditingController _tagOkController = TextEditingController();

  @override
  void dispose() {
    _customerKanbanController.dispose();
    _tagOkController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    fetchHistoryKanban();
    _customerKanbanController.addListener(_checkIfBothFieldsAreFilled);
    _tagOkController.addListener(_checkIfBothFieldsAreFilled);
  }

  Future<void> fetchHistoryKanban() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    try {
      final response = await http.post(
        Uri.parse('https://mspin.newarmada.biz/sto/combin-kanban/history-kanban'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $token',
        },
        body: {
          'customer': 'ADM',
          'quick': 'true'
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final List<dynamic> data = responseData['data'];
        setState(() {
          _historyKanban = data;
          _isLoading = false;
        });
      } else {
        print('Gagal ambil data history: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }


  void _checkIfBothFieldsAreFilled() {
    final idLabel = _customerKanbanController.text.trim();
    final idKanban = _tagOkController.text.trim();

    if (idKanban.isNotEmpty && idLabel.isNotEmpty && !_isSubmitting) {
      _isSubmitting = true;
      _submitToApi(idKanban, idLabel).whenComplete(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _submitToApi(String idKanban, String idLabel) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('https://mspin.newarmada.biz/sto/combin-kanban/adm-kanban'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $token',
        },
        body: {
          'id_kanban': idKanban,
          'id_label': idLabel,
        },
      );

      final data = jsonDecode(response.body);

      if (data['status']) {
        String detail = "${data['message']}\n\n"
            "DN : ${data['dn'] ?? '-'}\n"
            "Total Kanban : ${data['scanned'] ?? '-'} / ${data['total'] ?? '-'}\n";

        _showDialog('Sukses', detail, true);
      } else {
        String detail = "${data['message']}\n\n"
            "DN : ${data['dn'] ?? '-'}\n"
            "Total Kanban : ${data['scanned'] ?? '-'} / ${data['total'] ?? '-'}\n";
        _showDialog('Gagal', detail, false);
      }
      await fetchHistoryKanban();
      _customerKanbanController.clear();
      _tagOkController.clear();
    } catch (e) {
      _showDialog('Error', 'Terjadi kesalahan saat mengirim data: $e', false);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showDialog(String title, String message, bool isSuccess) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.noHeader,
      animType: AnimType.scale,
      headerAnimationLoop: false,
      customHeader: Icon(
        isSuccess ? Icons.check_circle : Icons.error,
        color: isSuccess ? Colors.green : Colors.red,
        size: 100,
      ),
      title: title,
      desc: message,
      btnOkOnPress: () {},
      btnOkColor: isSuccess ? Colors.green : Colors.red,
    ).show();
  }


  void _ScannerCustomerKanban(BuildContext context) {
    bool isProcessing = false;
    final cameraController = MobileScannerController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          content: Stack(
            children: [
              Container(
                width: 300,
                height: 400,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: MobileScanner(
                    controller: cameraController,
                    fit: BoxFit.cover,
                    onDetect: (capture) async {
                      if (isProcessing) return;
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        final String? code = barcode.rawValue;
                        if (code != null) {
                          print('Barcode terdeteksi: $code');
                          isProcessing = true;
                          await cameraController.stop();
                          Navigator.of(context).pop(code);
                        }
                      }
                    },
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    cameraController.dispose();
                    Navigator.of(context).pop();
                  },
                ),
              ),
              Positioned(
                bottom: 10,
                left: 10,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      isFlashOn ? Icons.flashlight_on : Icons.flashlight_off,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: () {
                      setState(() {
                        isFlashOn = !isFlashOn;
                        cameraController.toggleTorch();
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).then((scannedCode) {
      if (scannedCode != null && scannedCode is String) {
        print('Hasil scan: $scannedCode');
        _customerKanbanController.text = scannedCode;
      }
    });
  }

  void _ScannerTagOk(BuildContext context) {
    bool isProcessing = false;
    final cameraController = MobileScannerController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          content: Stack(
            children: [
              Container(
                width: 300,
                height: 400,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: MobileScanner(
                    controller: cameraController,
                    fit: BoxFit.cover,
                    onDetect: (capture) async {
                      if (isProcessing) return;
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        final String? code = barcode.rawValue;
                        if (code != null) {
                          print('Barcode terdeteksi: $code');
                          isProcessing = true;
                          await cameraController.stop();
                          Navigator.of(context).pop(code);
                        }
                      }
                    },
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    cameraController.dispose();
                    Navigator.of(context).pop();
                  },
                ),
              ),
              Positioned(
                bottom: 10,
                left: 10,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      isFlashOn ? Icons.flashlight_on : Icons.flashlight_off,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: () {
                      setState(() {
                        isFlashOn = !isFlashOn;
                        cameraController.toggleTorch();
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).then((scannedCode) {
      if (scannedCode != null && scannedCode is String) {
        print('Hasil scan: $scannedCode');
        _tagOkController.text = scannedCode;
      }
    });
  }

  final Color primaryColor = Colors.teal;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Text(
          "ADM Kanban",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        elevation: 0,
        centerTitle: true,
      ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Scan Barcode",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        )
                      ],
                    ),
                    padding: EdgeInsets.all(12),
                    child: Column(
                      children: [
                        // Customer Kanban
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Customer Kanban", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            SizedBox(height: 6),
                            TextField(
                              controller: _customerKanbanController,
                              autofocus: true,
                              decoration: InputDecoration(
                                labelText: "Barcode Customer Kanban",
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(Icons.camera_alt, color: primaryColor),
                                  onPressed: () => _ScannerCustomerKanban(context),
                                ),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        // Tag OK / E-Kanban
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Tag OK / E - Kanban", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            SizedBox(height: 6),
                            TextField(
                              controller: _tagOkController,
                              decoration: InputDecoration(
                                labelText: "QR Code TAG OK / E - Kanban",
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(Icons.camera_alt, color: primaryColor),
                                  onPressed: () => _ScannerTagOk(context),
                                ),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),
                  Text("Menu Navigasi", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          elevation: 1,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.of(context).push(
                                PageRouteBuilder(
                                  pageBuilder: (_, __, ___) => HistoryCombinKanban(sourcePage: "ADM"),
                                  transitionsBuilder: (_, animation, __, child) {
                                    return SlideTransition(
                                      position: Tween<Offset>(
                                        begin: Offset(-1, 0),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    );
                                  },
                                ),
                              );
                            },
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.history, size: 24, color: Colors.blueGrey),
                                  SizedBox(height: 4),
                                  Text("History", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          elevation: 1,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.of(context).push(
                                PageRouteBuilder(
                                  pageBuilder: (_, __, ___) => DnList(source: 'ADM'),
                                  transitionsBuilder: (_, animation, __, child) {
                                    return SlideTransition(
                                      position: Tween<Offset>(
                                        begin: Offset(1, 0),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    );
                                  },
                                ),
                              );
                            },
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.local_shipping, size: 24, color: Colors.green),
                                  SizedBox(height: 4),
                                  Text("Delivery Notes", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16),
                  Text("5 Scan Terakhir", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),

                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        )
                      ],
                    ),
                    padding: EdgeInsets.all(12),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch, // biar child Column memenuhi lebar
                        children: List.generate(_historyKanban.length, (index) {
                          final item = _historyKanban[index];
                          return Container(
                            padding: EdgeInsets.all(12),
                            margin: EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.qr_code_2, size: 28, color: Colors.teal), // lebih besar
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Part - ${item['part']}",
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        "Waktu: ${item['created_at']}",
                                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Loader
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  ),
                ),
              ),
          ],
        )
    );
  }
}
