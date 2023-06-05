# sigma_rot_helper.lua について

AviUtl の回転系スクリプトに使う自前の四元数計算ライブラリです．AviUtl への使用を前提としてはいますが，AviUtl の機能とは切り離した純粋計算ライブラリです．

忘備録，兼，何かの参考になればとリファレンスとしてまとめておきます．

あと，スクリプトに直接書いていたコメントをもとに文書を作成しており，日本語変換切り替えが面倒だったこともあってリファレンスは全部英語です．


# 使用法

```lua
local sigma_rot_helper = require "sigma_rot_helper";
```

`require` することで `package.loaded.sigma_rot_helper` に登録．戻り値はテーブルで，そこには以下の2つのテーブルが格納されている:

```lua
local quaternion = sigma_rot_helper.quaternion;
local rotation = sigma_rot_helper.rotation;
```
それぞれのテーブルに格納された下記の関数が使える．

`require` の戻り値はグローバル変数には登録していないので注意．


# 各関数のリファレンス

**目次:**

1. [`quaternion` テーブル](#the-table-quaternion)
1. [`rotation` テーブル](#the-table-rotation)


## The table `quaternion`

This table lists some functions related to quaternion arithmetics.
Hereafter, $i$, $j$ and $k$ denote the quaternions consisting the standard basis 
of the purely imaginary part of the quaternion algebra and satisfying the following equalities:

$$
i^2=j^2=k^2=-1;\\
ij=k,\; jk=i,\; ki = j;\\
ji=-k,\; kj=-i,\; ik=-j.
$$

## `a,b,c,d = quaternion.mult(a1,b1,c1,d1, a2,b2,c2,d2)`

Performs the multiplication

$$ a + bi + cj + dk = (a_1 + b_1i + c_1j + d_1k)(a_2 + b_2i + c_2j + d_2k) $$

where all 8 parameters are real numbers.
	
## `a,b,c,d = quaternion.mult_IQ(a1,b1, a2,b2,c2,d2)`

Performs the multiplication

$$ a + bi + cj + dk = (a_1 + b_1i)(a_2 + b_2i + c_2j + d_2k) $$

where all 6 parameters are real numbers. A simplified variant of [`mult()`](#abcd--quaternionmulta1b1c1d1-a2b2c2d2).

## `quaternion.mult_JQ(a1,c1, a2,b2,c2,d2)`, `quaternion.mult_KQ(a1,d1, a2,b2,c2,d2)`

Similar to [`mult_IQ()`](#abcd--quaternionmult_iqa1b1-a2b2c2d2) function,
they are also simplified variants of [`mult()`](#abcd--quaternionmulta1b1c1d1-a2b2c2d2).
	
## `a,b,c,d = quaternion.mult_RQ(a1, a2,b2,c2,d2)`

Returns `a1*a2,a1*b2,a1*c2,a1*d2`. This is equivalent to the multiplication

$$ a + bi + cj + dk = a_1(a_2 + b_2i + c_2j + d_2k). $$ 
	
## `a,b,c,d = quaternion.mult_ImQ(b1,c1,d1, a2,b2,c2,d2)`

Performs the multiplication

$$ a + bi + cj + dk = (b_1i + c_1j + d_1k)(a_2 + b_2i + c_2j + d_2k). $$

Another simplified variant of [`mult()`](#abcd--quaternionmulta1b1c1d1-a2b2c2d2).

## `r = quaternion.abs(a,b,c,d)`

Returns the absolute value of the quaternion $|a+bi+cj+dk| = (a^2+b^2+c^2+d^2)^{\tfrac12}$.

## `n = quaternion.abs_square(a,b,c,d)`

Returns the square of the absolute value of the quaternion $|a+bi+cj+dk|^2$.
Has the higher performance than [`abs()`](#r--quaternionabsabcd) function.

## `A,B,C,D = reciprocal(a,b,c,d)`

Returns four `number`s representing the reciprocal quaternion $(a+bi+cj+dk)^{-1}$;

$$ (a+bi+cj+dk)(A+Bi+Cj+Dk) = (A+Bi+Cj+Dk)(a+bi+cj+dk) = 1. $$


## The table `rotation`

This table lists useful functions related to 3-dimensional vector rotations,
where a *rotation* is a transform represented by an element of $\mathrm{SO}(3, \mathbb{R})$.

## `a,b,c,d = rotation.euler2quat(angleX, angleY, angleZ)`

Converts a rotation represented by Euler angles into a quaternion that represent the same rotation,
where *Euler angles* shall represent the rotation by:

$$
\begin{pmatrix} x \\
y \\
z \end{pmatrix}\mapsto
\begin{pmatrix} 1 \\
& \cos\theta_X & -\sin\theta_X \\
& \sin\theta_X & \cos\theta_X \end{pmatrix}
\begin{pmatrix} \cos\theta_Y && \sin\theta_Y \\
& 1 \\
-\sin\theta_Y && \cos\theta_Y \end{pmatrix}
\begin{pmatrix} \cos\theta_Z & -\sin\theta_Z \\
\sin\theta_Z & \cos\theta_Z \\
&& 1 \end{pmatrix}
\begin{pmatrix} x \\
y \\
z \end{pmatrix}
$$

where $\theta_X$, $\theta_Y$ and $\theta_Z$ represent `angleX`, `angleY` and `angleZ` respectively,
and a quaternion $q$ shall represent a rotation by:

$$
\begin{pmatrix} x \\
y \\
z \end{pmatrix}\mapsto \begin{pmatrix} X \\
Y \\
Z \end{pmatrix}
\quad\text{where}\quad Xi+Yj+Zk = q (xi+yj+zk)q^{-1}.
$$

The returned quaternion is normalized; i.e. the absolute value is $1$.

## `angleX,angleY,angleZ = rotation.quat2euler(a,b,c,d)`

Converts a quaternion into Euler angles whose rotation is equivalent to
the given quaternion.

## ``a,b,c,d = rotation.quat_from_rot(angle, axisX, axisY, axisZ)``

Constructs a quaternion that represent the rotation with a given axis
and an angle. The vector `(axisX, axisY, axisZ)` defines the axis of the rotation.

## `a,b,c,d = rotation.quat_from_rot1(angle, axisX, axisY, axisZ)`

Same as [`quat_from_rot()`](#abcd--rotationquat_from_rotangle-axisx-axisy-axisz)
with less overhead of performance and an additional requirement
that the vector `(axisX, axisY, axisZ)` must be normalized.

## `a11,a12,a13,a21,a22,a23,a31,a32,a33 = rotation.quat2matrix(a,b,c,d)`

Converts a rotation represented by a quaternion into a matrix representation.
The returned values represent the following matrix,
where vectors are represented by column vectors and multiplied from right of this matrix:

$$
\begin{pmatrix}
a_{11} & a_{12} & a_{13} \\
a_{21} & a_{22} & a_{23} \\
a_{31} & a_{32} & a_{33}
\end{pmatrix}.
$$

## `a11,a12,a13,a21,a22,a23,a31,a32,a33 = rotation.euler2matrix(angleX, angleY, angleZ)`

Converts a rotation represented by Euler angles into a matrix representation.

## `X,Y,Z = rotation.rotate_quat(x,y,z, a,b,c,d)`

Applies a rotation represented by the quaternion $a+bi+cj+dk$ to the vector
$^t(x\,y\,z)$, and returns three `number`s representing the resulting vector $^t(X\,Y\,Z)$.

## `X,Y,Z = rotation.rotate_quat1(x,y,z, a,b,c,d)`

Applies a rotation represented by the quaternion $a+bi+cj+dk$ to the vector
$^t(x\,y\,z)$, and returns three `number`s representing the resulting vector $^t(X\,Y\,Z)$.
Less overhead than [`rotate_quat()`](#xyz--rotationrotate_quatxyz-abcd),
but the given quaternion must be normalized;
i.e. $a^2+b^2+c^2+d^2$ must be $1$.

## `X,Y,Z = rotation.rotate_euler(x,y,z, angleX, angleY, angleZ [, invert])`

Applies a rotation represented by Euler angles to the vector.
If the optional boolean `invert` is `true`, it applies the inverse transform instead.

## `X,Y,Z = rotation.transform_matrix(x,y,z, a11,a12,a13,a21,a22,a23,a31,a32,a33)`

Applies a linear transform defined by the following formula:

$$
\begin{pmatrix} X \\
Y \\
Z \end{pmatrix}=
\begin{pmatrix}
a_{11} & a_{12} & a_{13} \\
a_{21} & a_{22} & a_{23} \\
a_{31} & a_{32} & a_{33}
\end{pmatrix}
\begin{pmatrix} x \\
y \\
z \end{pmatrix}.
$$

## `func = rotation.rotate_func_matrix(a11,a12,a13,a21,a22,a23,a31,a32,a33)`

Returns a `function` that transforms a vector
with the inear transform defined by the formula above.
Returned `function` is: `X,Y,Z = func(x,y,z)`.

## `func = rotation.rotate_func_quat(a,b,c,d)`

Returns a `function` that transforms a vector into the rotated vector
with the rotation specified by the quaternion $a+bi+cj+dk$.
Returned `function` is: `X,Y,Z = func(x,y,z)`.

## `func = rotation.rotate_func_quat1(a,b,c,d)`

Equivalent to [`rotate_func_quat()`](#func--rotationrotate_func_quatabcd),
with less overhead of performance and an additional requirement
that the given quaternion must be normalized;
i.e. $a^2+b^2+c^2+d^2$ must be $1$.

## `func = rotation.rotate_func_euler(angleX, angleY, angleZ)`

Returns a `function` that transforms a vector into the rotated vector
with the rotation specified by Euler angles.
Returned `function` is: `X,Y,Z = func(x,y,z)`.


# ライセンス・免責事項

このプログラムの利用・改変・再頒布等に関しては MIT ライセンスに従うものとします．

---

 The MIT License (MIT)

Copyright (C) 2023 sigma_axis

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

https://mit-license.org/


# Credits

## Lua 5.1

Copyright (C) 1994-2012 Lua.org, PUC-Rio.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

https://www.lua.org/


#	改版履歴

## v1.0.0 2023-06-??

- とりあえず公開．




