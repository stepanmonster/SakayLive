// lib/screens/admin/admin_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_view_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  List<Map<String, dynamic>> _conductorRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConductorRequests();
  }

  Future<void> _loadConductorRequests() async {
    try {
      print('🔍 DEBUG: Starting loadConductorRequests...');

      final userSnap = await FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(FirebaseAuth.instance.currentUser!.uid)
          .get();

      if (userSnap.child('isAdmin').value != true) {
        print('❌ Not admin');
        setState(() => _isLoading = false); // ✅ ADD THIS
        return;
      }

      // 🔥 Start listener
      final requestsRef = FirebaseDatabase.instance.ref().child(
        'conductorRequests',
      );
      requestsRef.onValue.listen(
        (DatabaseEvent event) {
          print('🔍 LIVE DATA: ${event.snapshot.value}');

          if (event.snapshot.value == null) {
            setState(() {
              _conductorRequests = [];
              _isLoading = false; // ✅ ADD THIS
            });
            return;
          }

          final data = event.snapshot.value as Map?;
          if (data == null) {
            setState(() {
              _conductorRequests = [];
              _isLoading = false; // ✅ ADD THIS
            });
            return;
          }

          final requests = <Map<String, dynamic>>[];
          data.forEach((key, value) {
            if (value is Map) {
              final request = Map<String, dynamic>.from(value as Map);
              request['uid'] = key; // ✅ ADD UID FOR BUTTONS (optional)
              requests.add(request);
            }
          });

          print('✅ Loaded ${requests.length} requests');
          setState(() {
            _conductorRequests = requests;
            _isLoading = false; // ✅ ADD THIS
          });
        },
        onError: (error) {
          print('❌ Live listener error: $error');
          setState(() {
            _conductorRequests = [];
            _isLoading = false; // ✅ ADD THIS
          });
        },
      );
    } catch (e) {
      print('💥 Error: $e');
      setState(() {
        _conductorRequests = [];
        _isLoading = false; // ✅ ADD THIS
      });
    }
  }

  Future<void> _handleLogout() async {
    try {
      await context.read<AuthViewModel>().signOut();
      // AuthWrapper automatically redirects to LandingPage3
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.waving_hand_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Logged out successfully'),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Logout error: $e')));
      }
    }
  }

  Future<void> _approveRequest(String uid) async {
    try {
      print('🔍 Approving user: $uid');

      // 1. Update request status
      await FirebaseDatabase.instance.ref('conductorRequests/$uid').update({
        'status': 'approved',
        'approvedAt': ServerValue.timestamp,
      });
      print('✅ Request status updated');

      // 2. Set user role (creates if missing)
      await FirebaseDatabase.instance.ref('users/$uid/role').set('conductor');
      await FirebaseDatabase.instance.ref('users/$uid').update({
        'updatedAt': ServerValue.timestamp,
      });
      print('✅ Role set to conductor');

      // 3. Refresh list
      await _loadConductorRequests();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Conductor approved & role assigned!'),
              ],
            ),
            backgroundColor: const Color(0xFF22C55E),
          ),
        );
      }
    } catch (e) {
      print('❌ Approve error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _rejectRequest(String uid) async {
    try {
      await FirebaseDatabase.instance.ref('conductorRequests/$uid').update({
        'status': 'rejected',
        'rejectedAt': ServerValue.timestamp,
      });

      await _loadConductorRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.cancel_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Request rejected'),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: Colors.red.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadConductorRequests,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conductorRequests.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pending_actions, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No pending conductor requests',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pending Conductor Requests',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final screenWidth = constraints.maxWidth;
                      final fontScale = (screenWidth / 375).clamp(0.85, 1.1);
                      final buttonWidth =
                          screenWidth * 0.20 * 2 +
                          screenWidth * 0.008; // Total buttons width

                      return Container(
                        width: double.infinity,
                        height: screenWidth < 360 ? 420 : 500,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ListView.separated(
                          padding: EdgeInsets.all(screenWidth * 0.03),
                          itemCount: _conductorRequests.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final request = _conductorRequests[index];
                            final status =
                                request['status']?.toString() ?? 'pending';

                            return Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: screenWidth * 0.01,
                              ),
                              child: Container(
                                margin: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.01,
                                ),
                                padding: EdgeInsets.all(screenWidth * 0.04),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: status == 'pending'
                                      ? Border.all(
                                          color: Colors.orange.shade200,
                                          width: 1,
                                        )
                                      : null,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // SINGLE ROW WITH CENTERED BUTTONS
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // LEFT: Username + Email (flexible width)
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                request['username'] ?? 'N/A',
                                                style: TextStyle(
                                                  fontSize: 18 * fontScale,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              SizedBox(
                                                height: screenWidth * 0.008,
                                              ),
                                              Text(
                                                request['email'] ?? 'N/A',
                                                style: TextStyle(
                                                  fontSize: 12 * fontScale,
                                                  color: Colors.grey.shade700,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),

                                        // CENTERED BUTTONS - Fixed width container
                                        SizedBox(
                                          width: buttonWidth,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: status == 'pending'
                                                ? [
                                                    // APPROVE BUTTON
                                                    Expanded(
                                                      child: GestureDetector(
                                                        onTap: () =>
                                                            _approveRequest(
                                                              request['userId'],
                                                            ),
                                                        child: Container(
                                                          height:
                                                              screenWidth *
                                                              0.11,
                                                          margin:
                                                              EdgeInsets.only(
                                                                right:
                                                                    screenWidth *
                                                                    0.008,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            gradient: LinearGradient(
                                                              colors: [
                                                                Colors
                                                                    .green
                                                                    .shade400!,
                                                                Colors
                                                                    .green
                                                                    .shade600!,
                                                              ],
                                                            ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  10,
                                                                ),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: Colors
                                                                    .green
                                                                    .withOpacity(
                                                                      0.25,
                                                                    ),
                                                                blurRadius:
                                                                    screenWidth *
                                                                    0.02,
                                                                offset: Offset(
                                                                  0,
                                                                  screenWidth *
                                                                      0.006,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          child: Center(
                                                            child: Text(
                                                              'APPROVE',
                                                              style: TextStyle(
                                                                fontSize:
                                                                    10 *
                                                                    fontScale,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    // REJECT BUTTON
                                                    Expanded(
                                                      child: GestureDetector(
                                                        onTap: () =>
                                                            _rejectRequest(
                                                              request['userId'],
                                                            ),
                                                        child: Container(
                                                          height:
                                                              screenWidth *
                                                              0.11,
                                                          decoration: BoxDecoration(
                                                            gradient: LinearGradient(
                                                              colors: [
                                                                Colors
                                                                    .red
                                                                    .shade400!,
                                                                Colors
                                                                    .red
                                                                    .shade600!,
                                                              ],
                                                            ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  10,
                                                                ),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: Colors
                                                                    .red
                                                                    .withOpacity(
                                                                      0.25,
                                                                    ),
                                                                blurRadius:
                                                                    screenWidth *
                                                                    0.02,
                                                                offset: Offset(
                                                                  0,
                                                                  screenWidth *
                                                                      0.006,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          child: Center(
                                                            child: Text(
                                                              'REJECT',
                                                              style: TextStyle(
                                                                fontSize:
                                                                    10 *
                                                                    fontScale,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ]
                                                : [
                                                    Container(
                                                      height:
                                                          screenWidth * 0.11,
                                                      decoration: BoxDecoration(
                                                        color: Colors
                                                            .green
                                                            .shade400,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                      ),
                                                      child: Icon(
                                                        Icons.verified,
                                                        color: Colors.white,
                                                        size:
                                                            screenWidth * 0.04,
                                                      ),
                                                    ),
                                                  ],
                                          ),
                                        ),
                                      ],
                                    ),

                                    SizedBox(height: screenWidth * 0.035),

                                    // ROW 2: Date | Status
                                    Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: screenWidth * 0.03,
                                            vertical: screenWidth * 0.015,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: 16 * fontScale,
                                                color: Colors.grey.shade600,
                                              ),
                                              SizedBox(
                                                width: screenWidth * 0.015,
                                              ),
                                              Text(
                                                _formatDate(
                                                  request['createdAt'],
                                                ),
                                                style: TextStyle(
                                                  fontSize: 12 * fontScale,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        const Spacer(),

                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: screenWidth * 0.035,
                                            vertical: screenWidth * 0.015,
                                          ),
                                          decoration: BoxDecoration(
                                            color: status == 'pending'
                                                ? Colors.orange.shade400
                                                : status == 'approved'
                                                ? Colors.green.shade400
                                                : Colors.red.shade400,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            status.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 11 * fontScale,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    try {
      final timestamp = date is int ? date : int.parse(date.toString());
      return DateTime.fromMillisecondsSinceEpoch(
        timestamp,
      ).toString().split(' ')[0];
    } catch (e) {
      return 'Unknown';
    }
  }
}
