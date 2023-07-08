--[[
The MIT License (MIT)
Copyright (C) 2023 sigma_axis

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

https://mit-license.org/
]]
local VERSION = "v1.0.0";

local cos,sin,atan2 = math.cos,math.sin,math.atan2;

--------------------------------------------------------------------------------
-- arithmetic operations of quaternions
--------------------------------------------------------------------------------
local function mult_qq(a,b,c,d, A,B,C,D)
	-- performs the multiplication (a+bi+cj+dk)(A+Bi+Cj+Dk) of two quaternions
	return a*A-b*B-c*C-d*D,
		a*B+b*A+c*D-d*C,
		a*C+c*A-b*D+d*B,
		a*D+d*A+b*C-c*B;
end
local function mult_c1q(a,b, A,B,C,D)
	-- performs the multiplication (a+bi)(A+Bi+Cj+Dk) of a complex number and a quaternion
	return a*A-b*B,a*B+b*A,a*C-b*D,a*D+b*C;
end
local function mult_c2q(a,c, A,B,C,D)
	-- performs the multiplication (a+cj)(A+Bi+Cj+Dk) of a complex number and a quaternion
	return a*A-c*C,a*B+c*D,a*C+c*A,a*D-c*B;
end
local function mult_c3q(a,d, A,B,C,D)
	-- performs the multiplication (a+dk)(A+Bi+Cj+Dk) of a complex number and a quaternion
	return a*A-d*D,a*B-d*C,a*C+d*B,a*D+d*A;
end
local function mult_c2c3(a,c, A,D)
	-- performs the multiplication (a+cj)(A+Dk) of a j-complex and a k-complex numbers, under the quaternion algebra
	return a*A,c*D,c*A,a*D;
end
local function mult_rq(a, A,B,C,D)
	-- performs the multiplication a(A+Bi+Cj+Dk) of a real number and a quaternion
	return a*A,a*B,a*C,a*D;
end
local function mult_imq(b,c,d, A,B,C,D)
	-- performs the multiplication (bi+cj+dk)(A+Bi+Cj+Dk) of a purely imaginary number and a quaternion
	return -b*B-c*C-d*D,
		b*A+c*D-d*C,
		c*A-b*D+d*B,
		d*A+b*C-c*B;
end
local function norm_q(a,b,c,d) return a^2+b^2+c^2+d^2 end
local function abs_q(a,b,c,d) return norm_q(a,b,c,d)^.5 end

--------------------------------------------------------------------------------
-- conversions between quaternions and euler angles
--------------------------------------------------------------------------------
local function rot2quat(angleX, angleY, angleZ)
	return mult_c1q(
			cos(angleX/2),sin(angleX/2), mult_c2c3(
			cos(angleY/2),sin(angleY/2),
			cos(angleZ/2),sin(angleZ/2)
		));
end

local function quat2rot_find_angle(x1,y1, x2,y2)
	if x1^2 + y1^2 < x2^2 + y2^2 then x1,y1 = x2,y2 end
	if x1 < 0 then x1,y1 = -x1,-y1 end
	return 2*atan2(y1,x1);
end
local function quat2rot(a,b,c,d)
	-- tan(angleX) = 2(ab-cd)/(a^2-b^2-c^2+d^2)
	local angleX = atan2(2*(a*b - c*d), a^2 - b^2 - c^2 + d^2);
	-- note that atan2(0,0) returns zero.

	-- now we have a quaternion that can be represented by only rotations of Y and Z axes
	a,b,c,d = mult_c1q(cos(angleX/2),-sin(angleX/2), a,b,c,d);

	return angleX, quat2rot_find_angle(a,c, d,b), quat2rot_find_angle(a,d, c,b);
end
local function quat_from_angle_axis1(angle, axisX, axisY, axisZ)
	local s = sin(angle/2);
	return cos(angle/2), s*axisX, s*axisY, s*axisZ;
end
local function quat_from_angle_axis(angle, axisX, axisY, axisZ)
	local t = (axisX^2+axisY^2+axisZ^2)^-.5;
	return quat_from_angle_axis1(angle, t*axisX,t*axisY,t*axisZ);
end

--------------------------------------------------------------------------------
-- conversions from quaternions and euler angles to matrices
--------------------------------------------------------------------------------
local function quat2matrix(a,b,c,d)
	local A,B,C,D = a^2,b^2,c^2,d^2;
	local bc,cd,db = 2*b*c,2*c*d,2*d*b;
	local ab,ac,ad = 2*a*b,2*a*c,2*a*d;
	return	A+B-C-D, bc - ad, db + ac,
			bc + ad, A-B+C-D, cd - ab,
			db - ac, cd + ab, A-B-C+D;
end
local function rot2matrix(angleX,angleY,angleZ)
	local cx,sx, cy,sy, cz,sz =
		cos(angleX),sin(angleX), cos(angleY),sin(angleY), cos(angleZ),sin(angleZ);

	return		cy*cz,			 -cy*sz,	 sy,
	 sx*sy*cz + cx*sz, cx*cz - sx*sy*sz, -sx*cy,
	-cx*sy*cz + sx*sz, sx*cz + cx*sy*sz,  cx*cy;
end

--------------------------------------------------------------------------------
-- rotating vectors
--------------------------------------------------------------------------------
local function apply_quat(x,y,z, a,b,c,d)
	local n = norm_q(a,b,c,d);
	n,x,y,z = mult_rq(1/n,mult_qq(a,b,c,d,mult_imq(x,y,z,a,-b,-c,-d)));
	return x,y,z;
end
local function apply_quat_n(x,y,z, a,b,c,d)
	local _;
	_,x,y,z = mult_qq(a,b,c,d,mult_imq(x,y,z,a,-b,-c,-d));
	return x,y,z;
end
local function apply_rot_1angle(x,y,a)
	local c,s = cos(a),sin(a);
	return c*x-s*y,s*x+c*y;
end
local function apply_rot(x,y,z, ax,ay,az)
	x,y = apply_rot_1angle(x,y,az);
	z,x = apply_rot_1angle(z,x,ay);
	return x,apply_rot_1angle(y,z,ax);
end
local function apply_rot_inv(x,y,z, ax,ay,az)
	z,y,x = apply_rot(z,y,x, az,ay,ax)
	return x,y,z;
end
local function apply_matrix(x,y,z, a11,a12,a13,a21,a22,a23,a31,a32,a33)
	return
		a11*x + a12*y + a13*z,
		a21*x + a22*y + a23*z,
		a31*x + a32*y + a33*z;
end

--------------------------------------------------------------------------------
-- function creating functions
--------------------------------------------------------------------------------
local function rotfunc_matrix(a11,a12,a13,a21,a22,a23,a31,a32,a33)
	return function(x,y,z) return
		a11*x + a12*y + a13*z,
		a21*x + a22*y + a23*z,
		a31*x + a32*y + a33*z;
	end
end
local function rotfunc_euler(angleX, angleY, angleZ)
	-- local cx,sx, cy,sy, cz,sz =
	-- 	cos(angleX),sin(angleX), cos(angleY),sin(angleY), cos(angleZ),sin(angleZ);

	-- return rotfunc_matrix(
	-- 				cy*cz,           -cy*sz,     sy,
	-- 	 sx*sy*cz + cx*sz, cx*cz - sx*sy*sz, -sx*cy,
	-- 	-cx*sy*cz + sx*sz, sx*cz + cx*sy*sz,  cx*cy);
	-- return function(x,y,z)
	-- 	x,y = cz*x-sz*y, sz*x+cz*y;
	-- 	z,x = cy*z-sy*x, sy*z+cy*x;
	-- 	y,z = cx*y-sx*z, sx*y+cx*z;
	-- 	return x,y,z;
	-- end
	return rotfunc_matrix(rot2matrix(angleX,angleY,angleZ));
end
local function rotfunc_quat1(a,b,c,d)
	-- local A,B,C,D = a^2,b^2,c^2,d^2;
	-- local bc,cd,db = 2*b*c,2*c*d,2*d*b;
	-- local ab,ac,ad = 2*a*b,2*a*c,2*a*d;
	-- return rotfunc_matrix(
	-- 	A+B-C-D, bc - ad, db + ac,
	-- 	bc + ad, A-B+C-D, cd - ab,
	-- 	db - ac, cd + ab, A-B-C+D);
	return rotfunc_matrix(quat2matrix(a,b,c,d));
end
local function rotfunc_quat(a,b,c,d)
	local n = abs_q(a,b,c,d);
	return rotfunc_quat1(a/n,b/n,c/n,d/n);
end

return {
	quaternion = {
		mult = mult_qq;
		mult_IQ = mult_c1q;
		mult_JQ = mult_c2q;
		mult_KQ = mult_c3q;
		mult_JK = mult_c2c3;
		mult_RQ = mult_rq;
		mult_ImQ = mult_imq;

		abs = abs_q;
		abs_square = norm_q;

		reciprocal = function(a,b,c,d)
			return mult_rq(1/norm_q(a,b,c,d),a,-b,-c,-d)
		end;
	};
	rotation = {
		euler2quat = rot2quat;
		quat2euler = quat2rot;
		quat_from_rot = quat_from_angle_axis;
		quat_from_rot1 = quat_from_angle_axis1;

		quat2matrix = quat2matrix,
		euler2matrix = rot2matrix,

		rotate_quat = apply_quat;
		rotate_quat1 = apply_quat_n;
		rotate_euler = function(x,y,z, ax,ay,az, invert)
			return (invert and apply_rot_inv or apply_rot)(x,y,z, ax,ay,az);
		end;
		transform_matrix = apply_matrix,

		rotate_func_matrix = rotfunc_matrix,
		rotate_func_quat = rotfunc_quat;
		rotate_func_quat1 = rotfunc_quat1;
		rotate_func_euler = rotfunc_euler;
	};

	VERSION = VERSION,
};
