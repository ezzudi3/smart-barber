import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() => _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  List<DocumentSnapshot> allUsers = [];
  List<DocumentSnapshot> filteredUsers = [];
  String searchQuery = '';
  String searchRole = '';
  String sortBy = 'name';

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      if (!mounted) return;
      setState(() {
        allUsers = snapshot.docs.where((doc) => (doc.data() as Map<String, dynamic>).containsKey('role')).toList();
        applyFilters();
      });
    } catch (e) {
      print('Error fetching users: $e');
    }
  }

  void applyFilters() {
    List<DocumentSnapshot> filtered = allUsers.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['name'] ?? '').toString().toLowerCase();
      final role = (data['role'] ?? '').toString().toLowerCase();
      return name.contains(searchQuery.toLowerCase()) && role.contains(searchRole.toLowerCase());
    }).toList();

    filtered.sort((a, b) {
      final aVal = (a.data() as Map<String, dynamic>)[sortBy] ?? '';
      final bVal = (b.data() as Map<String, dynamic>)[sortBy] ?? '';
      return aVal.toString().compareTo(bVal.toString());
    });

    setState(() {
      filteredUsers = filtered;
    });
  }

  void deleteUser(String userId) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).delete();
    fetchUsers();
  }

  void sendAdminAlert(String userId, String userName) async {
    TextEditingController titleController = TextEditingController();
    TextEditingController messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Send Warning to $userName"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  hintText: "Enter warning title",
                  labelText: "Title",
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: messageController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: "Write your warning message here...",
                  labelText: "Message",
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final message = messageController.text.trim();

              if (title.isNotEmpty && message.isNotEmpty) {
                await FirebaseFirestore.instance.collection('notifications').add({
                  'recipientId': userId,
                  'title': title,
                  'message': message,
                  'timestamp': Timestamp.now(),
                  'isRead': false,
                });
                Navigator.pop(context);
              }
            },
            child: const Text("Send", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void viewUserDetails(String userId, Map<String, dynamic> userData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileDetailScreen(userId: userId, userData: userData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search by name',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (val) {
                    setState(() {
                      searchQuery = val;
                    });
                    applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search by role',
                    prefixIcon: Icon(Icons.filter_alt),
                  ),
                  onChanged: (val) {
                    setState(() {
                      searchRole = val;
                    });
                    applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: sortBy,
                items: const [
                  DropdownMenuItem(value: 'name', child: Text('Sort by Name')),
                  DropdownMenuItem(value: 'role', child: Text('Sort by Role')),
                ],
                onChanged: (val) {
                  setState(() {
                    sortBy = val!;
                  });
                  applyFilters();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filteredUsers.length,
            itemBuilder: (context, index) {
              final doc = filteredUsers[index];
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] ?? 'No Name';
              final email = data['email'] ?? '';
              final role = data['role'] ?? 'N/A';
              final imageUrl = data['image'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                elevation: 3,
                child: ListTile(
                  onTap: () => viewUserDetails(doc.id, data),
                  leading: CircleAvatar(
                    backgroundImage: imageUrl.isNotEmpty
                        ? NetworkImage(imageUrl)
                        : const AssetImage('assets/user1.jpg') as ImageProvider,
                  ),
                  title: Text(name),
                  subtitle: Text('Role: $role\nEmail: $email'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                        onPressed: () => sendAdminAlert(doc.id, name),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text("Confirm Delete"),
                            content: Text("Delete user $name?"),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                              TextButton(
                                onPressed: () {
                                  deleteUser(doc.id);
                                  Navigator.pop(context);
                                },
                                child: const Text("Delete", style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        )
      ],
    );
  }
}

class UserProfileDetailScreen extends StatelessWidget {
  final String userId;
  final Map<String, dynamic> userData;
  const UserProfileDetailScreen({super.key, required this.userId, required this.userData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("User Details")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: userData['image'] != null && userData['image'].isNotEmpty
                  ? NetworkImage(userData['image'])
                  : const AssetImage('assets/user1.jpg') as ImageProvider,
            ),
            const SizedBox(height: 16),
            Text("Name: ${userData['name'] ?? ''}"),
            Text("Email: ${userData['email'] ?? ''}"),
            Text("Role: ${userData['role'] ?? ''}"),
            Text("Phone: ${userData['phone'] ?? ''}"),
            if (userData['role'] == 'user') ...[
              Text("Gender: ${userData['gender'] ?? ''}"),
              Text("Preferred Hairstyle: ${userData['preferredHairstyle'] ?? ''}"),
              FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('bookings')
                    .where('userId', isEqualTo: userId)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  final total = snapshot.data?.docs.length ?? 0;
                  return Text("Total Bookings: $total");
                },
              )
            ] else if (userData['role'] == 'barber') ...[
              FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('bookings')
                    .where('barberId', isEqualTo: userId)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  final docs = snapshot.data?.docs ?? [];
                  final total = docs.length;
                  return Text("Total Bookings: $total");
                },
              ),
              const SizedBox(height: 16),
              Text("Gallery:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (userData['gallery'] != null && userData['gallery'] is List && userData['gallery'].isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (userData['gallery'] as List<dynamic>).map<Widget>((imgUrl) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imgUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    );
                  }).toList(),
                )
              else
                const Text("No gallery images uploaded."),
            ]
          ],
        ),
      ),
    );
  }
}
