import 'package:flutter/material.dart';
import 'package:emanifest/component/MenuItems.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emanifest/services/auth_service.dart';
import 'dart:async';

class DashboardMenu extends StatefulWidget {
  @override
  _DashboardMenuPageState createState() => _DashboardMenuPageState();
}

class _DashboardMenuPageState extends State<DashboardMenu> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<MenuItemConfig> filteredMenuItems = [];
  List<String> accessPayload = [];
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<String> jumbotronImages = [
    'assets/img/IMG_3562.jpg',
    'assets/img/IMG_3577.jpg',
    'assets/img/IMG_3620.jpg',
  ];

  void exitSearchMode() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
      FocusScope.of(context).unfocus();
    });
  }

  Future<void> loadMenuWithPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token != null) {
      final payload = JwtDecoder.decode(token);
      accessPayload = List<String>.from(payload['payload'] ?? []);

      setState(() {
        filteredMenuItems = menuItems.where((item) {
          return accessPayload.any((perm) => item.permissions.contains(perm));
        }).toList();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    loadMenuWithPermissions();
    filteredMenuItems = List.from(menuItems);
    _searchController.addListener(() {
      final keyword = _searchController.text.toLowerCase();
      setState(() {
        filteredMenuItems = menuItems
            .where((item) => item.label.toLowerCase().contains(keyword))
            .toList();
      });
    });
  }


  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 45,
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onTap: () {
                                setState(() {
                                  _isSearching = true;
                                });
                              },
                              decoration: InputDecoration(
                                hintText: 'Cari menu...',
                                border: InputBorder.none,
                                icon: Icon(Icons.search, color: Colors.grey),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  IconButton(
                    icon: Icon(Icons.logout, size: 28, color: Colors.teal),
                    onPressed: () async {
                      final confirm = await showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('Konfirmasi Logout'),
                          content: Text('Apakah Anda yakin ingin logout?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text('Batal'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text('Logout'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        final success = await AuthService().logout();
                        if (!context.mounted) return;
                        if (success) {
                          Navigator.pushReplacementNamed(context, '/login');
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Logout gagal")),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),

            Expanded(
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: 300),
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                child: _isSearching
                    ? _buildSearchView()
                    : _buildMainView(),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildSearchView() {
    return Container(
      key: ValueKey('searchView'),
      color: Colors.white,
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: exitSearchMode,
            icon: Icon(Icons.close, color: Colors.grey),
            label: Text("Tutup Pencarian", style: TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: filteredMenuItems.isNotEmpty
                ? ListView(
              children: filteredMenuItems.map((item) {
                return ListTile(
                  leading: Icon(item.icon, color: Colors.teal),
                  title: Text(item.label),
                  onTap: () {
                    Navigator.pushNamed(context, item.route);
                  },
                );
              }).toList(),
            )
                : Center(child: Text("Tidak ditemukan")),
          ),
        ],
      ),
    );
  }

  Widget _buildMainView() {
    return SingleChildScrollView(
      key: ValueKey('mainView'),
      child: Column(
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 180,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: jumbotronImages.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(jumbotronImages[index], fit: BoxFit.cover),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.black45, Colors.transparent],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(jumbotronImages.length, (index) {
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == index ? 12 : 8,
                height: _currentPage == index ? 12 : 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index ? Colors.teal : Colors.grey[400],
                ),
              );
            }),
          ),
          SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Menu",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade800,
                  ),
                ),
                SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: filteredMenuItems.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.8,
                      ),
                      itemBuilder: (context, index) {
                        final item = filteredMenuItems[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, item.route);
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.grey[400],
                                child: Icon(item.icon, color: Colors.teal, size: 28),
                              ),
                              SizedBox(height: 6),
                              Flexible(
                                child: Text(
                                  item.label,
                                  style: TextStyle(fontSize: 10),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
