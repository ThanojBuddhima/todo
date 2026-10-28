package com.thanoj.todo

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth needs a FragmentActivity to host the system biometric prompt;
// plain FlutterActivity fails with "no_fragment_activity".
class MainActivity : FlutterFragmentActivity()
