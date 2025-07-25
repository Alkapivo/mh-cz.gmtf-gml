///@package io.mh-cz.gmtf
///@description https://github.com/mh-cz/Gamemaker-Multiline-Text-Field/tree/main

///@param {Struct} [config]
function _GMTFContext(config = {}) constructor {

	///@type {?GMTF}
	current = null

	///@type {Boolean}
	currentWasDrawn = false

	///@type {Boolean}
	uiWasScrolled = false

	///@type {Number}
	switchTick = 0

	///@private
	///@type {?Timer}
	timer = Core.isType(Struct.get(config, "timer"), Timer)
		? config.timer
		: null

	///@return {Boolean}
	isFocused = Core.isType(Struct.get(config, "isFocused"), Callable)
		? method(this, config.isFocused)
		: function() {
			return this.current != null
		}

	///@return {?GMTF}
	get = Core.isType(Struct.get(config, "get"), Callable)
		? method(this, config.get)
		: function() {
			return this.current
		}

	///@type {?GMTF} value
	///@return {GMTFContext}
	set = Core.isType(Struct.get(config, "set"), Callable)
		? method(this, config.set)
		: function(value) {
			this.current = value != null ? Assert.isType(value, GMTF) : value
			return this
		}

	///@return {GMTFContext}
	updateBegin = Core.isType(Struct.get(config, "update"), Callable)
		? method(this, config.update)
		: function() {
			if (this.timer == null) {
				this.timer = new Timer(3.0, { loop: Infinity })
			}

      if (this.current != null 
					&& this.current.uiItem != null 
					&& mouse_check_button_pressed(mb_left) 
					&& this.current.has_focus 
					&& !point_in_rectangle(
            this.current.mx,
            this.current.my,
            this.current.atx + this.current.uiItem.context.offset.x,
            this.current.aty + this.current.uiItem.context.offset.y,
            this.current.atx + this.current.uiItem.context.offset.x + this.current.style.w,
            this.current.aty + this.current.uiItem.context.offset.y + this.current.style.h)) {
				this.current.unfocus()
			}

			if (this.current != null && this.current.uiItem != null) {
				var uiTextField = this.current.uiItem

				// scroll offset to item
				if (!this.uiWasScrolled) {
					if (Core.isType(uiTextField.context, UI) 
						&& Core.isType(uiTextField.context.area, Rectangle)) {

						// horizontal offset
						var itemX = uiTextField.area.getX() + this.current.cursor1.cx
						var itemWidth = uiTextField.area.getWidth()
						var offsetX = abs(uiTextField.context.offset.x)
						var areaWidth = uiTextField.context.area.getWidth()
						var itemRight = itemX + itemWidth
						if (itemX < offsetX || itemRight > offsetX + areaWidth) {
							var newX = (itemX < offsetX) ? itemX : itemRight - areaWidth
							uiTextField.context.offset.x = -1 * clamp(newX, 0.0, abs(uiTextField.context.offsetMax.x))
						}
		
						// vertical offset
            var yy = uiTextField.area.getY() + this.current.cursor1.cy
            var yyTop = abs(uiTextField.context.offset.y) + 48
            var yyBottom = yyTop + uiTextField.context.area.getHeight() - 64
            if (yy < yyTop) {
              uiTextField.context.offset.y = -1.0 * clamp(yy - 48, 0, uiTextField.context.offsetMax.y)
            } else if (yy > yyBottom) {
              uiTextField.context.offset.y = -1.0 * clamp(yy + 64 - uiTextField.context.area.getHeight(), 0, uiTextField.context.offsetMax.y)
            }
					}
					this.uiWasScrolled = true
				}

        if (uiTextField.context.surface != null) {
					uiTextField.textField.update(
						uiTextField.context.area.getX(), 
						uiTextField.context.area.getY()
					)
				} else {
					uiTextField.textField.update(0, 0)
				}

				uiTextField.textField.updateFocused(
					uiTextField.area.getX(),
					uiTextField.area.getY()
				)
			}

			if (this.current != null && !this.currentWasDrawn) {
				if (this.timer.update().finished) {
					Logger.debug("GMTF", "reset current GMTFContext")
					this.current = null
				}
			} else {
				this.timer.reset()
			}

			this.currentWasDrawn = false
			return this
		}

	Struct.appendUnique(this, config)
}
global.__GMTFContext = null
#macro GMTFContext global.__GMTFContext


///@todo remove snake_case
///@todo replace lists with io.alkapivo.core.collection.Array
///@todo rename
///@param {?Struct} [style_struct]
function GMTF(style_struct = null) constructor {
	
	///@private
	///@type {String}
	symbolEnd = chr(28)

	///@private
	///@type {String}
	symbolEnter = chr(29)

	///@private
	///@type {String}
	symbolNewLine = chr(30)

	///@private
	///@type {Struct}
	surface = { x: 0, y: 0 }

	///@type {?UIItem}
	uiItem = null
	
	///@type {Struct}
	style = {
		w: 112, 
		w_min: 0,
		h: 28, 
		lh: 24, 
		text: "", 
		font: -1, 
		padding: { top: 4, bottom: 4, left: 4, right: 4 },
		c_bkg_unfocused: { c: c_gray, a: 1 }, 
		c_bkg_focused: { c: c_ltgray, a: 1 },
    c_outline_unfocused: { c: c_ltgray, a: 1 },
		c_outline_focused: { c: c_black, a: 1 },
		c_text_unfocused: { c: c_black, a: 1 },
		c_text_focused: { c: c_black, a: 1 },
		c_selection: { c: c_blue, a: 0.275 },
		char_limit: infinity,
		letter_case: 0,
		min_chw: 0,
		stoppers: " .,()[]{}<>?|:\\+-*/=" + this.symbolEnter + this.symbolNewLine + "\n",
		v_grow: false,
		trim: false,
	}

  GMTF_DECIMAL = Struct.getIfType(style_struct, "GMTF_DECIMAL", Number, 8)

	lines = new Array()
	chars = new Array()
	lines.add([ 0, 0, 0, "" ])
	chars.add([ this.symbolEnd, 0 ])
	
	///@todo all of these should be put in map or struct?
	mx = 0
	my = 0
	atx = 0
	aty = 0
	tf_lnum = 1
	pad_atx = 0
	pad_aty = 0
	pad_w = 0
	pad_h = 0
	
	cursor1 = { pos: 0, rel_pos: 0, line: lines.get(0), cx: 0, cy: 0, cxs: 0 } ///@todo rename, class & factory
	cursor2 = { pos: 0, rel_pos: 0, line: lines.get(0), cx: 0, cy: 0, cxs: 0 } ///@todo rename, class & factory
	
	has_focus = false
	gamespd = 60
	cursor_tick = 1
	cursor_visible = true
	spam_tick = 0
	spam_time = infinity
	spam_now = false
	clear = false
	click_tick = 0
	double_clicked = false
	last_click_pos = 0
	enabled = true
	
	next_tf = null
	previous_tf = null
	switch_to = null

	///@param {?GMTF} textField
	///@return {GMTF}
	setNext = function(textField) {
		this.next_tf = textField != null ?Assert.isType(textField, GMTF) : null
		return this
	}
	
	///@param {?GMTF} textField
	///@return {GMTF}
	setPrevious = function(textField) {
		this.previous_tf = textField != null ? Assert.isType(textField, GMTF) : null
		return this
	}
	
	///@return {GMTF}
	focus = function() {
		if (Core.isType(GMTFContext.get(), GMTF) && GMTFContext.get() != this) {
			GMTFContext.get().unfocus()
		}

		GMTFContext.set(this).uiWasScrolled = mouse_check_button_pressed(mb_any)

		if (Optional.is(this.uiItem) && Optional.is(this.uiItem.context)) {
			this.uiItem.context.finishUpdateTimer()
		}

		return this
	}
	
	///@return {GMTF}
	unfocus = function() {
		GMTFContext.set(null)
		cursor1.pos = 0
		cursor1.line = lines.get(0)
		cursor1.cx = 0
		cursor1.cy = 0
		cursor1.cxs = 0
		cursor2.pos = 0
		cursor2.line = lines.get(0)
		cursor2.cx = 0
		cursor2.cy = 0
		cursor2.cxs = 0

    if (Optional.is(this.uiItem) && Optional.is(this.uiItem.context)) {
			this.uiItem.context.finishUpdateTimer()
		}

		return this
	}
	
  ///@return {Boolean}
  isFocused = function() {
    return GMTFContext.get() == this
  }
  
	///@return {GMTF}
	updateStyle = function(style_struct = undefined, 
			update_lines = false, update_chars = false) {
		
		var keys = []
		if (style_struct != undefined) {
			keys = variable_struct_get_names(style_struct)
			var len = array_length(keys)
			for (var i = 0; i < len; i++) {
				var key = keys[i]
        if (!Struct.contains(this, key) && !Struct.contains(this.style, key)) {
          continue
        }

        if (key == "font") {
          var font = FontUtil.fetch(style_struct[$ key])
          style[$ key] = Optional.is(font) ? font.asset : style[$ key]
          update_lines = true
          continue
        }

        ///@bug
				style[$ key] = style_struct[$ key];
				switch (key) {
					case "w":
					case "h":
					case "lh":
					case "font":
					case "char_limit":
					case "padding":
					case "text":
						update_lines = true
						break
					case "min_chw":
					case "letter_case":
						update_chars = true
						break
				}
			}
		}
		
		pad_atx = atx + style.padding.left
		pad_aty = aty + style.padding.top
		pad_w = style.w - style.padding.right - style.padding.left
		pad_h = style.h - style.padding.top - style.padding.bottom
		
		var prevfont = draw_get_font()
		draw_set_font(style.font)
		
		if (update_chars) {
			var s = chars.size()
			for (var i = 0; i < s; i++) {
        var _c = chars.get(i)
				var ch = _c[0]
				if (ch != this.symbolEnter && ch != this.symbolEnd && ch != this.symbolNewLine) {
					if (style.letter_case == 1) {
						ch = string_lower(ch)
					} else if (style.letter_case == 2) {
						ch = string_upper(ch)
					}

					_c[0] = ch
					_c[1] = max(string_width(ch), style.min_chw)
				}
			}
		}
		
		if (update_lines || update_chars) {
			if (array_contains(keys, "text")) {
				this.setText(style.text)
			} else {
				while (!this.fitLines()) {
					chars.remove(--cursor1.pos)
          var __c = chars.get(cursor1.pos - 1)
					if (__c[0] == this.symbolNewLine) {
            chars.remove(--cursor1.pos)
					}
				}
				this.updateCursor(cursor1, true)
				this.updateCursor(cursor2, true)
			}
		}
		
		draw_set_font(prevfont)

		return this
	}
	
	///@return {GMTF}
	copyCursorInfo = function(from, to) {
		to.pos = from.pos
		to.line = [
			from.line[0], 
			from.line[1], 
			from.line[2], 
			from.line[3]
		]
		to.rel_pos = from.rel_pos
		to.cx = from.cx
		to.cy = from.cy
		to.cxs = from.cxs
		return this
	}
	
	///@param {Struct} cposfrom1
	///@param {Struct} cposfrom2
	///@return {Boolean}
	fitLines = function(cposfrom1 = cursor1.pos, cposfrom2 = cursor2.pos) {
		var li = 0
		var wid = 0
		var off = 0
		var pos = 0
		var char = 0
		var ch = ""
		var chw = 0
		var fit_ok = true
		
		lines.clear()
		var line = [ li, pos, pos, "" ]
		lines.set(li, line)
		for (var i = 0; i < chars.size(); i++) {
			char = chars.get(i)
			ch = char[0]
			chw = char[1]
			wid += chw
			var nl = wid >= pad_w
			if (!this.style.v_grow && !this.style.trim) {
				nl = false
			}

			var enter = ch == this.symbolEnter
			if (nl) {
				chars.add([ this.symbolNewLine, 0 ], i++)
				line[2] = pos++
				if (pos > cposfrom1 && pos <= cursor1.pos) {
					cursor1.pos++
				}

				if (pos > cposfrom2 && pos <= cursor2.pos) {
					cursor2.pos++
				}

				//line[3] += symbolNewLine;
			} else if (ch == this.symbolNewLine) {
				chars.remove(i--)
				line[2]++
				continue
			}

			if (enter) {
				line[2] = pos++;
				//line[3] += ch;
			}

			if (nl || enter) {
				fit_ok = (++li < tf_lnum)
				lines.set(li, [ li, pos, pos, "" ])
				line = lines.get(li)
				wid = chw
			}

			if (!enter) {
				line[2] = pos++
				if (ch != this.symbolEnd) {
					line[3] += ch
				}
			}
		}
		
		if (ch != this.symbolEnd) {
			chars.add([ this.symbolEnd, 0 ])
		} 
		
    if (this.style.v_grow) {
      var _h = this.style.lh
        * this.lines.size()
        + this.style.padding.top 
        + this.style.padding.bottom
      if (_h != this.style.h) {
        this.style.h = _h
        this.updateStyle()
      }
    }

		return fit_ok
	}

	///@param {String} _txt
	insert = function(_txt) {
		var txt = string_replace_all(_txt, chr(9), "");
		if (style.letter_case == 1) {
			txt = string_lower(txt)
		} else if (style.letter_case == 2) {
			txt = string_upper(txt)
		} 
		
		var prevfont = draw_get_font()
		draw_set_font(style.font)
		tf_lnum = max(1, pad_h div style.lh)
		if (cursor1.pos != cursor2.pos) {
			this.remove()
		}
		
		var len = string_length(txt)
		var cposfrom = cursor1.pos
		var ch = ""
		var chw = 0
		
		for (var i = 0; i < len; i++) {
			ch = string_char_at(txt, i + 1)
			chw = ((ch == this.symbolEnter || ch == this.symbolEnd || ch == this.symbolNewLine)
				? 0 
				: max(string_width(ch), style.min_chw))
			chars.add([ ch, chw ], cursor1.pos++)
		}
		
		while (!this.fitLines(cposfrom) 
			|| chars.size() > style.char_limit) {
			
			if (this.style.v_grow) {
				this.style.h = this.style.lh
          * this.lines.size()
					+ this.style.padding.top 
					+ this.style.padding.bottom
				this.updateStyle()
				cposfrom = cursor1.pos
				break
			}

			chars.remove(--cursor1.pos)
      var _c = chars.get(cursor1.pos - 1)
			if (_c[0] == this.symbolNewLine) {
				chars.remove(--cursor1.pos)
			} 

			cposfrom = cursor1.pos
		}
		
		this.updateCursor(cursor1, true, cursor2)
		draw_set_font(prevfont)
	}
	
	updateCursor = function(curs, save_cx = false, copy_to = undefined) {
		curs.pos = clamp(curs.pos, 0, chars.size() - 1)
		curs.info = this.getLine(curs.pos) // [line, rel_pos]
		curs.line = curs.info[0]
		curs.rel_pos = curs.info[1]
		curs.cx = this.getRangeWidth(curs.line[1], curs.line[1] + curs.rel_pos)
		curs.cy = curs.line[0] * style.lh
		
		if (save_cx) {
			curs.cxs = curs.cx
		}

		if (copy_to != undefined) {
			copyCursorInfo(curs, copy_to)
		} 
		
		cursor_tick = 0
		cursor_visible = true
	}
	
	getRangeWidth = function(from, to) {
		var wid = 0
		for (var i = from; i < to; i++) {
      var ch = chars.get(i)
			wid += ch[1]
		}
		return wid
	}
	
	getNearestRelPosByX = function(curs, target_x, line) {
		var closest = infinity
		var pos = -1
		var wid = 0
		for (var i = line[1]; i < line[2]; i++) {
			if (abs(target_x - wid) < closest) {
				closest = abs(target_x - wid)
				pos++
			} else {
				break
			}

      var _c = chars.get(i)
			wid += _c[1]
		}

		return pos + (abs(target_x - wid) < closest ? 1 : 0)
	}
	
	getLine = function(pos) {
		var s = lines.size()
		for (var i = 0; i < s; i++) {
			var line = lines.get(i)
			var from = line[1]
			var to = line[2]
			if (clamp(pos, from, to) == pos) {
				return [ line, pos - from ]
			}
		}
		return [ lines.get(0), 0 ]
	}
	
	cursorToMouse = function(curs, mousex = mx, mousey = my) {
		var iterator = clamp((mousey - pad_aty) div style.lh, 0, lines.size() - 1)
		var line = lines.get(iterator)
		curs.pos = line[1] + this.getNearestRelPosByX(curs, max(0, mousex - pad_atx), line)
		last_right = curs.pos == line[1] ? -1 : 1
		updateCursor(curs, true)
	}
	
	moveCursor = function(curs, r = 0, d = 0, ctrl = false) {
		if (GMTFContext.get() == this) {
			GMTFContext.uiWasScrolled = false
		}
		if (r != 0) {
			if (!ctrl) {
				curs.pos = clamp(curs.pos + r, 0, chars.size())
			} else {
				var prevpos = curs.pos
				this.expandSelection(r, style.stoppers, curs)
				if (curs.pos == prevpos) {
					curs.pos = clamp(curs.pos + r, 0, chars.size())
				}
			}
			this.updateCursor(curs, true)
		}
		
		if (d != 0) {
			var nextl = curs.line[0] + d
			if (nextl == clamp(nextl, 0, lines.size() - 1)) {
				var line = lines.get(nextl)
				curs.pos = line[1] + this.getNearestRelPosByX(curs, curs.cxs, line)
				this.updateCursor(curs)
			}
		}
		
		if (!keyboard_check(vk_shift)) {
			copyCursorInfo(cursor1, cursor2)
		}
	}
	
	expandSelection = function(right, stoppers = style.stoppers, curs = undefined) {
    var _c = null
		if (curs == undefined) {
			if (right) {
				var s = chars.size() - 1
				while (cursor1.pos++ < s) {
          _c = chars.get(cursor1.pos)
					if (string_pos(_c[0], style.stoppers)) {
						break
					} 
				}
			} else {
				while (cursor2.pos-- > 0) {
          _c = chars.get(cursor2.pos)
					if (string_pos(_c[0], style.stoppers)) {
						break
					}
				}
			}
		} else if (right) {
			var s = chars.size() - 1;
			while (curs.pos++ < s) {
        _c = chars.get(curs.pos)
				if (string_pos(_c[0], style.stoppers)) {
					break
				}
			}
		} else {
			while (curs.pos-- > 0) {
        _c = chars.get(curs.pos)
				if (string_pos(_c[0], style.stoppers)) {
					break
				}
			}
		}
	}
	
	renderSelection = function() {
    var alpha = draw_get_alpha()
		draw_set_color(style.c_selection.c)
		draw_set_alpha(style.c_selection.a)
		if (cursor1.line[0] == cursor2.line[0]) {
			draw_rectangle(
				pad_atx + cursor1.cx, 
				pad_aty + cursor1.cy, 
				pad_atx + cursor2.cx, 
				pad_aty + cursor2.cy + style.lh, 
				false
			)
		} else {
			var upper = cursor1.pos < cursor2.pos ? cursor1 : cursor2
			var lower = cursor1.pos < cursor2.pos ? cursor2 : cursor1
			draw_rectangle(
				pad_atx + upper.cx,
				pad_aty + upper.cy,
				pad_atx + getRangeWidth(upper.line[1], upper.line[2]),
				pad_aty + upper.cy + style.lh,
				false
			)
			draw_rectangle(
				pad_atx,
				pad_aty + lower.cy,
				pad_atx + getRangeWidth(lower.line[1], lower.pos),
				pad_aty + lower.cy + style.lh,
				false
			)

			for (var i = upper.line[0] + 1; i < lower.line[0]; i++) {
				var line = lines.get(i)
				draw_rectangle(
					pad_atx,
					pad_aty + (i * style.lh),
					pad_atx + getRangeWidth(line[1], line[2]),
					pad_aty + (i * style.lh) + style.lh,
					false
				)
			}
		}

		draw_set_alpha(alpha)
	}

	remove = function(backspace = true, ctrl = false) {
		var len = max(1, abs(cursor1.pos - cursor2.pos))
		if (backspace || cursor1.pos != cursor2.pos) {
			if (cursor1.pos < cursor2.pos) {
				repeat (len) {
					chars.remove(--cursor2.pos)
				}
				cursor1.pos = cursor2.pos
			} else {
				repeat (len) {
					chars.remove(--cursor1.pos)
				}
			}
		} else {
			repeat (len) {
				if (cursor1.pos + 1 < chars.size()) {
					chars.remove(cursor1.pos)
				} 
			}
		}
		
		if (ctrl) {
			this.expandSelection(!backspace)
			this.remove()
		}
		
		this.fitLines()
		this.updateCursor(cursor1, true, cursor2)
	}
	
  ///@param {any} text
  ///@return {GMTF}
	setText = function(txt) {
    try {
      chars.clear()
      chars.set(0, [ this.symbolEnd, 0 ])
  		cursor1.pos = 0
  		cursor2.pos = 0
      if (Core.isType(txt, Number)) {
        var parsed = string_format(txt, 1, this.GMTF_DECIMAL) 
        var length = string_length(parsed)
        var trim = length
        for (var index = 0; index < this.GMTF_DECIMAL; index++) {
          trim = length - index
          var char = string_char_at(parsed, trim)
          if (char != "0") {
            break
          }
        }
        parsed = string_copy(parsed, 1, trim)
        this.insert(parsed, true, true)
      } else {
				this.insert(String.replaceAll(txt, "\n", this.symbolEnter));
      }
    } catch (exception) {
      Logger.error("GMTF", $"setText exception: {exception.message}")
    }

    return this
	}
	
	///@param {Boolean} [keep_enters]
	///@return {String}
	getText = function(keep_enters = false) {
		var pos = 0
		var to = chars.size()
		var str = @""
		while (pos < to - 1) {
      var _c = chars.get(pos++)
			str += _c[0]
		}
		
		str = string_replace_all(str, this.symbolEnd, "")
		if (!keep_enters) {
			str = string_replace_all(str, this.symbolEnter, "\n")
		}
		str = string_replace_all(str, this.symbolNewLine, "")

		return str
	}
	
	copy = function(keep_enters = true) {
		var pos = min(cursor1.pos, cursor2.pos)
		var to = max(cursor1.pos, cursor2.pos)
		var str = keep_enters ? @"" : ""
		while (pos < to) {
      var _c = chars.get(pos++)
			str += _c[0]
		}
				
		str = string_replace_all(str, this.symbolEnd, "")
		str = string_replace_all(str, this.symbolEnter, "\n")
		str = string_replace_all(str, this.symbolNewLine, "")
		clipboard_set_text(str)
	}
	
	paste = function() {
		if (clipboard_has_text()) {
			var text = clipboard_get_text()
			text = String.replaceAll(text, "\r", "")
			text = String.replaceAll(text, "\n", this.symbolEnter)
			this.insert(text)
		}
	}
	
	cut = function() {
		this.copy()
		this.remove()
	}

	///@param {GMTF} textField
	///@return {?GMTF}
	findEnabledPrevious = function(textField) {
		if (!Optional.is(textField.previous_tf)) {
			return null
		}

		if (!textField.previous_tf.enabled) {
			return textField.previous_tf.findEnabledPrevious(textField.previous_tf)
		} else {
      var tf = textField.previous_tf
      if (Optional.is(tf.uiItem) 
          && Optional.is(tf.uiItem.store) 
          && tf.uiItem.hidden.value
          && Optional.is(tf.uiItem.store.getStore())) {         
        var store = tf.uiItem.store.getStore()
        if (Core.isType(tf.uiItem.hidden.keys, GMArray)) {
          for (var index = 0; index < GMArray.size(tf.uiItem.hidden.keys); index++) {
            var entry = tf.uiItem.hidden.keys[index]
            store.get(entry.key).set(Struct.getIfType(entry, "negate", Boolean, false))
          }
          uiItem.hidden.value = false
        } else if (Core.isType(tf.uiItem.hidden.key, String)) {
          store.get(tf.uiItem.hidden.key).set(Struct.getIfType(tf.uiItem.hidden, "negate", Boolean, false))
          uiItem.hidden.value = false
        }

        if (Optional.is(tf.uiItem.context)) {
          tf.uiItem.context.areaWatchdog.signal(2)
          tf.uiItem.context.clampUpdateTimer(0.9000)
        }
      }
			return textField.previous_tf
		}
	}

	///@param {GMTF} textField
	///@return {?GMTF}
	findEnabledNext = function(textField) {
		if (!Optional.is(textField.next_tf)) {
			return null
		}

		if (!textField.next_tf.enabled) {
			return textField.next_tf.findEnabledNext(textField.next_tf)
		} else {
      var tf = textField.next_tf
      if (Optional.is(tf.uiItem) 
          && Optional.is(tf.uiItem.store) 
          && tf.uiItem.hidden.value
          && Optional.is(tf.uiItem.store.getStore())) {          
        var store = tf.uiItem.store.getStore()
        if (Core.isType(tf.uiItem.hidden.keys, GMArray)) {
          for (var index = 0; index < GMArray.size(tf.uiItem.hidden.keys); index++) {
            var entry = tf.uiItem.hidden.keys[index]
            store.get(entry.key).set(Struct.getIfType(entry, "negate", Boolean, false))
          }
          uiItem.hidden.value = false
        } else if (Core.isType(tf.uiItem.hidden.key, String)) {
          store.get(tf.uiItem.hidden.key).set(Struct.getIfType(tf.uiItem.hidden, "negate", Boolean, false))
          uiItem.hidden.value = false
        }

        if (Optional.is(tf.uiItem.context)) {
          tf.uiItem.context.areaWatchdog.signal(2)
          tf.uiItem.context.clampUpdateTimer(0.9000)
        }
      }
			return textField.next_tf
		}
	}
  
	///@params {Number} x
  ///@params {Number} y
  ///@return {GMTF}
	updateFocused = function(x, y) {
		atx = x
		aty = y
		pad_atx = atx + style.padding.left
		pad_aty = aty + style.padding.top
		pad_w = style.w - style.padding.right - style.padding.left
		pad_h = style.h - style.padding.top - style.padding.bottom
		gamespd = game_get_speed(gamespeed_fps)
		mx = device_mouse_x_to_gui(0) - surface.x
		my = device_mouse_y_to_gui(0) - surface.y
		GMTFContext.switchTick = max(0, --GMTFContext.switchTick)
			
		if (!clear) {
			clear = true
			keyboard_string = ""
			cursor_tick = 0
			cursor_visible = true
		}
		
		double_clicked = false
		click_tick = max(0, --click_tick)
		if (mouse_check_button_released(mb_left)) {
			if (click_tick > 0 && last_click_pos == cursor1.pos) {
				double_clicked = true
				click_tick = 0
			} else {
				click_tick = gamespd * 0.5
				last_click_pos = cursor1.pos
			}
		}
		
		if (++cursor_tick >= gamespd * 0.5) {
			cursor_tick = 0
			cursor_visible = !cursor_visible
		}
		
		spam_now = false
		if (keyboard_check_pressed(vk_anykey)) {
			spam_time = gamespd * 0.5
			spam_tick = 0
		} else if (keyboard_check(vk_anykey)) {
			if (++spam_tick > spam_time) {
				spam_tick = 0
				spam_time = gamespd * 0.03
				spam_now = true
			}
		}
		
		if (double_clicked) {
			this.expandSelection(true)
			this.expandSelection(false)
			this.updateCursor(cursor1, true)
			this.updateCursor(cursor2)
		}
	
		if (keyboard_check_released(vk_anykey)
			&& !keyboard_check(vk_anykey)) {
			keyboard_string = ""
		}
	
		if (keyboard_check_pressed(vk_anykey) || spam_now) {
			switch (keyboard_key) {
				case vk_left:
					this.moveCursor(cursor1, -1, 0, keyboard_check(vk_control))
					break
				case vk_right:
					this.moveCursor(cursor1, 1, 0, keyboard_check(vk_control))
					break
				case vk_up:
					this.moveCursor(cursor1, 0, -1)
					break
				case vk_down:
					this.moveCursor(cursor1, 0, 1)
					break
				case vk_enter:
					if (this.style.v_grow) {
						keyboard_string += this.symbolEnter;
					} else {
						var nextTextField = this.findEnabledNext(this)
							if (Optional.is(nextTextField)) {
								nextTextField.focus()
								GMTFContext.switchTick = 2
							} else {
								if (this.has_focus) {
									this.unfocus()
								}
							}
					}
					break
				case vk_tab:
					keyboard_string = "";
					if (GMTFContext.switchTick == 0) {
						if (keyboard_check(vk_shift)) {
							var previousTextField = this.findEnabledPrevious(this)
							if (Optional.is(previousTextField)) {
								previousTextField.focus()
								GMTFContext.switchTick = 2
							}
						} else {
							var nextTextField = this.findEnabledNext(this)
							if (Optional.is(nextTextField)) {
								nextTextField.focus()
								GMTFContext.switchTick = 2
							}
						}
					}
					break
				case vk_backspace:
					this.remove(true, keyboard_check(vk_control))
					break
				case vk_delete:
					this.remove(false, keyboard_check(vk_control))
					break
        case vk_escape:
          if (this.has_focus) {
            if (Core.isType(this.uiItem, UIItem)) {
              this.setText(this.uiItem.value)
            }
            this.unfocus()
          }
          break
			}
		}
	
		if (keyboard_check(vk_anykey)) {
			if (keyboard_check_pressed(KeyboardKeyType.PAGE_UP)) {
        if (GMTFContext.get() == this) {
          GMTFContext.uiWasScrolled = false
        }

				this.cursor1.pos = 0
				this.cursor1.line = this.lines.get(0)
				this.updateCursor(this.cursor1)
        if (!keyboard_check(vk_shift)) {
          this.cursor2.pos = 0
          this.cursor2.line = this.lines.get(0)
          this.updateCursor(this.cursor2)
        }
			}

			if (keyboard_check_pressed(KeyboardKeyType.PAGE_DOWN)) {
        if (GMTFContext.get() == this) {
          GMTFContext.uiWasScrolled = false
        }

				this.cursor1.pos = this.chars.size() - 1
				this.cursor1.line = this.lines.get(this.lines.size() - 1)
				this.updateCursor(this.cursor1)
        if (!keyboard_check(vk_shift)) {
          this.cursor2.pos = this.chars.size() - 1
          this.cursor2.line = this.lines.get(this.lines.size() - 1)
          this.updateCursor(this.cursor2)
        } 
			}

			if (keyboard_check_pressed(KeyboardKeyType.HOME)) {
				this.moveCursor(this.cursor1, -1 * this.cursor1.rel_pos, 0, false)
        if (!keyboard_check(vk_shift)) {
          this.moveCursor(this.cursor2, -1 * this.cursor2.rel_pos, 0, false)
        }
			}

			if (keyboard_check_pressed(KeyboardKeyType.END)) {
				this.moveCursor(this.cursor1, String.size(this.cursor1.line[3]) - this.cursor1.rel_pos, 0, false)
        if (!keyboard_check(vk_shift)) {
				  this.moveCursor(this.cursor2, String.size(this.cursor2.line[3]) - this.cursor2.rel_pos, 0, false)
        }
			}

			if (keyboard_check(vk_control)) {
				if (keyboard_check_pressed(ord("C")) 
					&& cursor1.pos != cursor2.pos) {
					keyboard_string = ""
					this.copy()


				} else if (keyboard_check_pressed(ord("V")) 
					|| (keyboard_check(ord("V")) && spam_now)) {
					
					keyboard_string = ""
					this.paste()
				} else if (keyboard_check_pressed(ord("X")) 
					&& cursor1.pos != cursor2.pos) {
					
					keyboard_string = ""
					this.cut()
				} else if (keyboard_check_pressed(ord("A"))) {
					keyboard_string = ""
					cursor2.pos = 0
					cursor1.pos = chars.size()
					this.updateCursor(cursor1, true)
					this.updateCursor(cursor2)
				} else if (keyboard_check_pressed(vk_backspace)) {
					keyboard_string = ""
				}
			}
		
			if (string_length(keyboard_string) != 0) {
				this.insert(keyboard_string)
				keyboard_string = ""
			}
		}

		return this
	}

	bugDelay = false

  ///@return {GMTF}
	onMousePressed = function() {
		if (!this.isFocused()) {
			return this
		}

		if (mouse_check_button_pressed(mb_left)) {
			if (point_in_rectangle(mx, my, atx, aty, atx + style.w, aty + style.h)) {
				this.focus()
			} else if (this.has_focus) {
				this.unfocus()
			}

			this.bugDelay = false
			this.cursorToMouse(cursor2)
			this.copyCursorInfo(cursor2, cursor1)
			if (GMTFContext.get() == this) {
				GMTFContext.uiWasScrolled = false
			}
		} else if (mouse_check_button(mb_left) && !mouse_check_button_released(mb_left)) {
			if (this.bugDelay) {
				this.cursorToMouse(cursor1)
			} else {
				this.cursorToMouse(cursor2)
				this.copyCursorInfo(cursor2, cursor1)
			}
			this.bugDelay = true
		} else {
			this.bugDelay = false
		}

		return this
	}

  ///@params {Number} x
  ///@params {Number} y
  ///@return {GMTF}
  update = function(x, y) {
     this.surface.x = x
     this.surface.y = y
     return this
  }

	///@params {Number} x
  ///@params {Number} y
  ///@return {GMTF}
	draw = function(x, y) {
		atx = x
		aty = y
		pad_atx = atx + style.padding.left
		pad_aty = aty + style.padding.top
		pad_w = style.w - style.padding.right - style.padding.left
		pad_h = style.h - style.padding.top - style.padding.bottom
		gamespd = game_get_speed(gamespeed_fps)
		mx = device_mouse_x_to_gui(0) - surface.x
		my = device_mouse_y_to_gui(0) - surface.y
		has_focus = GMTFContext.get() == this
		if (!has_focus) {
			clear = false
		}

		this.onMousePressed()
		this.render(x, y)

		return this
	}

	///@param {Number} x
	///@param {Number} y
	render = function(x, y) {
		if (GMTFContext.get() == this) {
			GMTFContext.currentWasDrawn = true
		}

		var prevFont = draw_get_font()
		var prevColor = draw_get_color()
		var prevAlpha = draw_get_alpha()
		draw_set_font(style.font)

    draw_set_alpha(has_focus ? style.c_bkg_focused.a : style.c_bkg_unfocused.a)
		draw_set_color(has_focus ? style.c_bkg_focused.c : style.c_bkg_unfocused.c)
    draw_rectangle(atx, aty, atx + style.w, aty + style.h, false)

    draw_set_alpha(has_focus ? style.c_outline_focused.a : style.c_outline_unfocused.a)
		draw_set_color(has_focus ? style.c_outline_focused.c : style.c_outline_unfocused.c)
    draw_rectangle(atx + 1, aty + 1, atx + style.w - 1, aty + style.h - 1, true)
		
		if (has_focus && cursor1.pos != cursor2.pos) {
			this.renderSelection()
		}
		
		draw_set_color(has_focus ? style.c_text_focused.c : style.c_text_unfocused.c)
		draw_set_alpha(has_focus ? style.c_text_focused.a : style.c_text_unfocused.a)

		draw_set_valign(2)
		var s = null
		if (style.min_chw == 0) {
			draw_set_halign(0)
			s = lines.size()
			for (var i = 0; i < s; i++) {
        var line = lines.get(i)
				draw_text(pad_atx, pad_aty + i * style.lh + style.lh, line[3])
			}
		} else {
			draw_set_halign(1)
			var wid = 0
			s = lines.size()
			for (var i = 0; i < s; i++) {
				var line = lines.get(i)
				for (var pos = line[1]; pos < line[2]; pos++) {
					var char = chars.get(pos)
					var chw = char[1]
					draw_text(pad_atx + wid + (chw div 2), pad_aty + i * style.lh + style.lh, char[0])
					wid += chw
				}
				wid = 0
			}
		}
		draw_set_valign(0)
		draw_set_halign(0)
		
		if (has_focus && cursor_visible) {
			draw_line(
				pad_atx + cursor1.cx, 
				pad_aty + cursor1.cy, 
				pad_atx + cursor1.cx,
				pad_aty + cursor1.cy + style.lh
			)
		}
		
		draw_set_font(prevFont)
		draw_set_color(prevColor)
		draw_set_alpha(prevAlpha)

		return this
	}

	this.updateStyle(style_struct)
}


function initGMTF() {
	GMTFContext = new _GMTFContext()
}