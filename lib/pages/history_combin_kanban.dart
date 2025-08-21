import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class HistoryCombinKanban extends StatefulWidget {
  final String sourcePage;
  const HistoryCombinKanban({super.key, required this.sourcePage});
  @override
  State<HistoryCombinKanban> createState() => _HistoryCombinKanbanState();
}

class _HistoryCombinKanbanState extends State<HistoryCombinKanban> {
  DateTimeRange? _selectedDateRange;
  List<dynamic> _historyData = [];
  bool _isLoading = false;

  void _pickDateRange() async {
    final now = DateTime.now();
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2022),
      lastDate: now,
      initialDateRange: _selectedDateRange ??
          DateTimeRange(
            start: now.subtract(Duration(days: 7)),
            end: now,
          ),
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  Future<void> _callFilterApi(DateTime? start, DateTime? end) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        print('JWT tidak ditemukan di SharedPreferences');
        return;
      }

      final url = Uri.parse('https://mspin.newarmada.biz/sto/combin-kanban/history-kanban');

      final Map<String, String> body = {
        'customer': widget.sourcePage,
      };
      if (start != null) body['start_date'] = start.toString();
      if (end != null) body['end_date'] = end.toString();

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == true && decoded['data'] != null) {
          setState(() {
            _historyData = decoded['data'];
          });
        } else {
          print('✅ API balas tapi data kosong atau status false');
          setState(() {
            _historyData = [];
          });
        }
      } else {
        print('❌ Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Exception: $e');
    }  finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    print("Sumber halaman: ${widget.sourcePage}");
  }

  final Color primaryColor = Colors.teal;

  @override
  Widget build(BuildContext context) {
    String rangeText = _selectedDateRange == null
        ? "Pilih rentang tanggal"
        : "${_selectedDateRange!.start.toLocal().toString().split(' ')[0]} s.d. ${_selectedDateRange!.end.toLocal().toString().split(' ')[0]}";

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Riwayat Kanban ${widget.sourcePage}",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryColor, // hijau
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Judul filter
              Text(
                "Filter Riwayat",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),

              SizedBox(height: 12),

              // CARD FORM FILTER
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    )
                  ],
                ),
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Date range input
                    InkWell(
                      onTap: _pickDateRange,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey.shade50,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                rangeText,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                            Icon(Icons.calendar_today, size: 18, color: primaryColor),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 16),

                    // Tombol filter dan current
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.filter_alt, size: 18),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            label: Text(
                              "Terapkan Filter",
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () {
                              if (_selectedDateRange != null) {
                                final start = _selectedDateRange!.start;
                                final end = _selectedDateRange!.end;
                                _callFilterApi(start, end);
                              } else {
                                print('❗ Silakan pilih rentang tanggal dulu');
                              }
                            },
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.refresh, size: 18),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            label: Text(
                              "Current",
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () {
                              _callFilterApi(null, null);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),

              // Judul hasil
              Text(
                "Hasil Data",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),

              SizedBox(height: 12),

              // LIST RIWAYAT
              _isLoading
                  ? Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                  : _historyData.isEmpty
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text("Tidak ada data riwayat.",
                      style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                ),
              )
                  : ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _historyData.length,
                itemBuilder: (_, index) {
                  final item = _historyData[index];
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    margin: EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      contentPadding: EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: primaryColor.withOpacity(0.1),
                        child: Icon(Icons.qr_code_2, color: primaryColor),
                      ),
                      title: Text(
                        item['id_label'] ?? 'ID Label kosong',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Part       : ${item['part'] ?? '-'}", style: TextStyle(fontSize: 12)),
                            Text("TAG       : ${item['id_kanban'] ?? '-'}", style: TextStyle(fontSize: 12)),
                            Text("Tgl Scan : ${item['created_at'] ?? '-'}", style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

}
