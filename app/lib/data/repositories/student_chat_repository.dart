import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<Map<String, dynamic>>> streamClassMessages(String classId) {
    return _firestore
        .collection('class_chats')
        .doc(classId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {'id': doc.id, ...data};
          }).toList();
        });
  }

  Stream<Map<String, dynamic>?> streamClassChatRoom(String classId) {
    return _firestore.collection('class_chats').doc(classId).snapshots().map((
      doc,
    ) {
      return doc.data();
    });
  }

  Future<void> sendMessage({
    required String classId,
    required String text,
    required Map<String, dynamic> profile,
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    final trimmed = text.trim();

    if (trimmed.isEmpty && attachments.isEmpty) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Chưa đăng nhập');
    }

    final chatRef = _firestore.collection('class_chats').doc(classId);
    final chatDoc = await chatRef.get();

    if (chatDoc.exists) {
      final data = chatDoc.data() ?? {};
      if (data['isLocked'] == true) {
        throw Exception('Chat của lớp hiện đang bị khóa');
      }
    }

    final senderRole = (profile['role'] ?? 'student').toString();
    final senderName = (profile['fullName'] ?? 'Người dùng').toString();
    final senderAvatarUrl = (profile['avatarUrl'] ?? '').toString();

    final messageType = attachments.isEmpty
        ? 'text'
        : trimmed.isEmpty
        ? 'file'
        : 'mixed';

    final lastMessage = attachments.isNotEmpty
        ? (trimmed.isEmpty ? 'Đã gửi tệp đính kèm' : trimmed)
        : trimmed;

    await chatRef.collection('messages').add({
      'classId': classId,
      'senderId': currentUser.uid,
      'senderName': senderName,
      'senderRole': senderRole,
      'senderAvatarUrl': senderAvatarUrl,
      'text': trimmed,
      'messageType': messageType,
      'attachments': attachments,
      'likedBy': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': null,
      'deleted': false,
      'deletedBy': null,
      'deletedAt': null,
    });

    await chatRef.set({
      'classId': classId,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': lastMessage,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': currentUser.uid,
      'lastSenderRole': senderRole,
    }, SetOptions(merge: true));
  }

  Future<void> toggleLikeMessage({
    required String classId,
    required String messageId,
    required String uid,
    required bool liked,
  }) async {
    final ref = _firestore
        .collection('class_chats')
        .doc(classId)
        .collection('messages')
        .doc(messageId);

    await ref.set({
      'likedBy': liked
          ? FieldValue.arrayRemove([uid])
          : FieldValue.arrayUnion([uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> softDeleteMessage({
    required String classId,
    required String messageId,
    required String deletedBy,
  }) async {
    await _firestore
        .collection('class_chats')
        .doc(classId)
        .collection('messages')
        .doc(messageId)
        .set({
          'deleted': true,
          'deletedBy': deletedBy,
          'deletedAt': FieldValue.serverTimestamp(),
          'text': '',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }
}
