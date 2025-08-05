import 'package:collection/collection.dart';
import 'package:image/image.dart' as img;
import 'dart:math' as math;


List<List<List<int>>> imageToHxWxCArray(img.Image image){
  img.Image from = image.clone().convert(numChannels: 3);
  List<List<List<int>>> list = List<List<List<int>>>.generate(image.height, (i1) => List<List<int>>.generate(image.width, (i2) => [0,0,0]));

  for (img.Pixel pix in from) {
    list[pix.y][pix.x] = [pix.r.toInt(), pix.g.toInt(), pix.b.toInt()];
  }
  return list;
}

List<List<List<double>>> convertToLab(img.Image image) {
  img.Image from = image.clone().convert(numChannels: 3);
  List<List<List<double>>> list = List.generate(image.height, (i) => List.generate(image.width, (j) => [0.0, 0.0, 0.0]));
  for (img.Pixel pix in from) {
    list[pix.y][pix.x] = rgb2lab(pix.r, pix.g, pix.b);
  }
  return list;
}

List<List<double>> getAvgStd(List<List<List<double>>> image) {
  var avg = List<double>.filled(3, 0.0);
  var std = List<double>.filled(3, 0.0);
  var height = image.length;
  var width = image[0].length;

  for (var i = 0; i < height; i++) {
    for (var j = 0; j < width; j++) {
      avg[0] += image[i][j][0];
      avg[1] += image[i][j][1];
      avg[2] += image[i][j][2];
    }
  }

  avg = avg.map((e) => e / (height * width)).toList();

  for (var i = 0; i < height; i++) {
    for (var j = 0; j < width; j++) {
      std[0] += (image[i][j][0] - avg[0]) * (image[i][j][0] - avg[0]);
      std[1] += (image[i][j][1] - avg[1]) * (image[i][j][1] - avg[1]);
      std[2] += (image[i][j][2] - avg[2]) * (image[i][j][2] - avg[2]);
    }
  }

  std = std.map((e) => math.sqrt(e / (height * width))).toList();

  return [avg, std];
}

img.Image convertToBGR(List<List<List<double>>> image) {
  // Implement conversion from LAB to BGR
  // This is a placeholder for the actual conversion logic
  return img.Image(width: image[0].length, height: image.length);
}

img.Image convertLabToRGB(List<List<List<double>>> image) {
  List<List<List<int>>> q = convertLab2Rgb(image);
  img.Image f = img.Image(width: q[0].length, height: q.length);
  for (var pixel in f) {
    pixel
      ..r = q[pixel.y][pixel.x][0]
      ..g = q[pixel.y][pixel.x][1]
      ..b = q[pixel.y][pixel.x][2];
  }
  return f;
}

List<dynamic> mean(var values, {int? axis}) {
  if (values.isEmpty) {
    return [double.nan]; // Return NaN for empty lists
  }

  if (axis == null) {
    final List<num> flattenedValues = values.expand((list) => list).toList();
    final num total = flattenedValues.reduce((a, b) => a + b);
    return [total / flattenedValues.length];
  } else if (axis == 0) {
    final List<dynamic> columnSums = List<dynamic>.filled(values[0].length, 0);
    for (List<dynamic> row in values) {
      for (int i = 0; i < row.length; i++) {
        columnSums[i] += row[i];
      }
    }
    return columnSums.map((sum) => sum / values.length).toList();
  } else if (axis == 1) {
    return values.map((row) => row.reduce((a, b) => a + b) / row.length).toList();
  } else {
    throw ArgumentError("Axis must be null, 0, or 1.");
  }
}

List<List<double>> cov(List<List<int>> data, {bool rowvar = true}){
  List<List<int>> variables;

  if (rowvar) {
    variables = data; // Rows are variables
  } else {
    // Transpose the data if columns are variables
    variables = data[0].mapIndexed((colIndex, _) => data.map((row) => row[colIndex]).toList()).toList();
  }

  int numVariables = variables.length;
  int numObservations = variables[0].length;
  List<List<double>> covarianceMatrix = List<List<double>>.generate(numVariables, (i) => List<double>.generate(numVariables, (i2) => 0));

  // Calculate means for each variable
  var means = variables.map((variable) => variable.reduce((sum, val) => sum + val) / numObservations).toList();

  // Calculate covariance for each pair of variables
  for (int i = 0; i < numVariables; i++) {
    for (int j = 0; j < numVariables; j++) {
      double sumOfProductsOfDeviations = 0;
      for (int k = 0; k < numObservations; k++) {
        sumOfProductsOfDeviations += (variables[i][k] - means[i]) * (variables[j][k] - means[j]);
      }
      // Using N-1 for unbiased estimate (default in numpy.cov)
      covarianceMatrix[i][j] = sumOfProductsOfDeviations / (numObservations - 1);
    }
  }

  return covarianceMatrix;
}

// With denman beavers method
List<List<double>> matrixSqrt(List<List<double>> A, {iterations = 10, tolerance = 1e-9}){
  double error = 0;
  int iterations = 0;

  List<List<double>> Y = List<List<double>>.from(A);
  List<List<double>> Z = List<List<double>>.generate(A.length, (i) => List<double>.generate(A.length, (j) => (i == j ? 1 : 0)));

  do {
    List<List<double>> Yk = Y;
    Y = matrixMultiply(0.5, matrixAdd(Yk, inverseMatrix(Z)));
    Z = matrixMultiply(0.5, matrixAdd(Z, inverseMatrix(Yk)));

    error = matrixMax(matrixAbs(matrixSubtract(Y, Yk)));

    if (error > tolerance && ++iterations > iterations) {
      throw Exception('computing square root of matrix: iterative method could not converge');
    }
  } while (error > tolerance);

  return Y;
}

List<int> matrixSize(List<List<double>> A){
  return [A[0].length, A.length];
}

List<List<double>> matrixSqrtShit(List<List<double>> matrix, {iterations = 10, tolerance = 1e-9}){
  int n = matrix.length;
  if (n == 0 || matrix[0].length != n) {
    throw Exception("Input must be a square matrix.");
  }

  // Helper function for matrix multiplication
  List<List<double>> multiplyMatrices(List<List<double>> A, List<List<double>> B){
    List<List<double>> result = List<List<double>>.generate(n, (i) => List<double>.generate(n, (i2) => 0));
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        for (int k = 0; k < n; k++) {
          result[i][j] += A[i][k] * B[k][j];
        }
      }
    }
    return result;
  }

  // Helper function for matrix addition
  List<List<double>> addMatrices(List<List<double>> A, List<List<double>> B){
    List<List<double>> result = List<List<double>>.generate(n, (i) => List<double>.generate(n, (i2) => 0));
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        result[i][j] = A[i][j] + B[i][j];
      }
    }
    return result;
  }

  // Initial guess for the square root (e.g., identity matrix or scaled input)
  List<List<double>> X = List<List<double>>.generate(n, (i) => List<double>.generate(n, (j) => (i == j ? 1 : 0))); // Identity matrix

  for (int k = 0; k < iterations; k++) {
    List<List<double>> X_inv = inverseMatrix(X);
    List<List<double>> term1 = scalarMultiplyMatrix(0.5, X);
    List<List<double>> term2 = scalarMultiplyMatrix(0.5, multiplyMatrices(X_inv, matrix));
    List<List<double>> X_next = addMatrices(term1, term2);

    // Check for convergence
    num diffNorm = 0;
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        diffNorm += math.pow(X_next[i][j] - X[i][j], 2);
      }
    }
    if (math.sqrt(diffNorm) < tolerance) {
      return X_next;
    }
    X = X_next;
  }

  return X;
}

double getDeterminant(matrix) {
  int n = matrix.length;

  // Base case: 1x1 matrix
  if (n == 1) {
    return matrix[0][0];
  }

  // Base case: 2x2 matrix
  if (n == 2) {
    return (matrix[0][0] * matrix[1][1]) - (matrix[0][1] * matrix[1][0]);
  }

  double det = 0;
  for (int col = 0; col < n; col++) {
    // Create the sub-matrix (minor)
    List<List<double>> subMatrix = [];
    for (int i = 1; i < n; i++) { // Start from the second row
      List<double> newRow = [];
      for (int j = 0; j < n; j++) {
        if (j != col) { // Exclude the current column
          newRow.add(matrix[i][j]);
        }
      }
      subMatrix.add(newRow);
    }

    // Calculate the cofactor sign
    int sign = (col % 2 == 0) ? 1 : -1;

    // Add the product of the element, its sign, and the determinant of the sub-matrix
    det += sign * matrix[0][col] * getDeterminant(subMatrix);
  }

  return det;
}

List<List<double>> matrixDot(List<List<double>> matrixA, List<List<double>> matrixB) {
  int rowsA = matrixA.length;
  int colsA = matrixA[0].length;
  int rowsB = matrixB.length;
  int colsB = matrixB[0].length;

  if (colsA != rowsB) {
    throw Exception("Number of columns in the first matrix must equal the number of rows in the second matrix for multiplication.");
  }

  // Initialize the result matrix with zeros
  List<List<double>> resultMatrix = List<List<double>>.generate(rowsA, (i) => List<double>.generate(colsB, (i2) => 0));

  for (var i = 0; i < rowsA; i++) {
    for (var j = 0; j < colsB; j++) {
      for (var k = 0; k < colsA; k++) { // Or rowsB, as they are equal
        resultMatrix[i][j] += matrixA[i][k] * matrixB[k][j];
      }
    }
  }

  return resultMatrix;
}

List<List<double>> matrixAdd(List<List<double>> matrixA, List<List<double>> matrixB) {
// Ensure both inputs are 3x3 matrices
  if (matrixA.length != 3 || matrixB.length != 3) {
    throw Exception("Inputs must be 3x3 matrices.");
  }
  for (int i = 0; i < 3; i++) {
    if (matrixA[i].length != 3 || matrixB[i].length != 3) {
      throw Exception("Inputs must be 3x3 matrices with 3 elements per row.");
    }
  }

  // Initialize the result matrix with zeros
  List<List<double>> resultMatrix = [
    [0, 0, 0],
    [0, 0, 0],
    [0, 0, 0]
  ];

  // Perform matrix multiplication
  for (int i = 0; i < 3; i++) { // Iterate through rows of matrixA
    for (int j = 0; j < 3; j++) { // Iterate through columns of matrixB
      resultMatrix[i][j] += matrixA[i][j] + matrixB[i][j];
    }
  }

  return resultMatrix;
}

List<List<double>> matrixSubtract(List<List<double>> matrixA, List<List<double>> matrixB) {
// Ensure both inputs are 3x3 matrices
  if (matrixA.length != 3 || matrixB.length != 3) {
    throw Exception("Inputs must be 3x3 matrices.");
  }
  for (int i = 0; i < 3; i++) {
    if (matrixA[i].length != 3 || matrixB[i].length != 3) {
      throw Exception("Inputs must be 3x3 matrices with 3 elements per row.");
    }
  }

  // Initialize the result matrix with zeros
  List<List<double>> resultMatrix = [
    [0, 0, 0],
    [0, 0, 0],
    [0, 0, 0]
  ];

  // Perform matrix multiplication
  for (int i = 0; i < 3; i++) { // Iterate through rows of matrixA
    for (int j = 0; j < 3; j++) { // Iterate through columns of matrixB
      resultMatrix[i][j] += matrixA[i][j] - matrixB[i][j];
    }
  }

  return resultMatrix;
}

List<List<double>> matrixMultiply(double multiplier, List<List<double>> matrixA) {
  if (matrixA.length != 3) {
    throw Exception("Inputs must be 3x3 matrices.");
  }
  for (int i = 0; i < 3; i++) {
    if (matrixA[i].length != 3) {
      throw Exception("Inputs must be 3x3 matrices with 3 elements per row.");
    }
  }

  // Initialize the result matrix with zeros
  List<List<double>> resultMatrix = [
    [0, 0, 0],
    [0, 0, 0],
    [0, 0, 0]
  ];

  // Perform matrix multiplication
  for (int i = 0; i < 3; i++) { // Iterate through rows of matrixA
    for (int j = 0; j < 3; j++) { // Iterate through columns of matrixB
      resultMatrix[i][j] += matrixA[i][j] * multiplier;
    }
  }

  return resultMatrix;
}

List<List<double>> scalarMultiplyMatrix(scalar, List<List<double>> A){
  int n = A.length;
  if (n == 0 || A[0].length != n) {
    throw Exception("Input must be a square matrix.");
  }
  List<List<double>> result = List<List<double>>.generate(n, (i) => List<double>.generate(n, (i2) => 0));
  for (int i = 0; i < n; i++) {
    for (int j = 0; j < n; j++) {
      result[i][j] = scalar * A[i][j];
    }
  }
  return result;
}

List<List<double>> inverseMatrix(List<List<double>> A){
  int n = A.length;
  if (n == 0 || A[0].length != n) {
    throw Exception("Input must be a square matrix.");
  }

  if (n == 2) {
    double det = A[0][0] * A[1][1] - A[0][1] * A[1][0];
    if (det.abs() < 1e-12) {
      throw Exception("Matrix is singular, cannot find inverse.");
    }

    return scalarMultiplyMatrix(1 / det, [
      [A[1][1], -A[0][1]],
      [-A[1][0], A[0][0]]
    ]);
  } else {
    double det = getDeterminant(A);
    if (det == 0) {
      throw Exception('Matrix is singular and cannot be inverted');
    }

    List<List<double>> adjugateMatrix = List<List<double>>.generate(n, (i) => List<double>.generate(n, (i2) => 0));

    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        List<List<double>> subMatrix = [
          for (int p = 0; p < n; p++)
            if (p != i)
              [
                for (int q = 0; q < n; q++)
                  if (q != j) A[p][q]
              ]
        ];
        adjugateMatrix[j][i] = ((i + j) % 2 == 0 ? 1 : -1) * getDeterminant(subMatrix);
      }
    }

    double invDet = 1 / det;

    List<List<double>> inverseMatrix = adjugateMatrix.map((row) => row.map((val) => val * invDet).toList()).toList();
    return inverseMatrix;
  }
}

List<List<double>> matrixAbs(List<List<double>> A){
  int n = A.length;
  if (n == 0 || A[0].length != n) {
    throw Exception("Input must be a square matrix.");
  }

  int rows = A.length;
  if (rows == 0) return [];
  int cols = A[0].length;

  List<List<double>> resultMatrix = List<List<double>>.generate(rows, (i) => List<double>.generate(cols, (i2) => 0));

  for (int i = 0; i < rows; i++) {
    for (int j = 0; j < cols; j++) {
      resultMatrix[i][j] = A[i][j].abs();
    }
  }
  return resultMatrix;
}

double matrixMax(List<List<double>> A){
  // Handle empty or invalid matrix input
  if (A.isEmpty || A[0].isEmpty) {
    throw Exception('Invalid matrix'); // Or throw an error, depending on desired behavior
  }

  double maxVal = A[0][0]; // Initialize maxVal with the first element

  // Iterate through each row
  for (int i = 0; i < A.length; i++) {
    // Iterate through each element in the current row
    for (int j = 0; j < A[i].length; j++) {
      if (A[i][j] > maxVal) {
        maxVal = A[i][j]; // Update maxVal if a larger element is found
      }
    }
  }

  return maxVal;
}

List<double> bgrToLab(num b, num g, num r) {
  // 1. BGR to RGB (already done by parameter order)
  // 2. Normalize RGB
  double normR = r / 255;
  double normG = g / 255;
  double normB = b / 255;

  // 3. Linearize sRGB
  double linearR = sRGBtoLinearRGB(normR);
  double linearG = sRGBtoLinearRGB(normG);
  double linearB = sRGBtoLinearRGB(normB);

  // 4. Convert Linear RGB to XYZ
  var xyz = linearRGBtoXYZ(linearR, linearG, linearB);

  // 5. Convert XYZ to Lab
  var lab = xyzToLab(xyz[0], xyz[1], xyz[2]); // Renamed 'b' to 'labB' to avoid conflict

  return [lab[0], lab[1], lab[2]];
}

List<double> rgb2lab(num r, num g, num b){
  r = r / 255;
  g = g / 255;
  b = b / 255;
  num x, y, z;

  r = (r > 0.04045) ? math.pow((r + 0.055) / 1.055, 2.4) : r / 12.92;
  g = (g > 0.04045) ? math.pow((g + 0.055) / 1.055, 2.4) : g / 12.92;
  b = (b > 0.04045) ? math.pow((b + 0.055) / 1.055, 2.4) : b / 12.92;

  x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047;
  y = (r * 0.2126 + g * 0.7152 + b * 0.0722) / 1.00000;
  z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883;

  x = (x > 0.008856) ? math.pow(x, 1/3) : (7.787 * x) + 16/116;
  y = (y > 0.008856) ? math.pow(y, 1/3) : (7.787 * y) + 16/116;
  z = (z > 0.008856) ? math.pow(z, 1/3) : (7.787 * z) + 16/116;

  return [(116 * y) - 16, (500 * (x - y)).toDouble(), (200 * (y - z)).toDouble()];
}

List<int> lab2rgb(lab){
  num y = (lab[0] + 16) / 116,
      x = lab[1] / 500 + y,
      z = y - lab[2] / 200,
      r, g, b;

  x = 0.95047 * ((x * x * x > 0.008856) ? x * x * x : (x - 16/116) / 7.787);
  y = 1.00000 * ((y * y * y > 0.008856) ? y * y * y : (y - 16/116) / 7.787);
  z = 1.08883 * ((z * z * z > 0.008856) ? z * z * z : (z - 16/116) / 7.787);

  r = x *  3.2406 + y * -1.5372 + z * -0.4986;
  g = x * -0.9689 + y *  1.8758 + z *  0.0415;
  b = x *  0.0557 + y * -0.2040 + z *  1.0570;

  r = (r > 0.0031308) ? (1.055 * math.pow(r, 1/2.4) - 0.055) : 12.92 * r;
  g = (g > 0.0031308) ? (1.055 * math.pow(g, 1/2.4) - 0.055) : 12.92 * g;
  b = (b > 0.0031308) ? (1.055 * math.pow(b, 1/2.4) - 0.055) : 12.92 * b;

  return [
    (math.max(0, math.min(1, r)) * 255).round(),
    (math.max(0, math.min(1, g)) * 255).round(),
    (math.max(0, math.min(1, b)) * 255).round()
  ];
}

List<List<List<int>>> convertLab2Rgb(List<List<List<double>>> data) {
  print('W:${data[0].length} H:${data.length}');
  return List.generate(data.length, (h) => List.generate(data[0].length, (w) => lab2rgb(data[h][w])));
}

double sRGBtoLinearRGB(color) {
  if (color <= 0.04045) {
    return color / 12.92;
  } else {
    return math.pow((color + 0.055) / 1.055, 2.4).toDouble();
  }
}

List<double> linearRGBtoXYZ(r, g, b) {
  double X = 0.4124 * r + 0.3576 * g + 0.1805 * b;
  double Y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  double Z = 0.0193 * r + 0.1192 * g + 0.9505 * b;
  return [X, Y, Z];
}

List<double> xyzToLab(double X, double Y, double Z) {
  const Xn = 95.047; // D65 reference white
  const Yn = 100.000;
  const Zn = 108.883;

  double fx = X / Xn;
  double fy = Y / Yn;
  double fz = Z / Zn;

  double f(t) => (t > 0.008856 ? cbrt(t) : (t * 903.3) / 100);

  fx = f(fx);
  fy = f(fy);
  fz = f(fz);

  double L = 116 * fy - 16;
  double a = 500 * (fx - fy);
  double labB = 200 * (fy - fz);

  return [L, a, labB];
}

double cbrt(double x){
  if (x == 0 || x == double.infinity || x == -1 / 0 || x != x) {
    return x;
  }
  var a = x.abs();
  var y = math.exp(math.log(a) / 3);
  return (x / a) * (y + (a / (y * y) - y) / 3);
}