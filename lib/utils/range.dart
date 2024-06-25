import "dart:collection";

class Range extends IterableBase<int> {
  factory Range(int start, [int? stop, int step = 1]) {
    if (stop == null) {
      // reverse stop and start making start 0
      stop = start;
      start = 0;
    }
    if (step == 0) {
      throw new ArgumentError("step must not be 0");
    }

    return new Range._(start, stop, step);
  }

  Range._(this.start, this.stop, this.step);

  Iterator<int> get iterator => new RangeIterator(start, stop, step);

  int get length {
    if ((step > 0 && start > stop) || (step < 0 && start < stop)) {
      return 0;
    }
    return ((stop - start) / step).ceil();
  }

  bool get isEmpty => length == 0;

  int get hashCode {
    int result = 17;
    result = 37 * result + start.hashCode;
    result = 37 * result + stop.hashCode;
    result = 37 * result + step.hashCode;
    return result;
  }

  String toString() =>
      step == 1 ? "Range($start, $stop)" : "Range($start, $stop, $step)";

  /// *Deprecated*: use [any] instead.
  @deprecated
  bool some(bool f(int e)) => any(f);

  /// *Deprecated*: use [where] instead.
  @deprecated
  List<int> filter(bool f(int e)) => where(f).toList();

  bool operator ==(other) => other is Range &&
      start == other.start &&
      stop == other.stop &&
      step == other.step;

  final int start;
  final int stop;
  final int step;
}

class RangeIterator implements Iterator<int> {
  int _pos;
  final int _stop;
  final int _step;

  RangeIterator(int pos, int stop, int step)
      : _stop = stop,
        _pos = pos - step,
        _step = step;

  int get current => _pos;

  bool moveNext() {
    if (_step > 0 ? _pos + _step > _stop - 1 : _pos + _step < _stop + 1) {
      return false;
    }
    _pos += _step;
    return true;
  }
}

Range range(int start_inclusive, [int? stop_exclusive, int step = 1]) =>
    new Range(start_inclusive, stop_exclusive, step);

Range indices(lengthable) => new Range(0, lengthable.length);