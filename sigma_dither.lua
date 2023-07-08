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

-- -- ディザリングのランダムパターンの固定乱数シード．可能な範囲は 0 〜 2^31-1.
-- local dither_pattern_random_seed = 37564;

local math = math;
local slib = require "sigma_lib";
local obj = assert(obj);
local ffi do
	local c; c,ffi = pcall(require, "ffi");
	if not c then
		c = ffi; ffi = nil;
		debug_print(c);
		debug_print("ffiライブラリが見つかりませんでした．LuaJITの導入を推奨します．");

		local function ffi_absent()
			obj.setfont("ms ui gothic",34,3,0xffffff,0);
			obj.load("text", [[この機能を利用するには LuaJIT が必要です．]]);
		end
		return setmetatable({},{__index=function(_,_)return ffi_absent end});
	end
end
local band, bor, bnot, bxor, lshift, rshift;
if (package.loaded.bit or pcall(require,"bit")) and bit then
	band, bor, bnot, bxor, lshift, rshift
		= bit.band, bit.bor, bit.bnot, bit.bxor, bit.lshift, bit.rshift;
else
	band, bor, bnot, bxor, lshift
		= AND, OR, function(n) return -1-n end, XOR, SHIFT;
	rshift = function(n,b) return lshift(n%2^32,-b) end
end
local function invert_opacity() return obj.effect("反転","透明度反転",1) end

-- array to tables { size = size, load = function([threshold,invert,cont], seed) } where
-- size is the width and the height of the image of the unit of the pattern,
-- load is a function that loads the dithering pattern with up to four parameters.
-- threshold is a number with 0 < threshold < 1, invert and cont are booleans,
-- and seed is the random seed for the "dynamic random pattern".
-- load can also be called without the first three arguments to load the "raw" alpha values.
local dither_patterns do
	local MAX_SIZE_DITHER_PATTERN = 16;
	local function buffer_dest()
		local w,h = obj.getpixel();
		if w ~= MAX_SIZE_DITHER_PATTERN or h ~= MAX_SIZE_DITHER_PATTERN then
			obj.load("figure","四角形",0,MAX_SIZE_DITHER_PATTERN);
		end
		local buffer = obj.getpixeldata("alloc","work");
		buffer_dest = function() return buffer end;
		return buffer;
	end
	local function buffer_dest_pbyte()
		local ptr = ffi.cast("uint8_t*",buffer_dest());
		buffer_dest_pbyte = function() return ptr end
		return ptr;
	end

	local bias_and_load do
		local map = ffi.new("uint8_t[256]");
		-- discrete
		local function binarize_disc(threshold,invert,ubd)
			ffi.fill(map,threshold, invert and 0xff or 0);
			ffi.fill(map+threshold,ubd-threshold, invert and 0 or 0xff);
		end
		-- continuous
		local function binarize_cont(midvalue,midfrac,invert,ubd)
			ffi.fill(map,midvalue, invert and 0xff or 0);
			map[midvalue] = math.min(0xff,
				256*(invert and 1-midfrac or midfrac));
			ffi.fill(map+midvalue+1,ubd-midvalue-1, invert and 0 or 0xff);
		end
		-- scaling alpha
		local function normalize(ubd)
			local scale = 256/ubd; local shift = math.floor(scale/2);
			for i=0,ubd-1 do map[i] = scale*i + shift end
		end
		function bias_and_load(buffer,size, threshold, invert, ubd, cont)
			if cont == nil then normalize(ubd);
			elseif cont == true then
				local mv,mf = math.modf(ubd*threshold);
				if mv >= ubd then mv,mf = ubd-1,1 end
				binarize_cont(mv,1-mf,invert,ubd);
			else
				binarize_disc(1+math.floor((ubd-1)*threshold),invert,ubd);
			end

			local ptr = buffer_dest_pbyte();
			for i=0,size*size-1 do ptr[4*i+3] = map[buffer[i]] end

			local w,h = obj.getpixel();
			if w ~= size or h ~= size then obj.load("figure","四角形",0,size) end
			obj.putpixeldata(buffer_dest());
		end
	end

	-- bayer patterns
	local load_bayer_pattern_2x2,load_bayer_pattern_4x4,load_bayer_pattern_8x8,load_bayer_pattern_16x16 do
		local bayer_pattern_2x2, bayer_pattern_4x4, bayer_pattern_8x8, bayer_pattern_16x16 do
			local function bayer_value(x,y)
				local v,pow = 0,1;
				while x ~= 0 or y ~= 0 do
					pow = 0.25*pow;
					v = v + pow * (band(x,1) + 2*band(bxor(x,y),1));
					y, x = rshift(x,1), rshift(y,1);
				end
				return v;
			end
			local function bayer_pattern(n)
				local pattern = ffi.new("uint8_t[?]",n^2);
				for y=0,n-1 do for x=0,n-1 do
					pattern[x+n*y] = math.min(255, 0.5 + n^2*bayer_value(x,y));
				end end
				return pattern;
			end

			function bayer_pattern_2x2()
				local pattern = bayer_pattern(2);
				bayer_pattern_2x2 = function() return pattern end;
				return pattern;
			end
			function bayer_pattern_4x4()
				local pattern = bayer_pattern(4);
				bayer_pattern_4x4 = function() return pattern end;
				return pattern;
			end
			function bayer_pattern_8x8()
				local pattern = bayer_pattern(8);
				bayer_pattern_8x8 = function() return pattern end;
				return pattern;
			end
			function bayer_pattern_16x16()
				local pattern = bayer_pattern(16);
				bayer_pattern_16x16 = function() return pattern end;
				return pattern;
			end
		end
		function load_bayer_pattern_2x2(threshold,invert,cont,_)
			bias_and_load(bayer_pattern_2x2(),2, threshold, invert, 4, cont);
		end
		function load_bayer_pattern_4x4(threshold,invert,cont,_)
			bias_and_load(bayer_pattern_4x4(),4, threshold, invert, 16, cont);
		end
		function load_bayer_pattern_8x8(threshold,invert,cont,_)
			bias_and_load(bayer_pattern_8x8(),8, threshold, invert, 64, cont);
		end
		function load_bayer_pattern_16x16(threshold,invert,cont,_)
			bias_and_load(bayer_pattern_16x16(),16, threshold, invert, 256, cont);
		end
	end

	-- checker patterns
	local load_checker_pattern_16x16, load_checker_pattern2_16x16 do
		local checker_pattern,equalize_threshold,equalize_alpha do
			-- 16 values; 0 to 15
			local function checker_value(x,y)
				if (x+y)%2 == 1 then return 15-checker_value(x+7,y+8) end
				x,y = x+16,y+16;
				x = band(x,-x); y = band(y,-y); -- the lowest nonzero bits
				if x == y then
					if x >= 16 then return 0;
					elseif x >= 8 then return 1;
					elseif x >= 4 then return 3;
					elseif x >= 2 then return 5;
					else return 7 end
				else
					x = math.min(x,y);
					if x >= 8 then return 2;
					elseif x >= 4 then return 4;
					else return 6 end
				end
			end
			function equalize_threshold(x)
				if x > 0.5 then return 1-equalize_threshold(1-x) end
				local m,e = math.frexp(x);
				if e <= -8 or m <= 0 then m,e = 256*x,-8; -- when x < 2^-8
				else m = 2*m-1 end
				return (m+e+8)/16;
			end
			local function unequalize_threshold(x) -- the inverse of the above function
				if x > 0.5 then return 1-unequalize_threshold(1-x) end
				local e,m = math.modf(16*x);
				if e > 0 then m = (m+1)/2 end
				return m*2^(e-8);
			end

			function checker_pattern()
				local pattern = ffi.new("uint8_t[256]");
				for y=0,15 do for x=0,15 do
					pattern[x+16*y] = checker_value(x,y);
				end end
				checker_pattern = function() return pattern end;
				return pattern;
			end
			function equalize_alpha(...)
				local array = ffi.new("uint8_t[16]");
				for i=0,7 do
					array[i] = 0.5+255*unequalize_threshold(i/15);
					array[15-i] = 255-array[i];
				end
				equalize_alpha = function(buffer)
					local ptr = buffer_dest_pbyte();
					for i=0,255 do ptr[4*i+3] = array[buffer[i]] end
				end
				equalize_alpha(...);
			end
		end
		function load_checker_pattern_16x16(threshold,invert,cont,_)
			bias_and_load(checker_pattern(),16,threshold, invert, 16, cont);
		end
		function load_checker_pattern2_16x16(threshold,invert,cont,_)
			-- "equalize" the threshold
			if cont == nil then
				equalize_alpha(checker_pattern());

				local w,h = obj.getpixel();
				if w ~= 16 or h ~= 16 then obj.load("figure","四角形",0,16) end
				obj.putpixeldata(buffer_dest());
			else
				bias_and_load(checker_pattern(),16, equalize_threshold(threshold), invert, 16, cont);
			end
		end
	end

	-- random pattern
	local someprime = 5791;
	-- local load_random_pattern_16x16 do
	-- 	local random_pattern do
	-- 		local seed = -math.abs(dither_pattern_random_seed)-1;
	-- 		local rand = obj.rand;
	-- 		local function rng(N,i) return math.floor(rand(0,someprime*N-1,seed,i+1)/someprime) end

	-- 		function random_pattern()
	-- 			local pattern = ffi.new("uint8_t[256]");
	-- 			pattern[0] = 0;
	-- 			for i=1,255 do
	-- 				local j = rng(i+1,i);
	-- 				if j<i then pattern[i] = pattern[j] end
	-- 				pattern[j] = i;
	-- 			end
	-- 			random_pattern = function() return pattern end;
	-- 			return pattern;
	-- 		end
	-- 	end
	-- 	function load_random_pattern_16x16(threshold,invert,cont,_)
	-- 		bias_and_load(random_pattern(),16, threshold, invert, 256, cont);
	-- 	end
	-- end

	-- dynamic random pattern
	local load_dyn_rand_pattern_16x16 do
		local dyn_rand_pattern_16x16 do
			local rand = obj.rand;
			local function rng(seed,N,i) return math.floor(rand(0,someprime*N-1,seed,i+1)/someprime) end

			function dyn_rand_pattern_16x16(...)
				local buffer = ffi.new("uint8_t[256]");
				dyn_rand_pattern_16x16 = function(seed)
					buffer[0] = 0;
					for i=1,255 do
						local j = rng(seed,i+1,i);
						if j<i then buffer[i] = buffer[j] end
						buffer[j] = i;
					end
					return buffer;
				end
				return dyn_rand_pattern_16x16(...);
			end
		end
		function load_dyn_rand_pattern_16x16(threshold,invert,cont,seed)
			if cont == nil then threshold,seed = nil,threshold end
			bias_and_load(dyn_rand_pattern_16x16(seed),16, threshold, invert, 256, cont);
		end
	end

	dither_patterns = {
		{ size =  2, load = load_bayer_pattern_2x2 },
		{ size =  4, load = load_bayer_pattern_4x4 },
		{ size =  8, load = load_bayer_pattern_8x8 },
		{ size = 16, load = load_bayer_pattern_16x16 },
		{ size = 16, load = load_checker_pattern_16x16 },
		{ size = 16, load = load_checker_pattern2_16x16 },
		-- { size = 16, load = load_random_pattern_16x16 },
		{ size = 16, load = load_dyn_rand_pattern_16x16 },
	};
end
local function image_loop(n_h,n_v)
	if n_h < 400 and n_v < 400 then
		obj.effect("画像ループ", "横回数",n_h, "縦回数",n_v);
		return;
	end

	local w,h = obj.getpixel();
	local n2_h,n2_v = math.ceil(n_h/400),math.ceil(n_v/400);
	image_loop(n2_h, n2_v);

	local n3_h,n3_v = math.ceil(n_h/n2_h),math.ceil(n_v/n2_v);
	image_loop(n3_h, n3_v);

	obj.effect("クリッピング","右",w*(n2_h*n3_h-n_h),"下",h*(n2_v*n3_v-n_v));
end

local function dither_mask(pattern, seed, continuous, intensity, invert,
	size, aspect, offset_x, offset_y, offset_abs)

	local posinfo, x,y, w,h = slib.posinfo_save(), obj.x,obj.y, obj.getpixel();
	obj.copybuffer("tmp","obj");
	obj.setoption("dst","tmp");

	dither_patterns[pattern].load(intensity, not invert, continuous, seed);

	local W,H = obj.getpixel();
	if size > 1 then
		local szx,szy = slib.size_aspect_to_len(size,aspect);
		szx,szy = math.max(1,math.floor(0.5+szx)),math.max(1,math.floor(0.5+szy));
		W,H = W*szx,H*szy;
		obj.effect("リサイズ","ドット数でサイズ指定",1,"補間なし",1, "X",W, "Y",H);
	end

	-- multiply the pattern to span the entire original image
	if offset_abs then
		offset_x = offset_x-x-posinfo.ox+posinfo.cx;
		offset_y = offset_y-y-posinfo.oy+posinfo.cy;
	end
	local L,T,R,B = math.floor((-w/2-offset_x)/W),math.floor((-h/2-offset_y)/H),
		math.ceil((w/2-offset_x)/W),math.ceil((h/2-offset_y)/H);

	-- make sure that the looped image does not exceed the maximum size.
	local max_w, max_h = obj.getinfo("image_max");
	local n_h,n_v = math.ceil((R-L)/math.ceil((R-L)*W/max_w)),
		math.ceil((B-T)/math.ceil((B-T)*H/max_h));
	image_loop(n_h,n_v);

	-- apply the filter
	obj.setoption("blend","alpha_sub");
	for i=L,R-1,n_h do
		local x1 = (i+n_h/2)*W + offset_x;
		for j=T,B-1,n_v do
			local y1 = (j+n_v/2)*H + offset_y;
			obj.draw(x1,y1);
		end
	end
	obj.setoption("blend",0);

	-- load the resulting image
	obj.copybuffer("obj","tmp");
	slib.posinfo_load(posinfo);
end
local function call_mask(pattern, seed, continuous, intensity, invert,
	size, aspect, offset_x, offset_y, offset_abs)
	--track0:強さ,0,100,0
	--track1:サイズ,1,200,3,1
	--track2:Xずれ,-1600,1600,0,1
	--track3:Yずれ,-1600,1600,0,1
	--check0:位置調整を画面基準に,0
	--dialog:パターン (1〜7),_1=4;└(7)のシード,_2=123;半透明を許可/chk,_3=0;縦横比,_4=0;反転/chk,_5=0;TRACK,_0=nil;
	pattern = slib.coerce_int(pattern, 3, 1,#dither_patterns);
	seed = slib.coerce_int(seed,123, -0x80000000,0x7fffffff);
	intensity = slib.coerce_real(intensity,0, 0,1);
	size = slib.coerce_int(size,3, 1,200);
	aspect = slib.coerce_real(aspect,0, -1,1);
	offset_x = slib.coerce_int(offset_x,0);
	offset_y = slib.coerce_int(offset_y,0);

	if intensity <= 0 or intensity >= 1 then
		if intensity > 0 then slib.force_transparent() end
		return;
	end

	dither_mask(pattern, seed, continuous, invert and 1-intensity or intensity, invert,
		size, aspect, offset_x, offset_y, offset_abs);
end

local function call_fade(in_time, out_time, pattern,seed, continuous, invert,
	size, aspect, offset_x, offset_y, offset_abs)
	--track0:イン,0,10,0.50,0.01
	--track1:アウト,0,10,0.50,0.01
	--track2:サイズ,1,200,3,1
	--track3:縦横比,-100,100,0,0.01
	--check0:位置調整を画面基準に,0
	--dialog:パターン (1〜7),_1=4;└(7)のシード,_2=123;Xずれ,_3=0;Yずれ,_4=0;半透明を許可/chk,_5=0;反転/chk,_6=0;TRACK,_0=nil;
	in_time = slib.coerce_real(in_time,0.5, 0,10);
	out_time = slib.coerce_real(out_time,0.5, 0,10);
	pattern = slib.coerce_int(pattern, 3, 1,#dither_patterns);
	seed = slib.coerce_int(seed,123, -0x80000000,0x7fffffff);
	size = slib.coerce_int(size,3, 1,200);
	aspect = slib.coerce_real(aspect,0, -1,1);
	offset_x = slib.coerce_int(offset_x,0);
	offset_y = slib.coerce_int(offset_y,0);

	local opacity = 1 do
		local t,T,h = obj.time,obj.totaltime,1/obj.framerate;
		if t < in_time then opacity = math.min(opacity,(t+h)/(in_time+h)) end
		if T-t < out_time then opacity = math.min(opacity,(T-t+h)/(out_time+h)) end
	end

	if opacity >= 1 then return end
	dither_mask(pattern, seed, continuous, invert and opacity or 1-opacity, invert,
		size, aspect, offset_x, offset_y, offset_abs);
end

local function mosaic_preprocess(pattern_size, mosaic,interpolate, size,aspect, offset_x,offset_y,offset_abs)
	local size_h,size_v = slib.size_aspect_to_len(size,aspect);
	size_h,size_v = math.max(1,math.floor(0.5+size_h)),math.max(1,math.floor(0.5+size_v));

	local W,H;	-- the width and the height of the unit of the pattern
	W = pattern_size > 0 and pattern_size or 1;
	W,H = W*size_h,W*size_v

	if offset_abs then
		offset_x = math.floor(0.5+offset_x-obj.x-obj.ox+obj.cx);
		offset_y = math.floor(0.5+offset_y-obj.y-obj.oy+obj.cy);
	end
	local w,h = obj.getpixel(); local w2,h2 = math.floor(w/2),math.floor(h/2);
	local L,T,R,B = math.floor(-(w2+offset_x)/W),math.floor(-(h2+offset_y)/H),
		math.ceil((w-w2-offset_x)/W),math.ceil((h-h2-offset_y)/H);
	local l,t,r,b = offset_x+W*L, offset_y+H*T, offset_x+W*R, offset_y+H*B;

	-- make sure the looped image does not exceed the size limit.
	local max_w,max_h = obj.getinfo("image_max");
	local loop_h,loop_v = math.ceil((R-L)/math.ceil((R-L)*W/max_w)),
		math.ceil((B-T)/math.ceil((B-T)*H/max_h));
	offset_x,offset_y = offset_x-(w/2-w2), offset_y-(h/2-h2);

	local ex_l,ex_r,ex_t,ex_b;
	if mosaic and size > 1 then
		ex_l,ex_r,ex_t,ex_b = (-w2-l)%size_h,(r-w+w2)%size_h,(-h2-t)%size_v,(b-h+h2)%size_v;
		if ex_l > 0 or ex_r > 0 or ex_t > 0 or ex_b > 0 then
			obj.effect("領域拡張","上",ex_t,"下",ex_b,"左",ex_l,"右",ex_r,"塗りつぶし",1);
		end
		obj.effect("リサイズ","ドット数でサイズ指定",1, "補間なし",interpolate and 0 or 1,
			"X",(w+ex_l+ex_r)/size_h, "Y",(h+ex_t+ex_b)/size_v);
		offset_x = (offset_x+(ex_l-ex_r)/2)/size_h;
		offset_y = (offset_y+(ex_t-ex_b)/2)/size_v;
	else ex_l,ex_r,ex_t,ex_b = 0,0,0,0 end

	return offset_x,offset_y, loop_h,L,R,loop_v,T,B, size_h,size_v, ex_l,ex_r,ex_t,ex_b;
end
local function mosaic_postprocess(mosaic, interpolate, size_h,size_v, ex_l,ex_r,ex_t,ex_b)
	if not mosaic or (size_h <= 1 and size_v <= 1) then return end

	local w,h = obj.getpixel();
	obj.effect("リサイズ","ドット数でサイズ指定",1, "補間なし",interpolate and 0 or 1,
		"X",w*size_h, "Y",h*size_v);
	if ex_l > 0 or ex_r > 0 or ex_t > 0 or ex_b > 0 then
		obj.effect("クリッピング","上",ex_t,"下",ex_b,"左",ex_l,"右",ex_r);
	end
end
local dither_decay_color do
	local mask_pixels do
		local function mask_pixel(px, mask_high)
			-- handling the value 0xff of each component as special
			local tops = band(0x01010100, bxor(
				band(px,0x01ff01ff)+0x010101,band(px,0xff01ff01)+0x010101));
			return bor(band(px,mask_high), tops-rshift(tops,8));
		end
		local pint = ffi.typeof("int32_t*");
		function mask_pixels(mask_high)
			local data,w,h = obj.getpixeldata();
			local ptr = ffi.cast(pint,data);
			for i = 0,w*h-1 do
				ptr[i] = mask_pixel(ptr[i], mask_high);
			end
			obj.putpixeldata(data);
		end
	end
	function dither_decay_color(bits_r,bits_g,bits_b, pattern,seed,not_opaque,
		size,aspect,mosaic, average,bilinear, offset_x,offset_y,offset_abs)
		local posinfo = slib.posinfo_save();

		-- prepare the following variables:
		local loop_h,loop_v;		-- number of loops applied to the dither pattern
		local L,T,R,B;				-- the position of the boundary w.r.t. the loop count
		local size_h,size_v;		-- size of one pixel of the dither pattern
		local ex_l,ex_r,ex_t,ex_b;	-- extra region to adjust the position of the "mosaic"

		offset_x,offset_y, loop_h,L,R,loop_v,T,B, size_h,size_v, ex_l,ex_r,ex_t,ex_b
			= mosaic_preprocess(pattern > 0 and dither_patterns[pattern].size or 0,
				mosaic,average, size,aspect, offset_x, offset_y, offset_abs);

		-- the core process of color reduction
		if bits_r > 0 or bits_g > 0 or bits_b > 0 then
			if not_opaque then
				-- backup the alpha values for a non-opaque image
				obj.copybuffer("cache:obj","obj");
				slib.force_opaque();
			end
			obj.copybuffer("tmp","obj");

			-- prepare the pattern
			if pattern > 0 then dither_patterns[pattern].load(seed) end
			local mask_low = lshift(1,bits_r+16)+lshift(1,bits_g+8)+lshift(1,bits_b) - 0x010101;
			local mask_high = bnot(mask_low);
			-- capping the each component up to 254
			if bits_r >= 8 then mask_low = mask_low - 0x010000 end
			if bits_g >= 8 then mask_low = mask_low - 0x000100 end
			if bits_b >= 8 then mask_low = mask_low - 0x000001 end
			obj.effect("単色化","輝度を保持する",0,"color",mask_low);
			local w,h = obj.getpixel();
			if pattern > 0 then
				if not mosaic and (size_h > 1 or size_v > 1) then
					w,h = w*size_h,h*size_v;
					obj.effect("リサイズ","ドット数でサイズ指定",1,"補間なし",1, "X",w, "Y",h);
				end

				image_loop(loop_h,loop_v);
			end

			-- add blening
			obj.setoption("dst","tmp");
			obj.setoption("blend", 1); -- add
			if pattern > 0 then
				for i = L,R-1,loop_h do
					local x1 = (i+loop_h/2)*w + offset_x;
					for j = T,B-1,loop_v do
						local y1 = (j+loop_v/2)*h + offset_y
						obj.draw(x1,y1);
					end
				end
			else obj.draw(0,0,0, 1,0.5) end

			-- restore the alpha values
			if not_opaque then
				obj.copybuffer("obj","cache:obj");
				invert_opacity();
				obj.setoption("blend","alpha_sub");
				obj.draw();
			end
			obj.setoption("blend",0);

			-- round the color values by cropping the lower bits
			obj.copybuffer("obj","tmp");
			mask_pixels(mask_high);
		end

		-- resize back to original, and remove the extra edge
		-- that had been added in order to adjust the position of the "mosaic"
		mosaic_postprocess(mosaic, bilinear, size_h,size_v, ex_l,ex_r,ex_t,ex_b);

		slib.posinfo_load(posinfo);
	end
end
local function call_decay_color(bits_r,bits_g,bits_b, pattern,seed,not_opaque,
	size,aspect,mosaic, average,bilinear, offset_x,offset_y,offset_abs)
	--track0:R減色,0,8,0,1
	--track1:G減色,0,8,0,1
	--track2:B減色,0,8,0,1
	--track3:サイズ,1,200,1,1
	--check0:サイズに応じて解像度を落とす,1
	--dialog:パターン (0〜7),_1=4;└(7)のシード,_2=123;縦横比,_3=0;Xずれ,_4=0;Yずれ,_5=0;ずれ画面基準/chk,_6=0;縮小補間/chk,_7=1;拡大補間/chk,_8=0;半透明に配慮/chk,_9=0;TRACK,_0=nil;
	bits_r = slib.coerce_int(bits_r,0, 0,8);
	bits_g = slib.coerce_int(bits_g,0, 0,8);
	bits_b = slib.coerce_int(bits_b,0, 0,8);
	pattern = slib.coerce_int(pattern,3, 0,#dither_patterns);
	seed = slib.coerce_int(seed,123, -0x80000000,0x7fffffff);
	size = slib.coerce_int(size,1, 1,200);
	aspect = slib.coerce_real(aspect,0, -1,1);
	offset_x = slib.coerce_int(offset_x,0);
	offset_y = slib.coerce_int(offset_y,0);

	dither_decay_color(bits_r,bits_g,bits_b,pattern,seed,not_opaque,
		size,aspect,mosaic, average,bilinear, offset_x,offset_y,offset_abs);
end

local dither_decay_alpha do
	local round_pixels_alpha do
		local pbyte = ffi.typeof("uint8_t*");
		local map = ffi.new("uint8_t[256]"); map[0],map[255] = 0,255;
		function round_pixels_alpha(rate,min_white)
			local i_max = math.max(1,math.min(254,math.floor(0.5+255*min_white)));
			for i=1,i_max-1 do map[i] = math.min(255,math.ceil(rate*i)/rate) end
			ffi.fill(map+i_max,255-i_max,255);

			local data,w,h = obj.getpixeldata();
			local ptr = ffi.cast(pbyte,data);
			for i=3,4*w*h-1,4 do ptr[i] = map[ptr[i]] end
			obj.putpixeldata(data);
		end
	end
	function dither_decay_alpha(prec_a, invert, pattern,seed,
		size,aspect,mosaic,mosaic_color, offset_x,offset_y,offset_abs)
		local posinfo = slib.posinfo_save();
		if mosaic and not mosaic_color and size > 1 then
			obj.setoption("dst","tmp",obj.getpixel());
			obj.draw(0,0,0, 1,15); -- alpha = 15.0
			obj.copybuffer("cache:obj","tmp");
		end

		-- prepare the following variables:
		local loop_h,loop_v;		-- number of loops applied to the dither pattern
		local L,T,R,B;				-- the position of the boundary w.r.t. the loop count
		local size_h,size_v;		-- size of one pixel of the dither pattern
		local ex_l,ex_r,ex_t,ex_b;	-- extra region to adjust the position of the "mosaic"

		offset_x,offset_y, loop_h,L,R,loop_v,T,B, size_h,size_v, ex_l,ex_r,ex_t,ex_b
			= mosaic_preprocess(pattern > 0 and dither_patterns[pattern].size or 0,
				mosaic,true, size,aspect, offset_x, offset_y, offset_abs);

		if prec_a < 30 then
			obj.copybuffer("tmp","obj");

			-- prepare the pattern
			local w,h;
			if pattern > 0 then
				dither_patterns[pattern].load(seed);
				if not invert then invert_opacity() end

				w,h = obj.getpixel()
				if not mosaic and (size_h > 1 or size_v > 1) then
					w,h = w*size_h,h*size_v;
					obj.effect("リサイズ","ドット数でサイズ指定",1,"補間なし",1, "X",w, "Y",h);
				end

				image_loop(loop_h,loop_v);
			else slib.force_opaque() end

			local rate  = prec_a < 15 and (1+prec_a)/255 or 1/(31-prec_a);
			local alpha = math.min(math.floor(0.5+1/rate),254)/255;

			-- "add" blening
			obj.setoption("dst","tmp");
			obj.setoption("blend", "alpha_sub");
			if pattern > 0 then
				for i = L,R-1,loop_h do
					local x1 = (i+loop_h/2)*w + offset_x;
					for j = T,B-1,loop_v do
						local y1 = (j+loop_v/2)*h + offset_y
						obj.draw(x1,y1,0, 1,alpha);
					end
				end
			else obj.draw(0,0,0, 1,alpha/2) end

			-- round the color values by cropping the lower bits
			obj.copybuffer("obj","tmp");
			round_pixels_alpha(rate,1-alpha);
		end

		-- resize back to original, and remove the extra edge
		-- that had been added in order to adjust the position of the "mosaic"
		mosaic_postprocess(mosaic, false, size_h,size_v, ex_l,ex_r,ex_t,ex_b);

		if mosaic and not mosaic_color and size > 1 then
			obj.copybuffer("tmp","cache:obj");
			invert_opacity();
			if prec_a >= 30 then obj.setoption("blend", "alpha_sub") end
			obj.draw();
			obj.copybuffer("obj","tmp");
		end
		obj.setoption("blend", 0);

		slib.posinfo_load(posinfo);
	end
end
local function call_decay_alpha(prec_a, invert, pattern,seed,
	size,aspect,mosaic,mosaic_color, offset_x,offset_y,offset_abs)
	--track0:ビット減,0,8,0,1
	--track1:サイズ,1,200,1,1
	--track2:Xずれ,-1600,1600,0,1
	--track3:Yずれ,-1600,1600,0,1
	--check0:サイズに応じて解像度を落とす,1
	--dialog:パターン (0〜7),_1=4;└(7)のシード,_2=123;縦横比,_3=0;反転/chk,_4=0;ずれ画面基準/chk,_5=0;縮小補間/chk,_6=1;拡大補間/chk,_7=0;TRACK,_0=nil;
	prec_a = slib.coerce_int(prec_a,0, 0,30);
	pattern = slib.coerce_int(pattern,3, 0,#dither_patterns);
	seed = slib.coerce_int(seed,123, -0x80000000,0x7fffffff);
	size = slib.coerce_int(size,1, 1,200);
	aspect = slib.coerce_real(aspect,0, -1,1);
	offset_x = slib.coerce_int(offset_x,0);
	offset_y = slib.coerce_int(offset_y,0);

	dither_decay_alpha(prec_a, invert, pattern,seed,
		size,aspect,mosaic,mosaic_color, offset_x,offset_y,offset_abs)
end

return {
	mask = call_mask,
	fade = call_fade,
	decay_color = call_decay_color,
	decay_alpha = call_decay_alpha,
};
