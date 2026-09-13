import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image_background_remover/assets.dart';
import 'package:image_background_remover/src/utils/image_processor.dart';
import 'package:image_background_remover/src/utils/mask_processor.dart';

/// إزالة خلفية صورة الطبيب تلقائيًا عند الإضافة/التعديل.
///
/// بعد القطع تُركَّب خلفية Soft Medical Blue بهوية الغدير (بدل الشفافية)
/// حتى لا تبدو الحواف باهتة ولا تتأثر الدقة عند العرض على الهيرو.
class DoctorImageBgRemover {
  DoctorImageBgRemover._();

  static const int _modelSize = 320;
  /// أقرب لما يختاره المنتقي (2000) للحفاظ على التفاصيل بعد المعالجة.
  static const int _maxWorkingDimension = 2000;

  /// Soft Medical Blue / Ice Blue — نفس هوية هيرو بطاقة الطبيب.
  static const Color brandBg = Color(0xFFEAF4F6);
  static const Color brandBgSoft = Color(0xFFE5F1F4);
  static const Color brandBgMist = Color(0xFFF5FBFC);

  static OrtSession? _session;
  static Future<void>? _initFuture;

  static Future<void> ensureInitialized() {
    _initFuture ??= _initialize();
    return _initFuture!;
  }

  static Future<void> _initialize() async {
    final ort = OnnxRuntime();
    final data = await rootBundle.load(Assets.modelPath);
    final bytes = data.buffer.asUint8List();

    final dir = await Directory.systemTemp.createTemp('ghadeer_onnx_');
    final modelFile = File('${dir.path}/model.onnx');
    await modelFile.writeAsBytes(bytes, flush: true);

    _session = await ort.createSession(modelFile.path);
    debugPrint('DoctorImageBgRemover: ONNX ready at ${modelFile.path}');
  }

  /// يُرجع PNG بخلفية هوية الغدير (غير شفافة)، أو `null` عند الفشل.
  static Future<Uint8List?> removeBackground(Uint8List bytes) async {
    if (bytes.isEmpty) return null;
    try {
      await ensureInitialized();
      final session = _session;
      if (session == null) {
        throw StateError('ONNX session missing');
      }

      Future<Uint8List?> tryRemove(double threshold) async {
        final png = await _removeBgBytes(
          session,
          bytes,
          threshold: threshold,
        );
        final ok = await _hasMeaningfulForeground(png);
        debugPrint(
          'DoctorImageBgRemover: threshold=$threshold '
          'bytes=${png.length} foregroundOk=$ok',
        );
        return ok ? png : null;
      }

      final first = await tryRemove(0.38);
      if (first != null) return first;

      final second = await tryRemove(0.25);
      if (second != null) return second;

      debugPrint('DoctorImageBgRemover: no meaningful cutout');
      return null;
    } catch (e, st) {
      debugPrint('DoctorImageBgRemover failed: $e\n$st');
      _session = null;
      _initFuture = null;
      return null;
    }
  }

  /// نُبقي الجلسة حيّة بين فتحات نموذج الطبيب.
  static Future<void> dispose() async {}

  static Future<Uint8List> _removeBgBytes(
    OrtSession session,
    Uint8List imageBytes, {
    required double threshold,
  }) async {
    final originalImage = await decodeImageFromList(imageBytes);

    ui.Image workingImage = originalImage;
    final longestSide = originalImage.width > originalImage.height
        ? originalImage.width
        : originalImage.height;
    if (longestSide > _maxWorkingDimension) {
      final scale = _maxWorkingDimension / longestSide;
      final workingWidth = (originalImage.width * scale).round();
      final workingHeight = (originalImage.height * scale).round();
      workingImage = await ImageProcessor.resizeImage(
        originalImage,
        workingWidth,
        workingHeight,
      );
      originalImage.dispose();
    }

    final resizedImage = await ImageProcessor.resizeImage(
      workingImage,
      _modelSize,
      _modelSize,
    );

    final rgbFloats = await ImageProcessor.imageToFloatTensor(resizedImage);
    final inputTensor = await OrtValue.fromList(
      Float32List.fromList(rgbFloats),
      [1, 3, _modelSize, _modelSize],
    );

    final outputs = await session.run({'input.1': inputTensor});
    await inputTensor.dispose();

    final outputName = session.outputNames.first;
    final outputTensor = outputs[outputName];
    if (outputTensor == null) {
      workingImage.dispose();
      resizedImage.dispose();
      throw StateError('Unexpected ONNX output');
    }

    final outputData = await outputTensor.asList();
    final mask = outputData[0][0];

    final resizedMask = MaskProcessor.resizeMaskBilinear(
      mask,
      workingImage.width,
      workingImage.height,
    );
    final finalMask = await MaskProcessor.enhanceMaskEdges(
      workingImage,
      resizedMask,
    );

    final cutout = await ImageProcessor.applyMaskToImage(
      workingImage,
      finalMask,
      threshold: threshold,
      smooth: true,
    );

    await outputTensor.dispose();
    workingImage.dispose();
    resizedImage.dispose();

    // خلفية هوية الغدير بدل الشفافية → حواف أوضح ودقة محفوظة عند العرض.
    final composited = await _compositeOnBrandBackground(cutout);
    cutout.dispose();

    final byteData =
        await composited.toByteData(format: ui.ImageByteFormat.png);
    composited.dispose();
    if (byteData == null) {
      throw StateError('Failed to encode PNG');
    }
    return byteData.buffer.asUint8List();
  }

  /// يرسم القطع فوق تدرج Ice Blue الناعم بهوية الغدير.
  static Future<ui.Image> _compositeOnBrandBackground(ui.Image cutout) async {
    final w = cutout.width;
    final h = cutout.height;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());

    final bg = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, h.toDouble()),
        const [brandBg, brandBgSoft, brandBgMist],
        const [0.0, 0.55, 1.0],
      );
    canvas.drawRect(rect, bg);

    paintImage(
      canvas: canvas,
      rect: rect,
      image: cutout,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.high,
    );

    final picture = recorder.endRecording();
    return picture.toImage(w, h);
  }

  /// يتحقق أن القطع ليس فارغًا/خلفية فقط (بعد التركيب على لون ثابت).
  static Future<bool> _hasMeaningfulForeground(Uint8List png) async {
    try {
      final codec = await ui.instantiateImageCodec(png);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final pixels = image.width * image.height;
      image.dispose();
      if (data == null || pixels == 0) return false;

      final rgba = data.buffer.asUint8List();
      // بكسلات تختلف بوضوح عن لون خلفية الهوية = شخص/محتوى أمامي.
      const br = 0xEA;
      const bgC = 0xF4;
      const bb = 0xF6;
      var foreground = 0;
      for (var i = 0; i < rgba.length; i += 4) {
        final dr = (rgba[i] - br).abs();
        final dg = (rgba[i + 1] - bgC).abs();
        final db = (rgba[i + 2] - bb).abs();
        if (dr + dg + db > 45) foreground++;
      }
      return foreground / pixels >= 0.04;
    } catch (e) {
      debugPrint('DoctorImageBgRemover foreground check failed: $e');
      return false;
    }
  }
}
