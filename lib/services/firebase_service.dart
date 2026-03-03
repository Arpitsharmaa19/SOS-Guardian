import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveUserData(String email, String codeWord, List<String> contacts) async {
    try {
      String userId = _auth.currentUser?.uid ?? '';
      await _firestore.collection('users').doc(userId).set({
        'email': email,
        'codeWord': codeWord,
        'contacts': contacts,
      });
    } catch (e) {
      throw Exception('Error saving user data: $e');
    }
  }

  Future<Map<String, dynamic>?> getUserData() async {
    try {
      String userId = _auth.currentUser?.uid ?? '';
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      return doc.data() as Map<String, dynamic>?;
    } catch (e) {
      throw Exception('Error fetching user data: $e');
    }
  }
}
