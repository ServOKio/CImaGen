import 'dart:convert';
import 'dart:typed_data';

import '../Utils.dart';

class BufferReader{
  List<int> data;
  ByteData view = ByteData(0);
  int _offset = 0;
  int get offset => _offset;
  bool littleEndian = false;
  Endian endian = Endian.big;
  bool _isMotorolaByteOrder = true;
  late Uint8List bytes;

  BufferReader({
    required this.data,
  }){
    bytes = Uint8List.fromList(data);
    view = ByteData.view(bytes.buffer);
  }

  void setMotorolaByteOrder(bool yes) => _isMotorolaByteOrder = yes;

  void addOffset(int off) => _offset += off;
  void setOffset(int off) => _offset = off;

  int getInt8({bool dontMove = false, int? offset}){
    int v = getByte(offset ?? _offset);
    if(!dontMove && offset == null) _offset = (offset ?? _offset) + 1;
    return v;
  }

  int getUint8(){
    var value = view.getInt8(_offset);
    _offset += 1;
    return value;
  }

  int getInt32({bool dontMove = false, int? offset}){
    var value = view.getInt32(offset ?? _offset, endian);
    if(!dontMove && offset == null) _offset = (offset ?? _offset) + 4;
    return value;
  }

  int getInt16({bool dontMove = false, int? offset}) {
    var value = view.getInt16(offset ?? _offset, endian);
    _offset = (offset ?? _offset) + 2;
    return value;
  }

  int getUInt16({bool dontMove = false, int? offset}){
    //validateIndex(index, 2);

    if (_isMotorolaByteOrder) {
      // Motorola - MSB first
      int f = (getByte(offset ?? _offset) << 8 & 0xFF00) | (getByte((offset ?? _offset) + 1) & 0xFF);
      if(!dontMove && offset == null) _offset = (offset ?? _offset) + 2;
      return f;
    } else {
      // Intel ordering - LSB first
      int f = (getByte((offset ?? _offset) + 1) << 8 & 0xFF00) | (getByte(offset ?? _offset) & 0xFF);
      if(!dontMove && offset == null) _offset = (offset ?? _offset) + 2;
      return f;
    }
  }

  double getS15Fixed16({int? offset}) {
    if (_isMotorolaByteOrder) {
      int res = (getByte(offset ?? _offset) & 0xFF) << 8 | (getByte((offset ?? _offset) + 1) & 0xFF);
      int d = (getByte((offset ?? _offset) + 2) & 0xFF) << 8 | (getByte((offset ?? _offset) + 3) & 0xFF);
      if(offset == null) _offset += 4;
      return res + d / 65536.0;
    } else {
      // this particular branch is untested
      int res = (getByte((offset ?? _offset) + 3) & 0xFF) << 8 | (getByte((offset ?? _offset) + 2) & 0xFF);
      int d = (getByte((offset ?? _offset) + 1) & 0xFF) << 8 | (getByte(offset ?? _offset) & 0xFF);
      if(offset == null) _offset += 4;
      return (res + d / 65536.0);
    }
  }

  int getInt64(){
    var value = view.getInt64(_offset, endian);
    _offset += 8;
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

  List<int> get(int? byteLength, {bool dontMove = false}){
    int? end = byteLength == null ? null : _offset + byteLength;
    var value = data.sublist(_offset, end);
    if(!dontMove) _offset += value.length;
    return value;
  }

  List<int> getRange(int start, int byteLength){
    int end = start + byteLength;
    var value = data.sublist(start, end);
    return value;
  }

  int getByte(int index){
    return bytes[index];
  }

  List<int> getBytes(int ptr, int len){
    return data.sublist(ptr, ptr+len);
  }

  String getString(int byteLength){
    return utf8.decode(Uint8List.fromList(get(byteLength)));
  }

  String? get4ByteString(){
    dynamic i = view.getInt32(_offset, endian);
    if(i != 0){
      i = getStringFromInt32(i);
    }
    _offset += 4;
    return i == 0 ? null : i;
  }

  String getStringFromInt32(int d) {
    // MSB
    return utf8.decode([
      ((d & 0xFF000000) >> 24),
      ((d & 0x00FF0000) >> 16),
      ((d & 0x0000FF00) >> 8),
      ((d & 0x000000FF))
    ]);
  }

  String getDate() {
    final int y = view.getUint16(_offset);
    final int m = view.getUint16(_offset + 2);
    final int d = view.getUint16(_offset + 4);
    final int h = view.getUint16(_offset + 6);
    final int M = view.getUint16(_offset + 8);
    final int s = view.getUint16(_offset + 10);
    _offset += 12;
    if (isValidDate(y, m - 1, d) && isValidTime(h, M, s)) {
      String dateString = "$y:$m:$d $h:$M:$s";
      return dateString;
    } else {
      return "ICC data describes an invalid date/time: year=$y month=$m day=$d hour=$h minute=$M second=$s";
    }
  }

  Endian endianOfByte(int b) {
    if (b == 'I'.codeUnitAt(0)) {
      return Endian.little;
    }
    return Endian.big;
  }
}