import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../utils/ImageManager.dart';

class AspectSizes extends StatefulWidget {
  final ImageMeta data;
  const AspectSizes(this.data, {super.key});

  @override
  State<AspectSizes> createState() => _AspectSizesState();
}

class _AspectSizesState extends State<AspectSizes> {
  int maxSize = 10;

  @override
  void initState() {
    super.initState();
    maxSize = widget.data.size!.width > widget.data.size!.height ? widget.data.size!.height : widget.data.size!.width;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width > 610 ? 610 : MediaQuery.of(context).size.width - 30,
      height: MediaQuery.of(context).size.height > 700 ? 700 : MediaQuery.of(context).size.height - 30,
      child: SingleChildScrollView(
        child: Column(
          children: [
            AspectPreview(1/1, '1024 x 1024\n(1:1 Square)'),
            Gap(3),
            AspectPreview(9/7, '1152 x 896\n(9:7)'),
            Gap(3),
            AspectPreview(7/9, '896 x 1152\n(7:9)'),
            Gap(3),
            AspectPreview(19/13, '1216 x 832\n(19:13)'),
            Gap(3),
            AspectPreview(13/19, '832 x 1216\n(13:19)'),
            Gap(3),
            AspectPreview(7/4, '1344 x 768\n(7:4 Horizontal)'),
            Gap(3),
            AspectPreview(4/7, '768 x 1344\n(4:7 Vertical)'),
            Gap(3),
            AspectPreview(12/5, '1536 x 640\n(12:5 Horizontal)'),
            Gap(3),
            AspectPreview(5/12, '640 x 1536\n(5:12 Vertical, the closest to the iPhone resolution)'),
          ],
        ),
      ),
    );
  }
}

Widget AspectPreview(double aspect, String text){
  return SizedBox(
      width: 200,
      child: AspectRatio(aspectRatio: aspect, child: DottedBorder(
        dashPattern: const [6, 6],
        borderType: BorderType.RRect,
        strokeWidth: 2,
        radius: const Radius.circular(12),
        child: Center(child: SelectableText(text)),
      ))
  );
}