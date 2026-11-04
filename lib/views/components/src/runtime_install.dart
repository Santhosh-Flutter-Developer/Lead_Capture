import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '/views/views.dart';
import '/theme/theme.dart';

class RuntimeInstall extends StatefulWidget {
  const RuntimeInstall({super.key});

  @override
  State<RuntimeInstall> createState() => _RuntimeInstallState();
}

class _RuntimeInstallState extends State<RuntimeInstall> {
  final String vcDownloadUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe";

  Future<void> openDownloadLink() async {
    if (await canLaunchUrl(Uri.parse(vcDownloadUrl))) {
      await launchUrl(
        Uri.parse(vcDownloadUrl),
        mode: LaunchMode.externalApplication,
      );
    } else {
      FlushBar.show(context, 'Unable to open download link', isSuccess: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text("Missing Runtime"),
        backgroundColor: AppColors.primary,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: AppColors.danger, size: 90),
              const SizedBox(height: 20),
              Text(
                "Microsoft Visual C++ Runtime Required",
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                "To run this application, you must install the "
                "Microsoft Visual C++ Redistributable (x64).",
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "How to Install:",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "1. Download and install Microsoft Visual C++ Redistributable (x64) from the official Microsoft website.",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      "2. Run the file: vc_redist.x64.exe",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      "3. Complete the setup (Next → Next → Finish).",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      "4. Restart this application.",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
