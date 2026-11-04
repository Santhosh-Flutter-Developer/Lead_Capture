/*
  Copyright 2024 Srisoftwarez. All rights reserved.
  Use of this source code is governed by a BSD-style license that can be
  found in the LICENSE file.
*/

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart' as path;
import '/models/models.dart';
import '/theme/theme.dart';
import '/views/views.dart';
import '/utils/src/download_io.dart'
    if (dart.library.html) '/utils/src/download_web.dart'
    show saveFileToDownloads;
import '/utils/utils.dart';
import '/services/services.dart';

class AndroidUpdate extends StatefulWidget {
  const AndroidUpdate({super.key});

  @override
  State<AndroidUpdate> createState() => _AndroidUpdateState();
}

class _AndroidUpdateState extends State<AndroidUpdate> {
  VersionModel? _versionModel;

  @override
  void initState() {
    _versionModel = VersionService.version;
    if (Platform.isAndroid) {
      _init();
    }
    super.initState();
  }

  void _init() async {
    _installedLocation =
        "${await _getFolderPath()}/${_versionModel?.version ?? 'leadcapture'}.apk";
    _readyToInstall = await _checkFileExists();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: AppColors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(ImageAssets.update, height: 200, width: 200),
                  const SizedBox(height: 10),
                  Text(
                    "App Update Available",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Version : ${_versionModel?.version}",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Visibility(
                    visible: _isLoading,
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        Text(
                          "Downloading... ${(_progress * 100).toStringAsFixed(0)}%",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 5),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: LinearProgressIndicator(value: _progress),
                        ),
                      ],
                    ),
                  ),
                  Visibility(
                    visible: !_readyToInstall && !_isLoading,
                    child: ElevatedButton(
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(
                          AppColors.primary,
                        ),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      child: Text(
                        "Update Now",
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppColors.white),
                      ),
                      onPressed: () async {
                        _downloadApkAndInstall();
                      },
                    ),
                  ),
                  Visibility(
                    visible: _readyToInstall,
                    child: ElevatedButton(
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(
                          AppColors.primary,
                        ),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      child: Text(
                        "Install",
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppColors.white),
                      ),
                      onPressed: () async => _installApk(_installedLocation),
                    ),
                  ),
                ],
              ),
            ),
            Visibility(
              visible: _readyToInstall,
              child: TextButton.icon(
                label: Text(
                  "How to install?",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                icon: Icon(Iconsax.info_circle),
                onPressed: () async => await Sheet.showSheet(
                  context,
                  size: 0.6,
                  widget: const InstallInfo(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isLoading = false;
  bool _readyToInstall = false;
  double _progress = 0.0;
  String _installedLocation = "";
  static const platform = MethodChannel(
    'com.srisoftwarez.leadcapture/install_apk',
  );

  Future<void> _downloadApkAndInstall() async {
    try {
      setState(() {
        _isLoading = true;
        _progress = 0.0;
      });

      var uri = _versionModel?.url ?? '';
      var request = await http.Client().send(
        http.Request("GET", Uri.parse(uri)),
      );
      var totalBytes = request.contentLength ?? 1;
      List<int> bytes = [];

      request.stream
          .listen((chunk) {
            bytes.addAll(chunk);
            setState(() {
              _progress = bytes.length / totalBytes;
            });
          })
          .onDone(() async {
            await saveFileToDownloads(
              Uint8List.fromList(bytes),
              fileName: "${_versionModel?.version ?? 'leadcapture'}.apk",
            );
            _isLoading = false;
            _readyToInstall = true;
            setState(() {});
            FlushBar.show(
              context,
              "Download Completed\nClick install button to install app",
            );
          });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }

  Future<void> _installApk(String filePath) async {
    try {
      await platform.invokeMethod('installApk', {'filePath': filePath});
    } catch (e, st) {
      debugPrint('Error $e, $st');
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }

  Future<bool> _checkFileExists() async {
    var file = File(_installedLocation);
    return file.existsSync();
  }

  Future<String> _getFolderPath() async {
    var folderPath = "";
    final Directory? directory = await path.getExternalStorageDirectory();
    if (directory != null) {
      folderPath = directory.path;
    }
    return '$folderPath/Download';
  }
}