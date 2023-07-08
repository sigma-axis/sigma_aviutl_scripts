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

local math,tonumber,type = math,tonumber,type;
local deg2rad = math.pi/180;
local obj = assert(obj);

local ffi do
	local c; c,ffi = pcall(require, "ffi");
	if not c then ffi = nil end
end

local function coerce_int(n,default, min,max)
	n = math.floor(tonumber(n) or default or 0);
	return min and n < min and min or max and n > max and max or n;
end
local function coerce_real(x,default, min,max)
	x = tonumber(x) or default or 0;
	return min and x < min and min or max and x > max and max or x;
end
local function coerce_color(col,default)
	col = math.floor(tonumber(col) or -1);
	return 0 <= col and col <= 0xffffff and col or default or 0;
end
local function coerce_cachename(cachename, default)
	return type(cachename) == "string" and cachename:find("^cache:.") ~= nil
		and cachename or default or "cache:obj";
end

local function normalize_num_delimiter(s)
	return tostring(s):match("^%s*(.-)%s*$"):gsub("%s*[%s,]%s*"," ");
end
local function parse_twonum_core(source)
	local a,b = source:match("^(%S+) (%S+)$");
	a,b = tonumber(a),tonumber(b);
	if a and b then return a,b end
	return nil;
end
local function parse_threenum_core(source)
	local a,b,c = source:match("^(%S+) (%S+) (%S+)$");
	a,b,c = tonumber(a),tonumber(b),tonumber(c);
	if a and b and c then return a,b,c end
	return nil;
end
local function parse_fournum_core(source)
	local a,b,c,d = source:match("^(%S+) (%S+) (%S+) (%S+)$");
	a,b,c,d = tonumber(a),tonumber(b),tonumber(c),tonumber(d);
	if a and b and c and d then return a,b,c,d end
	return nil;
end
local function parse_twonum(source)
	return parse_twonum_core(normalize_num_delimiter(source));
end
local function parse_threenum(source)
	return parse_threenum_core(normalize_num_delimiter(source));
end
local function parse_fournum(source)
	return parse_fournum_core(normalize_num_delimiter(source));
end
local function parse_onetwonum(source)
	local a = tonumber(source);
	if a then return a,a end
	return parse_twonum(source);
end
local function parse_onethreenum(source)
	local a = tonumber(source);
	if a then return a,a,a end
	return parse_threenum(source);
end
local function parse_onefournum(source)
	local r = tonumber(source);
	if r then return r,r,r,r end
	return parse_fournum(source);
end
local function parse_thickness(source)
	local h,v;
	h = tonumber(source);
	if h then return h,h,h,h end

	source = normalize_num_delimiter(source);
	h,v = parse_twonum_core(source);
	if h then return h,v,h,v end

	return parse_fournum_core(source);
end

local function size_aspect_to_len(size, aspect)
	if aspect > 0 then return (1-aspect)*size,size;
	else return size,(1+aspect)*size end
end
local function len_to_size_aspect(width, height)
	if width > height then return width,-1+height/width;
	else return height,1-width/height end
end
local function extract_trackvalues(tbl)
	local c0,t1,t2,t3,t4;
	if tbl then c0,t1,t2,t3,t4 = tbl[0],tbl[1],tbl[2],tbl[3],tbl[4] end
	t1 = tonumber(t1) or obj.track0;
	t2 = tonumber(t2) or obj.track1;
	t3 = tonumber(t3) or obj.track2;
	t4 = tonumber(t4) or obj.track3;
	if c0 == nil then c0 = obj.check0;
	else c0 = c0==1 or c0==true end;

	return c0,t1,t2,t3,t4;
end

local function posinfo_copy(dst,src)
	dst.ox		= src.ox;
	dst.oy		= src.oy;
	dst.oz		= src.oz;
	dst.rx		= src.rx;
	dst.ry		= src.ry;
	dst.rz		= src.rz;
	dst.cx		= src.cx;
	dst.cy		= src.cy;
	dst.cz		= src.cz;
	dst.zoom	= src.zoom;
	dst.aspect	= src.aspect;
	dst.alpha	= src.alpha;
	return dst;
end
local function posinfo_save() return posinfo_copy({}, obj) end
local function posinfo_load(t) posinfo_copy(obj,t) end

local sjis_char_pat = "[\129-\159\224-\252]?.";
local function sjis_chars(str) return str:gmatch(sjis_char_pat) end
local sjis_revert_unescape do
	local was_hot_char;
	local function gsub_callback(c)
		if was_hot_char and c == "\\" then
			was_hot_char = false;
			return "";
		end
		was_hot_char = c:byte(2) == 0x5c; -- '\\'
	end
	function sjis_revert_unescape(str)
		was_hot_char = false;
		return str:gsub(sjis_char_pat,gsub_callback);
	end
end

local function find_midpoint_section(time)
	time = coerce_real(time, obj.time, 0, obj.totaltime);

	local N = obj.getoption("section_num");
	local m,n = 0,N;
	while m+1 < n do
		local u = math.floor((m+n)/2);
		if obj.getvalue("time",0,u) <= time then m = u else n = u end
	end

	local s,t = obj.getvalue("time",0,m),obj.getvalue("time",0,n);
	if n==N then t = t+1/obj.framerate end
	t = t-s;
	return m, (time-s)/t, N,t;
end

local function invert_transparency() return obj.effect("反転","透明度反転",1) end
local function force_transparent()
	local _,h = obj.getpixel();
	obj.effect("斜めクリッピング","中心Y",-h/2-2);
end
local function force_opaque()
	force_transparent();
	invert_transparency();
end
local force_opacity, push_opacity if ffi then
	local pbyte = ffi.typeof("uint8_t*");
	function force_opacity(alpha, load)
		load = load == nil or load == true;
		if alpha <= 0 then force_transparent();
		elseif alpha >= 1 then
			-- alpha > 1 doesn't seem to be kept by any means
			force_opaque();
		else
			-- manipulating through each pixel is faster in this case
			alpha = math.floor(255*alpha);
			local data,w,h = obj.getpixeldata();
			local ptr = ffi.cast(pbyte,data);
			for i=3,4*w*h-1,4 do ptr[i] = alpha end
			obj.putpixeldata(data);
		end
		if not load then obj.copybuffer("tmp", "obj") end
	end
	function push_opacity(alpha, load)
		load = load == nil or load == true;
		if alpha <= 0 then force_transparent();
		elseif alpha ~= 1 then
			local data,w,h = obj.getpixeldata();
			local ptr = ffi.cast(pbyte,data);
			if alpha > 1 then
				-- alpha > 1 doesn't seem to be kept by any means
				for i=3,4*w*h-1,4 do ptr[i] = math.min(255,alpha*ptr[i]) end
			else
				-- manipulating through each pixel is faster in this case
				for i=3,4*w*h-1,4 do ptr[i] = alpha*ptr[i] end
			end
			obj.putpixeldata(data);
		end
		if not load then obj.copybuffer("tmp", "obj") end
	end
else
	function push_opacity(alpha, load)
		load = load == nil or load == true;
		if alpha <= 0 or alpha == 1 then
			if alpha <= 0 then force_transparent() end
			if not load then obj.copybuffer("tmp", "obj") end
		else
			obj.setoption("dst","tmp",obj.getpixel());
			obj.draw(0,0,0,1,alpha);
			if load then obj.copybuffer("obj", "tmp") end
		end
	end
	function force_opacity(alpha, load)
		if alpha <= 0 then
			force_transparent();
			if load ~= nil and load ~= true then
				obj.copybuffer("tmp", "obj");
			end
		else
			force_opaque();
			push_opacity(alpha, load);
		end
	end
end

local function angle_cut_x(center_x,angle)
	return obj.effect("斜めクリッピング","ぼかし",0,"中心X",center_x,"角度",angle);
end
local function diamond_cut_x(w2,angle)
	angle_cut_x(-w2, angle);
	angle_cut_x(-w2,-angle+180);
	angle_cut_x( w2,-angle);
	angle_cut_x( w2, angle-180);
end
local function angle_cut_y(center_y,angle)
	return obj.effect("斜めクリッピング","ぼかし",0,"中心Y",center_y,"角度",angle);
end
local function diamond_cut_y(h2,angle)
	angle_cut_y(-h2, angle-180);
	angle_cut_y(-h2,-angle+180);
	angle_cut_y( h2, angle);
	angle_cut_y( h2,-angle);
end
local function load_diamond_core(color,width,height,thick, back_color, back_alpha)
	local frm_mode = 0;
	if thick and thick >= 0 and 2*thick < math.min(width,height) then
		if width < height then
			local sec_sq = 1+(height/width)^2;
			if 4*sec_sq*thick^2 < height^2 then
				thick = sec_sq^0.5 * thick;
				frm_mode = 1;
			end
		else
			local sec_sq = 1+(width/height)^2;
			if 4*sec_sq*thick^2 < width^2 then
				thick = sec_sq^0.5 * thick;
				frm_mode = 2;
			end
		end
	end
	if frm_mode == 0 or back_alpha <= 0 then back_color = color end

	if width == height then obj.load("figure","四角形", back_color,width);
	else
		obj.load("figure","四角形",back_color,1);
		obj.effect("リサイズ","X",width,"Y",height,"ドット数でサイズ指定",1,"補間なし",1);
	end

	local w,h = obj.getpixel();
	local angle;
	if w == h then angle = 45 else angle = math.atan(h/w)/deg2rad end
	if frm_mode > 0 then
		if frm_mode == 1 then
			diamond_cut_y(h==height and (height/2-thick) or (0.5-thick/height)*h,angle);
		else
			diamond_cut_x(w==width and (width/2-thick) or (0.5-thick/width)*w,angle);
		end
		if back_alpha > 0 then
			obj.setoption("dst","tmp",w,h);
			obj.draw(0,0,0, 1,back_alpha);
			invert_transparency();
			if color ~= back_color then
				obj.effect("単色化","color",color,"輝度を保持する",0);
			end
			obj.setoption("blend","alpha_add");
			obj.draw();
			obj.setoption("blend",0);
			obj.copybuffer("obj","tmp");
		else
			invert_transparency();
		end
	end

	if w < h then diamond_cut_y(h/2,angle);
	else diamond_cut_x(w/2,angle) end
end
local function load_diamond(color,width,height,thick,back_color,back_alpha)
	color = coerce_color(color,0xffffff);
	width = coerce_int(width,100,0);
	height = coerce_int(height,-1); if height < 0 then height = width end
	thick = coerce_real(thick, -1);
	back_color = coerce_color(back_color, 0x000000);
	back_alpha = coerce_real(back_alpha, 0, 0, 1);
	return load_diamond_core(color,width,height,thick, back_color, back_alpha);
end

local function corner_radius_resize(radiusTL,radiusTR,radiusBR,radiusBL, width,height)
	-- divisions are postponed to minimize errors of precision.
	local M = math.max(
		width * math.max(radiusTL + radiusBL, radiusTR + radiusBR),
		height * math.max(radiusTL + radiusTR, radiusBL + radiusBR));
	local p = width * height;
	if M <= p then return radiusTL, radiusTR, radiusBR, radiusBL;
	else
		-- do not calculate like "rad*(p/M)" to prevent precision loss of fractions.
		return math.floor((radiusTL * p)/M), math.ceil((radiusTR * p)/M),
			math.floor((radiusBR * p)/M), math.ceil((radiusBL * p)/M);
	end
end

local function load_rounding_corner(figure,color,size,invert)
	if figure == "" then load_diamond_core(color,size,size);
	else
		local posinfo = posinfo_save();
		obj.load("figure",figure,color, size);
		posinfo_load(posinfo);
	end
	local R1,B1 = obj.getpixel(); local R0,B0 = math.floor(R1/2),math.floor(B1/2);
	local L0,L1, T0,T1 = 0,R0, 0,B0;
	if invert or figure == "" then return L1,L0,R1,R0, T1,T0,B1,B0;
	else invert_transparency(); return L0,L1,R0,R1, T0,T1,B0,B1 end
end
local function place_rounding_corners(w2,h2,radiusTL,radiusTR,radiusBR,radiusBL, L0,L1,R0,R1, T0,T1,B0,B1)
	if radiusTL > 0 then
		obj.drawpoly(-w2,-h2,0, -w2+radiusTL,-h2,0, -w2+radiusTL,-h2+radiusTL,0, -w2,-h2+radiusTL,0,
			L0,T0, L1,T0, L1,T1, L0,T1);
	end
	if radiusTR > 0 then
		obj.drawpoly(w2-radiusTR,-h2,0, w2,-h2,0, w2,-h2+radiusTR,0, w2-radiusTR,-h2+radiusTR,0,
			R0,T0, R1,T0, R1,T1, R0,T1);
	end
	if radiusBR > 0 then
		obj.drawpoly(w2-radiusBR,h2-radiusBR,0, w2,h2-radiusBR,0, w2,h2,0, w2-radiusBR,h2,0,
			R0,B0, R1,B0, R1,B1, R0,B1);
	end
	if radiusBL > 0 then
		obj.drawpoly(-w2,h2-radiusBL,0, -w2+radiusBL,h2-radiusBL,0, -w2+radiusBL,h2,0, -w2,h2,0,
			L0,B0, L1,B0, L1,B1, L0,B1);
	end
end
local function round_corners_simple(radiusTL,radiusTR,radiusBR,radiusBL, figure,invert, tempbuffer,width,height)
	if not tempbuffer then
		obj.copybuffer("tmp","obj");
		obj.setoption("dst","tmp");
		width,height = obj.getpixel();
	end
	local w2,h2 = width/2,height/2;

	local r = math.max(radiusTL,radiusTR,radiusBR,radiusBL);
	local L0,L1,R0,R1, T0,T1,B0,B1 = load_rounding_corner(figure,0, 8*r, invert);

	obj.setoption("blend","alpha_sub");
	place_rounding_corners(w2,h2,radiusTL,radiusTR,radiusBR,radiusBL, L0,L1,R0,R1, T0,T1,B0,B1);
	obj.setoption("blend",0);

	if not tempbuffer then
		obj.copybuffer("obj","tmp");
	end
end

local function round_corners_precise(cachename, radiusTL,radiusTR,radiusBR,radiusBL, figure,invert, tempbuffer,width,height)
	cachename = coerce_cachename(cachename);
	if not tempbuffer then
		obj.copybuffer(cachename,"obj");
		width,height = obj.getpixel();
	else
		obj.copybuffer(cachename,"tmp");
	end
	local w2,h2 = width/2,height/2;

	obj.setoption("dst","tmp",width,height);
	obj.load("figure","四角形",0,1);
	obj.drawpoly(-w2,-h2,0, w2,-h2,0, w2,h2,0, -w2,h2,0)
	round_corners_simple(radiusTL,radiusTR,radiusBR,radiusBL, figure,invert,true,width,height);

	obj.copybuffer("obj",cachename);
	invert_transparency();
	obj.draw();
	obj.copybuffer("obj","tmp");
	invert_transparency();
	obj.copybuffer("tmp",cachename);
	obj.setoption("blend","alpha_sub");
	obj.draw();
	obj.setoption("blend",0);

	if not tempbuffer then
		obj.copybuffer("obj","tmp");
	end
end

local function round_corners(cachename, radiusTL,radiusTR,radiusBR,radiusBL, figure,invert, tempbuffer,width,height)
	local simple;
	if type(cachename) == "number" then
		simple = true;
		cachename, radiusTL,radiusTR,radiusBR,radiusBL, figure,invert, tempbuffer,width,height
			= nil, cachename, radiusTL,radiusTR,radiusBR,radiusBL, figure,invert, tempbuffer,width;
	end
	if not tempbuffer then width,height = obj.getpixel();
	else width,height = tonumber(width), tonumber(height);
		if not width or not height then
			error("width and height must specify the size of tempbuffer in pixels!",2);
		end
	end
	radiusTL = coerce_int(radiusTL,0, 0);
	radiusTR = coerce_int(radiusTR,-1); if radiusTR < 0 then radiusTR = radiusTL end
	radiusBR = coerce_int(radiusBR,-1); if radiusBR < 0 then radiusBR = radiusTL end
	radiusBL = coerce_int(radiusBL,-1); if radiusBL < 0 then radiusBL = radiusTL end
	radiusTL,radiusTR,radiusBR,radiusBL = corner_radius_resize(
		radiusTL,radiusTR,radiusBR,radiusBL, width, height);
	if radiusTL > 0 or radiusTR > 0 or radiusBR > 0 or radiusBL > 0 then
		if type(figure) ~= "string" then figure = "円" end
		if simple then
			round_corners_simple(radiusTL,radiusTR,radiusBR,radiusBL, figure,invert, tempbuffer,width,height);
		else
			round_corners_precise(cachename, radiusTL,radiusTR,radiusBR,radiusBL, figure,invert, tempbuffer,width,height);
		end
	end
end

local function round_rect_fill(width,height, color, radiusTL, radiusTR, radiusBR, radiusBL, figure,invert)
	obj.load("figure","四角形",color,1);
	obj.effect("リサイズ","X",width,"Y",height,"ドット数でサイズ指定",1,"補間なし",1);
	if radiusTL > 0 or radiusTR > 0 or radiusBR > 0 or radiusBL > 0 then
		obj.copybuffer("tmp","obj");
		obj.setoption("dst","tmp");
		round_corners_simple(radiusTL,radiusTR,radiusBR,radiusBL, figure,invert,true,width,height);
		return false;
	end
	return true;
end
local function nonround_rect_frame(width, height, color,back_color,back_alpha, thick)
	local w2,h2 = width/2,height/2;
	obj.setoption("dst","tmp",width,height);
	obj.load("figure","四角形",color,1);
	obj.drawpoly(-w2,-h2,0, w2,-h2,0, w2,h2,0, -w2,h2,0);

	obj.setoption("blend","alpha_sub");
	w2,h2 = w2-thick,h2-thick;
	if color == back_color then
		obj.drawpoly(-w2,-h2,0, w2,-h2,0, w2,h2,0, -w2,h2,0, 0,0, 0,0, 0,0, 0,0, 1-back_alpha);
	else
		obj.drawpoly(-w2,-h2,0, w2,-h2,0, w2,h2,0, -w2,h2,0);

		if back_alpha > 0 then
			obj.load("figure","四角形",back_color,1);
			obj.setoption("blend","alpha_add");
			obj.drawpoly(-w2,-h2,0, w2,-h2,0, w2,h2,0, -w2,h2,0, 0,0, 0,0, 0,0, 0,0, back_alpha);
		end
	end
	obj.setoption("blend",0);
end
local function round_rect_frame_in(width, height, color,back_color,back_alpha, thick,
	tl, tr, br, bl, figure,ratio_rad_thick,invert,extrapolate)
	local w2,h2 = width/2,height/2;

	local thick_fig = math.floor(ratio_rad_thick*thick);
	nonround_rect_frame(width, height, color, back_color, thick < thick_fig and 0 or back_alpha, thick);
	if thick < thick_fig then
		local extent,coeff,c0,draw_once;
		if extrapolate then
			local tan = ((ratio_rad_thick-1)/(ratio_rad_thick+1))^0.5;
			extent = tan * thick;
			local d = 2-(1-tan)^2;
			coeff = 2*tan/d;
			c0 = (1+tan^2)/d * thick; -- = coeff*(extent-thick) + thick
			draw_once = ratio_rad_thick^2 >= 2;
		else extent,coeff,c0,draw_once = 0,1,0,true end

		if thick-extent < tl then
			if thick_fig < tl then
				obj.drawpoly(-w2+thick,-h2+thick,0, -w2+tl+extent,-h2+thick,0, -w2+tl,-h2+thick_fig,0, -w2+thick,-h2+thick_fig,0);
				obj.drawpoly(-w2+thick,-h2+thick_fig,0, -w2+thick_fig,-h2+thick_fig,0, -w2+thick_fig,-h2+tl,0, -w2+thick,-h2+tl+extent,0);
			else
				local c = coeff*tl+c0; -- = coeff*(tl+extent-thick)+thick
				if draw_once then
					obj.drawpoly(-w2+thick,-h2+thick,0, -w2+tl+extent,-h2+thick,0, -w2+c,-h2+c,0, -w2+thick,-h2+tl+extent,0);
				else
					obj.drawpoly(-w2+thick,-h2+thick,0, -w2+tl+extent,-h2+thick,0, -w2+c,-h2+c,0, -w2+thick,-h2+c,0);
					obj.drawpoly(-w2+thick,-h2+thick,0, -w2+c,-h2+thick,0, -w2+c,-h2+c,0, -w2+thick,-h2+tl+extent,0);
				end
			end
		end
		if thick-extent < tr then
			if thick_fig < tr then
				obj.drawpoly(w2-thick,-h2+thick,0, w2-thick,-h2+thick_fig,0, w2-tr,-h2+thick_fig,0, w2-tr-extent,-h2+thick,0);
				obj.drawpoly(w2-thick,-h2+thick_fig,0, w2-thick,-h2+tr+extent,0, w2-thick_fig,-h2+tr,0, w2-thick_fig,-h2+thick_fig,0);
			else
				local c = coeff*tr+c0; -- = coeff*(tr+extent-thick)+thick
				if draw_once then
					obj.drawpoly(w2-thick,-h2+thick,0, w2-thick,-h2+tr+extent,0, w2-c,-h2+c,0, w2-tr-extent,-h2+thick,0);
				else
					obj.drawpoly(w2-thick,-h2+thick,0, w2-thick,-h2+c,0, w2-c,-h2+c,0, w2-tr-extent,-h2+thick,0);
					obj.drawpoly(w2-thick,-h2+thick,0, w2-thick,-h2+tr+extent,0, w2-c,-h2+c,0, w2-c,-h2+thick,0);
				end
			end
		end
		if thick-extent < br then
			if thick_fig < br then
				obj.drawpoly(w2-thick,h2-thick,0, w2-br-extent,h2-thick,0, w2-br,h2-thick_fig,0, w2-thick,h2-thick_fig,0);
				obj.drawpoly(w2-thick,h2-thick_fig,0, w2-thick_fig,h2-thick_fig,0, w2-thick_fig,h2-br,0, w2-thick,h2-br-extent,0);
			else
				local c = coeff*br+c0; -- = coeff*(br+extent-thick)+thick
				if draw_once then
					obj.drawpoly(w2-thick,h2-thick,0, w2-br-extent,h2-thick,0, w2-c,h2-c,0, w2-thick,h2-br-extent,0);
				else
					obj.drawpoly(w2-thick,h2-thick,0, w2-br-extent,h2-thick,0, w2-c,h2-c,0, w2-thick,h2-c,0);
					obj.drawpoly(w2-thick,h2-thick,0, w2-c,h2-thick,0, w2-c,h2-c,0, w2-thick,h2-br-extent,0);
				end
			end
		end
		if thick-extent < bl then
			if thick_fig < bl then
				obj.drawpoly(-w2+thick,h2-thick,0, -w2+thick,h2-thick_fig,0, -w2+bl,h2-thick_fig,0, -w2+bl+extent,h2-thick,0);
				obj.drawpoly(-w2+thick,h2-thick_fig,0, -w2+thick,h2-bl-extent,0, -w2+thick_fig,h2-bl,0, -w2+thick_fig,h2-thick_fig,0);
			else
				local c = coeff*bl+c0; -- = coeff*(bl+extent-thick)+thick
				if draw_once then
					obj.drawpoly(-w2+thick,h2-thick,0, -w2+thick,h2-bl-extent,0, -w2+c,h2-c,0, -w2+bl+extent,h2-thick,0);
				else
					obj.drawpoly(-w2+thick,h2-thick,0, -w2+thick,h2-c,0, -w2+c,h2-c,0, -w2+bl+extent,h2-thick,0);
					obj.drawpoly(-w2+thick,h2-thick,0, -w2+thick,h2-bl-extent,0, -w2+c,h2-c,0, -w2+c,h2-thick,0);
				end
			end
		end

		if back_alpha > 0 then
			obj.copybuffer("obj","tmp");
			invert_transparency();
			if back_color ~= color then
				obj.effect("単色化","color",back_color,"輝度を保持する",0);
			end
			obj.setoption("blend","alpha_add");
			obj.draw(0,0,0, 1,back_alpha);
			obj.setoption("blend",0);
		end
	end

	local L0,L1,R0,R1, T0,T1,B0,B1 = load_rounding_corner(figure,color,8*math.max(tl,tr,br,bl),invert);

	place_rounding_corners(w2-thick_fig,h2-thick_fig,
		tl-thick_fig, tr-thick_fig, br-thick_fig, bl-thick_fig,
		L0,L1,R0,R1, T0,T1,B0,B1);

	obj.setoption("blend","alpha_sub");
	place_rounding_corners(w2,h2,tl,tr,br,bl, L0,L1,R0,R1, T0,T1,B0,B1);
	obj.setoption("blend",0);
end
local function round_rect_frame_out(width, height, color,back_color,back_alpha, thick, tl, tr, br, bl, figure,ratio_rad_thick,invert)
	nonround_rect_frame(width, height, color, back_color, back_alpha, thick);

	local w2,h2,thick_fig = width/2,height/2,math.floor(thick*ratio_rad_thick);
	local L0,L1,R0,R1, T0,T1,B0,B1 = load_rounding_corner(figure,color,8*math.max(tl,tr,br,bl),invert);

	place_rounding_corners(w2,h2,
		tl>0 and tl+thick_fig or 0,tr>0 and tr+thick_fig or 0,
		br>0 and br+thick_fig or 0,bl>0 and bl+thick_fig or 0,
		L0,L1,R0,R1, T0,T1,B0,B1);

	obj.setoption("blend","alpha_sub");
	place_rounding_corners(w2,h2,tl,tr,br,bl, L0,L1,R0,R1, T0,T1,B0,B1);
	obj.setoption("blend",0);
end

local ratio_rad_thick_list = {
	[""] = 2^0.5,
	["背景"] = 1,
	["円"] = 1,
	["四角形"] = 1,
	["三角形"] = 2,
	["五角形"] = 1/math.cos(math.pi/5),
	["六角形"] = 1/math.cos(math.pi/6),
	["星型"] = 1/math.cos(2/5*math.pi),
};
local function round_rect(color, width, height, thick,
	radiusTL, radiusTR, radiusBR, radiusBL, figure,invert,ratio_rad_thick,flipcenter,extrapolate,
	back_color,back_alpha, load)

	color = coerce_color(color,0xffffff);
	width,height = coerce_int(width, 1, 1), coerce_int(height,1, 1);
	thick = coerce_int(thick, -1); if thick < 0 then thick = width end
	radiusTL = coerce_int(radiusTL,0, 0);
	radiusTR = coerce_int(radiusTR,-1); if radiusTR < 0 then radiusTR = radiusTL end
	radiusBR = coerce_int(radiusBR,-1); if radiusBR < 0 then radiusBR = radiusTL end
	radiusBL = coerce_int(radiusBL,-1); if radiusBL < 0 then radiusBL = radiusTL end
	radiusTL,radiusTR,radiusBR,radiusBL = corner_radius_resize(
		radiusTL,radiusTR,radiusBR,radiusBL, width,height);
	if type(figure) ~= "string" then figure = "円" end
	invert = invert == true;
	load = load == nil or load == true;

	local loaded = false;
	if math.min(width, height) <= 2*thick then
		loaded = round_rect_fill(width, height, color, radiusTL, radiusTR, radiusBR, radiusBL, figure, invert);
	else
		back_color = coerce_color(back_color, 0x000000);
		back_alpha = coerce_real(back_alpha,0, 0,1);

		if radiusTL == 0 and radiusTR == 0 and radiusBR == 0 and radiusBL == 0 then
			nonround_rect_frame(width, height, color,back_color,back_alpha, thick);
		else
			ratio_rad_thick = coerce_real(ratio_rad_thick, -1);
			if ratio_rad_thick < 0 then
				ratio_rad_thick = ratio_rad_thick_list[figure] or 1;
			end
			flipcenter = flipcenter == true;
			if invert == flipcenter then
				extrapolate = extrapolate == nil or extrapolate == true;
				round_rect_frame_in(width, height, color,back_color,back_alpha, thick,
					radiusTL,radiusTR,radiusBR,radiusBL, figure,ratio_rad_thick,invert,extrapolate);
			else
				round_rect_frame_out(width, height, color,back_color,back_alpha, thick,
				radiusTL,radiusTR,radiusBR,radiusBL, figure,ratio_rad_thick,invert);
			end
		end
	end
	if load ~= loaded then
		if load then obj.copybuffer("obj","tmp");
		else obj.copybuffer("tmp","obj") end
	end
end

local function proj_point1024(v)
	local r = 1/(1+v[3]/1024);
	return r*v[1],r*v[2];
end
local function transform_proj1024(transform_func, camera_dist, culling)
	local w2,h2 = obj.getpixel(); w2,h2 = w2/2,h2/2;
	local vertices = {{-w2,-h2,0},{w2,-h2,0},{w2,h2,0},{-w2,h2,0}};

	-- transform the vertices
	do
		local x,y,z,dz = -obj.cx,-obj.cy,-obj.cz, camera_dist-1024;
		for i=1,4 do
			local v = vertices[i];
			v[1],v[2],v[3] = transform_func(x+v[1],y+v[2],z);
			v[3] = v[3]+dz;
		end
	end

	-- find the bounding box
	local bd_l,bd_t,bd_r,bd_b;
	if culling then
		-- at the same time detect if we're drawing the backside of the surface
		local sum = 0; local x1,y1,prev_x,prev_y;
		for i=1,4 do
			local x,y = proj_point1024(vertices[i]);
			if i == 1 then
				bd_l,bd_t,bd_r,bd_b = x,y,x,y;
				x1,y1 = x,y;
			else
				if x < bd_l then bd_l = x elseif x > bd_r then bd_r = x end
				if y < bd_t then bd_t = y elseif y > bd_b then bd_b = y end
				sum = sum + prev_x*y-prev_y*x;
			end
			prev_x,prev_y = x,y;
		end
		culling = sum + prev_x*y1-prev_y*x1 < 0;
	else
		for i=1,4 do
			local x,y = proj_point1024(vertices[i]);
			if i == 1 then bd_l,bd_t,bd_r,bd_b = x,y,x,y;
			else
				if x < bd_l then bd_l = x elseif x > bd_r then bd_r = x end
				if y < bd_t then bd_t = y elseif y > bd_b then bd_b = y end
			end
		end
	end

	local cx, cy;
	if culling then obj.setoption("draw_state",true); cx,cy = 0,0;
	else
		-- move the 3D coordinates to the center of the drawing target
		cx, cy = -(bd_l+bd_r)/2, -(bd_t+bd_b)/2;
		for i=1,4 do
			local v = vertices[i];
			local r = 1+v[3]/1024;
			v[1],v[2] = v[1]+r*cx,v[2]+r*cy;
		end

		-- prepare the tempbuffer and draw
		obj.setoption("dst","tmp",
			math.max(1,math.ceil(bd_r-bd_l)), math.max(1,math.ceil(bd_b-bd_t)));
		obj.drawpoly(
			vertices[1][1],vertices[1][2],vertices[1][3],
			vertices[2][1],vertices[2][2],vertices[2][3],
			vertices[3][1],vertices[3][2],vertices[3][3],
			vertices[4][1],vertices[4][2],vertices[4][3]);
		obj.copybuffer("obj","tmp");
	end

	-- adjust the corrdinates
	obj.cx,obj.cy,obj.cz = cx,cy,0;
end

local function fill_back(color,alpha,alpha_f,load)
	color = coerce_color(color,0x808080);
	alpha = coerce_real(alpha,1);
	alpha_f = coerce_real(alpha_f,1);
	load = load == nil or load == true;

	if alpha_f ~= 1 then
		obj.setoption("dst","tmp",obj.getpixel());
		obj.draw(0,0,0,1,alpha_f);
		if alpha > 0 or load then obj.copybuffer("obj","tmp") end
		if alpha <= 0 then return end
	elseif alpha <= 0 then
		if not load then obj.copybuffer("tmp","obj") end
		return;
	else
		obj.copybuffer("tmp","obj");
		obj.setoption("dst","tmp");
	end
	invert_transparency();
	obj.effect("単色化", "輝度を保持する",0, "color",color);
	obj.setoption("blend","alpha_add");
	obj.draw(0,0,0,1,alpha);
	obj.setoption("blend",0);
	if load then obj.copybuffer("obj","tmp") end
end

local function pizza_cut_sharp(a_from, a_to, cx,cy)
	local invert = a_to - a_from < 180;
	if invert then
		a_from,a_to = a_to,a_from;
		obj.copybuffer("tmp","obj");
		obj.setoption("dst","tmp");
	end

	obj.effect("斜めクリッピング","中心X",cx,"中心Y",cy,"ぼかし",0,"角度",a_from-90);
	obj.effect("斜めクリッピング","中心X",cx,"中心Y",cy,"ぼかし",0,"角度",a_to+90);

	if invert then
		obj.setoption("blend","alpha_sub");
		obj.draw();
		obj.copybuffer("obj","tmp");
		obj.setoption("blend",0);
	end
end
local function pizza_cut_blunt(a_from, a_to, cx,cy, blur, cachename)
	local w2,h2 = obj.getpixel(); w2,h2 = w2/2,h2/2;
	local r = math.ceil(96/95*((w2+math.abs(cx))^2+(h2+math.abs(cy))^2)^0.5);

	local posinfo = posinfo_save();

	obj.load("figure","四角形",0,1);
	obj.effect("リサイズ","ドット数でサイズ指定",1,"補間なし",1,
		"X",math.min(math.max(math.ceil(math.pi*r/4)*4-96,360),(obj.getinfo("image_max"))),"Y",96);

	local a_after,flip = (a_from+a_to)/2,false;
	if blur <= 177.1875 then -- 180-blur >= 90/32
		-- suppress jittering by "stabilizing" a_after.
		local _,q = math.frexp((180-blur)/90);q=2^(q-1)*90;
		a_after = math.floor(0.5+a_after/q)*q;
	end
	a_from,a_to=a_from-a_after,a_to-a_after;
	if a_from+180 < a_to then
		a_from,a_to=a_to-180,a_from+180;
		a_after,flip = a_after-180,true;
	end
	local l = obj.getpixel()/360;
	obj.effect("斜めクリッピング","角度",-90,"中心X",-a_from*l, "ぼかし",blur*l);
	obj.effect("斜めクリッピング","角度",90,"中心X",-a_to*l, "ぼかし",blur*l);
	if flip == (not cachename) then invert_transparency() end

	obj.effect("極座標変換","回転",a_after+180,
		"拡大率",math.ceil(100*math.max(math.pi*r/(360*l+96),1)));

	l = obj.getpixel()/2; -- polar transform always yields the dimension of even size.
	obj.setoption("dst","tmp");
	if cachename then
		if l<r then
			for i=1,2 do
				obj.drawpoly(-w2,-h2,0, w2,-h2,0, w2,h2,0, -w2,h2,0,
					l*(1-(w2+cx)/r),l*(1-(h2+cy)/r), l*(1+(w2-cx)/r),l*(1-(h2+cy)/r),
					l*(1+(w2-cx)/r),l*(1+(h2-cy)/r), l*(1-(w2+cx)/r),l*(1+(h2-cy)/r));
				-- note that obj.draw(cx,cy,0, r/l) may fail due to the maximum size of image.
				if i < 2 then obj.setoption("blend","alpha_sub") end
			end
		else
			obj.draw(cx,cy);
			obj.setoption("blend","alpha_sub");
			obj.draw(cx,cy);
		end
		obj.copybuffer("obj","tmp");
		obj.copybuffer("tmp",cachename);
		obj.draw();
	else
		obj.setoption("blend","alpha_sub");
		if l<r then
			obj.drawpoly(-w2,-h2,0, w2,-h2,0, w2,h2,0, -w2,h2,0,
				l*(1-(w2+cx)/r),l*(1-(h2+cy)/r), l*(1+(w2-cx)/r),l*(1-(h2+cy)/r),
				l*(1+(w2-cx)/r),l*(1+(h2-cy)/r), l*(1-(w2+cx)/r),l*(1+(h2-cy)/r));
			-- note that obj.draw(cx,cy,0, r/l) may fail due to the maximum size of image.
		else obj.draw(cx,cy) end
	end
	obj.setoption("blend",0);
	obj.copybuffer("obj","tmp");

	posinfo_load(posinfo);
end
local function pizza_cut(a_from, a_to, cx,cy, blur, opaque, cachename, already_cached)
	blur = coerce_real(blur, 0, 0, 180);
	if a_from >= a_to+blur then return end
	if a_from + 360 <= a_to-blur then
		-- make the entire image transparent
		force_transparent();
		return;
	end

	if blur > 0 then
		obj.copybuffer("tmp","obj");
		if opaque ~= false then cachename = nil;
		else
			cachename = coerce_cachename(cachename);
			if not already_cached then obj.copybuffer(cachename,"obj") end
		end
		pizza_cut_blunt(a_from,a_to, cx,cy, blur,cachename);
	else
		pizza_cut_sharp(a_from,a_to,cx,cy);
	end
end


return {
	coerce_int = coerce_int,
	coerce_real = coerce_real,
	coerce_color = coerce_color,
	coerce_cachename = coerce_cachename,

	parse_thickness = parse_thickness,
	parse_twonum = parse_twonum,
	parse_onetwonum = parse_onetwonum,
	parse_threenum = parse_threenum,
	parse_onethreenum = parse_onethreenum,
	parse_fournum = parse_fournum,
	parse_onefournum = parse_onefournum,

	size_aspect_to_len = size_aspect_to_len,
	len_to_size_aspect = len_to_size_aspect,
	extract_trackvalues = extract_trackvalues,

	posinfo_save = posinfo_save,
	posinfo_load = posinfo_load,
	posinfo_copy = posinfo_copy,

	sjis_chars = sjis_chars,
	sjis_revert_unescape = sjis_revert_unescape,

	find_midpoint_section = find_midpoint_section,

	force_transparent = force_transparent,
	force_opaque = force_opaque,
	force_opacity = force_opacity,
	push_opacity = push_opacity,

	round_corners = round_corners,
	round_rect = round_rect,
	corner_radius_resize = corner_radius_resize,
	diamond_shape = load_diamond,

	transform_project1024 = transform_proj1024,

	fill_back = fill_back,

	pizza_cut = pizza_cut,

	VERSION = VERSION,
};
