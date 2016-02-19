YUI.add("gallery-outside-events", function (b) {
    var a = ["blur", "change", "click", "dblclick", "focus", "keydown", "keypress", "keyup", "mousedown", "mousemove", "mouseout", "mouseover", "mouseup", "select", "submit"];
    b.Event.defineOutside = function (d, c) {
        c = c || d + "outside";
        b.Event.define(c, {on: function (g, e, f) {
            e.onHandle = b.one("doc").on(d, function (h) {
                if (this.isOutside(g, h.target)) {
                    f.fire(h)
                }
            }, this)
        }, detach: function (g, e, f) {
            e.onHandle.detach()
        }, delegate: function (h, f, g, e) {
            f.delegateHandle = b.one("doc").delegate(d, function (i) {
                if (this.isOutside(h, i.target)) {
                    g.fire(i)
                }
            }, e, this)
        }, detachDelegate: function (h, f, g, e) {
            f.delegateHandle.detach()
        }, isOutside: function (e, f) {
            return f !== e && !f.ancestor(function (g) {
                return g === e
            })
        }})
    };
    b.each(a, function (c) {
        b.Event.defineOutside(c)
    })
}, "1.1.0", {requires: ["event-focus", "event-synthetic"]});

YUI.add("gallery-overlay-extras", function (d) {
    /*!
     * Overlay Extras
     *
     * Oddnut Software
     * Copyright (c) 2009-2011 Eric Ferraiuolo - http://oddnut.com
     * YUI BSD License - http://developer.yahoo.com/yui/license.html
     */
    var j = "overlay", r = "host", p = "renderUI", g = "bindUI", m = "syncUI", b = "rendered", t = "boundingBox", q = "visible", f = "zIndex", i = "align", n = "Change", k = d.Lang.isBoolean, s = d.ClassNameManager.getClassName, c = d.one("doc"), e = (function () {
        /*! IS_POSITION_FIXED_SUPPORTED - Juriy Zaytsev (kangax) - http://yura.thinkweb2.com/cft/ */
        var v = null, w, u;
        if (document.createElement) {
            w = document.createElement("div");
            if (w && w.style) {
                w.style.position = "fixed";
                w.style.top = "10px";
                u = document.body;
                if (u && u.appendChild && u.removeChild) {
                    u.appendChild(w);
                    v = (w.offsetTop === 10);
                    u.removeChild(w)
                }
            }
        }
        return v
    }()), a, l, o, h;
    (function () {
        var x = "overlayModal", w = "modal", v = "mask", u = {modal: s(j, w), mask: s(j, v)};
        a = d.Base.create(x, d.Plugin.Base, [], {_maskNode: null, _uiHandles: null, initializer: function (y) {
            this.afterHostMethod(p, this.renderUI);
            this.afterHostMethod(g, this.bindUI);
            this.afterHostMethod(m, this.syncUI);
            if (this.get(r).get(b)) {
                this.renderUI();
                this.bindUI();
                this.syncUI()
            }
        }, destructor: function () {
            if (this._maskNode) {
                this._maskNode.remove(true)
            }
            this._detachUIHandles();
            this.get(r).get(t).removeClass(u.modal)
        }, renderUI: function () {
            var z = this.get(r).get(t), y = d.one("body");
            this._maskNode = d.Node.create("<div></div>");
            this._maskNode.addClass(u.mask);
            this._maskNode.setStyles({position: e ? "fixed" : "absolute", width: "100%", height: "100%", top: "0", left: "0", display: "none"});
            y.insert(this._maskNode, y.get("firstChild"));
            z.addClass(u.modal)
        }, bindUI: function () {
            this.afterHostEvent(q + n, this._afterHostVisibleChange);
            this.afterHostEvent(f + n, this._afterHostZIndexChange)
        }, syncUI: function () {
            var y = this.get(r);
            this._uiSetHostVisible(y.get(q));
            this._uiSetHostZIndex(y.get(f))
        }, _focus: function () {
            var z = this.get(r), A = z.get(t), y = A.get("tabIndex");
            A.set("tabIndex", y >= 0 ? y : 0);
            z.focus();
            A.set("tabIndex", y)
        }, _blur: function () {
            this.get(r).blur()
        }, _getMaskNode: function () {
            return this._maskNode
        }, _uiSetHostVisible: function (y) {
            if (y) {
                d.later(1, this, "_attachUIHandles");
                this._maskNode.setStyle("display", "block");
                this._focus()
            } else {
                this._detachUIHandles();
                this._maskNode.setStyle("display", "none");
                this._blur()
            }
        }, _uiSetHostZIndex: function (y) {
            this._maskNode.setStyle(f, y || 0)
        }, _attachUIHandles: function (z) {
            if (this._uiHandles) {
                return
            }
            var y = this.get(r), A = y.get(t);
            this._uiHandles = [A.on("clickoutside", d.bind(this._focus, this)), A.on("focusoutside", d.bind(this._focus, this))];
            if (!e) {
                this._uiHandles.push(d.one("win").on("scroll", d.bind(function (C) {
                    var B = this._maskNode;
                    B.setStyle("top", B.get("docScrollY"))
                }, this)))
            }
        }, _detachUIHandles: function () {
            d.each(this._uiHandles, function (y) {
                y.detach()
            });
            this._uiHandles = null
        }, _afterHostVisibleChange: function (y) {
            this._uiSetHostVisible(y.newVal)
        }, _afterHostZIndexChange: function (y) {
            this._uiSetHostZIndex(y.newVal)
        }}, {NS: w, ATTRS: {maskNode: {getter: "_getMaskNode", readOnly: true}}, CLASSES: u})
    }());
    (function () {
        var v = "overlayKeepaligned", u = "keepaligned";
        l = d.Base.create(v, d.Plugin.Base, [], {_uiHandles: null, initializer: function (w) {
            this.afterHostMethod(g, this.bindUI);
            this.afterHostMethod(m, this.syncUI);
            if (this.get(r).get(b)) {
                this.bindUI();
                this.syncUI()
            }
        }, destructor: function () {
            this._detachUIHandles()
        }, bindUI: function () {
            this.afterHostEvent(q + n, this._afterHostVisibleChange)
        }, syncUI: function () {
            this._uiSetHostVisible(this.get(r).get(q))
        }, syncAlign: function () {
            this.get(r)._syncUIPosAlign()
        }, _uiSetHostVisible: function (w) {
            if (w) {
                this._attachUIHandles()
            } else {
                this._detachUIHandles()
            }
        }, _attachUIHandles: function () {
            if (this._uiHandles) {
                return
            }
            var w = d.bind(this.syncAlign, this);
            this._uiHandles = [d.on("windowresize", w), d.on("scroll", w)]
        }, _detachUIHandles: function () {
            d.each(this._uiHandles, function (w) {
                w.detach()
            });
            this._uiHandles = null
        }, _afterHostVisibleChange: function (w) {
            this._uiSetHostVisible(w.newVal)
        }}, {NS: u})
    }());
    (function () {
        var x = "overlayAutohide", v = "autohide", w = "clickedOutside", y = "focusedOutside", u = "pressedEscape";
        o = d.Base.create(x, d.Plugin.Base, [], {_uiHandles: null, initializer: function (z) {
            this.afterHostMethod(g, this.bindUI);
            this.afterHostMethod(m, this.syncUI);
            if (this.get(r).get(b)) {
                this.bindUI();
                this.syncUI()
            }
        }, destructor: function () {
            this._detachUIHandles()
        }, bindUI: function () {
            this.afterHostEvent(q + n, this._afterHostVisibleChange)
        }, syncUI: function () {
            this._uiSetHostVisible(this.get(r).get(q))
        }, _uiSetHostVisible: function (z) {
            if (z) {
                d.later(1, this, "_attachUIHandles")
            } else {
                this._detachUIHandles()
            }
        }, _attachUIHandles: function () {
            if (this._uiHandles) {
                return
            }
            var B = this.get(r), C = B.get(t), A = d.bind(B.hide, B), z = [];
            if (this.get(w)) {
                z.push(C.on("clickoutside", A))
            }
            if (this.get(y)) {
                z.push(C.on("focusoutside", A))
            }
            if (this.get(u)) {
                z.push(c.on("key", A, "esc"))
            }
            this._uiHandles = z
        }, _detachUIHandles: function () {
            d.each(this._uiHandles, function (z) {
                z.detach()
            });
            this._uiHandles = null
        }, _afterHostVisibleChange: function (z) {
            this._uiSetHostVisible(z.newVal)
        }}, {NS: v, ATTRS: {clickedOutside: {value: true, validator: k}, focusedOutside: {value: true, validator: k}, pressedEscape: {value: true, validator: k}}})
    }());
    (function () {
        var x = "overlayPointer", v = "pointer", w = "pointing", u = {pointer: s(j, v), pointing: s(j, w)};
        h = d.Base.create(x, d.Plugin.Base, [], {_pointerNode: null, initializer: function (y) {
            this.afterHostMethod(p, this.renderUI);
            this.afterHostMethod(g, this.bindUI);
            this.afterHostMethod(m, this.syncUI);
            if (this.get(r).get(b)) {
                this.renderUI();
                this.bindUI();
                this.syncUI()
            }
        }, destructor: function () {
            var z = this.get(r), A = z.get(t), B = z.get(i), y = this._pointerNode;
            A.removeClass(u.pointing);
            if (B && B.points) {
                A.removeClass(s(j, w, B.points[0]))
            }
            if (y) {
                y.remove(true)
            }
        }, renderUI: function () {
            this._pointerNode = d.Node.create("<span></span>").addClass(u.pointer);
            this.get(r).get(t).append(this._pointerNode)
        }, bindUI: function () {
            this.afterHostEvent(i + n, this._afterHostAlignChange)
        }, syncUI: function () {
            this._uiSetHostAlign(this.get(r).get(i))
        }, _getPointerNode: function () {
            return this._pointerNode
        }, _uiSetHostAlign: function (z, y) {
            var B = this.get(r), C = B.get(t), A = this._pointerNode;
            if (y && y.points) {
                C.removeClass(s(j, w, y.points[0]));
                C.removeClass(s(j, w, y.points[0], y.points[1]))
            }
            if (z && z.node && z.points[0] !== d.WidgetPositionAlign.CC) {
                C.addClass(u.pointing);
                C.addClass(s(j, w, z.points[0]));
                C.addClass(s(j, w, z.points[0], z.points[1]));
                A.show()
            } else {
                A.hide();
                C.removeClass(u.pointing)
            }
            B._syncUIPosAlign()
        }, _afterHostAlignChange: function (y) {
            this._uiSetHostAlign(y.newVal, y.prevVal)
        }}, {NS: v, ATTRS: {pointerNode: {getter: "_getPointerNode", readOnly: true}}, CLASSES: u})
    }());
    d.Plugin.OverlayModal = a;
    d.Plugin.OverlayKeepaligned = l;
    d.Plugin.OverlayAutohide = o;
    d.Plugin.OverlayPointer = h
}, "gallery-2011.05.04-20-03", {requires: ["base", "widget-anim", "gallery-outside-events"]});

