// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// SharedOptions=--enable-experiment=sealed-class

// Error when we try to construct a sealed class or mixin because they should
// both be implicitly abstract.

sealed class NotConstructable {}

sealed mixin AlsoNotConstructable {}

mixin M {}
sealed class NotConstructableWithMixin = Object with M;

main() {
  var error = NotConstructable();
  //          ^
  // [cfe] The class 'NotConstructable' is abstract and can't be instantiated.
  var error2 = AlsoNotConstructable();
  //           ^^^^^^^^^^^^^^^^^^^^
  // [analyzer] COMPILE_TIME_ERROR.MIXIN_INSTANTIATE
  // [cfe] Couldn't find constructor 'AlsoNotConstructable'.
  var error3 = NotConstructableWithMixin();
  //           ^
  // [cfe] The class 'NotConstructableWithMixin' is abstract and can't be instantiated.
}
