import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medknows/pages/medicines_screen.dart';
import 'package:medknows/pages/camera_screen.dart';
import 'package:medknows/pages/reminder_screen.dart';
import 'package:medknows/pages/profile_screen.dart';
import 'package:medknows/widgets/bottom_nav_bar.dart';
import 'package:medknows/pages/medicines.dart';
import 'package:medknows/widgets/medicine_details_card.dart';
import 'package:medknows/widgets/custom_profile_drawer.dart';
import '../utils/active_medicine_manager.dart';
import '../utils/medicine_recommender.dart';

class HomeScreen extends StatefulWidget {
  final String userName;
  final Map<String, dynamic>? reminderData;
  final int initialIndex;

  const HomeScreen({super.key, required this.userName, this.reminderData, this.initialIndex = 0});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int _currentIndex;
  late String _userName; // Add this
  Map<String, dynamic>? _reminderData; // Add this property

  HomeScreenState() : _currentIndex = 0;

  Map<String, dynamic>? _reminderMedicine;
  DateTime? _nextIntake;
  int? _tablets;
  int? _dosage;

  late List<Widget> _screens;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isProfileOpen = false;

  @override
  void initState() {
    super.initState();
    _userName = widget.userName; // Initialize in initState
    _currentIndex = widget.initialIndex;
    if (widget.reminderData != null) {
      _reminderData = widget.reminderData; // Store the reminder data
      _reminderMedicine = widget.reminderData!['medicine'];
      _nextIntake = widget.reminderData!['nextIntake'];
      _tablets = widget.reminderData!['tablets'];
      _dosage = widget.reminderData!['dosage'];
      if (_currentIndex != 1) {
        _currentIndex = 3; // Navigate to the ReminderScreen
      }
    }
    _screens = [
      HomeScreenContent(userName: _userName), // Pass userName here
      MedicinesScreen(),
      CameraScreen(),
      ReminderScreen(
        reminderData: _reminderMedicine != null
            ? {
                'medicine': _reminderMedicine,
                'nextIntake': _nextIntake,
                'tablets': _tablets,
                'dosage': _dosage,
              }
            : null,
        onDelete: clearReminder,
      ),
    ]; // Removed ProfileScreen from screens list
    if (widget.reminderData != null) {
      ActiveMedicineManager.setActiveMedicine(widget.reminderData!);
    }
    _loadActiveMedicine();
  }

  Future<void> _loadActiveMedicine() async {
    final activeMedicine = await ActiveMedicineManager.getActiveMedicine();
    if (mounted) {
      setState(() {
        _reminderData = activeMedicine;
      });
    }
  }

  void _onNavBarTapped(int index) async {
    if (index == 1) {
      final activeMedicine = await ActiveMedicineManager.getActiveMedicine();
      if (activeMedicine != null && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Active Medicine Warning'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('You currently have an active medicine:'),
                  SizedBox(height: 8),
                  Text(
                    activeMedicine['medicine']['name'],
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('Please be careful about potential drug interactions.'),
                ],
              ),
              actions: [
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: Text('Continue'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MedicinesScreen(
                          showBackButton: true,
                          reminderData: activeMedicine,
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
        return;
      }
    }
    setState(() {
      _currentIndex = index;
    });
  }

  void setReminder(Map<String, dynamic> medicine, DateTime nextIntake, int tablets, int dosage) {
    setState(() {
      _reminderMedicine = medicine;
      _nextIntake = nextIntake;
      _tablets = tablets;
      _dosage = dosage;
      _currentIndex = 3; // Navigate to the ReminderScreen
    });
  }

  void clearReminder() {
    setState(() {
      _reminderMedicine = null;
      _nextIntake = null;
      _tablets = null;
      _dosage = null;
      _currentIndex = 0; // Navigate back to the HomeScreenContent
    });
  }

  void updateUserName(String newName) {
    setState(() {
      _userName = newName;
      _screens = [
        HomeScreenContent(userName: _userName),
        MedicinesScreen(),
        CameraScreen(),
        ReminderScreen(
          reminderData: _reminderMedicine != null
              ? {
                  'medicine': _reminderMedicine,
                  'nextIntake': _nextIntake,
                  'tablets': _tablets,
                  'dosage': _dosage,
                }
              : null,
          onDelete: clearReminder,
        ),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    _screens = [
      HomeScreenContent(userName: _userName),
      MedicinesScreen(),
      CameraScreen(),
      ReminderScreen(
        reminderData: _reminderMedicine != null
            ? {
                'medicine': _reminderMedicine,
                'nextIntake': _nextIntake,
                'tablets': _tablets,
                'dosage': _dosage,
              }
            : null,
        onDelete: clearReminder,
      ),
    ];

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0,
        automaticallyImplyLeading: false,
        actions: [],
      ),
      body: Stack(
        children: [
          _screens[_currentIndex],
          if (_isProfileOpen)
            GestureDetector(
              onTap: () => setState(() => _isProfileOpen = false),
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),
          if (_isProfileOpen)
            CustomProfileDrawer(
              onClose: () => setState(() => _isProfileOpen = false),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _isProfileOpen ? 4 : _currentIndex,
        onTap: (index) {
          if (index == 4) {
            setState(() {
              _isProfileOpen = true;
            });
          } else if (index == 1) { // Check for Medicines tab
            _onNavBarTapped(index);
          } else {
            setState(() {
              _isProfileOpen = false;
              _currentIndex = index;
            });
          }
        },
        isProfileOpen: _isProfileOpen,  // Pass this new property
        reminderData: _reminderData,  // Use the class property instead of widget.reminderData
      ),
    );
  }
}

class HomeScreenContent extends StatefulWidget {
  final String userName; // Add this

  HomeScreenContent({required this.userName}); // Update constructor

  @override
  _HomeScreenContentState createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<HomeScreenContent> {
  List<String> selectedCategories = ['All'];
  Map<String, dynamic>? selectedMedicine;
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTopButton = false;

  // Update categories list based on unique classifications
  final List<String> categories = [
    'All',
    'Analgesic',
    'Antacid',
    'Antihistamine',
    'Antitussive',
    'Antipyretic',
    'Decongestant',
    'Mucolytic',
    'NSAID'
  ];

  final List<String> categoryImages = [
    'assets/icons/medicines.png',
    'assets/icons/pain.png',      // Analgesic
    'assets/icons/stomach.png',   // Antacid
    'assets/icons/allergy.png',   // Antihistamine
    'assets/icons/coughing.png',  // Antitussive
    'assets/icons/fever.png',     // Antipyretic
    'assets/icons/nose.png',      // Decongestant
    'assets/icons/mucus.png',     // Mucolytic
    'assets/icons/inflammation.png' // NSAID
  ];

  // Change to single category selection
  String selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      setState(() {
        _showBackToTopButton = _scrollController.offset >= 200;
      });
    });
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _onCategorySelected(String category) {
    setState(() {
      selectedCategory = category;
      selectedCategories = [category]; // Update selectedCategories to match
    });
  }

  void _onMedicineSelected(Map<String, dynamic> medicine) {
    setState(() {
      selectedMedicine = medicine;
    });
  }

  void _onCloseCard() {
    setState(() {
      selectedMedicine = null;
    });
  }

  List<Map<String, dynamic>> getFilteredMedicines(List<Map<String, dynamic>> allMedicines) {
    // If 'All' is selected or no search query, use all medicines
    List<Map<String, dynamic>> filteredMedicines = selectedCategory == 'All' 
        ? allMedicines
        : allMedicines.where((medicine) {
            return medicine['classification'].contains(selectedCategory);
          }).toList();

    // Apply search filtering if there's a search query
    if (searchQuery.isNotEmpty) {
      filteredMedicines = filteredMedicines.where((medicine) {
        return medicine['name'].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
               medicine['genericName'].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
               medicine['description'].toString().toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();
    }

    return filteredMedicines;
  }

  @override
  Widget build(BuildContext context) {
    // Initialize medicines list
    List<Map<String, dynamic>> sortedMedicines = List.from(medicines)
      ..sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));

    // Apply category and search filtering
    sortedMedicines = getFilteredMedicines(sortedMedicines);

    return Stack(
      children: [
        CustomScrollView(
          controller: _scrollController,  // Add this line
          slivers: [
            SliverAppBar(
              primary: false, // Add this line to remove the endDrawer button
              automaticallyImplyLeading: false,
              actions: const [], // Add this to remove the endDrawer button
              pinned: false, // Changed from true to false
              expandedHeight: 100.0,
              flexibleSpace: FlexibleSpaceBar(
                title: Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: Text(
                    'Hi, ${widget.userName}',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.openSans(
                      textStyle: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color:  Colors.blue,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search medicines...',
                    hintStyle: TextStyle(color: Colors.blue.withOpacity(0.5)),
                    prefixIcon: Icon(Icons.search, color: Colors.blue),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide(color: Colors.blue, width: 2),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
                child: CategoriesWidget(
                  categories: categories,
                  categoryImages: categoryImages,
                  selectedCategories: selectedCategories,
                  onCategorySelected: _onCategorySelected,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0).copyWith(bottom: 10.0), // Add bottom padding
              sliver: sortedMedicines.isEmpty
                  ? SliverToBoxAdapter(
                      child: Center(
                        child: Text('No medicine available for the selected category.'),
                      ),
                    )
                  : SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final medicine = sortedMedicines[index];

                          return GestureDetector(
                            onTap: () => _onMedicineSelected(medicine),
                            child: Stack(
                              children: [
                                AspectRatio(
                                  aspectRatio: 1, // Maintain a square aspect ratio
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.5),
                                          spreadRadius: 2,
                                          blurRadius: 5,
                                          offset: Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.all(10.0),
                                            child: Center(
                                              child: Image.asset(
                                                medicine['image'],
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Text(
                                                medicine['name'],
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  height: 1.0, // Set line height to 1
                                                ),
                                              ),
                                              SizedBox(height: 2),
                                              Text(
                                                medicine['genericName'],
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey,
                                                  height: 1.0, // Set line height to 1
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(height: 8), // Add some space at the bottom
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        childCount: sortedMedicines.length,
                      ),
                    ),
            ),
          ],
        ),
        if (_showBackToTopButton)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              mini: true,
              onPressed: _scrollToTop,
              backgroundColor: Colors.blue.withOpacity(0.5), // Adjusted opacity
              child: const Icon(Icons.arrow_upward, color: Colors.white),
            ),
          ),
        if (selectedMedicine != null)
          Stack(
            children: [
              ModalBarrier(dismissible: false, color: Colors.black.withOpacity(0.3)), // Changed from 0.5 to 0.3
              MedicineDetailsCard(
                image: selectedMedicine!['image'],
                name: selectedMedicine!['name'],
                genericName: selectedMedicine!['genericName'],
                description: selectedMedicine!['description'],
                categories: selectedMedicine!['categories'],
                dosage: selectedMedicine!['dosage'],
                directionsOfUse: selectedMedicine!['directions of use'],
                administration: selectedMedicine!['administration'],
                contraindication: selectedMedicine!['contraindication'],
                onClose: _onCloseCard,
              ),
            ],
          ),
      ],
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}

class CategoriesWidget extends StatelessWidget {
  final List<String> categories;
  final List<String> categoryImages;
  final List<String> selectedCategories;
  final ValueChanged<String> onCategorySelected;

  const CategoriesWidget({
    super.key,
    required this.categories,
    required this.categoryImages,
    required this.selectedCategories,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              'Categories',
              style: GoogleFonts.roboto(
                textStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color.fromRGBO(0, 0, 0, 1),
                  height: 2,
                ),
              ),
            ),
          ),
          Container(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return GestureDetector(
                  onTap: () => onCategorySelected(category),
                  child: Container(
                    width: 100,
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    margin: EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: selectedCategories.first == category ? Colors.blue : Colors.grey,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          categoryImages[index],
                          color: Colors.white,
                          height: 36,
                          width: 36,
                        ),
                        SizedBox(height: 5),
                        Text(
                          category,
                          style: GoogleFonts.openSans(
                            textStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
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
  }
}