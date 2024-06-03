// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library utf.utf16;

import 'dart:collection';

// import 'list_range.dart';
// import 'utf_16_code_unit_decoder.dart';
// import 'util.dart';

/// Generate a string from the provided Unicode codepoints.
///
/// *Deprecated* Use [String.fromCharCodes] instead.
@deprecated
String codepointsToString(List<int> codepoints) {
  return String.fromCharCodes(codepoints);
}

const int UNICODE_REPLACEMENT_CHARACTER_CODEPOINT = 0xfffd;
const int UNICODE_BOM = 0xfeff;
const int UNICODE_UTF_BOM_LO = 0xff;
const int UNICODE_UTF_BOM_HI = 0xfe;

const int UNICODE_BYTE_ZERO_MASK = 0xff;
const int UNICODE_BYTE_ONE_MASK = 0xff00;
const int UNICODE_VALID_RANGE_MAX = 0x10ffff;
const int UNICODE_PLANE_ONE_MAX = 0xffff;
const int UNICODE_UTF16_RESERVED_LO = 0xd800;
const int UNICODE_UTF16_RESERVED_HI = 0xdfff;
const int UNICODE_UTF16_OFFSET = 0x10000;
const int UNICODE_UTF16_SURROGATE_UNIT_0_BASE = 0xd800;
const int UNICODE_UTF16_SURROGATE_UNIT_1_BASE = 0xdc00;
const int UNICODE_UTF16_HI_MASK = 0xffc00;
const int UNICODE_UTF16_LO_MASK = 0x3ff;

/// Decodes the UTF-16 bytes as an iterable. Thus, the consumer can only convert
/// as much of the input as needed. Determines the byte order from the BOM,
/// or uses big-endian as a default. This method always strips a leading BOM.
/// Set the [replacementCodepoint] to null to throw an ArgumentError
/// rather than replace the bad value. The default value for
/// [replacementCodepoint] is U+FFFD.
IterableUtf16Decoder decodeUtf16AsIterable(List<int> bytes, {int offset = 0, int? length, int replacementCodepoint = UNICODE_REPLACEMENT_CHARACTER_CODEPOINT}) {
  return IterableUtf16Decoder._(() => Utf16BytesToCodeUnitsDecoder(bytes, offset: offset, length: length, replacementCodepoint: replacementCodepoint), replacementCodepoint);
}

/// Decodes the UTF-16BE bytes as an iterable. Thus, the consumer can only
/// convert as much of the input as needed. This method strips a leading BOM by
/// default, but can be overridden by setting the optional parameter [stripBom]
/// to false. Set the [replacementCodepoint] to null to throw an
/// ArgumentError rather than replace the bad value. The default
/// value for the [replacementCodepoint] is U+FFFD.
IterableUtf16Decoder decodeUtf16beAsIterable(List<int> bytes, {int offset = 0, int length = 0, bool stripBom = true, int replacementCodepoint = UNICODE_REPLACEMENT_CHARACTER_CODEPOINT}) {
  return IterableUtf16Decoder._(() => Utf16beBytesToCodeUnitsDecoder(bytes, offset: offset, length: length, stripBom: stripBom, replacementCodepoint: replacementCodepoint), replacementCodepoint);
}

/// Decodes the UTF-16LE bytes as an iterable. Thus, the consumer can only
/// convert as much of the input as needed. This method strips a leading BOM by
/// default, but can be overridden by setting the optional parameter [stripBom]
/// to false. Set the [replacementCodepoint] to null to throw an
/// ArgumentError rather than replace the bad value. The default
/// value for the [replacementCodepoint] is U+FFFD.
IterableUtf16Decoder decodeUtf16leAsIterable(List<int> bytes, {int offset = 0, int length = 0, bool stripBom = true, int replacementCodepoint = UNICODE_REPLACEMENT_CHARACTER_CODEPOINT}) {
  return IterableUtf16Decoder._(() => Utf16leBytesToCodeUnitsDecoder(bytes, offset: offset, length: length, stripBom: stripBom, replacementCodepoint: replacementCodepoint),replacementCodepoint);
}

/// Produce a String from a sequence of UTF-16 encoded bytes. This method always
/// strips a leading BOM. Set the [replacementCodepoint] to null to throw  an
/// ArgumentError rather than replace the bad value. The default
/// value for the [replacementCodepoint] is U+FFFD.
String decodeUtf16(List<int> bytes, {int offset = 0, int length = 0, int replacementCodepoint = UNICODE_REPLACEMENT_CHARACTER_CODEPOINT}) {
  var decoder = Utf16BytesToCodeUnitsDecoder(bytes, offset: offset, length: length, replacementCodepoint: replacementCodepoint);
  var codeunits = decoder.decodeRest();
  return String.fromCharCodes(utf16CodeUnitsToCodepoints(codeunits, offset: 0, length: null, replacementCodepoint: replacementCodepoint));
}

/// Produce a String from a sequence of UTF-16BE encoded bytes. This method
/// strips a leading BOM by default, but can be overridden by setting the
/// optional parameter [stripBom] to false. Set the [replacementCodepoint] to
/// null to throw an ArgumentError rather than replace the bad value.
/// The default value for the [replacementCodepoint] is U+FFFD.
String decodeUtf16be(List<int> bytes, {int offset = 0, int length = 0, bool stripBom = true, int replacementCodepoint = UNICODE_REPLACEMENT_CHARACTER_CODEPOINT}) {
  var codeunits = (Utf16beBytesToCodeUnitsDecoder(bytes, offset: offset, length: length, stripBom: stripBom, replacementCodepoint: replacementCodepoint)).decodeRest();
  return String.fromCharCodes(utf16CodeUnitsToCodepoints(codeunits, offset: 0, length: null, replacementCodepoint: replacementCodepoint));
}

/// Produce a String from a sequence of UTF-16LE encoded bytes. This method
/// strips a leading BOM by default, but can be overridden by setting the
/// optional parameter [stripBom] to false. Set the [replacementCodepoint] to
/// null to throw an ArgumentError rather than replace the bad value.
/// The default value for the [replacementCodepoint] is U+FFFD.
String decodeUtf16le(List<int> bytes, {int offset = 0, int? length, bool stripBom = true, int replacementCodepoint = UNICODE_REPLACEMENT_CHARACTER_CODEPOINT}) {
  var codeunits = (Utf16leBytesToCodeUnitsDecoder(bytes, offset: offset, length: length, stripBom: stripBom, replacementCodepoint: replacementCodepoint)).decodeRest();
  return String.fromCharCodes(utf16CodeUnitsToCodepoints(codeunits, offset: 0, length: null, replacementCodepoint: replacementCodepoint));
}

/// Produce a list of UTF-16 encoded bytes. This method prefixes the resulting
/// bytes with a big-endian byte-order-marker.
List<int> encodeUtf16(String str) => encodeUtf16be(str, true);

/// Produce a list of UTF-16BE encoded bytes. By default, this method produces
/// UTF-16BE bytes with no BOM.
List<int> encodeUtf16be(String str, [bool writeBOM = false]) {
  var utf16CodeUnits = _stringToUtf16CodeUnits(str);
  List<int> encoding = List.filled(2 * utf16CodeUnits.length + (writeBOM ? 2 : 0), 0);
  var i = 0;
  if (writeBOM) {
    encoding[i++] = UNICODE_UTF_BOM_HI;
    encoding[i++] = UNICODE_UTF_BOM_LO;
  }
  for (var unit in utf16CodeUnits) {
    encoding[i++] = (unit & UNICODE_BYTE_ONE_MASK) >> 8;
    encoding[i++] = unit & UNICODE_BYTE_ZERO_MASK;
  }
  return encoding;
}

/// Produce a list of UTF-16LE encoded bytes. By default, this method produces
/// UTF-16LE bytes with no BOM.
List<int> encodeUtf16le(String str, [bool writeBOM = false]) {
  var utf16CodeUnits = _stringToUtf16CodeUnits(str);
  List<int> encoding = List.filled(2 * utf16CodeUnits.length + (writeBOM ? 2 : 0), 0);
  var i = 0;
  if (writeBOM) {
    encoding[i++] = UNICODE_UTF_BOM_LO;
    encoding[i++] = UNICODE_UTF_BOM_HI;
  }
  for (var unit in utf16CodeUnits) {
    encoding[i++] = unit & UNICODE_BYTE_ZERO_MASK;
    encoding[i++] = (unit & UNICODE_BYTE_ONE_MASK) >> 8;
  }
  return encoding;
}

/// Identifies whether a List of bytes starts (based on offset) with a
/// byte-order marker (BOM).
bool hasUtf16Bom(List<int> utf32EncodedBytes, {int offset = 0, int? length}) {
  return hasUtf16beBom(utf32EncodedBytes, offset: offset, length: length) || hasUtf16leBom(utf32EncodedBytes, offset: offset, length: length);
}

/// Identifies whether a List of bytes starts (based on offset) with a
/// big-endian byte-order marker (BOM).
bool hasUtf16beBom(List<int> utf16EncodedBytes, {int offset = 0, int? length}) {
  var end = length != null ? offset + length : utf16EncodedBytes.length;
  return (offset + 2) <= end && utf16EncodedBytes[offset] == UNICODE_UTF_BOM_HI && utf16EncodedBytes[offset + 1] == UNICODE_UTF_BOM_LO;
}

/// Identifies whether a List of bytes starts (based on offset) with a
/// little-endian byte-order marker (BOM).
bool hasUtf16leBom(List<int> utf16EncodedBytes, {int offset = 0, int? length}) {
  var end = length != null ? offset + length : utf16EncodedBytes.length;
  return (offset + 2) <= end &&
      utf16EncodedBytes[offset] == UNICODE_UTF_BOM_LO &&
      utf16EncodedBytes[offset + 1] == UNICODE_UTF_BOM_HI;
}

List<int> _stringToUtf16CodeUnits(String str) {
  return codepointsToUtf16CodeUnits(str.codeUnits);
}

typedef _CodeUnitsProvider = ListRangeIterator Function();

/// Return type of [decodeUtf16AsIterable] and variants. The Iterable type
/// provides an iterator on demand and the iterator will only translate bytes
/// as requested by the user of the iterator. (Note: results are not cached.)
// TODO(floitsch): Consider removing the extend and switch to implements since
// that's cheaper to allocate.
class IterableUtf16Decoder extends IterableBase<int> {
  final _CodeUnitsProvider codeunitsProvider;
  final int replacementCodepoint;

  IterableUtf16Decoder._(this.codeunitsProvider, this.replacementCodepoint);

  @override
  Utf16CodeUnitDecoder get iterator => Utf16CodeUnitDecoder.fromListRangeIterator(codeunitsProvider(), replacementCodepoint);
}

/// Convert UTF-16 encoded bytes to UTF-16 code units by grouping 1-2 bytes
/// to produce the code unit (0-(2^16)-1). Relies on BOM to determine
/// endian-ness, and defaults to BE.
abstract class Utf16BytesToCodeUnitsDecoder implements ListRangeIterator {
  // TODO(kevmoo): should this field be private?
  final ListRangeIterator utf16EncodedBytesIterator;
  final int replacementCodepoint;
  dynamic _current;

  Utf16BytesToCodeUnitsDecoder._fromListRangeIterator(this.utf16EncodedBytesIterator, this.replacementCodepoint);

  factory Utf16BytesToCodeUnitsDecoder(List<int> utf16EncodedBytes, {int offset = 0, int? length, int replacementCodepoint = UNICODE_REPLACEMENT_CHARACTER_CODEPOINT}) {
    length ??= utf16EncodedBytes.length - offset;
    if (hasUtf16beBom(utf16EncodedBytes, offset: offset, length: length)) {
      return Utf16beBytesToCodeUnitsDecoder(utf16EncodedBytes, offset: offset + 2, length: length - 2, stripBom: false, replacementCodepoint: replacementCodepoint);
    } else if (hasUtf16leBom(utf16EncodedBytes, offset: offset, length: length)) {
      return Utf16leBytesToCodeUnitsDecoder(utf16EncodedBytes, offset: offset + 2, length: length - 2, stripBom: false, replacementCodepoint: replacementCodepoint);
    } else {
      return Utf16beBytesToCodeUnitsDecoder(utf16EncodedBytes, offset: offset, length: length, stripBom: false, replacementCodepoint: replacementCodepoint);
    }
  }

  /// Provides a fast way to decode the rest of the source bytes in a single
  /// call. This method trades memory for improved speed in that it potentially
  /// over-allocates the List containing results.
  List<int> decodeRest() {
    List<int> codeunits = List.filled(remaining, 0);
    var i = 0;
    while (moveNext()) {
      codeunits[i++] = current;
    }
    if (i == codeunits.length) {
      return codeunits;
    } else {
      List<int> truncCodeunits = List.filled(i, 0);
      truncCodeunits.setRange(0, i, codeunits);
      return truncCodeunits;
    }
  }

  @override
  int get current => _current;

  @override
  bool moveNext() {
    _current = null;
    var remaining = utf16EncodedBytesIterator.remaining;
    if (remaining == 0) {
      _current = null;
      return false;
    }
    if (remaining == 1) {
      utf16EncodedBytesIterator.moveNext();
      if (replacementCodepoint != null) {
        _current = replacementCodepoint;
        return true;
      } else {
        throw ArgumentError('Invalid UTF16 at ${utf16EncodedBytesIterator.position}');
      }
    }
    _current = decode();
    return true;
  }

  @override
  int get position => utf16EncodedBytesIterator.position ~/ 2;

  @override
  void backup([int by = 1]) {
    utf16EncodedBytesIterator.backup(2 * by);
  }

  @override
  int get remaining => (utf16EncodedBytesIterator.remaining + 1) ~/ 2;

  @override
  void skip([int count = 1]) {
    utf16EncodedBytesIterator.skip(2 * count);
  }

  int decode();
}

/// Convert UTF-16BE encoded bytes to utf16 code units by grouping 1-2 bytes
/// to produce the code unit (0-(2^16)-1).
class Utf16beBytesToCodeUnitsDecoder extends Utf16BytesToCodeUnitsDecoder {
  Utf16beBytesToCodeUnitsDecoder(List<int> utf16EncodedBytes, {int offset = 0, int? length, bool stripBom = true, int replacementCodepoint = UNICODE_REPLACEMENT_CHARACTER_CODEPOINT}) : super._fromListRangeIterator((ListRange(utf16EncodedBytes, offset: offset, length: length)).iterator,replacementCodepoint) {
    if (stripBom && hasUtf16beBom(utf16EncodedBytes, offset: offset, length: length)) {
      skip();
    }
  }

  @override
  int decode() {
    utf16EncodedBytesIterator.moveNext();
    var hi = utf16EncodedBytesIterator.current;
    utf16EncodedBytesIterator.moveNext();
    var lo = utf16EncodedBytesIterator.current;
    return (hi << 8) + lo;
  }
}

/// Convert UTF-16LE encoded bytes to utf16 code units by grouping 1-2 bytes
/// to produce the code unit (0-(2^16)-1).
class Utf16leBytesToCodeUnitsDecoder extends Utf16BytesToCodeUnitsDecoder {
  Utf16leBytesToCodeUnitsDecoder(List<int> utf16EncodedBytes, {int offset = 0, int? length, bool stripBom = true, int replacementCodepoint = UNICODE_REPLACEMENT_CHARACTER_CODEPOINT}) : super._fromListRangeIterator(
      (ListRange(utf16EncodedBytes, offset: offset, length: length)).iterator,
      replacementCodepoint) {
    if (stripBom && hasUtf16leBom(utf16EncodedBytes, offset: offset, length: length)) {
      skip();
    }
  }

  @override
  int decode() {
    utf16EncodedBytesIterator.moveNext();
    var lo = utf16EncodedBytesIterator.current;
    utf16EncodedBytesIterator.moveNext();
    var hi = utf16EncodedBytesIterator.current;
    return (hi << 8) + lo;
  }
}

List<int> utf16CodeUnitsToCodepoints(List<int> utf16CodeUnits, {int offset = 0, int? length, int replacementCodepoint = UNICODE_REPLACEMENT_CHARACTER_CODEPOINT}) {
  var source = (ListRange(utf16CodeUnits, offset: offset, length: length)).iterator;
  var decoder = Utf16CodeUnitDecoder.fromListRangeIterator(source, replacementCodepoint);
  List<int> codepoints = List.filled(source.remaining, 0);
  var i = 0;
  while (decoder.moveNext()) {
    codepoints[i++] = decoder.current;
  }
  if (i == codepoints.length) {
    return codepoints;
  } else {
    List<int> codepointTrunc = List.filled(i, 0);
    codepointTrunc.setRange(0, i, codepoints);
    return codepointTrunc;
  }
}

class ListRange extends IterableBase<int> {
  final List<int> _source;
  final int _offset;
  final int _length;

  ListRange(List<int> source, {int offset = 0, int? length}) : _source = source, _offset = offset, _length = (length ?? source.length - offset) {
    if (_offset < 0 || _offset > _source.length) {
      throw RangeError.value(_offset);
    }
    if (_length != null && (_length < 0)) {
      throw RangeError.value(_length);
    }
    if (_length + _offset > _source.length) {
      throw RangeError.value(_length + _offset);
    }
  }

  @override
  ListRangeIterator get iterator =>_ListRangeIteratorImpl(_source, _offset, _offset + _length);

  @override
  int get length => _length;
}

/// The ListRangeIterator provides more capabilities than a standard iterator,
/// including the ability to get the current position, count remaining items,
/// and move forward/backward within the iterator.
abstract class ListRangeIterator implements Iterator<int> {
  @override
  bool moveNext();
  @override
  int get current;
  int get position;
  void backup([int by]);
  int get remaining;
  void skip([int count]);
}

class _ListRangeIteratorImpl implements ListRangeIterator {
  final List<int> _source;
  int _offset;
  final int _end;

  _ListRangeIteratorImpl(this._source, int offset, this._end): _offset = offset - 1;

  @override
  int get current => _source[_offset];

  @override
  bool moveNext() => ++_offset < _end;

  @override
  int get position => _offset;

  @override
  void backup([int by = 1]) {
    _offset -= by;
  }

  @override
  int get remaining => _end - _offset - 1;

  @override
  void skip([int count = 1]) {
    _offset += count;
  }
}

List<int> codepointsToUtf16CodeUnits(List<int> codepoints, {int offset = 0, int? length, int replacementCodepoint = UNICODE_REPLACEMENT_CHARACTER_CODEPOINT}) {
  var listRange = ListRange(codepoints, offset: offset, length: length);
  var encodedLength = 0;
  for(var value in listRange) {
    if ((value >= 0 && value < UNICODE_UTF16_RESERVED_LO) || (value > UNICODE_UTF16_RESERVED_HI && value <= UNICODE_PLANE_ONE_MAX)) {
      encodedLength++;
    } else if (value > UNICODE_PLANE_ONE_MAX &&
      value <= UNICODE_VALID_RANGE_MAX) {
      encodedLength += 2;
    } else {
      encodedLength++;
    }
  }

  List<int> codeUnitsBuffer = List.filled(encodedLength, 0);
  var j = 0;
  for (var value in listRange) {
    if ((value >= 0 && value < UNICODE_UTF16_RESERVED_LO) ||
      (value > UNICODE_UTF16_RESERVED_HI && value <= UNICODE_PLANE_ONE_MAX)) {
      codeUnitsBuffer[j++] = value;
    } else if (value > UNICODE_PLANE_ONE_MAX &&
      value <= UNICODE_VALID_RANGE_MAX) {
      var base = value - UNICODE_UTF16_OFFSET;
      codeUnitsBuffer[j++] = UNICODE_UTF16_SURROGATE_UNIT_0_BASE +((base & UNICODE_UTF16_HI_MASK) >> 10);
      codeUnitsBuffer[j++] = UNICODE_UTF16_SURROGATE_UNIT_1_BASE + (base & UNICODE_UTF16_LO_MASK);
    } else if (replacementCodepoint != null) {
      codeUnitsBuffer[j++] = replacementCodepoint;
    } else {
      throw ArgumentError('Invalid encoding');
    }
  }
  return codeUnitsBuffer;
}

class Utf16CodeUnitDecoder implements Iterator<int> {
  // TODO(kevmoo): should this field be private?
  final ListRangeIterator utf16CodeUnitIterator;
  final int replacementCodepoint;
  dynamic _current;

  Utf16CodeUnitDecoder(List<int> utf16CodeUnits, {int offset = 0, int? length, this.replacementCodepoint = UNICODE_REPLACEMENT_CHARACTER_CODEPOINT}): utf16CodeUnitIterator = (ListRange(utf16CodeUnits, offset: offset, length: length)).iterator;

  Utf16CodeUnitDecoder.fromListRangeIterator(this.utf16CodeUnitIterator, this.replacementCodepoint);

  Iterator<int> get iterator => this;

  @override
  int get current => _current;

  @override
  bool moveNext() {
    _current = null;
    if (!utf16CodeUnitIterator.moveNext()) return false;

    var value = utf16CodeUnitIterator.current;
    if (value < 0) {
    if (replacementCodepoint != null) {
      _current = replacementCodepoint;
    } else {
      throw ArgumentError('Invalid UTF16 at ${utf16CodeUnitIterator.position}');
    }
    } else if (value < UNICODE_UTF16_RESERVED_LO || (value > UNICODE_UTF16_RESERVED_HI && value <= UNICODE_PLANE_ONE_MAX)) {
      // transfer directly
      _current = value;
    } else if (value < UNICODE_UTF16_SURROGATE_UNIT_1_BASE && utf16CodeUnitIterator.moveNext()) {
      // merge surrogate pair
      var nextValue = utf16CodeUnitIterator.current;
      if (nextValue >= UNICODE_UTF16_SURROGATE_UNIT_1_BASE && nextValue <= UNICODE_UTF16_RESERVED_HI) {
        value = (value - UNICODE_UTF16_SURROGATE_UNIT_0_BASE) << 10;
        value += UNICODE_UTF16_OFFSET + (nextValue - UNICODE_UTF16_SURROGATE_UNIT_1_BASE);
        _current = value;
      } else {
        if (nextValue >= UNICODE_UTF16_SURROGATE_UNIT_0_BASE && nextValue < UNICODE_UTF16_SURROGATE_UNIT_1_BASE) {
        utf16CodeUnitIterator.backup();
        }
        if (replacementCodepoint != null) {
          _current = replacementCodepoint;
        } else {
          throw ArgumentError('Invalid UTF16 at ${utf16CodeUnitIterator.position}');
        }
      }
    } else if (replacementCodepoint != null) {
      _current = replacementCodepoint;
    } else {
      throw ArgumentError('Invalid UTF16 at ${utf16CodeUnitIterator.position}');
    }
    return true;
  }
}