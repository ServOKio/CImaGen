import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class MiniSD extends StatefulWidget{
  ImageMeta? imageMeta;
  MiniSD({ Key? key, this.imageMeta}): super(key: key);

  @override
  _MiniSDState createState() => _MiniSDState();
}

class _MiniSDState extends State<MiniSD> {
  //Text(widget.imageMeta!.fullPath)
  List<String> list = <String>['One', 'Two', 'Three', 'Four'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
            title: const Text('SD'),
            backgroundColor: const Color(0xaa000000),
            elevation: 0,
            actions: []
        ),
        body: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  DropdownButton(
                      items: list.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                      },
                  )
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                            color: Colors.black
                        ),
                        height: MediaQuery.of(context).size.height * 0.30,
                        child: TextField(
                            keyboardType: TextInputType.multiline,
                            maxLines: null,
                            expands: true,
                            style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 13)
                        ),
                      ),
                      const Gap(8),
                      Container(
                        decoration: BoxDecoration(
                            color: Colors.black
                        ),
                        height: MediaQuery.of(context).size.height * 0.30,
                        child: TextField(
                            keyboardType: TextInputType.multiline,
                            maxLines: null,
                            expands: true,
                            style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 13)
                        ),
                      )
                    ],
                  )),
                  const Gap(8),
                  Column(
                    children: [
                      ElevatedButton(
                          style: ButtonStyle(
                              foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
                              backgroundColor: MaterialStateProperty.all<Color>(Theme.of(context).primaryColor),
                              shape: MaterialStateProperty.all<RoundedRectangleBorder>(const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))))
                          ),
                          onPressed: () {  },
                          child: const Text(
                              "Generate",
                              style: TextStyle(fontSize: 14)
                          )
                      )
                    ],
                  )
                ],
              )
            ],
          )
        )
    );
  }
}