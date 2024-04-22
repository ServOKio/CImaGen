import 'dart:convert';
import 'dart:typed_data';

class BufferUtils {

}

class BufferReader{
  List<int> data;
  ByteData view = ByteData(0);
  int _offset = 0;
  bool littleEndian = false;
  Endian endian = Endian.big;

  BufferReader({
    required this.data,
  }){
    view = ByteData.view(Uint8List.fromList(data).buffer);
  }

  int getUint8(){
    var value = view.getInt8(_offset);
    _offset += 1;
    return value;
  }

  int getInt32(){
    var value = view.getInt32(_offset, endian);
    _offset += 4;
    return value;
  }

  String getNullTerminatedByteString() {
    int index = data.sublist(_offset).indexOf(0);

    if (index == -1) {
      throw Exception('null byte not found');
    }

    if (index == 0) {
      _offset += 1;
      return '';
    }

    String value = getString(index);
    _offset += 1;
    return value;
  }

  List<int> get(int? byteLength){
    int? end = byteLength == null ? null : _offset + byteLength;
    var value = data.sublist(_offset, end);
    _offset += value.length;
    return value;
  }

  String getString(int byteLength){
    return utf8.decode(Uint8List.fromList(get(byteLength)));
  }
}