import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'package:photo_view/photo_view.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

part 'main.g.dart';

@HiveType(typeId: 0)
class Booking {
  @HiveField(0)
  String name;
  @HiveField(1)
  String contact;
  @HiveField(2)
  String ticketType;
  @HiveField(3)
  bool isPaid;
  @HiveField(4)
  bool isTicketGiven;
  @HiveField(5)
  String? photoPath;
  @HiveField(6)
  String? routeFrom;
  @HiveField(7)
  String? routeTo;
  @HiveField(8)
  DateTime? date;

  Booking({
    required this.name,
    required this.contact,
    required this.ticketType,
    this.isPaid = false,
    this.isTicketGiven = false,
    this.photoPath,
    this.routeFrom,
    this.routeTo,
    this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'contact': contact,
      'ticketType': ticketType,
      'isPaid': isPaid,
      'isTicketGiven': isTicketGiven,
      'photoPath': photoPath,
      'routeFrom': routeFrom,
      'routeTo': routeTo,
      'date': date?.toIso8601String(),
    };
  }

  static Booking fromMap(Map<String, dynamic> map) {
    return Booking(
      name: map['name'] ?? '',
      contact: map['contact'] ?? '',
      ticketType: map['ticketType'] ?? 'Single',
      isPaid: map['isPaid'] ?? false,
      isTicketGiven: map['isTicketGiven'] ?? false,
      photoPath: map['photoPath'],
      routeFrom: map['routeFrom'],
      routeTo: map['routeTo'],
      date: map['date'] != null ? DateTime.tryParse(map['date']) : null,
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Hive.initFlutter();
    Hive.registerAdapter(BookingAdapter());
    await Hive.openBox<Booking>('bookings');
    await Hive.openBox('settings');
    runApp(const TicketMatePro());
  } catch (e) {
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Failed to initialize app: $e'),
        ),
      ),
    ));
  }
}

class TicketMatePro extends StatelessWidget {
  const TicketMatePro({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('settings').listenable(),
      builder: (context, box, _) {
        final themeMode = box.get('themeMode', defaultValue: 'light') == 'light'
            ? ThemeMode.light
            : ThemeMode.dark;
        return MaterialApp(
          title: 'TicketMate Pro',
          theme: ThemeData(
            textTheme: GoogleFonts.poppinsTextTheme(),
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            textTheme: GoogleFonts.poppinsTextTheme().apply(bodyColor: Colors.white),
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: themeMode,
          home: const BookingDashboard(),
        );
      },
    );
  }
}

class BookingDashboard extends StatefulWidget {
  const BookingDashboard({super.key});

  @override
  State<BookingDashboard> createState() => _BookingDashboardState();
}

class _BookingDashboardState extends State<BookingDashboard> {
  List<Booking> bookings = [];
  List<Booking> filteredBookings = [];
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController contactController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  final TextEditingController routeFromController = TextEditingController();
  final TextEditingController routeToController = TextEditingController();
  String? selectedTicketType = 'Single';
  DateTime? selectedDate;
  XFile? selectedImage;
  bool imageSelected = false;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBookings();
    searchController.addListener(_filterBookings);
  }

  Future<void> _loadBookings() async {
    try {
      final box = Hive.box<Booking>('bookings');
      setState(() {
        bookings = box.values.toList();
        filteredBookings = bookings;
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      try {
        await Hive.deleteBoxFromDisk('bookings');
        await Hive.openBox<Booking>('bookings');
        setState(() {
          bookings = [];
          filteredBookings = [];
          isLoading = false;
          errorMessage = 'Data reset due to corruption. Try adding bookings again.';
        });
      } catch (e) {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load bookings: $e';
        });
      }
    }
  }

  Future<void> _saveBooking(Booking booking, {int? index}) async {
    try {
      final box = Hive.box<Booking>('bookings');
      if (index != null) {
        await box.putAt(index, booking);
      } else {
        await box.add(booking);
      }
      await _loadBookings();
    } catch (e) {
      // ignore: dead_code
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save booking: $e')),
        );
      }
    }
  }

  void _filterBookings() {
    String query = searchController.text.toLowerCase();
    setState(() {
      filteredBookings = bookings
          .where((booking) =>
              booking.name.toLowerCase().contains(query) ||
              booking.contact.contains(query))
          .toList();
    });
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      // ignore: dead_code
      if (!mounted) return;
      if (image != null &&
          ['.jpg', '.jpeg', '.png']
              .contains(image.path.toLowerCase().substring(image.path.length - 4))) {
        setState(() {
          selectedImage = image;
          imageSelected = true;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a JPG, JPEG, or PNG image')),
        );
      }
    } catch (e) {
      // ignore: dead_code
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void editBooking(int index) {
    final booking = bookings[index];
    nameController.text = booking.name;
    contactController.text = booking.contact;
    String editTicketType = booking.ticketType;
    routeFromController.text = booking.routeFrom ?? '';
    routeToController.text = booking.routeTo ?? '';
    DateTime? editDate = booking.date;
    XFile? editImage = booking.photoPath != null ? XFile(booking.photoPath!) : null;
    bool editImageSelected = booking.photoPath != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter modalSetState) {
          return SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 20,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Edit Booking',
                    style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 25),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (val) => val!.isEmpty ? 'Enter name' : null,
                  ),
                  TextFormField(
                    controller: contactController,
                    decoration: const InputDecoration(labelText: 'Contact Number'),
                    keyboardType: TextInputType.phone,
                    validator: (val) => val!.isEmpty ? 'Enter contact number' : null,
                  ),
                  const SizedBox(height: 25),
                  Text('Ticket Type', style: GoogleFonts.poppins(fontSize: 16)),
                  ToggleButtons(
                    isSelected: [
                      editTicketType == 'Single',
                      editTicketType == 'Group',
                    ],
                    onPressed: (int index) {
                      modalSetState(() {
                        editTicketType = index == 0 ? 'Single' : 'Group';
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    selectedColor: Colors.white,
                    fillColor: Colors.deepPurple,
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text('Single'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text('Group'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  TextFormField(
                    controller: routeFromController,
                    decoration: const InputDecoration(labelText: 'Route From (Optional)'),
                  ),
                  TextFormField(
                    controller: routeToController,
                    decoration: const InputDecoration(labelText: 'Route To (Optional)'),
                  ),
                  const SizedBox(height: 25),
                  ListTile(
                    title: Text(
                      editDate == null
                          ? 'Select Date (Optional)'
                          : 'Date: ${DateFormat.yMd().format(editDate!)}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: editDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        modalSetState(() {
                          editDate = date;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 25),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          editImageSelected ? 'Photo selected' : 'No photo selected',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            final picker = ImagePicker();
                            final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                            // ignore: dead_code
                            if (!mounted) return;
                            if (image != null &&
                                ['.jpg', '.jpeg', '.png']
                                    .contains(image.path.toLowerCase().substring(image.path.length - 4))) {
                              modalSetState(() {
                                editImage = image;
                                editImageSelected = true;
                              });
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please select a JPG, JPEG, or PNG image')),
                              );
                            }
                          } catch (e) {
                            // ignore: dead_code
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error picking image: $e')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.image),
                        label: const Text('Add Photo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (_formKey.currentState!.validate() && editTicketType != null) {
                        final updatedBooking = Booking(
                          name: nameController.text,
                          contact: contactController.text,
                          ticketType: editTicketType,
                          isPaid: booking.isPaid,
                          isTicketGiven: booking.isTicketGiven,
                          photoPath: editImage?.path,
                          routeFrom: routeFromController.text.isNotEmpty ? routeFromController.text : null,
                          routeTo: routeToController.text.isNotEmpty ? routeToController.text : null,
                          date: editDate,
                        );
                        _saveBooking(updatedBooking, index: index);
                        nameController.clear();
                        contactController.clear();
                        routeFromController.clear();
                        routeToController.clear();
                        setState(() {
                          selectedImage = null;
                          imageSelected = false;
                          selectedDate = null;
                          selectedTicketType = 'Single';
                        });
                        Navigator.of(context).pop();
                      }
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Update'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void deleteBooking(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Booking'),
        content: const Text('Are you sure you want to delete this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final box = Hive.box<Booking>('bookings');
                await box.deleteAt(index);
                await _loadBookings();
                Navigator.pop(context);
              } catch (e) {
                // ignore: dead_code
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete booking: $e')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void togglePaidStatus(int index) {
    try {
      final booking = bookings[index];
      booking.isPaid = !booking.isPaid;
      _saveBooking(booking, index: index);
    } catch (e) {
      // ignore: dead_code
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating paid status: $e')),
        );
      }
    }
  }

  void toggleTicketStatus(int index) {
    try {
      final booking = bookings[index];
      booking.isTicketGiven = !booking.isTicketGiven;
      _saveBooking(booking, index: index);
    } catch (e) {
      // ignore: dead_code
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating ticket status: $e')),
        );
      }
    }
  }

  void toggleTheme() {
    try {
      final box = Hive.box('settings');
      final currentTheme = box.get('themeMode', defaultValue: 'light');
      box.put('themeMode', currentTheme == 'light' ? 'dark' : 'light');
    } catch (e) {
      // ignore: dead_code
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error toggling theme: $e')),
        );
      }
    }
  }

  Future<void> _exportToPDF() async {
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(
                children: [
                  pw.Text('Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Contact', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Ticket Type', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Paid', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Ticket Status', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Route', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
              for (var booking in bookings)
                pw.TableRow(
                  children: [
                    pw.Text(booking.name),
                    pw.Text(booking.contact),
                    pw.Text(booking.ticketType),
                    pw.Text(booking.isPaid ? 'Paid' : 'Unpaid'),
                    pw.Text(booking.isTicketGiven ? 'Ticket Given' : 'Pending'),
                    pw.Text(booking.routeFrom != null && booking.routeTo != null
                        ? '${booking.routeFrom} to ${booking.routeTo}'
                        : 'None'),
                    pw.Text(booking.date != null ? DateFormat.yMd().format(booking.date!) : 'None'),
                  ],
                ),
            ],
          ),
        ),
      );

      // ignore: dead_code
      if (!mounted) return;
      String? path = await FilePicker.platform.getDirectoryPath();
      // ignore: dead_code
      if (!mounted) return;
      if (path != null) {
        final file = File('$path/bookings.pdf');
        await file.writeAsBytes(await pdf.save());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF saved to ${file.path}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No folder selected')),
        );
      }
    } catch (e) {
      // ignore: dead_code
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting to PDF: $e')),
        );
      }
    }
  }

  Future<void> _exportToCSV() async {
    try {
      List<List<dynamic>> rows = [
        ['Name', 'Contact', 'Ticket Type', 'Paid', 'Ticket Status', 'Route', 'Date'],
        for (var booking in bookings)
          [
            booking.name,
            booking.contact,
            booking.ticketType,
            booking.isPaid ? 'Paid' : 'Unpaid',
            booking.isTicketGiven ? 'Ticket Given' : 'Pending',
            booking.routeFrom != null && booking.routeTo != null
                ? '${booking.routeFrom} to ${booking.routeTo}'
                : 'None',
            booking.date != null ? DateFormat.yMd().format(booking.date!) : 'None',
          ],
      ];

      // ignore: dead_code
      if (!mounted) return;
      String csv = const ListToCsvConverter().convert(rows);
      String? path = await FilePicker.platform.getDirectoryPath();
      // ignore: dead_code
      if (!mounted) return;
      if (path != null) {
        final file = File('$path/bookings.csv');
        await file.writeAsString(csv);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV saved to ${file.path}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No folder selected')),
        );
      }
    } catch (e) {
      // ignore: dead_code
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting to CSV: $e')),
        );
      }
    }
  }

  void _showImageZoom(String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Photo')),
          body: PhotoView(
            imageProvider: FileImage(File(path)),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
          ),
        ),
      ),
    );
  }

  void openAddBookingDialog() {
    String addTicketType = 'Single';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter modalSetState) {
          return SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 20,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Add Booking',
                    style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 25),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (val) => val!.isEmpty ? 'Enter name' : null,
                  ),
                  TextFormField(
                    controller: contactController,
                    decoration: const InputDecoration(labelText: 'Contact Number'),
                    keyboardType: TextInputType.phone,
                    validator: (val) => val!.isEmpty ? 'Enter contact number' : null,
                  ),
                  const SizedBox(height: 25),
                  Text('Ticket Type', style: GoogleFonts.poppins(fontSize: 16)),
                  ToggleButtons(
                    isSelected: [
                      addTicketType == 'Single',
                      addTicketType == 'Group',
                    ],
                    onPressed: (int index) {
                      modalSetState(() {
                        addTicketType = index == 0 ? 'Single' : 'Group';
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    selectedColor: Colors.white,
                    fillColor: Colors.deepPurple,
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text('Single'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text('Group'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  TextFormField(
                    controller: routeFromController,
                    decoration: const InputDecoration(labelText: 'Route From (Optional)'),
                  ),
                  TextFormField(
                    controller: routeToController,
                    decoration: const InputDecoration(labelText: 'Route To (Optional)'),
                  ),
                  const SizedBox(height: 25),
                  ListTile(
                    title: Text(
                      selectedDate == null
                          ? 'Select Date (Optional)'
                          : 'Date: ${DateFormat.yMd().format(selectedDate!)}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        modalSetState(() {
                          selectedDate = date;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 25),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          imageSelected ? 'Photo selected' : 'No photo selected',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await _pickImage();
                          modalSetState(() {});
                        },
                        icon: const Icon(Icons.image),
                        label: const Text('Add Photo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (_formKey.currentState!.validate() && addTicketType != null) {
                        final booking = Booking(
                          name: nameController.text,
                          contact: contactController.text,
                          ticketType: addTicketType,
                          photoPath: selectedImage?.path,
                          routeFrom: routeFromController.text.isNotEmpty ? routeFromController.text : null,
                          routeTo: routeToController.text.isNotEmpty ? routeToController.text : null,
                          date: selectedDate,
                        );
                        _saveBooking(booking);
                        nameController.clear();
                        contactController.clear();
                        routeFromController.clear();
                        routeToController.clear();
                        modalSetState(() {
                          selectedImage = null;
                          imageSelected = false;
                          selectedDate = null;
                          addTicketType = 'Single';
                        });
                        Navigator.of(context).pop();
                      }
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Submit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget bookingCard(Booking booking, int index) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                booking.photoPath != null
                    ? GestureDetector(
                        onTap: () => _showImageZoom(booking.photoPath!),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(booking.photoPath!),
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, __) => const Icon(Icons.error),
                          ),
                        ),
                      )
                    : const Icon(Icons.person, size: 50),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text('Contact: ${booking.contact}'),
                      Text('Ticket Type: ${booking.ticketType}'),
                      if (booking.routeFrom != null && booking.routeTo != null)
                        Text('Route: ${booking.routeFrom} to ${booking.routeTo}'),
                      if (booking.date != null)
                        Text('Date: ${DateFormat.yMd().format(booking.date!)}'),
                    ],
                  ),
                ),
                Column(
                  children: [
                    GestureDetector(
                      onTap: () => togglePaidStatus(index),
                      child: Chip(
                        label: Text(booking.isPaid ? 'Paid' : 'Unpaid'),
                        backgroundColor: booking.isPaid ? Colors.green[100] : Colors.red[100],
                        labelStyle: TextStyle(color: booking.isPaid ? Colors.green : Colors.red),
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => toggleTicketStatus(index),
                      child: Chip(
                        label: Text(booking.isTicketGiven ? 'Ticket Given' : 'Pending'),
                        backgroundColor:
                            booking.isTicketGiven ? Colors.blue[100] : Colors.orange[100],
                        labelStyle: TextStyle(
                            color: booking.isTicketGiven ? Colors.blue : Colors.orange),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  label: const Text('Edit', style: TextStyle(color: Colors.blue)),
                  onPressed: () => editBooking(index),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text('Delete', style: TextStyle(color: Colors.red)),
                  onPressed: () => deleteBooking(index),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget statsCards() {
    final totalBookings = bookings.length;
    final paidBookings = bookings.where((b) => b.isPaid).length;
    final ticketsGiven = bookings.where((b) => b.isTicketGiven).length;
    final pendingBookings = bookings.where((b) => !b.isTicketGiven).length;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Card(
                  color: Colors.blue[50],
                  child: ListTile(
                    leading: const Icon(Icons.book, color: Colors.blue),
                    title: const Text('Total Bookings'),
                    subtitle: Text('$totalBookings'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  color: Colors.green[50],
                  child: ListTile(
                    leading: const Icon(Icons.payment, color: Colors.green),
                    title: const Text('Paid Bookings'),
                    subtitle: Text('$paidBookings'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Card(
                  color: Colors.purple[50],
                  child: ListTile(
                    leading: const Icon(Icons.confirmation_number, color: Colors.purple),
                    title: const Text('Tickets Given'),
                    subtitle: Text('$ticketsGiven'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  color: Colors.orange[50],
                  child: ListTile(
                    leading: const Icon(Icons.pending, color: Colors.orange),
                    title: const Text('Pending Bookings'),
                    subtitle: Text('$pendingBookings'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<Booking>('bookings').listenable(),
      builder: (context, value, _) {
        if (isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (errorMessage != null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        isLoading = true;
                        errorMessage = null;
                      });
                      _loadBookings();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('TicketMate Pro'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(
                  Theme.of(context).brightness == Brightness.light
                      ? Icons.dark_mode
                      : Icons.light_mode,
                ),
                onPressed: toggleTheme,
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.settings),
                onSelected: (value) {
                  if (value == 'pdf') {
                    _exportToPDF();
                  } else if (value == 'csv') {
                    _exportToCSV();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'pdf', child: Text('Export to PDF')),
                  const PopupMenuItem(value: 'csv', child: Text('Export to CSV')),
                ],
              ),
            ],
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).brightness == Brightness.light
                      ? const Color(0xFFEDE7F6)
                      : Colors.grey[900]!,
                  Theme.of(context).brightness == Brightness.light
                      ? const Color(0xFFF3E5F5)
                      : Colors.grey[800]!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name or contact',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                statsCards(),
                Expanded(
                  child: filteredBookings.isEmpty
                      ? const Center(child: Text('No bookings found'))
                      : MediaQuery.removePadding(
                          context: context,
                          removeTop: true,
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 80),
                            itemCount: filteredBookings.length,
                            itemBuilder: (context, index) => bookingCard(filteredBookings[index], index),
                          ),
                        ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: openAddBookingDialog,
            backgroundColor: Colors.deepPurple,
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    searchController.removeListener(_filterBookings);
    searchController.dispose();
    nameController.dispose();
    contactController.dispose();
    routeFromController.dispose();
    routeToController.dispose();
    // Safely close Hive boxes if open
    if (Hive.isBoxOpen('bookings')) {
      Hive.box<Booking>('bookings').close();
    }
    if (Hive.isBoxOpen('settings')) {
      Hive.box('settings').close();
    }
    super.dispose();
  }
}
