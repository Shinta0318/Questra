import 'package:flutter/material.dart';

enum AuthEntryMode { login, signup }

class AuthEntrySwitcher extends StatelessWidget {
  const AuthEntrySwitcher({
    required this.selected,
    required this.onLogin,
    required this.onSignup,
    super.key,
  });

  final AuthEntryMode selected;
  final VoidCallback onLogin;
  final VoidCallback onSignup;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<AuthEntryMode>(
        segments: const [
          ButtonSegment(
            value: AuthEntryMode.login,
            icon: Icon(Icons.login_rounded),
            label: Text('ログイン'),
          ),
          ButtonSegment(
            value: AuthEntryMode.signup,
            icon: Icon(Icons.person_add_alt_1_outlined),
            label: Text('新規登録'),
          ),
        ],
        selected: {selected},
        showSelectedIcon: false,
        onSelectionChanged: (selection) {
          final next = selection.single;
          if (next == selected) return;
          switch (next) {
            case AuthEntryMode.login:
              onLogin();
            case AuthEntryMode.signup:
              onSignup();
          }
        },
      ),
    );
  }
}
