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

local math = math;
local deg2rad = math.pi/180;
local slib = require "sigma_lib";
local srot = require "sigma_rot_helper";
local obj = assert(obj);
local ffi do
	local c; c,ffi = pcall(require, "ffi");
	if not c then
		c = ffi; ffi = nil;
		debug_print(c);
		debug_print("ffiライブラリが見つかりませんでした．LuaJITの導入を推奨します．");
	end
end
local band, bor, lshift;
if (package.loaded.bit or pcall(require,"bit")) and bit then
	band, bor, lshift = bit.band, bit.bor, bit.lshift;
else band, bor, lshift = AND, OR, SHIFT end

local function call_rectangle(w,h,l, color,back_color,back_alpha, r_tl,r_tr,r_br,r_bl,
	align_h,align_v, corner_fig, corner_inv, corner_thickcoeff,corner_flipcenter,corner_extrapolate)
	--track0:幅,0,2000,100,1
	--track1:高さ,0,2000,100,1
	--track2:ライン幅,0,2000,2000,1
	--track3:角半径,0,2000,0,1
	--check0:角丸凹凸反転,0
	--dialog:色/col,_1=0xffffff;背景色/col,_2=0x000000;背景透明度,_3=100;水平揃え,_4=0.0;垂直揃え,_5=0.0;角丸図形/fig,_6="円";└縁幅比率,_7=-1;└中心反転/chk,_8=0;└内側補外/chk,_9=1;右上半径,_10=-1;右下半径,_11=-1;左下半径,_12=-1;TRACK,_0=nil;
	w = slib.coerce_int(w, 100,0);
	h = slib.coerce_int(h, 100,0);

	if w == 0 or h == 0 then
		obj.setoption("draw_state",true);
		return;
	end

	color = slib.coerce_color(color, 0xffffff);
	back_color = slib.coerce_color(back_color, 0x000000);
	back_alpha = slib.coerce_real(back_alpha,0, 0,1);
	l = slib.coerce_int(l,2000,0);
	r_tl = slib.coerce_int(r_tl,0,0);
	r_tr = slib.coerce_int(r_tr,-1,-1); if r_tr < 0 then r_tr = r_tl end
	r_br = slib.coerce_int(r_br,-1,-1); if r_br < 0 then r_br = r_tl end
	r_bl = slib.coerce_int(r_bl,-1,-1); if r_bl < 0 then r_bl = r_tl end

	align_h = slib.coerce_real(align_h, 0);
	align_v = slib.coerce_real(align_v, 0);
	if type(corner_fig) ~= "string" then corner_fig = "円" end
	corner_thickcoeff = slib.coerce_real(corner_thickcoeff,-1);

	-- デフォルトな菱形はちょっと特別扱い．
	if corner_fig == "" and corner_thickcoeff < 0 and corner_extrapolate then
		corner_flipcenter = not corner_inv;
	end

	slib.round_rect(color,w,h,l, r_tl,r_tr,r_br,r_bl, corner_fig, corner_inv,
		corner_thickcoeff,corner_flipcenter,corner_extrapolate, back_color,back_alpha);

	obj.cx = obj.cx-w*align_h/2;
	obj.cy = obj.cy-h*align_v/2;
end

local function ellipse(w,h,l,res,color,back_color,back_alpha,load)
	load = load == nil or load == true;

	local size = math.max(w,h);
	if (w == h and back_alpha <= 0) or l >= math.min(w,h)/2 then
		if w == h then obj.load("figure","円",color, res*size, res*l);
		else obj.load("figure","円",color, res*size) end
		if w ~= h or res > 1 then
			obj.effect("リサイズ","X",w,"Y",h,"ドット数でサイズ指定",1);
		end
		if not load then obj.copybuffer("tmp","obj") end
	else
		local w2,h2 = w/2,h/2;
		obj.load("figure","円",color,res*size);
		obj.setoption("dst","tmp",w,h);
		obj.drawpoly(-w2,-h2,0, w2,-h2,0, w2,h2,0, -w2,h2,0);

		w2,h2 = w2-l,h2-l;
		obj.setoption("blend","alpha_sub");
		obj.drawpoly(-w2,-h2,0, w2,-h2,0, w2,h2,0, -w2,h2,0);
		if back_alpha > 0 then
			obj.effect("単色化","color",back_color,"輝度を保持する",0);
			obj.setoption("blend","alpha_add");
			local ww,hh = obj.getpixel();
			obj.drawpoly(-w2,-h2,0, w2,-h2,0, w2,h2,0, -w2,h2,0,
				0,0, ww,0, ww,hh, 0,hh, back_alpha);
		end
		obj.setoption("blend",0);

		if load then obj.copybuffer("obj","tmp") end
	end
end
local function call_ellipse(w,h,l, color,back_color,back_alpha, align_h, align_v, res)
	--track0:幅,0,2000,100,1
	--track1:高さ,0,2000,100,1
	--track2:ライン幅,0,2000,2000,1
	--track3:背景透明度,0,100,100
	--check0:真円,0
	--dialog:色/col,_1=0xffffff;背景色/col,_4=0x000000;水平揃え,_2=0.0;垂直揃え,_3=0.0;精度(1〜8),_5=4;TRACK,_0=nil;
	w = slib.coerce_int(w, 100,0);
	h = slib.coerce_int(h, 100,0);

	if w == 0 or h == 0 then
		obj.setoption("draw_state",true);
		return;
	end

	l = slib.coerce_int(l,2000,0);
	color = slib.coerce_color(color, 0xffffff);
	back_color = slib.coerce_color(back_color, 0x000000);
	back_alpha = slib.coerce_real(back_alpha,0, 0,1);

	align_h = slib.coerce_real(align_h, 0);
	align_v = slib.coerce_real(align_v, 0);
	res = slib.coerce_int(res,4,1,8);

	ellipse(w,h,l,res,color,back_color,back_alpha);

	obj.cx = obj.cx-w*align_h/2;
	obj.cy = obj.cy-h*align_v/2;
end
local function call_diamond_shape(w,h,l, color,back_color,back_alpha, align_h, align_v)
	--track0:幅,0,2000,100,1
	--track1:高さ,0,2000,100,1
	--track2:ライン幅,0,2000,2000,1
	--track3:背景透明度,0,100,100
	--check0:正方形,0
	--dialog:色/col,_1=0xffffff;背景色/col,_2=0x000000;水平揃え,_3=0.0;垂直揃え,_4=0.0;TRACK,_0=nil;
	w = slib.coerce_int(w, 100,0);
	h = slib.coerce_int(h, 100,0);

	if w == 0 or h == 0 then
		obj.setoption("draw_state",true);
		return;
	end

	l = slib.coerce_int(l,2000,0);
	color = slib.coerce_color(color, 0xffffff);
	back_color = slib.coerce_color(back_color, 0x000000);
	back_alpha = slib.coerce_real(back_alpha,0, 0,1);

	align_h = slib.coerce_real(align_h, 0);
	align_v = slib.coerce_real(align_v, 0);

	slib.diamond_shape(color, w,h, l, back_color,back_alpha);

	obj.cx = obj.cx-w*align_h/2;
	obj.cy = obj.cy-h*align_v/2;
end

local function call_round_corners(r_tl, r_tr, r_br, r_bl, corner_fig, corner_inv, precise)
	--track0:左上半径,0,2000,32,1
	--track1:右上半径,0,2000,32,1
	--track2:右下半径,0,2000,32,1
	--track3:左下半径,0,2000,32,1
	--check0:半径均一,1
	--dialog:角図形/fig,_1="円";凹凸反転/chk,_2=0;半透明に配慮/chk,_3=0;TRACK,_0=nil;
	r_tl = slib.coerce_int(r_tl,32,0);
	r_tr = slib.coerce_int(r_tr,32,0);
	r_br = slib.coerce_int(r_br,32,0);
	r_bl = slib.coerce_int(r_bl,32,0);
	if type(corner_fig) ~= "string" then corner_fig = "円" end

	local posinfo = slib.posinfo_save();
	if precise then
		slib.round_corners(nil, r_tl, r_tr, r_br, r_bl, corner_fig, corner_inv);
	else
		slib.round_corners(r_tl, r_tr, r_br, r_bl, corner_fig, corner_inv);
	end
	slib.posinfo_load(posinfo);
end

local function canvas_resize(l,t,r,b, move_pos, fill)
	local w,h = obj.getpixel();

	-- have to be careful not to clip out all the pixels
	local L,T,R,B = math.min(math.max(l,1-w),0),math.min(math.max(t,1-h),0),
		math.min(math.max(r,1-w),0),math.min(math.max(b,1-h),0);
	if L<0 or R<0 or T<0 or B<0 then
		obj.effect("クリッピング", "上",-T,"下",-B,"左",-L,"右",-R,
			"中心の位置を変更",move_pos and 1 or 0);
		l,t,r,b = l-L,t-T,r-R,b-B;
	end

	L,T,R,B = math.max(l,0),math.max(t,0),math.max(r,0),math.max(b,0);
	if L>0 or T>0 or R>0 or B>0 then
		local cx,cy = obj.cx,obj.cy;
		obj.effect("領域拡張","上",T,"下",B,"左",L,"右",R, "塗りつぶし",fill and 1 or 0);
		if move_pos then obj.cx,obj.cy = cx,cy end
		l,t,r,b = l-L,t-T,r-R,b-B;
	end

	if l<0 or r<0 or t<0 or b<0 then
		obj.effect("クリッピング", "上",-t,"下",-b,"左",-l,"右",-r,
			"中心の位置を変更",move_pos and 1 or 0);
	end
end
local function call_canvas_resize(l,t,r,b, move_pos, fill)
	--track0:上,-2000,2000,0,1
	--track1:下,-2000,2000,0,1
	--track2:左,-2000,2000,0,1
	--track3:右,-2000,2000,0,1
	--check0:中心の位置を変更,0
	--dialog:塗りつぶし/chk,_1=0;TRACK,_0=nil;
	l = slib.coerce_int(l,0);
	t = slib.coerce_int(t,0);
	r = slib.coerce_int(r,0);
	b = slib.coerce_int(b,0);
	canvas_resize(l,t,r,b,move_pos,fill);
end

local function call_canvas_resize_rational(l,t,r,b, move_pos, fill)
	--track0:上(%),-100,100,0,0.01
	--track1:下(%),-100,100,0,0.01
	--track2:左(%),-100,100,0,0.01
	--track3:右(%),-100,100,0,0.01
	--check0:中心の位置を変更,0
	--dialog:塗りつぶし/chk,_1=0;TRACK,_0=nil;
	l = slib.coerce_real(l,0);
	t = slib.coerce_real(t,0);
	r = slib.coerce_real(r,0);
	b = slib.coerce_real(b,0);
	local w,h = obj.getpixel();
	canvas_resize(l*w,t*h,r*w,b*h, move_pos,fill);
end

local function canvas_set_size(w,h, x,y, move_pos, fill,
	align_h,disable_h, align_v,disable_v)
	local W,H = obj.getpixel();
	local l,t;
	if disable_h then l,w = 0,W else l = math.ceil(((1-align_h)*w-W)/2-x) end
	if disable_v then t,h = 0,H else t = math.ceil(((1-align_v)*h-H)/2-y) end
	canvas_resize(l,t,w-W-l,h-H-t, move_pos, fill);
end
local function call_canvas_set_size(w,h, x,y, move_pos, fill,
	align_h,disable_h, align_v,disable_v)
	--track0:X,-2000,2000,0,1
	--track1:Y,-2000,2000,0,1
	--track2:幅,1,2000,100,1
	--track3:高さ,1,2000,100,1
	--check0:中心の位置を変更,0
	--dialog:塗りつぶし/chk,_1=0;アンカーXY反転/chk,_2=0;水平揃え,_3=0.0;幅指定無効/chk,_4=0;垂直揃え/chk,_5=0.0;高さ指定無効/chk,_6=0;TRACK,_0=nil;
	if disable_h and disable_v then return end
	w = slib.coerce_int(w,100,1);
	h = slib.coerce_int(h,100,1);
	x = slib.coerce_int(x,0);
	y = slib.coerce_int(y,0);
	align_h = slib.coerce_real(align_h,0);
	align_v = slib.coerce_real(align_v,0);
	canvas_set_size(w,h, x,y, move_pos, fill, align_h,disable_h, align_v,disable_v);
end

local function invert_opacity() return obj.effect("反転","透明度反転",1) end
local function call_push_opacity(alpha, apply_existing)
	--track0:透明度,-100,100,0
	--check0:このフィルタ以前の透明度も適用,0
	--dialog:TRACK,_0=nil;
	alpha = slib.coerce_real(alpha,1,0);

	if apply_existing then
		alpha,obj.alpha = alpha*obj.alpha,1;
	end
	slib.push_opacity(alpha);
end
local function call_force_opacity(alpha)
	--track0:透明度,0,100,0
	--dialog:TRACK,_0=nil;
	alpha = slib.coerce_real(alpha,1,0,1);
	slib.force_opacity(alpha);
end

local function call_fill_back(color, alpha, padding, alpha_f, backonly)
	--track0:透明度,0,100,0
	--track1:前透明度,0,100,0
	--check0:前景クリア,0
	--dialog:背景色/col,_1=0x808080;余白,_2="0";TRACK,_0=nil;
	color = slib.coerce_color(color, 0x808080);
	alpha = slib.coerce_real(alpha,1,0,1);
	local l,t,r,b = slib.parse_thickness(padding);
	l = slib.coerce_int(l,0); t = slib.coerce_int(t,0);
	r = slib.coerce_int(r,0); b = slib.coerce_int(b,0);

	if l ~= 0 or t ~= 0 or r ~= 0 or b ~= 0 then
		canvas_resize(l,t,r,b, false, false);
	end

	if backonly then
		if alpha_f < 1 then slib.push_opacity(alpha_f) end
		invert_opacity();
		obj.effect("単色化","輝度を保持する",0,"color",color);
		if alpha < 1 then slib.push_opacity(alpha) end
	else slib.fill_back(color, alpha, alpha_f) end
end

local function acryl_material(blurtype_lens,blur_rad,blur_asp,blur_light,
	tint_col,tint_int,tint_keep_luma, luma_scale,luma_std,sat_scale,chroma_arg)

	-- apply blur
	if blur_rad > 0 then
		if blurtype_lens then
			obj.effect("レンズブラー","範囲",blur_rad,"光の強さ",blur_light);
		else
			obj.effect("ぼかし","範囲",blur_rad,"縦横比",100*blur_asp,"光の強さ",blur_light,"サイズ固定",1);
		end
	end

	-- apply luma/chroma adjustment
	local luma_add = math.min(math.max(luma_std-luma_scale/2,-1-luma_scale/2),1+luma_scale/2);
	obj.effect("色調補正","明るさ",100*(1+luma_add),
		"輝度",100*luma_scale,"彩度",100*sat_scale,"色相",chroma_arg);
	while luma_add > 1 do
		luma_add = luma_add - 1;
		obj.effect("色調補正","明るさ",100*(1+luma_add));
	end
	while luma_add < -1 do
		luma_add = luma_add + 1;
		obj.effect("色調補正","明るさ",100*(1+luma_add));
	end

	-- apply tint
	if tint_int > 0 then
		obj.effect("単色化","color",tint_col,"強さ",100*tint_int,"輝度を保持する",tint_keep_luma and 1 or 0);
	end
end
local function call_acryl_material(blurtype_lens,blur_rad,blur_asp,blur_light,
	tint_col,tint_int,tint_keep_luma, luma_scale,luma_std,sat_scale,chroma_arg)
	--@アクリル素材
	--track0:ぼかし量,0,300,16,1
	--track1:着色強さ,0,100,20
	--track2:輝度倍率,0,200,30
	--track3:輝度中心,-100,200,50
	--check0:着色で輝度を保持,1
	--dialog:色/col,_1=0x808080;ぼかし縦横比,_2=0;ぼかし光度,_3=0;彩度(0~200%),_4=100;色相,_5=0;TRACK,_0=nil;
	--@磨りガラス素材
	--track0:ぼかし量,0,200,16,1
	--track1:着色強さ,0,100,20
	--track2:輝度倍率,0,200,30
	--track3:輝度中心,-100,200,50
	--check0:着色で輝度を保持,1
	--dialog:色/col,_1=0x808080;ぼかし光度,_2=30;彩度(0~200%),_3=100;色相,_4=0;TRACK,_0=nil;
	blur_rad = slib.coerce_int(blur_rad,16, 0,blurtype_lens and 200 or 300);
	blur_asp = slib.coerce_real(blur_asp,0,-1,1);
	blur_light = slib.coerce_real(blur_light,blurtype_lens and 32 or 0,0,60);
	tint_col = slib.coerce_color(tint_col,0x808080);
	tint_int = slib.coerce_real(tint_int,0.20,0,1);
	luma_scale = slib.coerce_real(luma_scale,0.30,0,2);
	luma_std = slib.coerce_real(luma_std,0.50,-1,2);
	sat_scale = slib.coerce_real(sat_scale,1,0,2);
	chroma_arg = slib.coerce_real(chroma_arg,0)%360;

	acryl_material(blurtype_lens,blur_rad,blur_asp,blur_light,
		tint_col,tint_int,tint_keep_luma, luma_scale,luma_std,sat_scale,chroma_arg);
end

local function acryl_surface(x, y, width, height, blurtype_lens,blur_rad,blur_asp,blur_light,
	tint_col,tint_int,tint_keep_luma, luma_scale,luma_std,sat_scale,chroma_arg)

	-- crop the framebuffer
	-- a bit bigger than the desired one, taking the blur radius into account.
	local bw,bh = slib.size_aspect_to_len(blur_rad,blurtype_lens and 0 or -blur_asp);
	bw,bh = math.ceil(bw),math.ceil(bh);
	obj.copybuffer("obj","frm");
	canvas_set_size(width+2*bw,height+2*bh, x,y, true,true, 0,false, 0,false);

	acryl_material(blurtype_lens,blur_rad,blur_asp,blur_light,
		tint_col, tint_int, tint_keep_luma, luma_scale, luma_std, sat_scale, chroma_arg);

	-- snip off the "extra" edge
	if blur_rad > 0 then
		obj.effect("クリッピング","上",bh,"下",bh,"左",bw,"右",bw);
	end
end
local function call_acryl_surface(x, y, width, height, align_h, align_v,
	blurtype_lens,blur_rad,blur_asp,blur_light,
	tint_col,tint_int,tint_keep_luma, luma_scale,luma_std,sat_scale,chroma_arg)
	--@アクリル矩形
	--track0:幅,1,2000,100,1
	--track1:高さ,1,2000,100,1
	--track2:ぼかし量,0,300,16,1
	--track3:着色強さ,0,100,20
	--check0:着色で輝度を保持,1
	--dialog:色/col,_1=0x808080;水平揃え,_2=0.0;垂直揃え,_3=0.0;ぼかし縦横比,_4=0;ぼかし光度,_5=0;輝度倍率(%),_6=30;輝度中心(%),_7=50;彩度(0~200%),_8=100;色相,_9=0;TRACK,_0=nil;
	--@磨りガラス矩形
	--track0:幅,1,2000,100,1
	--track1:高さ,1,2000,100,1
	--track2:ぼかし量,0,200,16,1
	--track3:着色強さ,0,100,20
	--check0:着色で輝度を保持,1
	--dialog:色/col,_1=0x808080;水平揃え,_2=0.0;垂直揃え,_3=0.0;ぼかし光度,_4=32;輝度倍率(%),_5=30;輝度中心(%),_6=50;彩度(0~200%),_7=100;色相,_8=0;TRACK,_0=nil;
	width = slib.coerce_int(width,100, 1);
	height = slib.coerce_int(height,100, 1);
	align_h = slib.coerce_real(align_h,0);
	align_v = slib.coerce_real(align_v,0);
	blur_rad = slib.coerce_int(blur_rad,16, 0,blurtype_lens and 200 or 300);
	blur_asp = slib.coerce_real(blur_asp,0,-1,1);
	blur_light = slib.coerce_real(blur_light,blurtype_lens and 32 or 0,0,60);
	tint_col = slib.coerce_color(tint_col,0x808080);
	tint_int = slib.coerce_real(tint_int,0.20,0,1);
	luma_scale = slib.coerce_real(luma_scale,0.30,0,2);
	luma_std = slib.coerce_real(luma_std,0.50,-1,2);
	sat_scale = slib.coerce_real(sat_scale,1,0,2);
	chroma_arg = slib.coerce_real(chroma_arg,0)%360;

	obj.cx = obj.cx-width*align_h/2; obj.cy = obj.cy-height*align_v/2;
	acryl_surface(x+width*align_h/2, y+height*align_v/2, width, height,
		blurtype_lens,blur_rad,blur_asp,blur_light,
		tint_col,tint_int,tint_keep_luma, luma_scale,luma_std,sat_scale,chroma_arg);
end

local function call_acrylify(blurtype_lens,blur_rad,blur_asp,blur_light, tint_col,tint_int,tint_keep_luma,
	luma_scale,luma_std,sat_scale,chroma_arg, offset_x, offset_y)
	--@アクリル化
	--track0:ぼかし量,0,300,16,1
	--track1:着色強さ,0,100,20
	--track2:Xずれ,-2000,2000,0,1
	--track3:Yずれ,-2000,2000,0,1
	--check0:着色で輝度を保持,1
	--dialog:単色化/chk,_1=0;└色/col,_2=0x808080;ぼかし縦横比,_3=0;ぼかし光度,_4=0;輝度倍率(%),_5=30;輝度中心(%),_6=50;彩度(0~200%),_7=100;色相,_8=0;TRACK,_0=nil;
	--@磨りガラス化
	--track0:ぼかし量,0,200,16,1
	--track1:着色強さ,0,100,20
	--track2:Xずれ,-2000,2000,0,1
	--track3:Yずれ,-2000,2000,0,1
	--check0:着色で輝度を保持,1
	--dialog:単色化/chk,_1=0;└色/col,_2=0x808080;ぼかし光度,_3=32;輝度倍率(%),_4=30;輝度中心(%),_5=50;彩度(0~200%),_6=100;色相,_7=0;TRACK,_0=nil;
	blur_rad = slib.coerce_int(blur_rad,16, 0,blurtype_lens and 200 or 300);
	blur_asp = slib.coerce_real(blur_asp,0,-1,1);
	blur_light = slib.coerce_real(blur_light,blurtype_lens and 32 or 0,0,60);
	local tint_obj = tint_col == nil;
	tint_col = slib.coerce_color(tint_col,0x808080);
	tint_int = slib.coerce_real(tint_int,0.20,0,1);
	luma_scale = slib.coerce_real(luma_scale,0.30,0,2);
	luma_std = slib.coerce_real(luma_std,0.50,-1,2);
	sat_scale = slib.coerce_real(sat_scale,1,0,2);
	chroma_arg = slib.coerce_real(chroma_arg,0)%360;
	offset_x = slib.coerce_int(offset_x,0);
	offset_y = slib.coerce_int(offset_y,0);

	local posinfo,w,h = slib.posinfo_save(), obj.getpixel();
	obj.copybuffer("cache:obj","obj");

	acryl_surface(obj.x+obj.ox-obj.cx - offset_x, obj.y+obj.oy-obj.cy - offset_y, w,h,
		blurtype_lens,blur_rad,blur_asp,blur_light,
		tint_col,tint_obj and 0 or tint_int,tint_keep_luma,
		luma_scale,luma_std,sat_scale,chroma_arg);

	-- blend the color of the original image
	obj.copybuffer("tmp","obj");
	obj.setoption("dst","tmp");
	if tint_obj and tint_int > 0 then
		obj.copybuffer("obj","cache:obj");
		slib.force_opaque();
		if tint_keep_luma then obj.setoption("blend",9) end
		obj.draw(0,0,0,1,tint_int);
	end

	-- clip by the original object
	obj.copybuffer("obj","cache:obj");
	invert_opacity();
	obj.setoption("blend","alpha_sub");
	obj.draw();
	obj.setoption("blend",0);
	obj.copybuffer("obj","tmp");

	-- restore the positions
	slib.posinfo_load(posinfo);
end

local function place_back_image(pad_l, pad_t, pad_r, pad_b, alpha_b, loaded, alpha_f, cachename)
	local dcx,dcy = (pad_l-pad_r)/2,(pad_t-pad_b)/2;
	if pad_l<0 or pad_t<0 or pad_r<0 or pad_b<0 then
		if not loaded then obj.copybuffer("obj","tmp"); loaded = true end
		local L,T,R,B = math.ceil(math.max(-pad_l,0)),math.ceil(math.max(-pad_t,0)),
			math.ceil(math.max(-pad_r,0)),math.ceil(math.max(-pad_b,0));
		obj.effect("領域拡張","上",T,"下",B,"左",L,"右",R);
		dcx,dcy = dcx+(L-R)/2,dcy+(T-B)/2;
	end
	if alpha_b < 1 then
		if not loaded then obj.copybuffer("obj","tmp") end
		loaded = ffi ~= nil;
		slib.push_opacity(alpha_b,loaded);
	end

	if loaded then obj.copybuffer("tmp","obj") end
	obj.copybuffer("obj",cachename);
	obj.setoption("dst","tmp");
	obj.draw(dcx,dcy,0,1,alpha_f);
	obj.copybuffer("obj","tmp");

	return dcx, dcy;
end

local function call_back_rectangle(color,back_color,back_alpha,thick,alpha, r_tl, r_tr, r_br, r_bl,
	corner_fig,corner_inv,corner_thickcoeff,corner_flipcenter,corner_extrapolate, alpha_f, padding)
	--track0:ライン幅,0,2000,2000,1
	--track1:角半径,0,2000,32,1
	--track2:透明度,0,100,0
	--track3:前透明度,0,100,0
	--check0:角丸凹凸反転,0
	--dialog:色/col,_1=0x808080;背景色/col,_2=0x808080;背景透明度,_3=100;余白,_4="0";角丸図形/fig,_5="円";└縁幅比率,_6=-1;└中心反転/chk,_7=0;└内側補外/chk,_8=1;右上半径,_9=-1;右下半径,_10=-1;左下半径,_11=-1;TRACK,_0=nil;
	color = slib.coerce_color(color,0x808080);
	back_color = slib.coerce_color(back_color, 0x808080);
	back_alpha = slib.coerce_real(back_alpha,0, 0,1);
	thick = slib.coerce_int(thick, 2000,0);
	alpha = slib.coerce_real(alpha, 1,0,1);
	r_tl = slib.coerce_int(r_tl, 32,0);
	r_tr = slib.coerce_int(r_tr, -1,-1); if r_tr < 0 then r_tr = r_tl end
	r_br = slib.coerce_int(r_br, -1,-1); if r_br < 0 then r_br = r_tl end
	r_bl = slib.coerce_int(r_bl, -1,-1); if r_bl < 0 then r_bl = r_tl end
	if type(corner_fig) ~= "string" then corner_fig = "円" end
	corner_thickcoeff = slib.coerce_real(corner_thickcoeff,-1);

	-- デフォルトな菱形はちょっと特別扱い．
	if corner_fig == "" and corner_thickcoeff < 0 and corner_extrapolate then
		corner_flipcenter = not corner_inv;
	end

	alpha_f = slib.coerce_real(alpha_f, 1,0,1);
	local l,t,r,b = slib.parse_thickness(padding);
	l = slib.coerce_int(l,0); t = slib.coerce_int(t,0);
	r = slib.coerce_int(r,0); b = slib.coerce_int(b,0);

	local w,h = obj.getpixel(); w,h = w+l+r, h+t+b;
	if w <= 0 or h <= 0 or thick <= 0 then
		if alpha_f < 1 then slib.push_opacity(alpha_f) end
		return;
	end

	local posinfo = slib.posinfo_save();
	obj.copybuffer("cache:obj","obj");

	slib.round_rect(color,w,h,thick, r_tl,r_tr,r_br,r_bl,
		corner_fig,corner_inv,corner_thickcoeff,corner_flipcenter,corner_extrapolate,
		back_color,back_alpha, false);
	local dcx, dcy = place_back_image(l,t,r,b, alpha,false, alpha_f, "cache:obj");

	slib.posinfo_load(posinfo);
	obj.cx, obj.cy = obj.cx+dcx, obj.cy+dcy;
end

local function call_back_ellipse(color,back_color,back_alpha, thick,res,alpha, alpha_f, padding, tangent,circle)
	--track0:ライン幅,0,2000,2000,1
	--track1:精度,1,8,4,1
	--track2:透明度,0,100,0
	--track3:前透明度,0,100,0
	--check0:内接する,1
	--dialog:色/col,_1=0x808080;背景色/col,_2=0x808080;背景透明度,_3=100;余白,_4="0";真円/chk,_5=0;TRACK,_0=nil;
	color = slib.coerce_color(color,0x808080);
	back_color = slib.coerce_color(back_color, 0x808080);
	back_alpha = slib.coerce_real(back_alpha,0, 0,1);
	thick = slib.coerce_int(thick, 2000,0);
	res = slib.coerce_int(res,4,1,8);
	alpha = slib.coerce_real(alpha,1,0,1);
	alpha_f = slib.coerce_real(alpha_f,1,0,1);
	local l,t,r,b = slib.parse_thickness(padding);
	l = slib.coerce_int(l,0); t = slib.coerce_int(t,0);
	r = slib.coerce_int(r,0); b = slib.coerce_int(b,0);

	local w,h = obj.getpixel(); w,h = w+l+r, h+t+b;
	if tangent then
		local dx,dy;
		if circle then
			local dia = math.floor((w^2+h^2)^0.5);
			dx,dy = dia-w,dia-h;
		else dx,dy = math.floor((2^0.5-1)*w),math.floor((2^0.5-1)*h) end
		w,l,r = w+dx,l+dx/2,r+dx/2;
		h,t,b = h+dy,t+dy/2,b+dy/2;
	elseif circle then
		if w < h then w,l,r = h,l+(h-w)/2,r+(h-w)/2;
		else h,t,b = w,t+(w-h)/2,b+(w-h)/2 end
	end
	if w <= 0 or h <= 0 or thick <= 0 then
		if alpha_f < 1 then slib.push_opacity(alpha_f) end
		return;
	end

	local posinfo = slib.posinfo_save();
	obj.copybuffer("cache:obj","obj");

	ellipse(w,h,thick,res,color,back_color,back_alpha, false);
	local dcx, dcy = place_back_image(l,t,r,b, alpha,false, alpha_f, "cache:obj");

	slib.posinfo_load(posinfo);
	obj.cx, obj.cy = obj.cx+dcx, obj.cy+dcy;
end
local function call_back_diamond(color,back_color,back_alpha, thick,alpha, alpha_f, padding, tangent,square)
	--track0:ライン幅,0,2000,2000,1
	--track1:透明度,0,100,0
	--track2:前透明度,0,100,0
	--check0:内接する,1
	--dialog:色/col,_1=0x808080;背景色/col,_2=0x808080;背景透明度,_3=100;余白,_4="0";正方形/chk,_5=0;TRACK,_0=nil;
	color = slib.coerce_color(color,0x808080);
	back_color = slib.coerce_color(back_color, 0x808080);
	back_alpha = slib.coerce_real(back_alpha,0, 0,1);
	thick = slib.coerce_int(thick, 2000,0);
	alpha = slib.coerce_real(alpha,1,0,1);
	alpha_f = slib.coerce_real(alpha_f,1,0,1);
	local l,t,r,b = slib.parse_thickness(padding);
	l = slib.coerce_int(l,0); t = slib.coerce_int(t,0);
	r = slib.coerce_int(r,0); b = slib.coerce_int(b,0);

	local w,h = obj.getpixel(); w,h = w+l+r, h+t+b;
	if tangent then
		local dx,dy;
		if square then dx,dy = h,w else dx,dy = w,h end
		w,l,r = w+dx,l+dx/2,r+dx/2;
		h,t,b = h+dy,t+dy/2,b+dy/2;
	elseif square then
		if w < h then w,l,r = h,l+(h-w)/2,r+(h-w)/2;
		else h,t,b = w,t+(w-h)/2,b+(w-h)/2 end
	end
	if w <= 0 or h <= 0 or thick <= 0 then
		if alpha_f < 1 then slib.push_opacity(alpha_f) end
		return;
	end

	local posinfo = slib.posinfo_save();
	obj.copybuffer("cache:obj","obj");

	slib.diamond_shape(color,w,h,thick, back_color,back_alpha);
	local dcx, dcy = place_back_image(l,t,r,b, alpha,true, alpha_f, "cache:obj");

	slib.posinfo_load(posinfo);
	obj.cx, obj.cy = obj.cx+dcx, obj.cy+dcy;
end

local function call_align_center(align_h, align_v, offset_x, offset_y,
	move_center, relative_x,relative_y)
	--track0:左右%,-100,100,0,0.01
	--track1:上下%,-100,100,0,0.01
	--track2:Xずれ,-2000,2000,0
	--track3:Yずれ,-2000,2000,0
	--check0:回転中心を移動,1
	--dialog:割合倍率,_1=1.00;X相対指定/chk,_2=0;Y相対指定/chk,_3=0;TRACK,_0=nil;
	align_h = slib.coerce_real(align_h,0);
	align_v = slib.coerce_real(align_v,0);
	offset_x = slib.coerce_real(offset_x,0);
	offset_y = slib.coerce_real(offset_y,0);

	local w,h = obj.getpixel();
	local x,y = w*align_h/2+offset_x,h*align_v/2+offset_y;
	if move_center then
		if relative_x then obj.cx = obj.cx-x else obj.cx = -x end
		if relative_y then obj.cy = obj.cy-y else obj.cy = -y end
	else
		if relative_x then obj.ox = obj.ox+x else obj.ox = x end
		if relative_y then obj.oy = obj.oy+y else obj.oy = y end
	end
end
local function move_center(cx,cy,cz,pos_before_rot,move_relpos,absolute)
	if absolute then cx,cy,cz = cx-obj.ox,cy-obj.oy,cz-obj.oz end
	if pos_before_rot then
		obj.cx,obj.cy,obj.cz = obj.cx+cx,obj.cy+cy,obj.cz+cz;
		if move_relpos then
			local ox,oy,oz = srot.rotation.rotate_euler(
				cx,cy,cz, deg2rad*obj.rx,deg2rad*obj.ry,deg2rad*obj.rz);
			obj.ox,obj.oy,obj.oz = obj.ox+ox,obj.oy+oy,obj.oz+oz;
		end
	else
		if move_relpos then
			obj.ox,obj.oy,obj.oz = obj.ox+cx,obj.oy+cy,obj.oz+cz;
		end
		cx,cy,cz = srot.rotation.rotate_euler(
			cx,cy,cz, deg2rad*obj.rx,deg2rad*obj.ry,deg2rad*obj.rz,true);
		obj.cx,obj.cy,obj.cz = obj.cx+cx,obj.cy+cy,obj.cz+cz;
	end
end
local function call_move_center(cx,cy,cz,pos_before_rot,move_relpos,absolute)
	--track0:X,-2000,2000,0
	--track1:Y,-2000,2000,0
	--track2:Z,-2000,2000,0
	--check0:回転前の座標で指定,0
	--dialog:相対座標連動/chk,_1=1;移動量で指定/chk,_2=0;TRACK,_0=nil;
	cx = slib.coerce_real(cx,0);
	cy = slib.coerce_real(cy,0);
	cz = slib.coerce_real(cz,0);
	move_center(cx,cy,cz,pos_before_rot,move_relpos,absolute);
end
local function call_move_center_absolute(cx,cy,cz,pos_before_rot)
	--track0:X,-2000,2000,0
	--track1:Y,-2000,2000,0
	--track2:Z,-2000,2000,0
	--check0:回転前の座標で指定,0
	--dialog:TRACK,_0=nil;
	cx = slib.coerce_real(cx,0);
	cy = slib.coerce_real(cy,0);
	cz = slib.coerce_real(cz,0);

	obj.ox,obj.oy,obj.oz, cx,cy,cz
		= cx-obj.x,cy-obj.y,cz-obj.z,
			cx-obj.x-obj.ox,cy-obj.y-obj.oy,cz-obj.z-obj.oz;
	move_center(cx,cy,cz,pos_before_rot,false,false);
end

local function rotate_draw_quat(camera_z, draw, culling, a,b,c,d)
	if obj.rx ~= 0 or obj.ry ~= 0 or obj.rz ~= 0 then
		a,b,c,d = srot.quaternion.mult(a,b,c,d,
			srot.rotation.euler2quat(deg2rad*obj.rx,deg2rad*obj.ry,deg2rad*obj.rz));
	end
	if draw then
		local a11,a12,a13,a21,a22,a23,a31,a32,a33 = srot.rotation.quat2matrix(a,b,c,d);
		local sx, sy = slib.size_aspect_to_len(obj.zoom,obj.aspect);
		slib.transform_project1024(srot.rotation.rotate_func_matrix(
			sx*a11, sy*a12, a13,
			sx*a21, sy*a22, a23,
			sx*a31, sy*a32, a33),
			obj.z+obj.oz-camera_z, culling);
		obj.oz,obj.zoom,obj.aspect = -obj.z,1,0;
		-- obj.zoom,obj.aspect = (1+(obj.z+obj.oz)/1024),0;
		obj.rx,obj.ry,obj.rz = 0,0,0;
	else
		local ax,ay,az = srot.rotation.quat2euler(a,b,c,d);
		obj.rx,obj.ry,obj.rz = ax/deg2rad,ay/deg2rad,az/deg2rad;
	end
end
local function call_rotation_euler(rx,ry,rz, camera_z, draw, culling)
	--track0:X軸回転,-360,360,0,0.01
	--track1:Y軸回転,-360,360,0,0.01
	--track2:Z軸回転,-360,360,0,0.01
	--track3:カメラZ,-2048,0,-1024
	--check0:描画,0
	--dialog:裏面を描画しない/chk,_1=0;TRACK,_0=nil;
	rx = slib.coerce_real(rx,0);
	ry = slib.coerce_real(ry,0);
	rz = slib.coerce_real(rz,0);
	camera_z = slib.coerce_real(camera_z,-1024,-2048,0);

	rotate_draw_quat(camera_z, draw, culling,
		srot.rotation.euler2quat(deg2rad*rx,deg2rad*ry,deg2rad*rz));
end
local function call_rotation_axis(angle, axisX,axisY,axisZ, camera_z, draw, culling)
	--track0:軸X成分,-200,200,100,0.01
	--track1:軸Y成分,-200,200,0,0.01
	--track2:軸Z成分,-200,200,0,0.01
	--track3:回転角度,-360,360,0,0.01
	--check0:描画,0
	--dialog:カメラZ,_1=-1024;裏面を描画しない/chk,_2=0;TRACK,_0=nil;
	angle = slib.coerce_real(angle,0);
	axisX = slib.coerce_real(axisX,100);
	axisY = slib.coerce_real(axisY,0);
	axisZ = slib.coerce_real(axisZ,0);
	if axisX == 0 and axisY == 0 and axisZ == 0 then axisX = 1 end
	camera_z = slib.coerce_real(camera_z,-1024,-2048,0);

	rotate_draw_quat(camera_z, draw, culling,
		srot.rotation.quat_from_rot(deg2rad*angle, axisX,axisY,axisZ));
end
local function skew(slope, offset,direction, from_center)
	local w2,h2 = obj.getpixel(); w2,h2 = w2/2,h2/2;
	local c,s = math.cos(direction),math.sin(direction);
	local cx,cy = -offset*s,offset*c;
	if from_center then cx,cy = cx+obj.cx,cy+obj.cy end

	local pts = { -w2,-h2, w2,-h2, w2,h2, -w2,h2, obj.cx, obj.cy };
	local bbl,bbr, bbt, bbb;
	for i=1,9,2 do
		local x,y = pts[i],pts[i+1];
		x,y = x-cx,y-cy;
		x,y = c*x-s*y,s*x+c*y;
		x = x-slope*y;
		x,y = c*x+s*y,-s*x+c*y;
		x,y = x+cx,y+cy;
		pts[i],pts[i+1] = x,y;

		if i == 1 then bbl,bbr, bbt,bbb = x,x, y,y;
		elseif i < 9 then
			if x < bbl then bbl = x elseif x > bbr then bbr = x end
			if y < bbt then bbt = y elseif y > bbb then bbb = y end
		end
	end

	local bbox,bboy = (bbl+bbr)/2,(bbt+bbb)/2;
	obj.setoption("dst","tmp",bbr-bbl,bbb-bbt);
	obj.drawpoly(
		pts[1]-bbox,pts[2]-bboy,0,
		pts[3]-bbox,pts[4]-bboy,0,
		pts[5]-bbox,pts[6]-bboy,0,
		pts[7]-bbox,pts[8]-bboy,0);
	obj.copybuffer("obj","tmp");
	obj.ox, obj.cx = obj.ox+pts[ 9]-obj.cx, pts[ 9]-bbox
	obj.oy, obj.cy = obj.oy+pts[10]-obj.cy, pts[10]-bboy;
end
local function call_skew(angle,slope, offset,direction, from_center)
	--track0:角度,-80,80,0,0.01
	--track1:傾き%,-500,500,0
	--track2:中心,-2000,2000,0,0.01
	--track3:基準軸,-360,360,0,0.01
	--check0:回転中心基準,1
	--dialog:TRACK,_0=nil;
	angle = slib.coerce_real(angle,0,-89,89); -- up to 89 deg, despite of the limit of track0
	slope = slib.coerce_real(slope,0,-40,40); -- up to 4000%, despite of the limit of track1
	offset = slib.coerce_real(offset,0);
	direction = slib.coerce_real(direction,0)%360;

	skew(math.tan(deg2rad*angle)+slope, offset, deg2rad*direction, from_center);
end

local midrange_clipping_per_axis do
	local function set_gap_H(w,h, l,r, W)
		obj.setoption("dst","tmp",W,h);
		obj.drawpoly(-W/2,-h/2,0, -W/2+l,-h/2,0, -W/2+l,h/2,0, -W/2,h/2,0,
			0,0, l,0, l,h, 0,h);
		obj.drawpoly(W/2-w+r,-h/2,0, W/2,-h/2,0, W/2,h/2,0, W/2-w+r,h/2,0,
			r,0, w,0, w,h, r,h);
	end
	local function set_gap_V(h,w, t,b, H)
		obj.setoption("dst","tmp",w,H);
		obj.drawpoly(-w/2,-H/2,0, w/2,-H/2,0, w/2,-H/2+t,0, -w/2,-H/2+t,0,
			0,0, w,0, w,t, 0,t);
		obj.drawpoly(-w/2,H/2-h+b,0, w/2,H/2-h+b,0, w/2,H/2,0, -w/2,H/2,0,
			0,b, w,b, w,h, 0,h);
	end
	local function set_gap(sz1,sz2, rg_lo,rg_hi, gap, horiz)
		if rg_hi <= 0 then
			if gap > 0 then obj.effect("領域拡張",horiz and "左" or "上",gap) end
			return rg_hi-rg_lo;
		elseif rg_lo <= 0 then
			if rg_hi >= sz1 then return nil end
			local lbl = horiz and "左" or "上";
			obj.effect("クリッピング",lbl,rg_hi);
			if gap > 0 then obj.effect("領域拡張",lbl,gap) end
			return -rg_lo;
		elseif rg_hi <= sz1 then
			(horiz and set_gap_H or set_gap_V)(
				sz1,sz2, rg_lo,rg_hi, sz1+rg_lo-rg_hi+gap);
			obj.copybuffer("obj","tmp");
			return 0;
		elseif rg_lo < sz1 then
			local lbl = horiz and "右" or "下";
			obj.effect("クリッピング",lbl,sz1-rg_lo);
			if gap > 0 then obj.effect("領域拡張",lbl,gap) end
			return sz1-rg_hi;
		else
			if gap > 0 then obj.effect("領域拡張",horiz and "右" or "下",gap) end
			return rg_lo-rg_hi;
		end
	end

	local function configure_grad(gap,len, ...)
		-- this turned out to be a very delicate and complicated adjustment,
		-- to hide "dips" or "lumps" of alpha values produced by "斜めクリッピング".
		if len == 0 then gap,len = gap-2,1;
		elseif len < 2 or len%2 == 0 then gap = gap-1;
		else len = len-1 end

		if gap > 0 then
			obj.effect("斜めクリッピング","ぼかし",gap,"幅",-len, ...);
			obj.setoption("blend","alpha_add");
		else obj.setoption("blend","alpha_max") end
	end
	local function set_grad_H(gap, w,h, l,r, W)
		configure_grad(gap,r-l, "中心X",math.floor((l+r-w)/2),"角度",90);
		set_gap_H(w,h, l,r, W);
	end
	local function set_grad_V(gap, h,w, t,b, H)
		configure_grad(gap,b-t, "中心Y",math.floor((t+b-h)/2));
		set_gap_V(h,w, t,b, H);
	end
	local function set_grad(sz1,sz2, rg_lo,rg_hi, gap, horiz)
		gap = -gap; -- gap is now positive
		if rg_hi <= 0 then return rg_hi-rg_lo+gap;
		elseif rg_lo <= 0 then
			if rg_hi >= sz1 then return nil end
			obj.effect("クリッピング",horiz and "左" or "上",rg_hi);
			return -rg_lo+gap;
		elseif rg_hi <= sz1 then
			local gap2 = math.min(rg_lo,sz1-rg_hi,gap);
			(horiz and set_grad_H or set_grad_V)(gap2,
				sz1,sz2, rg_lo,rg_hi, sz1+rg_lo-rg_hi-gap2);
			obj.setoption("blend",0);
			obj.copybuffer("obj","tmp");

			local delta_c1,delta_c2 = math.max(gap-rg_lo,0),math.max(gap-sz1+rg_hi,0);
			if delta_c1+delta_c2 > gap then
				local r = gap/(2*gap - (delta_c1+delta_c2));
				-- delta_c1,delta_c2 = math.floor(r*delta_c1),math.floor(r*delta_c2);
				delta_c1,delta_c2 = math.floor(0.5+r*(delta_c1-delta_c2)),0;
			end
			return delta_c1-delta_c2, gap-gap2;
		elseif rg_lo < sz1 then
			obj.effect("クリッピング",horiz and "右" or "下",sz1-rg_lo);
			return -(rg_hi-sz1+gap);
		else return -(rg_hi-rg_lo+gap) end
	end

	local function find_range(size, pos, range, align)
		pos = pos + math.ceil((size - range*(1-align)) / 2);
		return pos, pos + range;
	end
	function midrange_clipping_per_axis(sz1,sz2, pos,range, align, gap, horiz)
		if range == 0 and gap == 0 then return 0,sz1 end

		local rg_lo,rg_hi = find_range(sz1, pos, range, align);
		local delta_c, ex_size = (gap >= 0 and set_gap or set_grad)(
			sz1,sz2, rg_lo,rg_hi, gap, horiz);

		if delta_c == nil then
			obj.setoption("draw_state",true);
			return 0, 0;
		end

		ex_size = ex_size or math.abs(delta_c);
		return (range - gap)/2 * align + delta_c/2,
			sz1-range+gap + ex_size;
	end
end
local function call_midrange_clipping(x,width,y,height, gap_w,gap_h, align_h,align_v, move_pos)
	--track0:X,-2000,2000,0,1
	--track1:Y,-2000,2000,0,1
	--track2:幅,0,2000,0,1
	--track3:高さ,0,2000,0,1
	--check0:中心の位置を変更,0
	--dialog:余白幅,_1=0;余白高さ,_2=0;水平揃え,_3=0.0;垂直揃え,_4=0.0;TRACK,_=nil;
	x = slib.coerce_int(x,0);
	width = slib.coerce_int(width,0,0);
	gap_w = slib.coerce_int(gap_w,0);
	y = slib.coerce_int(y,0);
	height = slib.coerce_int(height,0,0);
	gap_h = slib.coerce_int(gap_h,0);
	align_h = slib.coerce_real(align_h,0);
	align_v = slib.coerce_real(align_v,0);

	local cx,cy,w,h = obj.cx, obj.cy, obj.getpixel();
	local dcx, dcy;
	dcx,w = midrange_clipping_per_axis(w,h,x,width, align_h, gap_w, true);
	dcy = midrange_clipping_per_axis(h,w,y,height,align_v, gap_h, false);
	if not move_pos then cx,cy = cx+dcx,cy+dcy end
	obj.cx,obj.cy = cx,cy;
end

local function call_pizza_cut(a_from, a_to, cx,cy, blur, precise)
	--track0:中心X,-2000,2000,0,1
	--track1:中心Y,-2000,2000,0,1
	--track2:開始角,-720,720,0,0.01
	--track3:終了角,-720,720,0,0.01
	--check0:指定範囲を残す,0
	--dialog:ぼかし角度,_1=0;半透明に配慮/chk,_2=0;TRACK,_0=nil;
	a_from = slib.coerce_real(a_from, 0);
	a_to = slib.coerce_real(a_to, 0);
	cx = slib.coerce_int(cx,0);
	cy = slib.coerce_int(cy,0);
	blur = slib.coerce_real(blur,0, 0,180);

	slib.pizza_cut(a_from, a_to, cx, cy, blur, not precise);
end

local function apply_file_pattern(file,offset_x,offset_y,handle_alpha,cachename)
	obj.effect("画像ファイル合成","ループ画像",1, "mode",2, "file",file,
		"X",offset_x,"Y",offset_y);
	if handle_alpha then
		if cachename then obj.copybuffer(cachename,"tmp") end
		obj.copybuffer("tmp","obj");

		invert_opacity();
		obj.effect("画像ファイル合成","ループ画像",1, "file",file,
			"X",offset_x,"Y",offset_y);
		invert_opacity();
		obj.setoption("blend","alpha_sub");
		obj.draw();
		obj.setoption("blend",0);

		obj.copybuffer("obj","tmp");
		if cachename then obj.copybuffer("tmp",cachename) end
	end
end
local function inner_shadow(file,color,alpha,offset_x,offset_y,radius,handle_alpha)
	local posinfo = slib.posinfo_save();

	obj.copybuffer("tmp","obj");
	obj.setoption("dst","tmp");
	local dx,dy,im_x,im_y do
		local l,r,u,d = radius+offset_x,radius-offset_x,radius+offset_y,radius-offset_y;
		l,r,u,d = math.max(0,l),math.max(0,r),math.max(0,u),math.max(0,d);
		dx,dy = (l-r)/2,(u-d)/2; im_x,im_y = l,u;
		obj.effect("領域拡張","左",l,"右",r,"上",u,"下",d);
	end
	invert_opacity();
	obj.copybuffer("cache:obj","obj");
	obj.setoption("blend","alpha_add");
	obj.draw(-dx,-dy);
	obj.setoption("blend",0);

	obj.effect("単色化","輝度を保持する",0,"color",color or 0); -- in case the file doesn't exist
	if radius>0 then obj.effect("ぼかし","範囲",radius) end;
	if file then
		apply_file_pattern(file, im_x-offset_x+radius, im_y-offset_y+radius,
			handle_alpha, "cache:tmp");
	end
	obj.draw(offset_x-dx,offset_y-dy,0,1,alpha);

	obj.copybuffer("obj","cache:obj");
	obj.setoption("blend","alpha_sub");
	obj.draw(-dx,-dy);
	obj.setoption("blend",0);

	obj.copybuffer("obj","tmp");

	slib.posinfo_load(posinfo);
end
local function call_inner_shadow(file_or_color,alpha, offset_x,offset_y, radius, handle_alpha)
	--track0:X,-200,200,-40,1
	--track1:Y,-200,200,24,1
	--track2:濃さ,0,100,40
	--track3:拡散,0,50,10,1
	--dialog:色/col,_1=0x000000;パターン画像,_2=[[]];└α値適用/chk,_3=1;TRACK,_0=nil;
	local file,color;
	if type(file_or_color) == "string" then file = file_or_color;
	else color = slib.coerce_color(file_or_color,0) end
	alpha = slib.coerce_real(alpha,0.4,0,1);
	offset_x = slib.coerce_int(offset_x,-40);
	offset_y = slib.coerce_int(offset_y,24);
	radius = slib.coerce_int(radius,10,0,50);

	inner_shadow(file,color,alpha,offset_x,offset_y,radius,handle_alpha);
end

local function alpha_border(size, blur, border_alpha,inner_alpha, file,handle_alpha,ofs_x,ofs_y, color)
	local w,h = obj.getpixel();
	obj.setoption("dst","tmp",w+2*size,h+2*size);
	obj.draw(0,0,0, 1,inner_alpha);
	obj.copybuffer("cache:obj","tmp");
	if inner_alpha < 1 then
		obj.setoption("dst","tmp",w+2*size,h+2*size);
		obj.draw();
	end
	obj.effect("縁取り","サイズ",size, "ぼかし",blur);
	invert_opacity();
	obj.setoption("blend","alpha_add");
	obj.draw();
	obj.copybuffer("obj","tmp");
	invert_opacity();
	obj.effect("単色化","輝度を保持する",0,"color",color or 0); -- in case the file doesn't exist.
	if file then apply_file_pattern(file, size+ofs_x, size+ofs_y, handle_alpha) end

	obj.copybuffer("tmp","cache:obj");
	obj.draw(0,0,0, 1,border_alpha);
	obj.setoption("blend",0);
	obj.copybuffer("obj","tmp");
end
local function call_alpha_border(size, blur, border_alpha,inner_alpha, file_or_color, handle_alpha, offset_x,offset_y)
	--track0:サイズ,0,500,3,1
	--track1:ぼかし,0,100,10,1
	--track2:縁透明度,0,100,0
	--track3:内透明度,0,100,0
	--dialog:縁色の設定/col,_1=0x0;パターン画像,_2=[[]];└α値適用/chk,_3=1;└X位置,_4=0;└Y位置,_5=0;TRACK,_0=nil;
	size = slib.coerce_int(size,3, 0,500);
	inner_alpha = slib.coerce_real(inner_alpha,1, 0,1);
	border_alpha = slib.coerce_real(border_alpha,1, 0,1);
	if size <= 0 or border_alpha <= 0 then
		if inner_alpha < 1 then slib.push_opacity(inner_alpha) end
		return;
	end
	blur = slib.coerce_int(blur,10, 0,100);

	local file, color;
	if type(file_or_color) == "string" then
		file = file_or_color;
		offset_x = slib.coerce_int(offset_x, 0);
		offset_y = slib.coerce_int(offset_y, 0);
	else color = slib.coerce_color(file_or_color, 0) end

	alpha_border(size, blur, border_alpha,inner_alpha, file,handle_alpha,offset_x,offset_y, color);
end

local function inner_border(size, blur, border_alpha,inner_alpha, file,handle_alpha,ofs_x,ofs_y, color, erase,trim)
	local w,h = obj.getpixel();
	if inner_alpha < 1 then
		obj.setoption("dst","tmp",w,h);
		obj.draw(0,0,0, 1,inner_alpha);
	else
		obj.setoption("dst","tmp");
		obj.copybuffer("tmp","obj");
	end
	do local W,H = obj.getinfo("image_max");
		local sz_blur = math.max(math.min(math.ceil(size*blur/50),size),1);
		W = math.max(math.min(sz_blur, math.floor((W-w)/2)-size),0);
		H = math.max(math.min(sz_blur, math.floor((H-h)/2)-size),0);
		obj.effect("領域拡張","上",H,"下",H,"左",W,"右",W);
		ofs_x = ofs_x+W; ofs_y = ofs_y+H;
	end
	invert_opacity();

	obj.setoption("blend","alpha_add");
	if erase then
		obj.draw(0,0,0, 1,border_alpha*inner_alpha);
		obj.effect("縁取り","サイズ",size, "ぼかし",blur);
		obj.setoption("blend","alpha_sub");
		obj.draw(0,0,0, 1,border_alpha*inner_alpha);
		obj.setoption("blend",0);
	else
		obj.copybuffer("cache:obj","obj");
		obj.draw(0,0,0, 1,inner_alpha);
		obj.effect("縁取り","サイズ",size, "ぼかし",blur);
		obj.effect("単色化","輝度を保持する",0,"color",color or 0); -- in case the file doesn't exist.
		if file then apply_file_pattern(file, size+ofs_x, size+ofs_y, handle_alpha,"cache:tmp") end
		obj.setoption("blend",0);
		obj.draw(0,0,0, 1,border_alpha);

		obj.copybuffer("obj","cache:obj");
		-- if file and handle_alpha then
		--
		-- end
		obj.setoption("blend","alpha_sub");
		obj.draw(0,0,0, 1,border_alpha+inner_alpha - border_alpha*inner_alpha);
		obj.setoption("blend",0);
	end
	obj.copybuffer("obj","tmp");

	if erase and trim and border_alpha >= 1 then
		local sz_blur = math.floor(size*(1-2*(blur/100)^2));
		if sz_blur > 0 then
			obj.effect("クリッピング","上",sz_blur,"下",sz_blur,"左",sz_blur,"右",sz_blur);
		end
	end
end
local function call_inner_border(size, blur, border_alpha,inner_alpha, file_or_color, trim_or_handle_alpha, offset_x,offset_y)
	--track0:サイズ,0,500,3,1
	--track1:ぼかし,0,100,10,1
	--track2:縁透明度,0,100,0
	--track3:内透明度,0,100,0
	--check0:縁を除去,0
	--dialog:縁色の設定/col,_1=0x0;パターン画像,_2=[[]];└α値適用/chk,_3=1;└X位置,_4=0;└Y位置,_5=0;縁除去で縮小/chk,_6=0;TRACK,_0=nil;
	size = slib.coerce_int(size,3, 0,500);
	inner_alpha = slib.coerce_real(inner_alpha,1, 0,1);
	border_alpha = slib.coerce_real(border_alpha,1, 0,1);
	if size <= 0 or border_alpha <= 0 then
		if inner_alpha < 1 then slib.push_opacity(inner_alpha) end
		return;
	end
	blur = slib.coerce_int(blur,10, 0,100);

	local file, color, erase;
	if file_or_color == nil then erase = true;
	elseif type(file_or_color) == "string" then
		file = file_or_color;
		offset_x = slib.coerce_int(offset_x, 0);
		offset_y = slib.coerce_int(offset_y, 0);
	else color = slib.coerce_color(file_or_color, 0) end

	inner_border(size, blur, border_alpha,inner_alpha, file,trim_or_handle_alpha,offset_x,offset_y, color, erase,trim_or_handle_alpha);
end

local place_light_shadow if ffi then
	local pint = ffi.typeof("int32_t*");
	local array_ld = ffi.new("int32_t[256]"); array_ld[128] = 0;
	function place_light_shadow(convex,alpha_l,color_l, alpha_d,color_d)
		local data,w,h = obj.getpixeldata();
		alpha_l = 255/127*alpha_l; alpha_d = 255/128*alpha_d;
		for i=0,127 do
			array_ld[i] = bor(lshift((128-i)*alpha_d,24),color_d);
		end
		for i=129,255 do
			array_ld[i] = bor(lshift((i-128)*alpha_l,24),color_l);
		end

		local ptr = ffi.cast(pint,data);
		for i=0,w*h-1 do ptr[i] = array_ld[band(ptr[i],255)] end
		obj.putpixeldata(data);

		if convex then obj.copybuffer("tmp","obj") else obj.draw() end
	end
else
	function place_light_shadow(convex,alpha_l,color_l, alpha_d,color_d)
		if convex then obj.setoption("dst","tmp",obj.getpixel()) end

		obj.copybuffer("cache:tmp","obj");
		obj.effect("ルミナンスキー","基準輝度",0,"ぼかし",2048,"type",1);
		obj.effect("単色化","color",color_d,"輝度を保持する",0);
		obj.draw(0,0,0,1,alpha_d);

		obj.copybuffer("obj","cache:tmp");
		obj.effect("ルミナンスキー","基準輝度",4096,"ぼかし",2048,"type",0);
		obj.effect("単色化","color",color_l,"輝度を保持する",0);
		obj.draw(0,0,0,1,alpha_l);
	end
end
local function neumorphism(size, blur, color_l,alpha_l, color_d,alpha_d, angle)
	if size == 0 or (alpha_l <= 0 and alpha_d <= 0) then
		if size > 0 then
			local sz = size+blur;
			obj.effect("領域拡張","左",sz,"右",sz,"上",sz,"下",sz);
		end
		return;
	end

	obj.copybuffer("cache:obj","obj");

	local convex = size > 0;
	if not convex then
		angle,size = angle-180,-size;
		slib.force_opaque();
		obj.copybuffer("tmp","obj");
		obj.copybuffer("obj","cache:obj");
	end

	obj.effect("領域拡張","左",size,"右",size,"上",size,"下",size);
	obj.effect("単色化","color",0x808080,"輝度を保持する",0);
	obj.effect("凸エッジ","幅",size,"角度",angle);
	slib.force_opaque();

	if blur>0 then
		if convex then
			obj.effect("領域拡張","左",blur,"右",blur,"上",blur,"下",blur,"塗りつぶし",1);
		end
		obj.effect("ぼかし","範囲",blur,"サイズ固定",1);
	end
	if not convex then
		obj.effect("クリッピング","左",size,"右",size,"上",size,"下",size);
	end

	obj.setoption("dst","tmp");
	place_light_shadow(convex, alpha_l,color_l, alpha_d,color_d);

	if convex then
		obj.copybuffer("obj","cache:obj");
		obj.draw();
	else
		obj.copybuffer("obj","cache:obj");
		invert_opacity();
		obj.setoption("blend","alpha_sub");
		obj.draw();
		obj.setoption("blend",0);
	end
	obj.copybuffer("obj","tmp");
end
local function call_neumorphism(size, blur, intensity, balance, color_l, color_d, angle)
	--track0:幅,-100,100,30,1
	--track1:ぼかし比,0,500,50
	--track2:強さ,0,100,50
	--track3:バランス,-100,100,0
	--dialog:光色/col,_1=0xffffff;影色/col,_2=0x000000;光角度,_3=-45;TRACK,_0=nil;
	size = slib.coerce_int(size,30,-100,100); if size == 0 then return end
	blur = slib.coerce_real(blur,0.5, 0,5);
	intensity = slib.coerce_real(intensity,0.5, 0,1);
	balance = slib.coerce_real(balance,0,-1,1);
	color_l = slib.coerce_color(color_l,0xffffff);
	color_d = slib.coerce_color(color_d,0x000000);
	angle = slib.coerce_real(angle, -45)%360;

	local balance_l, balance_d = 1,1;
	if balance >= 0 then balance_d = 1-balance else balance_l = 1+balance end

	neumorphism(size, math.ceil(blur*math.abs(size)),
		color_l,intensity*balance_l, color_d,intensity*balance_d, angle);
end

return {
	rectangle = call_rectangle,
	ellipse = call_ellipse,
	diamond_shape = call_diamond_shape,

	round_corners = call_round_corners,

	canvas_resize = call_canvas_resize,
	canvas_resize_rational = call_canvas_resize_rational,
	canvas_set_size = call_canvas_set_size,

	push_opacity = call_push_opacity,
	force_opacity = call_force_opacity,
	fill_back = call_fill_back,

	acryl_material = call_acryl_material,
	acryl_surface = call_acryl_surface,
	acrylify = call_acrylify,

	back_rectangle = call_back_rectangle,
	back_ellipse = call_back_ellipse,
	back_diamond = call_back_diamond,

	align_center = call_align_center,
	move_center = call_move_center,
	move_center_absolute = call_move_center_absolute,

	rotation_euler = call_rotation_euler,
	rotation_axis = call_rotation_axis,

	skew = call_skew,
	midrange_clipping = call_midrange_clipping,
	pizza_cut = call_pizza_cut,

	inner_shadow = call_inner_shadow,
	alpha_border = call_alpha_border,
	inner_border = call_inner_border,
	neumorphism = call_neumorphism,
};
