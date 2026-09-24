import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cams = await availableCameras();
  runApp(NaodHD(cameras: cams));
}

class NaodHD extends StatelessWidget {
  final List<CameraDescription> cameras;
  const NaodHD({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Naod HD Camera',
    theme: ThemeData.dark(useMaterial3: true),
    home: CameraHome(cameras: cameras),
  );
}

class CameraHome extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraHome({super.key, required this.cameras});
  @override State<CameraHome> createState() => _CameraHomeState();
}

class _CameraHomeState extends State<CameraHome> {
  CameraController? c;
  int cameraIndex = 0;
  bool ready = false, grid = true, hdr = true, stabilization = true;
  bool beauty = false, portrait = false, recording = false;
  String quality = '4K';
  String mode = 'PHOTO';
  int timer = 0;
  double zoom = 1, minZoom = 1, maxZoom = 1, exposure = 0, minExp = 0, maxExp = 0;
  FlashMode flash = FlashMode.auto;
  Offset? focus;
  Timer? recTimer;
  Duration recordingTime = Duration.zero;

  @override void initState() { super.initState(); _openCamera(); }

  ResolutionPreset get preset {
    if (quality == '4K') return ResolutionPreset.ultraHigh;
    if (quality == '1080P') return ResolutionPreset.high;
    if (quality == '720P') return ResolutionPreset.medium;
    return ResolutionPreset.max;
  }

  Future<void> _openCamera() async {
    if (widget.cameras.isEmpty) return;
    setState(() => ready = false);
    await c?.dispose();
    c = CameraController(widget.cameras[cameraIndex], preset, enableAudio: true);
    try {
      await c!.initialize();
      minZoom = await c!.getMinZoomLevel();
      maxZoom = await c!.getMaxZoomLevel();
      minExp = await c!.getMinExposureOffset();
      maxExp = await c!.getMaxExposureOffset();
      zoom = zoom.clamp(minZoom, maxZoom).toDouble();
      exposure = exposure.clamp(minExp, maxExp).toDouble();
      await c!.setFlashMode(flash);
      if (mounted) setState(() => ready = true);
    } catch (e) {
      if (mounted) _msg('Camera error: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (recording || widget.cameras.length < 2) return;
    cameraIndex = (cameraIndex + 1) % widget.cameras.length;
    await _openCamera();
  }

  Future<void> _takePhoto() async {
    if (!ready || c == null || recording || c!.value.isTakingPicture) return;
    if (timer > 0) await Future.delayed(Duration(seconds: timer));
    try {
      final f = await c!.takePicture();
      await Gal.putImage(f.path, album: 'Naod HD Camera');
      if (mounted) _msg('Photo saved to Gallery');
    } catch (e) { if (mounted) _msg('Photo error: $e'); }
  }

  Future<void> _video() async {
    if (!ready || c == null) return;
    try {
      if (recording) {
        final f = await c!.stopVideoRecording();
        recTimer?.cancel();
        setState(() { recording = false; recordingTime = Duration.zero; });
        await Gal.putVideo(f.path, album: 'Naod HD Camera');
        if (mounted) _msg('Video saved to Gallery');
      } else {
        await c!.startVideoRecording();
        setState(() => recording = true);
        recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => recordingTime += const Duration(seconds: 1));
        });
      }
    } catch (e) { if (mounted) _msg('Video error: $e'); }
  }

  Future<void> _focus(Offset p, Size size) async {
    if (c == null) return;
    try {
      final point = Offset((p.dx / size.width).clamp(0, 1), (p.dy / size.height).clamp(0, 1));
      await c!.setFocusPoint(point);
      await c!.setExposurePoint(point);
      if (mounted) {
        setState(() => focus = p);
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) setState(() => focus = null);
        });
      }
    } catch (_) {}
  }

  Future<void> _flash() async {
    if (c == null) return;
    flash = switch (flash) {
      FlashMode.auto => FlashMode.always,
      FlashMode.always => FlashMode.off,
      FlashMode.off => FlashMode.auto,
      FlashMode.torch => FlashMode.auto,
    };
    await c!.setFlashMode(flash);
    if (mounted) setState(() {});
  }

  void _settings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff03070d),
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(builder: (ctx, setSheet) {
        return SafeArea(child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width:46,height:5,decoration:BoxDecoration(
              color:Colors.white24,borderRadius:BorderRadius.circular(20))),
            const SizedBox(height:12),
            Row(children:[
              Container(width:58,height:58,decoration:BoxDecoration(
                shape:BoxShape.circle,
                border:Border.all(color:const Color(0xffffd400),width:3),
                image:const DecorationImage(
                  image:AssetImage('assets/naod_logo.jpg'),fit:BoxFit.cover))),
              const SizedBox(width:12),
              const Expanded(child:Text('NAOD PRO SETTINGS',
                style:TextStyle(fontWeight:FontWeight.w900,fontSize:19))),
              IconButton(onPressed:()=>Navigator.pop(ctx),
                icon:const Icon(Icons.close))
            ]),
            const SizedBox(height:10),
            ClipRRect(
              borderRadius:BorderRadius.circular(18),
              child: Container(height:90,width:double.infinity,
                decoration:const BoxDecoration(
                  image:DecorationImage(
                    image:AssetImage('assets/naod_logo.jpg'),
                    fit:BoxFit.cover,opacity:.22)),
                child:Container(
                  decoration:const BoxDecoration(
                    gradient:LinearGradient(
                      colors:[Color(0xdd03070d),Color(0x9903070d)])),
                  alignment:Alignment.center,
                  child:const Text('Naod HD Camera • Professional Controls',
                    style:TextStyle(fontWeight:FontWeight.w800))))),
            const SizedBox(height:8),
            _row('Resolution',quality,() async{
              final a=['4K','1080P','720P','MAX']; final i=a.indexOf(quality);
              setState(()=>quality=a[(i+1)%a.length]); setSheet((){});
              await _openCamera();
            }),
            _switch('HDR',hdr,(v){setState(()=>hdr=v);setSheet((){});}),
            _switch('Grid',grid,(v){setState(()=>grid=v);setSheet((){});}),
            _row('Timer',timer==0?'Off':'$timer seconds',(){
              final a=[0,3,5,10]; final i=a.indexOf(timer);
              setState(()=>timer=a[(i+1)%a.length]);setSheet((){});
            }),
            _row('Flash',flash==FlashMode.auto?'Auto':flash==FlashMode.always?'On':'Off',_flash),
            _switch('Stabilization',stabilization,(v){setState(()=>stabilization=v);setSheet((){});}),
            _switch('Beauty Mode',beauty,(v){setState(()=>beauty=v);setSheet((){});}),
            _switch('Portrait Mode',portrait,(v){setState(()=>portrait=v);setSheet((){});}),
            _row('Slow Motion',mode=='SLO-MO'?'On':'Off',(){setState(()=>mode='SLO-MO');Navigator.pop(ctx);}),
            _row('Time-lapse',mode=='TIME-LAPSE'?'On':'Off',(){setState(()=>mode='TIME-LAPSE');Navigator.pop(ctx);}),
            const SizedBox(height:8),
            const Text('Capture Your Best Moments',
              style:TextStyle(color:Color(0xffffd400),fontWeight:FontWeight.w800,fontStyle:FontStyle.italic))
          ]),
        ));
      }),
    );
  }

  Widget _row(String a,String b,VoidCallback f)=>ListTile(
    title:Text(a),trailing:Row(mainAxisSize:MainAxisSize.min,children:[
      Text(b,style:const TextStyle(color:Color(0xffffd400),fontWeight:FontWeight.bold)),
      const Icon(Icons.chevron_right)]),onTap:f);

  Widget _switch(String a,bool v,ValueChanged<bool> f)=>SwitchListTile(
    title:Text(a),value:v,activeThumbColor:const Color(0xffffd400),onChanged:f);

  void _msg(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));

  @override void dispose(){recTimer?.cancel();c?.dispose();super.dispose();}

  @override
  Widget build(BuildContext context){
    if(widget.cameras.isEmpty)return const Scaffold(body:Center(child:Text('No camera available')));
    if(!ready||c==null)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    return Scaffold(
      backgroundColor:const Color(0xff03070d),
      body:SafeArea(child:Stack(children:[
        GestureDetector(onTapDown:(d){
          final box=context.findRenderObject() as RenderBox?;
          _focus(d.localPosition,box?.size??const Size(1,1));
        },child:CameraPreview(c!)),
        if(grid)const IgnorePointer(child:CustomPaint(painter:GridPainter())),
        if(focus!=null)Positioned(left:focus!.dx-32,top:focus!.dy-32,
          child:Container(width:64,height:64,decoration:BoxDecoration(
            border:Border.all(color:const Color(0xffffd400),width:2),
            borderRadius:BorderRadius.circular(5)))),
        _top(),
        if(stabilization)Positioned(top:58,left:12,child:Container(
          padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),
          decoration:BoxDecoration(color:Colors.black54,borderRadius:BorderRadius.circular(12)),
          child:const Row(mainAxisSize:MainAxisSize.min,children:[
            Icon(Icons.vibration,size:14,color:Color(0xffffd400)),
            SizedBox(width:4),Text('STABILIZED',style:TextStyle(fontSize:10,fontWeight:FontWeight.w800))]))),
        _bottom(),
        if(recording)Positioned(top:70,left:0,right:0,child:Center(child:Text(
          '● REC  ${recordingTime.inMinutes.toString().padLeft(2,'0')}:${(recordingTime.inSeconds%60).toString().padLeft(2,'0')}',
          style:const TextStyle(color:Colors.redAccent,fontWeight:FontWeight.w900,fontSize:16))))
      ])),
    );
  }

  Widget _top()=>Positioned(top:0,left:0,right:0,child:Container(
    padding:const EdgeInsets.symmetric(horizontal:6,vertical:5),
    decoration:const BoxDecoration(gradient:LinearGradient(
      begin:Alignment.topCenter,end:Alignment.bottomCenter,
      colors:[Color(0xee02060c),Color(0x0002060c)])),
    child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
      GestureDetector(onTap:_settings,child:Container(width:46,height:46,
        decoration:BoxDecoration(shape:BoxShape.circle,
          border:Border.all(color:const Color(0xffffd400),width:2.5),
          image:const DecorationImage(
            image:AssetImage('assets/naod_logo.jpg'),fit:BoxFit.cover)))),
      _chip(quality,quality=='4K'),
      _chip('HDR',hdr),
      IconButton(onPressed:()=>setState(()=>grid=!grid),
        icon:Icon(Icons.grid_3x3,color:grid?const Color(0xffffd400):Colors.white)),
      Text('⏱ ${timer==0?'OFF':'${timer}s'}'),
      IconButton(onPressed:_flash,icon:Icon(
        flash==FlashMode.auto?Icons.flash_auto:flash==FlashMode.always?Icons.flash_on:Icons.flash_off)),
      IconButton(onPressed:_switchCamera,icon:const Icon(Icons.flip_camera_ios_outlined))
    ])));

  Widget _chip(String t,bool active)=>Container(
    padding:const EdgeInsets.symmetric(horizontal:10,vertical:7),
    decoration:BoxDecoration(borderRadius:BorderRadius.circular(18),
      border:Border.all(color:active?const Color(0xffffd400):Colors.white54,width:active?2:1)),
    child:Text(t,style:TextStyle(fontWeight:FontWeight.w900,
      color:active?const Color(0xffffd400):Colors.white)));

  Widget _bottom()=>Positioned(left:0,right:0,bottom:0,child:Container(
    padding:const EdgeInsets.fromLTRB(12,8,12,16),
    decoration:const BoxDecoration(gradient:LinearGradient(
      begin:Alignment.topCenter,end:Alignment.bottomCenter,
      colors:[Color(0x0002070d),Color(0xf002070d)])),
    child:Column(mainAxisSize:MainAxisSize.min,children:[
      Row(mainAxisAlignment:MainAxisAlignment.center,children:[
        ...['0.5','1.0','2.0','5.0'].map((z)=>Padding(
          padding:const EdgeInsets.symmetric(horizontal:10),
          child:Text(z,style:TextStyle(fontWeight:FontWeight.bold,
            color:z==zoom.toStringAsFixed(1)?const Color(0xffffd400):Colors.white))))]),
      Slider(value:zoom,min:minZoom,max:maxZoom,onChanged:(v){
        setState(()=>zoom=v);c!.setZoomLevel(v);
      }),
      Row(children:[
        const Icon(Icons.wb_sunny_outlined,size:18),
        Expanded(child:Slider(value:exposure,min:minExp,max:maxExp,onChanged:(v){
          setState(()=>exposure=v);c!.setExposureOffset(v);
        })),
        SizedBox(width:48,child:Text('${exposure.toStringAsFixed(1)} EV'))
      ]),
      SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(
        mainAxisAlignment:MainAxisAlignment.center,children:[
        ...['SLO-MO','VIDEO','PHOTO','PORTRAIT','TIME-LAPSE'].map((m)=>Padding(
          padding:const EdgeInsets.symmetric(horizontal:13),
          child:TextButton(onPressed:recording?null:()=>setState(()=>mode=m),
            child:Text(m,style:TextStyle(fontWeight:FontWeight.w900,
              color:mode==m?const Color(0xffffd400):Colors.white70)))))
      ])),
      Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[
        Container(width:48,height:48,decoration:BoxDecoration(
          borderRadius:BorderRadius.circular(10),
          border:Border.all(color:const Color(0xffffd400),width:2),
          image:const DecorationImage(image:AssetImage('assets/naod_logo.jpg'),fit:BoxFit.cover))),
        GestureDetector(onTap:mode=='VIDEO'||mode=='SLO-MO'||mode=='TIME-LAPSE'?_video:_takePhoto,
          child:Container(width:82,height:82,decoration:BoxDecoration(
            shape:BoxShape.circle,color:recording?Colors.red:Colors.white,
            border:Border.all(color:const Color(0xffffd400),width:5)),
            child:Icon(recording?Icons.stop:Icons.camera_alt,color:Colors.black,size:36))),
        IconButton(onPressed:_switchCamera,icon:const Icon(Icons.flip_camera_ios,size:30))
      ])
    ])));

}

class GridPainter extends CustomPainter{
  const GridPainter();
  @override void paint(Canvas c,Size s){
    final p=Paint()..color=Colors.white24..strokeWidth=1;
    for(final x in [s.width/3,s.width*2/3])c.drawLine(Offset(x,0),Offset(x,s.height),p);
    for(final y in [s.height/3,s.height*2/3])c.drawLine(Offset(0,y),Offset(s.width,y),p);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
}

