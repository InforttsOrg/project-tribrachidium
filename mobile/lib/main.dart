import 'package:flutter/material.dart';
import 'package:infortts_shared/infortts_shared.dart';

void main() {
  runApp(const TribrachidiumApp());
}

class TribrachidiumApp extends StatelessWidget {
  const TribrachidiumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tribrachidium by Infortts',
      debugShowCheckedModeBanner: false,
      theme: AcousticTheme.darkTheme,
      home: InforttsAppShell(
        appName: 'Tribrachidium by Infortts',
        appDescription: 'Dynamic UI component tokens & theme registry',
        appVersion: '1.2.0',
        workspaceChild: InforttsNodeWorkspace(
          appName: 'Tribrachidium',
          tagline: 'Dynamic UI component tokens & theme registry',
          packageId: 'com.infortts.tribrachidium',
        ),
      ),
    );
  }
}
