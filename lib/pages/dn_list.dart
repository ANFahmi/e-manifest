import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class DnList extends StatefulWidget {
  final String source;
  const DnList({Key? key, required this.source}) : super(key: key);

  @override
  State<DnList> createState() => _DnListState();
}

class _DnListState extends State<DnList> {
  DateTimeRange? _selectedDateRange;
  List<dynamic> _historyData = [];
  bool _isLoading = false;
  String? _selectedCustomer;
  List<String> _customerOptions = [];

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

  void _showKanbanBottomSheet(BuildContext context, String bstnk, List kanbanList) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      margin: EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Text(
                    'Detail Kanban',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'BSTNK: $bstnk',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: kanbanList.length,
                      itemBuilder: (_, idx) {
                        final item = kanbanList[idx];
                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                          margin: EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: Icon(Icons.qr_code_2, color: Colors.teal),
                            title: Text(
                              item['barcode'] ?? '-',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 4),
                                Text("Part         : ${item['part_number'] ?? '-'}", style: TextStyle(fontSize: 12)),
                                Text("Job Number : ${item['job_number'] ?? '-'}", style: TextStyle(fontSize: 12)),
                                Text("Qty          : ${item['qty'] ?? '-'}", style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showKanbanDialog(BuildContext context, String bstnk, List kanbanList) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Detail Kanban untuk $bstnk'),
          content: kanbanList.isEmpty
              ? Text("Tidak ada data kanban.")
              : SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: kanbanList.length,
              separatorBuilder: (_, __) => Divider(),
              itemBuilder: (context, idx) {
                final item = kanbanList[idx];
                return ListTile(
                  leading: Icon(Icons.assignment),
                  title: Text(item['barcode'] ?? '-'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Part        : ${item['part_number'] ?? '-'}",
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        "Job Number : ${item['job_number'] ?? '-'}",
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        "Qty      : ${item['qty'] ?? '-'}",
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: Text('Tutup'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _callFilterApi(DateTime? start, DateTime? end, String? customer) async {
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

      final url = Uri.parse('https://mspin.newarmada.biz/sto/combin-kanban/dn-require');

      final Map<String, String> body = {};
      if (customer != null) body['customer'] = customer;
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
          print('API balas tapi data kosong atau status false');
          setState(() {
            _historyData = [];
          });
        }
      } else {
        print('Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Exception: $e');
    }  finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeCustomerOptions();
  }

  void _initializeCustomerOptions() {
    if (widget.source == 'ADM') {
      _customerOptions = [
        'ADM PLANT 1',
        'ADM PLANT 4',
        'ADM PLANT 5',
      ];
    } else if (widget.source == 'TMMIN') {
      _customerOptions = ['TMMIN'];
    } else {
      _customerOptions = ['HMMI'];
    }
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
          "DN ${widget.source}",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // FORM FILTER
              Text(
                "Filter Pengiriman",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),

              SizedBox(height: 12),

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
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
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
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Customer',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            value: _selectedCustomer,
                            items: _customerOptions.map((customer) {
                              return DropdownMenuItem<String>(
                                value: customer,
                                child: Text(
                                  customer,
                                  style: TextStyle(
                                    fontSize: 13,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedCustomer = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        icon: Icon(Icons.filter_alt),
                        label: Text(
                          "Terapkan Filter",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        onPressed: () {
                          if (_selectedDateRange != null && _selectedCustomer != null) {
                            final start = _selectedDateRange!.start;
                            final end = _selectedDateRange!.end;
                            _callFilterApi(start, end, _selectedCustomer);
                          } else {
                            print('❗ Silakan lengkapi filter');
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),

              Text(
                "Hasil Data",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),

              SizedBox(height: 12),

              _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _historyData.isEmpty
                  ? Center(child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox, size: 48, color: Colors.grey.shade400),
                    SizedBox(height: 8),
                    Text(
                      "Belum ada pengiriman untuk filter ini",
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    )
                  ],
                ),
              ))
                  : ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _historyData.length,
                itemBuilder: (_, index) {
                  final parent = _historyData[index];
                  final kanbanList = parent['kanban'] ?? [];

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 3,
                    margin: EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      contentPadding: EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: primaryColor.withOpacity(0.1),
                        child: Icon(Icons.local_shipping, color: primaryColor),
                      ),
                      title: Text(
                        parent['BSTNK'] ?? 'BSTNK kosong',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 4),
                          Text("Customer : ${parent['CUSTOMER'] ?? '-'}"),
                          Text("VDATU       : ${parent['VDATU'] ?? '-'}"),
                        ],
                      ),
                      onTap: () {
                        _showKanbanBottomSheet(context, parent['BSTNK'], kanbanList);
                      },
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
