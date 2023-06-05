#	sigma_lib.lua について

AviUtlのスクリプトで汎用的に使う関数をまとめた自前の補助ライブラリです．
忘備録，兼，何かの参考になればとリファレンスとしてまとめておきます．

#	必要環境

-	AviUtl

	**1.10 推奨**．1.00 でも動くとは思いますが未確認．

	-	公式サイト: http://spring-fragrance.mints.ne.jp/aviutl

-	拡張編集

	**0.92 推奨**．0.93rc1 でも動くとは思いますが未確認．

-	LuaJIT (**推奨**)

	一部の機能は LuaJIT の機能 FFI ライブラリを用いて書いています．
	用いない場合に比べて高速だと実験的に確認できた処理に限りますが．
	LuaJIT でない場合，代替処理として純 Lua 5.1 でも動くものも書いていますが基本的に LuaJIT の導入を推奨します．

	-	LuaJIT公式: https://luajit.org
	-	Auto Buildによるバイナリ配布(非公式): https://github.com/Per-Terra/LuaJIT-Auto-Builds


#	使用法

```lua
local sigma_lib = require "sigma_lib";
```

`require` することで `package.loaded.sigma_lib` に登録．戻り値はテーブルで，そこに格納された以下の関数が使える．グローバル変数には登録していないので注意．


#	各関数のリファレンス

**目次:**

1.	[パラメタ矯正系](#パラメタ矯正系)
1.	[パラメタ解釈系](#パラメタ解釈系)
1.	[縦横比](#縦横比)
1.	[いわゆる ePi 規格](#いわゆる-epi-規格)
1.	[`obj`の変数バックアップ](#objの変数バックアップ)
1.	[Shift-JIS関連](#shift-jis関連)
1.	[中間点の位置把握](#中間点の位置把握)
1.	[透明度操作](#透明度操作)
1.	[丸角四角形](#丸角四角形)
1.	[その他](#その他)

##	パラメタ矯正系

##	`coerce_int(n [, default [, min [, max]]])`

任意の値を整数に矯正する関数．パラメタチェックへの利用を想定している．

`n` が `number` でない場合, `default` に置き換えられる．更に `math.floor()` 関数で丸められた後, `min`, `max` を指定した場合その範囲に収められる．

###	パラメタ

1.	**`n`**

	任意の型の値．矯正の対象．

1.	**`default`**

	`number` 値．整数値を指定．
	`n` が `number` でない場合の既定値．省略した場合 `0` 指定と同義．

1.	**`min`**

	`number` 値．整数値を指定．
	許容範囲の最小値．省略した場合や `nil` を指定した場合，最小値チェックは行われない．

1.	**`max`**

	`number` 値．整数値を指定．
	許容範囲の最大値．省略した場合や `nil` を指定した場合，最大値チェックは行われない．

###	戻り値

-	`number` 値．整数．矯正された結果の値．

###	使用例

-	```lua
	n1 = sigma_lib.coerce_int(n1, 42);
	```

	`n1` が `number` でない場合，`42` に置き換えられて `math.floor()` で丸められる．

-	```lua
	n2 = sigma_lib.coerce_int(n2, 5, 0);
	```

	`n2` は `0` 以上の整数であることが保証される．既定値は `5`.

-	```lua
	n3 = sigma_lib.coerce_int(n3, 50, 0, 100);
	```

	`n3` は `0` 以上 `100` 以下の整数であることが保証される．既定値は `50`.

##	`coerce_real(x [, default [, min [, max]]])`

任意の値を `number` 値に矯正する関数．パラメタチェックへの利用を想定している．

`x` が `number` でない場合, `default` に置き換えられる．
`min`, `max` を指定した場合，その範囲に収められる．

###	パラメタ

1.	**`x`**

	任意の型の値．矯正の対象．

1.	**`default`**

	`number` 値．
	`x` が `number` でない場合の既定値．省略した場合 `0` 指定と同義．

1.	**`min`**

	`number` 値．
	許容範囲の最小値．省略した場合や `nil` を指定した場合，最小値チェックは行われない．

1.	**`max`**

	`number` 値．
	許容範囲の最大値．省略した場合や `nil` を指定した場合，最大値チェックは行われない．

###	戻り値

-	`number` 値．矯正された結果の値．

###	使用例

-	```lua
	x1 = sigma_lib.coerce_real(x1, 42);
	```

	`x1` が `number` でない場合，`42` に置き換えられる．

-	```lua
	x2 = sigma_lib.coerce_real(x2, 5, 0);
	```

	`x2` は `0` 以上の実数であることが保証される．既定値は `5`.

-	```lua
	x3 = sigma_lib.coerce_real(x3, 0.5, -1, 1);
	```

	`x3` は `-1` 以上 `1` 以下の実数であることが保証される．既定値は `0.5`.


##	`coerce_color(color [, default])`

任意の値を，色を表す整数値に矯正する関数．パラメタチェックへの利用を想定している．

`color` が色を表す整数値でない場合, `default` に置き換えられる．
色は16進法で `0xrrggbb` の形式，アルファ値は含まない．

###	パラメタ

1.	**`color`**

	任意の型の値．矯正の対象．

1.	**`default`**

	`number` 値．`0` から `0xffffff` の整数値を指定．
	`color` が `number` でない，あるいは色を表す範囲を超えた場合の既定値．
	省略した場合 `0x000000` （黒）を既定値として利用．

###	戻り値

-	`number` 値．`0` 以上 `0xffffff` 以下の整数．矯正された結果の値．

###	使用例

-	```lua
	color = sigma_lib.coerce_color(color, 0x808080);
	```

	`color` が色を表す整数でない場合 50% の灰色に置き換えられる．


##		`coerce_cachename(cachename [, default])`

任意の値を，AviUtl の `obj.copybuffer(dst, src)` 関数のキャッシュ名として矯正する関数．

キャッシュ名として不正な場合, `default` に置き換えられる．
パラメタチェックへの利用を想定している．

###	パラメタ

1.	**`cachename`**

	任意の型の値．矯正の対象．
	通常は `"cache:name"` など `"cache:***"` の形．

1.	**`default`**
	
	`string` 値．通常は `"cache:name"` など `"cache:***"` の形．
	`cachename` がキャッシュ名として不正な場合の代替値．
	省略した場合 `"cache:obj"` を既定値として利用．

###	戻り値

-	`string` 値．`default` と同一 か `"cache:***"` の形式．

###	使用例

-	```lua
	cachename = sigma_lib.coerce_cachename(cachename, "cache:image1");
	```

	`cachename` が `string` でなかったり不正な形式の場合 `"cache:image1"` に置き換えられる．


##	パラメタ解釈系

##	`parse_twonum(source)`
`source` を数値2つ組の表現文字列として読み取る関数．
`"a, b"` の形式とする．失敗した場合は `nil` を返す．

###	パラメタ

-	**`source`**

	`string` 値．解釈元の文字列．

###	戻り値

2つの値を返す．ただし `source` が不正な形式の場合は `nil` となる．

###	使用例

-	```lua
	a,b = sigma_lib.parse_twonum("12,34");
	```

	`a = 12, b = 34;` と同義．

###	付記

数値の区切り文字は空白文字でも構わない．カンマ(`,`)前後の空白は無視される．

##	`parse_onetwonum(source)`

`source` を数値1つ，または2つ組の表現文字列として読み取る関数．
`"uniform"`, `"a, b"` の2形式が可能．失敗した場合は `nil` を返す．

###	パラメタ

-	**`source`**

	`string` または `number` 値．解釈元の文字列．

###	戻り値

2つの値を返す．ただし `source` が不正な形式の場合は `nil` となる．

###	使用例

-	```lua
	a,b = sigma_lib.parse_twonum(42);
	```

	`a` と `b` は両方 `42`．

-	```lua
	a,b = sigma_lib.parse_twonum("12,34");
	```

	`a = 12, b = 34;` と同義．

###	付記

数値の区切り文字は空白文字でも構わない．カンマ(`,`)前後の空白は無視される．


##	`parse_threenum(source)`

`source` を数値3つ組の表現文字列として読み取る関数．
`"a, b, c"` の形式とする．失敗した場合は `nil` を返す．

`parse_twonum()` 関数の3つ組版．パラメタ等の詳細は [`parse_twonum()`](#parse_twonumsource) 関数を参照．

##	`parse_onethreenum(source)`

`source` を数値1つ，または3つ組の表現文字列として読み取る関数．
`"uniform"`, `"a, b, c"` の2形式が可能．失敗した場合は `nil` を返す．

`parse_onetwonum()` 関数の3つ組版．パラメタ等の詳細は [`parse_onetwonum()`](#parse_onetwonumsource) 関数を参照．

##	`parse_fournum(source)`

`source` を数値4つ組の表現文字列として読み取る関数．
`"a, b, c, d"` の形式とする．失敗した場合は `nil` を返す．

`parse_twonum()` 関数の4つ組版．パラメタ等の詳細は [`parse_twonum()`](#parse_twonumsource) 関数を参照．

##	`parse_onefournum(source)`

`source` を数値1つ，または4つ組の表現文字列として読み取る関数．
`"uniform"`, `"a, b, c, d"` の2形式が可能．失敗した場合は `nil` を返す．

`parse_onetwonum()` 関数の4つ組版．パラメタ等の詳細は [`parse_onetwonum()`](#parse_onetwonumsource) 関数を参照．


##		`parse_thickness(source)`

[WPF の `Thickness` 構造体](https://learn.microsoft.com/ja-jp/dotnet/api/system.windows.thickness)に相当するデータを文字列から読み取る関数．XAML の記法を模して記述できる．
`"uniform"`, `"LR, TB"`, `"L,T,R,B"` の3形式のいずれかを許容．失敗した場合 `nil` を返す．

###	パラメタ

-	**`source`**

	`string` または `number` 値．解釈元の文字列．

###	戻り値

4つの値を返す．

-	**`L`**, **`T`**, **`R`**, **`B`**

	`number` 値．解釈結果のそれぞれ左，上，右，下の値．
	ただし `source` が不正な形式の場合は `nil` となる．

###	使用例

-	```lua
	l,t,r,b = sigma_lib.parse_thickness(42);
	```

	`l`, `t`, `r`, `b` は全て `42`.

-	```lua
	l,t,r,b = sigma_lib.parse_thickness("13,57");
	```

	`l = 13; t = 57; r = 13; b = 57;` と同義．

-	```lua
	l,t,r,b = sigma_lib.parse_thickness("12,34,56,78");
	```

	`l = 12; t = 34; r = 56; b = 78;` と同義．

###	付記

数値の区切り文字は空白文字でも構わない．カンマ(`,`)前後の空白は無視される．


##	縦横比

##	`size_aspect_to_len(size, aspect)`

AviUtl の「サイズ」と「縦横比」から $x$, $y$ 軸に沿った長さを計算する関数．

###	パラメタ

1.	**`size`**

	`number` 値．計算元の「サイズ」．

1.	**`aspect`**

	`number` 値．「縦横比」と表される数値を `-1.0` から `+1.0` に正規化した数．

###	戻り値

2つの値を返す．

-	**`size_x`**, **`size_y`**

	`number` 値．それぞれ $x$, $y$ 軸に沿った長さ．

###	使用例

-	```lua
	width,height = sigma_lib.size_aspect_to_len(100,0.5);
	```

	`width = 50; height = 100;` と計算される．

-	```lua
	width,height = sigma_lib.size_aspect_to_len(100,-0.7);
	```

	`width = 100; height = 30;` と計算される．

###	注意

1.	「縦横比」は正のとき縦長，負のときは横長の場合が多いため，上で示した使用例や戻り値の名前はそれに従っている．ただし「ぼかし」や「境界ぼかし」だと正のとき横長，負のとき縦長と逆であるため，戻り値の受け方を入れ替えるか，`aspect` を `-1` 倍して渡す必要がある．

1.	AviUtl 拡張編集に付属するオブジェクトやフィルタ効果の「縦横比」は10進法で3桁の精度しかなく，内部でも3桁で丸められている様子なため，「サイズ」が `1000` を超えた場合「縦横比」では短辺の長さを1ピクセル単位で正確に表現できない．

	この関数や下の [`len_to_size_aspect()`](#len_to_size_aspectwidth-height) 関数は	その3桁丸めを考慮していないため高い精度になっているが，AviUtlの `obj.load("figure", figurename, color, size, thick, aspect)` に渡すなどした場合の幅，高さと食い違うことがある．

	また，この関数の戻り値は整数とは限らない．必要に応じて `math.floor()` などで丸めること．

##	`len_to_size_aspect(width, height)`

AviUtl の「サイズ」と「縦横比」を $x$, $y$ 軸に沿った長さから計算する関数．

###	パラメタ

1.	**`width`**
1.	**`height`**

	`number` 値．計算元の幅と高さ．（図形オブジェクトの場合．）

###	戻り値

2つの値を返す．

1.	**`size`**

	`number` 値．「サイズ」の値．

1.	**`aspect`**

	`number` 値．「縦横比」の値で，`-1.0` から `+1.0` に正規化した数．

###	使用例
-	```lua
	size,aspect = sigma_lib.len_to_size_aspect(400,300);
	```

	`size = 400; aspect = -0.25;` と計算される．

-	```lua
	size,aspect = sigma_lib.len_to_size_aspect(100,500);
	```

	`size = 500; aspect = 0.8;` と計算される．

###	注意

上記の [`size_aspect_to_len()`](#size_aspect_to_lensize-aspect) 関数の注意を参照のこと．


##	いわゆる ePi 規格

##	`extract_trackvalues(tbl)`

AviUtl スクリプトの設定ダイアログ内で，

```lua
{ [0] = check0, track0, track1, track2, track3 }
```

というテーブル形式でトラックバーやチェックボックスの値を指定をできる機能の補助関数．
テーブル内に有効なデータがある場合その値を，ない場合 `obj.track0`, ... や `obj.check0` の値を返す．

###	パラメタ

-	**`tbl`**

	`table` 値．以下のフィールドを利用する．
	-	**`[0]`**
	
		`nil`, `boolean` または `number` 値．

		`obj.check0` の値に対応．`boolean` 値の `true` または `number` 値の `1` の場合 `true`,
		それ以外は `false` とみなす．`nil` の場合，`obj.check0` の値で代替する．

	-	**`[1]`**, **`[2]`**, **`[3]`**, **`[4]`**
	
		`nil` または `number` 値．

		それぞれ `obj.track0`, `obj.track1`, `obj.track2`, `obj.track3` の値に対応．
		`tonumber()` して `nil` の場合，対応する `obj.track0`, ... の値で代替する．

###	戻り値

5つの値を返す．

1.	**`check0`**

	`obj.check0` の代替になる `boolean` 値．
	
1.	**`track0`**
1.	**`track1`**
1.	**`track2`**
1.	**`track3`**

	それぞれ `obj.track0`, ... の代替になる `number` 値．

###	使用例

-	```lua
	--dialog:TRACK,_0=nil;
	local c0,t0,t1,t2,t3 = sigma_lib.extract_trackvalues(_0); _0=nil;
	```

	例えば設定ダイアログに `{ nil, obj.time^2, [0] = false }` と書いていた場合...
	1.	`c0` はスクリプトのチェックボックスの状態に関わらず `false`,
	1.	`t0` は `obj.track0` の値，
	1.	`t1` はトラックバーの値に関わらず `obj.time^2` を計算した数値，
	1.	`t2`, `t3` はそれぞれ `obj.track2`, `obj.track3` の値．

###	注意

トラックバーの移動単位や上下限の設定は反映されない;
例えばトラックバーに整数値しかとらない設定をしていても
`0.5` など端数を持つ数値を返すことがあるし，上限，下限を超える場合もある．


##	`obj`の変数バックアップ

##	`posinfo_save()`

`obj.load()` で失われる情報を保存しておく関数．`posinfo_copy({}, obj)` と等価．保存する情報については [`posinfo_copy()`](#posinfo_copydst-src) の説明を参照．

###	戻り値

-	**`posinfo`**

	バックアップしたテーブル．後に [`posinfo_load()`](#posinfo_loadposinfo)で使う．

###	使用例:

-	```lua
	posinfo = sigma_lib.posinfo_save();
	-- 何かする．
	sigma_lib.posinfo_load(posinfo);
	```

##	`posinfo_load(posinfo)`

`obj.load()` で失われた情報を復元する関数．`posinfo_copy(obj,posinfo)` と戻り値がない点を除いて等価．復元する情報については [`posinfo_copy()`](#posinfo_copydst-src) の説明を参照．

###	パラメタ

-	**`posinfo`**

	`table` 値．予め `posinfo_save()` でとっておいたバックアップテーブル．

##	`posinfo_copy(dst, src)`

`obj.load()` で失われる情報を別テーブルにコピーしておく関数．テーブル内の次のフィールドを `src` から `dst` にコピーする:

```
.ox .oy .oz .rx .ry .rz .cx .cy .cz .zoom .aspect .alpha
```

これらの情報は `obj.load("figure",...)` や `obj.load("tempbuffer")` などすると初期値に書き換わってしまうため，アニメーション効果で一時的に他の画像をロードしたいなどの場合，バックアップ/復元の操作が必要．なお `obj.copybuffer("obj","tmp")` だとこれらの情報は書き換わらないため `tempbuffer` のロードにはこちらを使うのが便利．

###	パラメタ

1.	**`dst`**

	`table` 値．コピー先のテーブル．

1.	**`src`**

	`table` 値．コピー元のテーブル．

###	戻り値

-	**`dst`**

	パラメタの `dst` と同一物．

###	付記

外部から利用する場面は想定していないが一応 expose しておく．内部的に `posinfo_save()`, `posinfo_load()` で利用している．

##	Shift-JIS関連

##	`sjis_chars(str)`

Shift-JIS 文字列の各文字に対して走査するイテレータを返す関数．次の形で利用する:

```lua
for c in sigma_lib.sjis_chars(str) do
	-- ...
	-- str 内の Shift-JIS 文字 c (1バイトか2バイト長) に対する操作を記述．
	-- ...
end
```

###	パラメタ

-	**`str`**

	`string` 値．Shift-JIS 形式で格納されているものとする．

###	戻り値

-	**`iterator`**

	`for` 構文のイテレータとして使える関数値．

###	付記

次のコードと等価:

```lua
str:gmatch("[\129-\159\224-\252]?.")
```

##	`sjis_revert_unescape(str)`

Shift-JIS 文字を含む Lua コードを AviUtl が取り扱う際，Shift-JIS 2バイト目が `0x5c` (`\`) な文字 (いわゆる「ダメ文字」) を見つけると，その文字の直後に `\` をもう1つ付加してエスケープ回避するという仕様がある．ダブルクォートで括られた通常の文字列リテラル (`"..."`) なら入力通りに解釈されるが，verbatim 形式の文字列 (`[[...]]` や `[==[...]==]` など) の場合，余計な `\` が挿入されてしまう副作用がある．

-	例: `[[ソフト表現機能]]` → `ソ\フト表\現機能\` 

このように余計なエスケープ回避がされてしまった文字列を元に戻す関数．

スクリプトの設定ダイアログに `[[...]]` 形式でファイルパスを渡してもらう際，ダメ文字に対する誤解釈を回避する目的で用意した．

影響があるのは AviUtl が直接触れるコードのみで，`require()` や `dofile()` 経由でコンパイルされるコードにはこのような配慮は不要である．(ただし Shift-JIS 形式の文字列を `"..."` 内で取り扱う際には，ダメ文字に対する通常の配慮は必要．)

###	パラメタ

-	**`str`**

	`string` 値．`[[...]]` などの形式で指定した，ダメ文字が含まれている可能性のある文字列．

###	戻り値

-	**`source`**

	エスケープ回避処理を行う前の文字列．

###	使用例

-	```lua
	--dialog:ファイル,_1=[[]];
	```

	ここでダイアログに `[[C:\ソフト\機能.jpg]]` と指定すると，AviUtlの処理により `_1` は `C:\ソ\フト\機能\.jpg` となり，余計な `\` が入り込むためユーザーの意図しないパスになる．そこで，

	```lua
	_1 = sigma_lib.sjis_revert_unescape(_1);
	```

	とすると，`_1` は `C:\ソフト\機能.jpg` とユーザーの指定した本来の文字列に戻る．

###	付記

`[[...]]` の記法も万能ではない．`ゾ`, `江`, `転`, `脳`, `評`, `望`, `余`, `肋` などの文字は
Shift-JIS の 2 バイト目が `0x5d` で，これは `]` と一致する．そのため例えば `[[ほげ[絶望]ふが]]` だと `望` の2バイト目と直後の `]` で文字列の終了と認識されてしまう．この場合 `[=[ほげ[絶望]ふが]=]` ともう1段長い *long bracket* だと誤認回避できる．

意図しない限りほとんど起こり得ないケースだとは思われるが念のため書いておく．

###	参考

-	「ダメ文字」の一覧: https://sites.google.com/site/fudist/Home/grep/sjis-damemoji-jp


##	中間点の位置把握

##	`find_midpoint_section([time])`

指定フレームがオブジェクトの中間点区間のどの位置にあるのかを取得する関数．

###	パラメタ

-	**`time`**

	`number` 値．指定フレームの位置を秒単位で指定．省略時の既定値は `obj.time`.
	負のときや `obj.totaltime` を超えた場合，それぞれ `0`, `obj.totaltime` に置き換えられる．

###	戻り値

4つの `number` 値を返す; `curr_int`, `curr_frac`, `total_sections`, `total_curr_section`.

1.	**`curr_int`**

	指定フレームのある中間点区間を表す整数値．`0` 以上 `total_sections` 未満．
	-	`0`: 最初 -- 最初の中間点,
	-	`1`: 最初の中間点 -- 2番目の中間点,
	-	`2`: 2番目の中間点 -- 3番目の中間点,

		...

1.	**`curr_frac`**

	中間点区間中の指定フレームの相対位置を表す `0` 以上 `1` 未満の実数値．

1.	**`total_sections`**

	`(中間点の個数) + 1` の値．`obj.getoption("section_num")` と等価．

1.	**`total_curr_section`**

	指定フレームのある中間点区間の長さで単位は秒．

###	使用例

-	例えば, `find_midpoint_section()` の戻り値が `3, 0.25, 5, 1.6` だったとき...
	-	3番目の戻り値が `5` なので，現在オブジェクトは 5つに分割されていて中間点は 4つ．
	-	現在フレームは 3番目と 4番目の中間点の間を，25% 進んだ位置にある．
	-	その 3番目と 4番目の中間点は 1.6 秒だけ離れている．

	...といったことがわかる．


##	透明度操作

##	`force_transparent()`

現在オブジェクトの全ピクセルを完全透明にする関数．パラメタ，戻り値はない．

##	`force_opaque()`

現在オブジェクトの全ピクセルを完全不透明にする関数．パラメタ，戻り値はない．

##	`force_opacity(alpha [, load])`

現在オブジェクトのアルファ値を指定値に強制する関数．

LuaJIT がない場合，`obj`, `tempbuffer` の両方の内容が破棄改変されるため，必要ならバックアップを取っておくこと．

###	パラメタ

1.	**`alpha`**

	`number` 値．アルファ値に上書きする値．`0` 以下の場合全ピクセルを透明化する．

1.	**`load`**

	`boolean` 値．省略時の既定値は `true`.
	
	結果の画像を現在のオブジェクトとしてロードする場合 `true`,
	`tempbuffer` に置く場合は `false` を指定．

	LuaJIT または `alpha <= 0` の場合， `true` の方が少ない手順で済む．

##	`push_opacity(alpha [, load])`

現在オブジェクトのアルファ値に指定値を乗算する関数．

LuaJIT がない場合，完全透明なピクセルの色成分が保持される保証はなく，さらに `obj`, `tempbuffer` の両方の内容が破棄改変されるため，必要ならバックアップを取っておくこと．

###	パラメタ

1.	**`alpha`**

	`number` 値．アルファ値に乗算する値．`0` 以下の場合全ピクセルを透明化する．

1.	**`load`**

	`boolean` 値．省略時の既定値は `true`.

	結果の画像を現在のオブジェクトとしてロードする場合 `true`,
	`tempbuffer` に残す場合は `false` を指定．

	LuaJIT または `alpha <= 0 or alpha == 1` の場合， `true` の方が少ない手順で済む．


##	丸角四角形

##	`round_corners([cachename,] radiusTL, radiusTR, radiusBR, radiusBL [, figure, invert [, tempbuffer, width, height]])`

既存の画像の四隅を指定した図形で丸める．

`tempbuffer` が `false` のとき，結果の画像は現在のオブジェクトとしてロードされる．`tempbuffer` が `true` のとき，結果の画像は `tempbuffer` に残ったままとなる．いずれの場合も `obj`, `tempbuffer` 両方の内容が破棄改変されるため，必要ならバックアップを取っておくこと．

「簡易版」と「詳細版」とがあり，`cachename` を指定せず `number` を第1引数に渡すと「簡易版」,
`nil` か `string` を第1引数に渡すと「詳細版」となる．

###	パラメタ

1.	**`cachename`**

	`nil` または `string` 値．

	「詳細版」で必要なキャッシュの名前を `"cache:xyz"` の形式で指定する．不正な形式の文字列や `nil` を渡した場合，`"cache:obj"` を既定値として利用する．

	ここに `number` 値を渡すことで省略とみなし，「簡易版」で処理される．

1.	**`radiusTL`**
1.	**`radiusTR`**
1.	**`radiusBR`**
1.	**`radiusBL`**

	`number` 値．0 以上の整数を指定．

	それぞれ左上，右上，右下，左下の角半径をピクセル単位で指定する．
	`radiusTL` が負や `nil` の場合，0 を既定値として利用する．
	`radiusTR`, `radiusBR`, `radiusBL` が負や `nil` の場合，`radiusTL` を既定値として利用する．

	ここで指定した半径は必要な場合 [`corner_radius_resize()`](#corner_radius_resizeradiustl-radiustr-radiusbr-radiusbl-width-height) 関数で縮小される．

1.	**`figure`**

	`string` 値．丸角に利用する図形を指定する．省略時の既定値は `"円"`.
	空文字列 `""` を指定した場合，特別仕様として菱形 (◆) を生成する．

1.	**`invert`**

	`boolean` 値．省略時の既定値は `false`.
	丸角の凹凸を反転するかどうかを指定．

1.	**`tempbuffer`**

	`boolean` 値．省略時の既定値は `false`.

	丸角化の対象画像が `tempbuffer` にある場合 `true`, `obj` にある場合 `false` を指定．
	`true` を指定した場合，後続の `width`, `height` を指定すること．

1.	**`width`**
1.	**`height`**

	`number` 値．`0` 以上の整数を指定．

	`tempbuffer` が `false` の場合は無視される．

	`tempbuffer` が `true` のとき，対象画像の幅，高さをそれぞれピクセル単位で指定．

	`tempbuffer` が `true` でかつ指定を省略した場合，エラーを発生させる．

###	付記

-	「簡易版」は手順が少なくキャッシュも必要がないが，半透明ピクセルが丸角の境界付近にある場合正確な結果にならない．
-	「詳細版」だと丸角境界付近の半透明ピクセルも正しく扱えるが，キャッシュが1つ必要．名前の衝突が起こらないようキャッシュ名は指定するのを推奨．


##	`round_rect(color, width, height, thick [, radiusTL [, radiusTR, radiusBR, radiusBL [, figure, invert [, ratio_rad_thick, flipcenter, extrapolate, [, back_color,back_alpha [, load]]]]]])`

指定した図形を角に持つ丸角矩形を作成する．

`obj`, `tempbuffer` の両方が破棄改変されるため，必要ならバックアップを取っておくこと．

角部分のライン幅は，図形の拡大率を変えた際の差分として定義しているため，図形によっては線の幅が不均一になることもあるので注意．

###	パラメタ

1.	**`color`**

	`number` 値．`0` 以上の整数．`0xrrggbb` の形式で矩形の色を指定．

1.	**`width`**
1.	**`height`**

	`number` 値．正の整数．それぞれ生成する矩形の幅，高さをピクセル単位で指定．

1.	**`thick`**

	`number` 値．`0` 以上の整数．矩形のライン幅をピクセル単位で指定．
	省略時や `width` または `height` の半分以上のときは塗りつぶされた矩形を作成する．

1.	**`radiusTL`**
1.	**`radiusTR`**
1.	**`radiusBR`**
1.	**`radiusBL`**

	`number` 値．`0` 以上の整数を指定．それぞれ左上，右上，右下，左下の角半径をピクセル単位で指定する．

	`radiusTL` が負や `nil` の場合，`0` を既定値として利用する．
	`radiusTR`, `radiusBR`, `radiusBL` が負や `nil` の場合，`radiusTL` を既定値として利用する．

	ここで指定した半径は必要な場合，後述の [`corner_radius_resize()`](#corner_radius_resizeradiustl-radiustr-radiusbr-radiusbl-width-height) 関数で縮小される．

1.	**`figure`**

	`string` 値．丸角に利用する図形を指定する．省略時の既定値は `"円"`.
	空文字列 `""` を指定した場合，特殊仕様として菱形 (◆) を生成する．

1.	**`invert`**

	`boolean` 値．省略時の既定値は `false`.
	丸角の凹凸を反転するかどうかを指定．

1.	**`ratio_rad_thick`**

	`number` 値．`0` 以上の実数値で省略時や負数を指定すると既定値を自動で選ぶ．

	矩形のライン幅を指定した場合の処理手順は，丸角部分は外側を指定サイズの図形で切り取るが，	内側は小さめの図形で切り取っている．その「小さめの図形」のサイズを指定サイズからどのくらい小さくすればいいかを指定する数値で,
	$\dfrac{\text{(半径縮小幅)}}{\text{(ライン幅)}}$
	の比を指定する．

	通常は `1` 以上の実数．各図形に対する既定値は以下の通り:

	図形|既定値||
	:---:|---|---
	菱形 (`""`)|`1.414`| $\approx \sqrt 2$
	円|`1`
	四角形|`1`
	三角形|`2`| $= 1/\cos \frac{\pi}3$
	五角形|`1.236`| $\approx 1/\cos \frac{\pi}5$
	六角形|`1.155`| $\approx 1/\cos \frac{\pi}6$
	星型|`3.236`| $\approx 1/\cos \frac{2}5\pi$
	(その他)|`1`


1.	**`flipcenter`**

	`boolean` 値．省略時の既定値は `false`.

	角図形の拡大中心を外側にする．

	`false` の場合，角図形のライン幅の内側部分切り出しに，指定サイズより縮小した図形を使用する．その際の縮小中心は図形の中心点，矩形の位置だと各辺から半径だけ内側へ入り込んだ位置になる．

	`true` を指定した場合，内側の切り取りには，より拡大した図形を使用するようになる．その際の拡大率中心は指定図形の四隅，矩形の位置でも対応する四隅となる．

	図形の形状によって，どちらが自然に見えるかは変わってくる．AviUtl のビルトインの図形だと全て `false` のほうが自然に見えるはず．

1.	**`extrapolate`**

	`boolean` 値．省略時の既定値は `true`. 

	内側の角部分と辺部分の境界を，角部分を補外して埋める．

	矩形のライン幅(`thick`)を指定し，`ratio_rad_thick > 1` でかつ，`flipcenter == invert` の場合のみ有効．このとき，ライン内側の角部分と辺部分には角度 90 度の不自然に切り取られたような形が残るため，それを誤魔化す処理を施す．

	`ratio_rad_thick` の値からこの境界付近での図形の接線を推定し，その接線を延長したようなものを図形の内側部分に描画して，「この切り取り跡」を目立たなくする．

1.	**`back_color`**

	`number` 値．`0` 以上の整数．`0xrrggbb` の形式で縁の内側の色を指定．
	`nil` や省略時は `0` (黒)を既定値として利用する．

1.	**`back_alpha`**

	`number` 値．`0` 以上 `1` 以下の実数．
	
	縁取り内側の背景色の不透明度を指定．`nil` や省略時の既定値は `0` (背景描画なし).

1.	**`load`**

	`boolean` 値．省略時の既定値は `true`.

	出来上がった矩形を現在のオブジェクトとしてロードするかどうかを指定．

###	付記

任意に選んだ角図形でライン幅を指定するときの角の切り取り方に関しては，書いた私自身でもややこしく不自然な仕様だと感じています．とはいえある程度の一般図形でも成立するものとしてはきちんと出来上がっているのでこのまま公開することにしました．何かもっといい案があれば教えてほしいです．


##	`corner_radius_resize(radiusTL, radiusTR, radiusBR, radiusBL, width, height)`

丸角半径を矩形の幅，高さに合わせて許容範囲に再調整する．

例えば，左上半径と右上半径の和は矩形の幅を超えることはできない．丸角半径の実現に必要最小な幅・高さと，指定された幅・高さとの比をとって，許容範囲を超えている場合，4つの半径を一律に定数倍して許容範囲に収める．

###	パラメタ

1.	**`radiusTL`**
1.	**`radiusTR`**
1.	**`radiusBR`**
1.	**`radiusBL`**

	`number` 値．`0` 以上の整数を指定．それぞれ左上，右上，右下，左下の角半径をピクセル単位で指定する．省略不可．

1.	**`width`**
1.	**`height`**

	`number` 値．`0` 以上の整数を指定．対象の矩形の幅と高さをピクセル単位で指定．省略不可．

###	戻り値

4つの値を返す．

-	**`radiusTL`**, **`radiusTR`**, **`radiusBR`**, **`radiusBL`**

	`number` 値．`0` 以上の整数．再調整された計算結果．


##	その他

##	`diamond_shape(color, width [, height [, thick [, back_color, back_alpha]]])`

指定した幅，高さの菱形を作成する．ライン幅の指定も可能．

`obj` が破棄改変されるため，必要ならバックアップを取っておくこと．さらに `back_alpha` が正で `thick` が十分小さく縁取り図形になる場合 `tempbuffer` も破棄改変されるので注意．

###	パラメタ

1.	**`color`**

	`number` 値．`0` 以上の整数．`0xrrggbb` の形式で菱形の色を指定．

1.	**`width`**

	`number` 値．正の整数．生成する菱形の幅をピクセル単位で指定．

1.	**`height`**

	`number` 値 または `nil`．整数を指定．
	
	生成する菱形の高さをピクセル単位で指定．省略時や負数または `nil` を指定した場合，既定値として `width` を利用する．

1.	**`thick`**

	`number` 値．`0` 以上の整数．

	菱形のライン幅をピクセル単位で指定．省略時や負数，または `width` もしくは `height` に比べて十分大きい場合，塗りつぶされた菱形を作成する．

1.	**`back_color`**

	`number` 値．`0` 以上の整数．`0xrrggbb` の形式で縁の内側の色を指定．省略時は `0` (黒)を既定値として利用する．

1.	**`back_alpha`**

	`number` 値．`0` 以上 `1` 以下の実数．縁取り内側の背景色の不透明度を指定． 省略時の既定値は `0` (背景描画なし).


##	`transform_project1024(transform_func, camera_dist [, culling])`

線形変換を適用した後，カメラから $z$ 座標が $1024$ 離れた平面に射影した画像を描画する．用途としては，回転変形を適用した画像を用意して更なる加工のベースとするなどを想定している．

`obj`, `tempbuffer` の両方が破棄改変されるため，必要ならバックアップを取っておくこと．また `obj.cx`, `obj.cy`, `obj.cz` も書き変わるが，次の値は元のまま保持する:

```lua
obj.ox, obj.oy, obj.oz, obj.rx, obj.ry, obj.rz, obj.zoom, obj.aspect, obj.alpha
```

###	パラメタ

1.	**`transform_func`**

	`function` 値で次の形:

	```lua
	X,Y,Z = transform_func(x,y,z)
	```

	`x`,`y`,`z` は変換前の座標，`X`,`Y`,`Z` は変換後の座標．変換の原点はオブジェクトの回転中心（`obj.cx`, `obj.cy`, `obj.cz` で指定される点）．

	線形変換を指定すること．ここに $f$ が線形変換とは次を満たす実3次元空間上の関数:

	1.	$f(x,y,z) = (X,Y,Z)$ のとき，任意の実数 $a$ に対して $f(a x,a y,a z) = (a X,a Y,a Z)$.
	1.	$f(x,y,z) = (X,Y,Z)$ かつ $f(x',y',z') = (X',Y',Z')$ のとき $f(x+x',y+y',z+z') = (X+X',Y+Y',Z+Z')$.

	特に，$f(0,0,0) = (0,0,0)$ であることに注意．ここでは平行移動は線形変換に含まない．

1.	**`camera_dist`**

	`number` 値．オブジェクトの回転中心の，カメラ位置を基準とした $z$ 座標の相対位置を指定．

	通常は正の値で，このときカメラの前方にオブジェクトの回転中心がある．通常はカメラの座標は $z = -1024$ なので，この場合 `1024` を指定．

	また，`obj.z+obj.oz+1024` を指定した上で適用後に `obj.oz=-obj.z` と設定すると，フレームバッファ描画時に「$z$ 座標移動 → 線形変換」の順序での結果がシミュレートできる．

	なお，カメラの $x$, $y$ 座標はオブジェクトの回転中心と同じ．

1.	**`culling`**

	`boolean` 値．省略した場合は既定値として `false` を利用．

	線形変換による回転でオブジェクトの背面を描画する場合は `false`, 省略する場合は `true`.

	`obj.setoption("culling", true|false)` とは別枠の指定．
	`obj.drawpoly()` だと`obj.setoption("culling", true|false)`
	の設定が反映されない上に，この設定をスクリプト上で取得する手段が標準で存在しないため別枠での指定となった．

###	使用例

-	現在オブジェクトを時計回りに45度回転させた画像を作成:

	```lua
	sigma_lib.transform_project1024(
		function(x, y, z)
			return 2^-.5*(x-y), 2^-.5*(x+y), z;
		end, 1024);
	```

	`obj.rz=obj.rz+45` だと，後続フィルタに「凸エッジ」や「シャドー」などをかけた場合，光の角度や影の位置まで回転してしまうが，一度回転させた画像を用意することで
	ユーザの指定通りに光の角度や影の位置が設定できる．


##	`fill_back(color [, alpha [, alpha_f [, load]]])`

現在オブジェクトの背景を指定色で塗りつぶす．
`obj`, `tempbuffer` 両方が破棄改変されるため，必要ならバックアップを取っておくこと．

###	パラメタ

1.	**`color`**

	`number` 値．`0` 以上の整数．`0xrrggbb` の形式で背景の色を指定．省略時や不正な範囲の場合，既定値として `0x808080`（50%の灰色）を利用．

1.	**`alpha`**

	`number` 値．`0.0` 以上 `1.0` 以下．背景の不透明度を指定．省略時の既定値は `1.0`.

1.	**`alpha_f`**

	`number` 値．`0.0` 以上 `1.0` 以下．前景画像の不透明度を指定．省略時の既定値は `1.0`.

1.	**`load`**

	`boolean` 値．省略時の既定値は `true`.

	結果の画像を現在のオブジェクトとしてロードする場合 `true`,
	`tempbuffer` に残す場合は `false` を指定．

###	付記

キャッシュ利用なしで実現している．

##	`pizza_cut(a_from, a_to, cx, cy [, blur [, opaque [, cachename [, already_cached]]]])`

扇型に図形を切り取る．`blur` が正でかつ `opaque` が `false` の場合キャッシュが1つ必要．
`obj`, `tempbuffer` の両方が破棄改変されるため，必要ならバックアップを取っておくこと．

###	パラメタ

1.	**`a_from`**
1.	**`a_to`**

	`number` 値．それぞれ切り取る部分の開始/終了角度．度数法で指定，真上が `0`, 時計回りに正．

	`a_from >= a_to + blur` のときは何もしない．
	
	`a_from + 360 <= a_to - blur` のときは完全に透明化する．

1.	**`cx`**
1.	**`cy`**

	`number` 値．整数を指定．それぞれ扇の中心の $x$, $y$ 座標．

1.	**`blur`**

	`number` 値．`0` 以上 `180` 以下の実数．省略時の既定値は `0`.

	切り取り部分のぼかし角度を度数法で指定．

1.	**`opaque`**

	`boolean` 値．省略時の既定値は `true`.

	`blur` が正の場合のみ有効．現在のオブジェクト画像が完全不透明な場合に `true` を指定すると半透明の場合に必要だった操作を省く．`false` の場合キャッシュが1つ必要．

1.	**`cachename`**

	`nil` または `string` 値．

	`blur` が正でかつ `opaque` が `false` の場合のみ有効．必要なキャッシュの名前を `"cache:xyz"` の形式で指定する．省略時や不正な形式の文字列や `nil` を渡した場合，`"cache:obj"` を既定値として利用する．

	`already_cached` が `true` の場合，ここにそのキャッシュ名を渡すこと．

1.	**`already_cached`**

	`boolean` 値．省略時の既定値は `false`.

	`blur` が正でかつ `opaque` が `false` の場合のみ有効．既に現在のオブジェクト画像をキャッシュしている場合 `true` を指定するとキャッシュ処理を省く．


#	ライセンス・免責事項

このプログラムの利用・改変・再頒布等に関しては MIT ライセンスに従うものとします．

---

The MIT License (MIT)

Copyright (C) 2023 sigma_axis

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

https://mit-license.org/


#	Credits

##	LuaJIT -- a Just-In-Time Compiler for Lua.

Copyright (C) 2005-2017 Mike Pall. All rights reserved.

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

[ MIT license: http://www.opensource.org/licenses/mit-license.php ]

http://luajit.org/

##	Lua 5.1/5.2

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

##	v1.0.0 2023-06-??

-	とりあえず公開．

