/*
Collection of linear algebra functions for vectors with 3 elements and 4x4 matrices.
Useful for 3D calculations.
*/

var m4x4mulv3, newv3, tmpVec, v3diffLength, v3dotv3, v3length;

tmpVec = new Array(3);

newv3 = function() {
  return new Array(3);
};

/*
Caluculates the dot product of a and b,
where a and b are vectors with 3 elements.
*/


v3dotv3 = function(a, b) {
  return (a[0] * b[0]) + (a[1] * b[1]) + (a[2] * b[2]);
};

v3length = function(v) {
  return Math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
};

v3diffLength = function(v1, v2) {
  var v;
  v = newv3();
  v[0] = v2[0] - v1[0];
  v[1] = v2[1] - v1[1];
  v[2] = v2[2] - v1[2];
  return v3length(v);
};

/*
r = m * v

m: 4x4 matrix
v: vector with 3 elements
r: vetor with 3 elements to store results
*/


m4x4mulv3 = function(m, v, r) {
  var w;
  tmpVec[0] = m[3];
  tmpVec[1] = m[7];
  tmpVec[2] = m[11];
  w = v3dotv3(v, tmpVec) + m[15];
  tmpVec[0] = m[0];
  tmpVec[1] = m[4];
  tmpVec[2] = m[8];
  r[0] = (v3dotv3(v, tmpVec) + m[12]) / w;
  tmpVec[0] = m[1];
  tmpVec[1] = m[5];
  tmpVec[2] = m[9];
  r[1] = (v3dotv3(v, tmpVec) + m[13]) / w;
  tmpVec[0] = m[2];
  tmpVec[1] = m[6];
  tmpVec[2] = m[10];
  return r[2] = (v3dotv3(v, tmpVec) + m[14]) / w;
};