import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cameras = await availableCameras();

  runApp(
    NaodHD(cameras: cameras),
  );
}

class NaodHD extends StatelessWidget {
  final List<CameraDescription> cameras;

  const NaodHD({
    super.key,
    required this.cameras,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Naod HD Camera',
      theme: ThemeData.dark(useMaterial3: true),
      home: CameraHome(cameras: cameras),
    );
  }
}

class CameraHome extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraHome({
    super.key,
    required this.cameras,
  });

  @override
  State<CameraHome> createState() => _CameraHomeState();
}

class _CameraHomeState extends State<CameraHome> {
  CameraController? cameraController;

  int cameraIndex = 0;

  bool ready = false;

  bool grid = true;
  bool hdr = true;
  bool stabilization = true;
  bool beauty = false;
  bool portrait = false;
  bool recording = false;

  String quality = '4K';
  String mode = 'PHOTO';

  int timer = 0;

  double zoom = 1.0;
  double minZoom = 1.0;
  double maxZoom = 1.0;

  double exposure = 0.0;
  double minExposure = 0.0;
  double maxExposure = 0.0;

  FlashMode flash = FlashMode.auto;

  Offset? focusPoint;

  Timer? recordingTimer;

  Duration recordingTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _openCamera();
  }

  ResolutionPreset get resolutionPreset {
    if (quality == '4K') {
      return ResolutionPreset.ultraHigh;
    }

    if (quality == '1080P') {
      return ResolutionPreset.high;
    }

    if (quality == '720P') {
      return ResolutionPreset.medium;
    }

    return ResolutionPreset.max;
  }

  Future<void> _openCamera() async {
    if (widget.cameras.isEmpty) {
      return;
    }

    if (mounted) {
      setState(() {
        ready = false;
      });
    }

    await cameraController?.dispose();

    final controller = CameraController(
      widget.cameras[cameraIndex],
      resolutionPreset,
      enableAudio: true,
    );

    cameraController = controller;

    try {
      await controller.initialize();

      minZoom = await controller.getMinZoomLevel();
      maxZoom = await controller.getMaxZoomLevel();

      minExposure = await controller.getMinExposureOffset();
      maxExposure = await controller.getMaxExposureOffset();

      zoom = zoom.clamp(minZoom, maxZoom).toDouble();
      exposure = exposure.clamp(
        minExposure,
        maxExposure,
      ).toDouble();

      await controller.setFlashMode(flash);

      if (!mounted) {
        return;
      }

      setState(() {
        ready = true;
      });
    } catch (e) {
      if (mounted) {
        _message('Camera error: $e');
      }
    }
  }

  Future<void> _switchCamera() async {
    if (recording) {
      return;
    }

    if (widget.cameras.length < 2) {
      return;
    }

    cameraIndex =
        (cameraIndex + 1) % widget.cameras.length;

    await _openCamera();
  }

  Future<void> _takePhoto() async {
    final controller = cameraController;

    if (!ready ||
        controller == null ||
        recording ||
        controller.value.isTakingPicture) {
      return;
    }

    if (timer > 0) {
      await Future.delayed(
        Duration(seconds: timer),
      );
    }

    try {
      final file = await controller.takePicture();

      await Gal.putImage(
        file.path,
        album: 'Naod HD Camera',
      );

      if (mounted) {
        _message('Photo saved to Gallery');
      }
    } catch (e) {
      if (mounted) {
        _message('Photo error: $e');
      }
    }
  }

  Future<void> _video() async {
    final controller = cameraController;

    if (!ready || controller == null) {
      return;
    }

    try {
      if (recording) {
        final file =
            await controller.stopVideoRecording();

        recordingTimer?.cancel();

        if (mounted) {
          setState(() {
            recording = false;
            recordingTime = Duration.zero;
          });
        }

        await Gal.putVideo(
          file.path,
          album: 'Naod HD Camera',
        );

        if (mounted) {
          _message('Video saved to Gallery');
        }
      } else {
        await controller.startVideoRecording();

        if (mounted) {
          setState(() {
            recording = true;
            recordingTime = Duration.zero;
          });
        }

        recordingTimer = Timer.periodic(
          const Duration(seconds: 1),
          (_) {
            if (mounted && recording) {
              setState(() {
                recordingTime +=
                    const Duration(seconds: 1);
              });
            }
          },
        );
      }
    } catch (e) {
      if (mounted) {
        _message('Video error: $e');
      }
    }
  }

  Future<void> _focus(
    Offset position,
    Size size,
  ) async {
    final controller = cameraController;

    if (controller == null) {
      return;
    }

    try {
      final point = Offset(
        (position.dx / size.width).clamp(0.0, 1.0),
        (position.dy / size.height).clamp(0.0, 1.0),
      );

      await controller.setFocusPoint(point);
      await controller.setExposurePoint(point);

      if (!mounted) {
        return;
      }

      setState(() {
        focusPoint = position;
      });

      Future.delayed(
        const Duration(milliseconds: 900),
        () {
          if (mounted) {
            setState(() {
              focusPoint = null;
            });
          }
        },
      );
    } catch (_) {}
  }

  Future<void> _flash() async {
    final controller = cameraController;

    if (controller == null) {
      return;
    }

    if (flash == FlashMode.auto) {
      flash = FlashMode.always;
    } else if (flash == FlashMode.always) {
      flash = FlashMode.off;
    } else {
      flash = FlashMode.auto;
    }

    try {
      await controller.setFlashMode(flash);

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        _message('Flash error: $e');
      }
    }
  }

  void _settings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff070b12),
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (
            context,
            setSheetState,
          ) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  12,
                  18,
                  24,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'NAOD PRO SETTINGS',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),

                      const SizedBox(height: 8),

                      _settingRow(
                        'Resolution',
                        quality,
                        () async {
                          const options = [
                            '4K',
                            '1080P',
                            '720P',
                            'MAX',
                          ];

                          final index =
                              options.indexOf(quality);

                          setState(() {
                            quality = options[
                              (index + 1) %
                                  options.length
                            ];
                          });

                          setSheetState(() {});

                          await _openCamera();
                        },
                      ),

                      _settingSwitch(
                        'HDR',
                        hdr,
                        (value) {
                          setState(() {
                            hdr = value;
                          });

                          setSheetState(() {});
                        },
                      ),

                      _settingSwitch(
                        'Grid',
                        grid,
                        (value) {
                          setState(() {
                            grid = value;
                          });

                          setSheetState(() {});
                        },
                      ),

                      _settingRow(
                        'Timer',
                        timer == 0
                            ? 'Off'
                            : '$timer seconds',
                        () {
                          const options = [
                            0,
                            3,
                            5,
                            10,
                          ];

                          final index =
                              options.indexOf(timer);

                          setState(() {
                            timer = options[
                              (index + 1) %
                                  options.length
                            ];
                          });

                          setSheetState(() {});
                        },
                      ),

                      _settingRow(
                        'Flash',
                        _flashText(),
                        () async {
                          await _flash();
                          setSheetState(() {});
                        },
                      ),

                      _settingSwitch(
                        'Stabilization',
                        stabilization,
                        (value) {
                          setState(() {
                            stabilization = value;
                          });

                          setSheetState(() {});
                        },
                      ),

                      _settingSwitch(
                        'Beauty Mode',
                        beauty,
                        (value) {
                          setState(() {
                            beauty = value;
                          });

                          setSheetState(() {});
                        },
                      ),

                      _settingSwitch(
                        'Portrait Mode',
                        portrait,
                        (value) {
                          setState(() {
                            portrait = value;
                          });

                          setSheetState(() {});
                        },
                      ),

                      _settingRow(
                        'Slow Motion',
                        mode == 'SLO-MO'
                            ? 'On'
                            : 'Off',
                        () {
                          setState(() {
                            mode = 'SLO-MO';
                          });

                          Navigator.pop(sheetContext);
                        },
                      ),

                      _settingRow(
                        'Time-lapse',
                        mode == 'TIME-LAPSE'
                            ? 'On'
                            : 'Off',
                        () {
                          setState(() {
                            mode = 'TIME-LAPSE';
                          });

                          Navigator.pop(sheetContext);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _settingRow(
    String title,
    String value,
    VoidCallback onTap,
  ) {
    return ListTile(
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xffffd400),
              fontWeight: FontWeight.bold,
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _settingSwitch(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      activeThumbColor: const Color(0xffffd400),
      onChanged: onChanged,
    );
  }

  String _flashText() {
    if (flash == FlashMode.auto) {
      return 'Auto';
    }

    if (flash == FlashMode.always) {
      return 'On';
    }

    return 'Off';
  }

  void _message(String text) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
      ),
    );
  }

  String _recordingTimeText() {
    final minutes =
        recordingTime.inMinutes
            .toString()
            .padLeft(2, '0');

    final seconds =
        (recordingTime.inSeconds % 60)
            .toString()
            .padLeft(2, '0');

    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    recordingTimer?.cancel();
    cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cameras.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text(
            'No camera available',
          ),
        ),
      );
    }

    if (!ready || cameraController == null) {
      return const Scaffold(
        backgroundColor: Color(0xff03070d),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xffffd400),
          ),
        ),
      );
    }

    final controller = cameraController!;

    return Scaffold(
      backgroundColor: const Color(0xff03070d),
      body: SafeArea(
        child: Stack(
          children: [
            GestureDetector(
              onTapDown: (details) {
                final renderObject =
                    context.findRenderObject();

                if (renderObject is RenderBox) {
                  _focus(
                    details.localPosition,
                    renderObject.size,
                  );
                }
              },
              child: SizedBox.expand(
                child: CameraPreview(controller),
              ),
            ),

            if (grid)
              const IgnorePointer(
                child: CustomPaint(
                  painter: GridPainter(),
                  child: SizedBox.expand(),
                ),
              ),

            if (focusPoint != null)
              Positioned(
                left: focusPoint!.dx - 32,
                top: focusPoint!.dy - 32,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xffffd400),
                      width: 2,
                    ),
                    borderRadius:
                        BorderRadius.circular(5),
                  ),
                ),
              ),

            _topControls(),

            if (stabilization)
              Positioned(
                top: 58,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.vibration,
                        size: 14,
                        color: Color(0xffffd400),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'STABILIZED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            _bottomControls(),

            if (recording)
              Positioned(
                top: 70,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    '● REC  ${_recordingTimeText()}',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _topControls() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 5,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xee02060c),
              Color(0x0002060c),
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: recording
                  ? null
                  : _settings,
              icon: const Icon(
                Icons.settings_outlined,
              ),
            ),

            _chip(
              quality,
              quality == '4K',
            ),

            _chip(
              'HDR',
              hdr,
            ),

            IconButton(
              onPressed: () {
                setState(() {
                  grid = !grid;
                });
              },
              icon: Icon(
                Icons.grid_3x3,
                color: grid
                    ? const Color(0xffffd400)
                    : Colors.white,
              ),
            ),

            Text(
              '⏱ ${timer == 0 ? 'OFF' : '${timer}s'}',
            ),

            IconButton(
              onPressed: recording
                  ? null
                  : _flash,
              icon: Icon(
                flash == FlashMode.auto
                    ? Icons.flash_auto
                    : flash == FlashMode.always
                        ? Icons.flash_on
                        : Icons.flash_off,
              ),
            ),

            IconButton(
              onPressed: _switchCamera,
              icon: const Icon(
                Icons.flip_camera_ios_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(
    String text,
    bool active,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active
              ? const Color(0xffffd400)
              : Colors.white54,
          width: active ? 2 : 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: active
              ? const Color(0xffffd400)
              : Colors.white,
        ),
      ),
    );
  }

  Widget _bottomControls() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          12,
          8,
          12,
          16,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0x0002070d),
              Color(0xf002070d),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                _zoomLabel('0.5'),
                _zoomLabel('1.0'),
                _zoomLabel('2.0'),
                _zoomLabel('5.0'),
              ],
            ),

            Slider(
              value: zoom.clamp(
                minZoom,
                maxZoom,
              ),
              min: minZoom,
              max: maxZoom,
              activeColor:
                  const Color(0xffffd400),
              onChanged: (value) {
                setState(() {
                  zoom = value;
                });

                cameraController
                    ?.setZoomLevel(value);
              },
            ),

            Row(
              children: [
                const Icon(
                  Icons.wb_sunny_outlined,
                  size: 18,
                ),

                Expanded(
                  child: Slider(
                    value: exposure.clamp(
                      minExposure,
                      maxExposure,
                    ),
                    min: minExposure,
                    max: maxExposure,
                    activeColor:
                        const Color(0xffffd400),
                    onChanged: (value) {
                      setState(() {
                        exposure = value;
                      });

                      cameraController
                          ?.setExposureOffset(value);
                    },
                  ),
                ),

                SizedBox(
                  width: 48,
                  child: Text(
                    '${exposure.toStringAsFixed(1)} EV',
                  ),
                ),
              ],
            ),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  _modeButton('SLO-MO'),
                  _modeButton('VIDEO'),
                  _modeButton('PHOTO'),
                  _modeButton('PORTRAIT'),
                  _modeButton('TIME-LAPSE'),
                ],
              ),
            ),

            const SizedBox(height: 4),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: () {
                    _message(
                      'Open Photos/Gallery to view Naod HD Camera media',
                    );
                  },
                  icon: const Icon(
                    Icons.photo_library_outlined,
                    size: 30,
                  ),
                ),

                GestureDetector(
                  onTap: () {
                    if (mode == 'VIDEO' ||
                        mode == 'SLO-MO' ||
                        mode == 'TIME-LAPSE') {
                      _video();
                    } else {
                      _takePhoto();
                    }
                  },
                  child: Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: recording
                          ? Colors.red
                          : Colors.white,
                      border: Border.all(
                        color: Colors.white,
                        width: 5,
                      ),
                    ),
                    child: Icon(
                      recording
                          ? Icons.stop
                          : Icons.camera_alt,
                      color: Colors.black,
                      size: 36,
                    ),
                  ),
                ),

                IconButton(
                  onPressed: _switchCamera,
                  icon: const Icon(
                    Icons.flip_camera_ios,
                    size: 30,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _zoomLabel(String value) {
    final current =
        zoom.toStringAsFixed(1);

    final selected = value == current;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
      ),
      child: Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: selected
              ? const Color(0xffffd400)
              : Colors.white,
        ),
      ),
    );
  }

  Widget _modeButton(String value) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 13,
      ),
      child: TextButton(
        onPressed: recording
            ? null
            : () {
                setState(() {
                  mode = value;
                });
              },
        child: Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: mode == value
                ? const Color(0xffffd400)
                : Colors.white70,
          ),
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  const GridPainter();

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;

    final verticalOne =
        size.width / 3;

    final verticalTwo =
        size.width * 2 / 3;

    final horizontalOne =
        size.height / 3;

    final horizontalTwo =
        size.height * 2 / 3;

    canvas.drawLine(
      Offset(verticalOne, 0),
      Offset(
        verticalOne,
        size.height,
      ),
      paint,
    );

    canvas.drawLine(
      Offset(verticalTwo, 0),
      Offset(
        verticalTwo,
        size.height,
      ),
      paint,
    );

    canvas.drawLine(
      Offset(0, horizontalOne),
      Offset(
        size.width,
        horizontalOne,
      ),
      paint,
    );

    canvas.drawLine(
      Offset(0, horizontalTwo),
      Offset(
        size.width,
        horizontalTwo,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}
