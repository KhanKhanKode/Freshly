import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:freshly/utils/constants/colors.dart';
import 'package:iconsax/iconsax.dart';

final _fireStore = FirebaseFirestore.instance;
User? loggedInUser;
String? recipientId;

class ChatScreen extends StatefulWidget {
  final String email;
  final String name;

  const ChatScreen({Key? key, required this.name, required this.email}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController messageTextController = TextEditingController();
  late String messageText;

  Stream<QuerySnapshot> _chatStream() {
    String chatId = generateChatId(loggedInUser!.email!, recipientId!);
    if(loggedInUser?.email == null || recipientId == null){
      return Stream.empty();
    }
    final currentUser = _auth.currentUser?.email;

    return FirebaseFirestore.instance
        .collection('messages')
        // This query assumes you want to fetch messages where the current user
        // is either the sender or receiver, and the same for widget.userId.
        // Adjust the logic as per your database schema and requirements.
        .where('participants', arrayContainsAny: [currentUser, recipientId])
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  @override
  void initState() {
    super.initState();
    getCurrentUser();
    fetchRecipientIdByEmail(widget.email);
  }

  void getCurrentUser() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      loggedInUser = user;
    }
  }

  void fetchRecipientIdByEmail(String email) async {
    setState(() {
      recipientId = email;
    });
  }

  String generateChatId(String userEmail, recipientEmail){
    List<String> ids = [userEmail, recipientEmail];
    ids.sort();
    return ids.join('_');
  }

  void sendMessage() {
    if (messageText.trim().isNotEmpty && loggedInUser?.email != null) {
      String chatId = generateChatId(loggedInUser!.email!, recipientId!);
      _fireStore.collection('messages').add({
        'text': messageText,
        'sender': loggedInUser!.email,
        'recipient': recipientId,
        'participants': [loggedInUser!.email, recipientId],
        'chatId': chatId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      messageTextController.clear();
      //messageText = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(),
            SizedBox(
              width: 10,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.name,
                    style: TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 22,
                        fontWeight: FontWeight.normal)),
                Text("Offline",
                    style: TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 15,
                        fontWeight: FontWeight.normal,
                        color: MColors.dark.withOpacity(0.6))),
              ],
            ),
          ],
        ),
        actions: [IconButton(onPressed: () {}, icon: Icon(Icons.more_vert))],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatStream(), // Use your _chatStream method here.
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Something went wrong');
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data?.docs ?? [];
                return ListView(
                  reverse: true,
                  children: messages.map((message) {
                    final messageData = message.data() as Map<String, dynamic>;
                    final messageText = messageData['text'] ?? '';
                    final messageSender = messageData['sender'];
                    final isSender = loggedInUser?.email == messageSender;
                    //final currentUserEmail = loggedInUser?.email;

                    return MessageBubble(
                      message: messageText,
                      isSender: isSender,
                    );
                  }).toList(),
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageTextController,
                    onChanged: (value) {
                      messageText = value;
                    },
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                    ),
                  ),
                ),
                IconButton(
                  onPressed: sendMessage,
                  icon: Icon(Icons.send_rounded, color: MColors.accentColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    messageTextController.dispose();
    super.dispose();
  }
}

class MessageStream extends StatelessWidget {
  const MessageStream({super.key, required String email});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
        stream: _fireStore
            .collection('messages')
            .orderBy('timestamp', descending: false)
            .snapshots(),
        // .where("text", isEqualTo: "message")
        // .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(),
            );
          }
          final messages = snapshot.data?.docs.reversed;
          List<MessageBubble> messageBubbles = [];
          for (var message in messages!) {
            final messageData = message.data() as Map<String, dynamic>;
            final messageText = message["text"];
            final messageSender = message["sender"];

            final currentUser = loggedInUser?.email;
            //final sender = loggedInUser?.displayName;

            final messageBubble = MessageBubble(
              message: messageText,
              isSender: currentUser == messageSender,
            );
            messageBubbles.add(messageBubble);
          }

          return Expanded(
            child: ListView(
              reverse: true,
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 20),
              children: messageBubbles,
            ),
          );
        });
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isSender,
  });

  final String message;
  final bool isSender;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment:
            isSender ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Material(
            color: isSender
                ? MColors.success.withOpacity(0.3)
                : MColors.grey.withOpacity(0.5),
            borderRadius: isSender
                ? BorderRadius.only(
                    topLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                    bottomLeft: Radius.circular(30),
                  )
                : BorderRadius.only(
                    topRight: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                    bottomLeft: Radius.circular(30),
                  ),
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Text(message,
                  style: TextStyle(
                      color: isSender ? MColors.accentColor : MColors.dark)),
            ),
          ),
        ],
      ),
    );
  }
}
