/*
    rhtml.js
    (c) Wolfgang Schwarz <wo@umsu.de> 
*/

/***

bookmarklet for debugging:

javascript:(function(){var%20s=document.createElement('script');%20s.type='text/javascript';%20s.src='http://umsu.de/opp/debug/rhtml.js';%20document.getElementsByTagName("head")[0].appendChild(s);setTimeout('function%20dump(s)%20{%20if%20(!self.dWsN){dWsN=self.open(\'about:blank\',\'dWsN\');dWsN.document.write("<pre>");}dWsN.document.write(s.replace(/</g,"&lt;")+"\\n");%20};%20rhtml()',1000);})()

***/

var DEBUG = false;

function WebProgressListener() {
}

WebProgressListener.prototype = {
  _requestsStarted: 0,
  _requestsFinished: 0,

  QueryInterface: function(iid) {
    if (iid.equals(Components.interfaces.nsIWebProgressListener) ||
        iid.equals(Components.interfaces.nsISupportsWeakReference) ||
        iid.equals(Components.interfaces.nsISupports))
      return this;
    
    throw Components.results.NS_ERROR_NO_INTERFACE;
  },

  onStateChange: function(webProgress, request, stateFlags, status) {
    const WPL = Components.interfaces.nsIWebProgressListener;

    if (stateFlags & WPL.STATE_IS_REQUEST) {
      if (stateFlags & WPL.STATE_START) {
        this._requestsStarted++;
      } else if (stateFlags & WPL.STATE_STOP) {
        this._requestsFinished++;
      }
    }

    if (stateFlags & WPL.STATE_IS_NETWORK) {
      if (stateFlags & WPL.STATE_STOP) {
        this.onStatusChange(webProgress, request, 0, "Done");
        this._requestsStarted = this._requestsFinished = 0;
      }
    }
  },

  onProgressChange: function(webProgress, request, curSelf, maxSelf, curTotal, maxTotal) {
  },

  onLocationChange: function(webProgress, request, location) {
  },

  onStatusChange: function(webProgress, request, status, message) {
    if (status == 0) rhtml();
  },

  onSecurityChange: function(webProgress, request, state) {
  }
};

function rhtml() {
     DEBUG = DEBUG || !document.getElementById("browser");
     try {
        if (DEBUG) dump("starting rhtml()\n");
        var Tstart = new Date().getTime();
        var browser = document.getElementById("browser");
        var doc = browser ? browser.contentWindow.document : document;
        doc.fonts = [];
        doc.getTextChunks = getTextChunks;
        var chunks = doc.getTextChunks(doc);
        if (DEBUG) dump("starting xml output\n");
        var xml  = [
           '<?xml version="1.0" encoding="ISO-8859-1"?>',
           '<!DOCTYPE rhtml SYSTEM "rhtml.dtd">',
           '',
           '<rhtml>',
           '<page number="1" position="absolute" top="0" left="0"'
           + ' height="' + doc.realHeight + '" width="' + doc.realWidth + '">'
        ];
        for (var family in doc.fonts) {
           for (var size in doc.fonts[family]) {
              for (var color in doc.fonts[family][size]) {
                 var id = doc.fonts[family][size][color];
                 xml.push('   <fontspec id="'+id+'" size="'+size+'" family="'+family+'" color="'+color+'"/>');
              }
           }
        }
        xml.push('');
        for (var i=0; i<chunks.length; i++) {
           var chunk = chunks[i];
           xml.push('<text top="'+chunk.top+'" left="'+chunk.left+'" width="'+chunk.width
                   +'" height="'+chunk.height+'" font="'+chunk.font+'">'+chunk.text+'</text>');
        }
        xml.push('</page>');
        xml.push('</rhtml>');
        dump(xml.join('\n')+'\n');
     } catch (e) { 
	 dump('oh no. '+e.message+'\n'); 
     }
     var Tend = new Date().getTime();
     if (DEBUG) dump("rhtml() finished: "+(Tend-Tstart));
     window.close();
};

function getTextChunks(el) {
   if (DEBUG) dump("getTextChunks()\n");
   // Need to turn all words in all text nodes into separate elements.
   var textNodes = getTextNodes(el);
   if (DEBUG) dump(textNodes.length+" text nodes");
   var blocks = [];
   // This can take ages, so we break after a certain time.
   var time1 = new Date().getTime();
   var TIMEOUT = 20000;
   for (var i=0; i<textNodes.length; i++) {
      if (new Date().getTime() - time1 > TIMEOUT) {
         dump("TIMEOUT: WE ARE TAKING TOO LONG.\n");
         break;
      }
      el = textNodes[i];
      var str = el.nodeValue.replace(/\s/g, ' ');
      var block = [];
      var space, nextEl;
      do {
         // split node before next space:
         var spacePos = str.indexOf(' ');
	 // lines can also be broken at minus symbols:
	 var minusPos = str.indexOf('-');
         if (minusPos > 0 && (minusPos < spacePos) || spacePos == -1) {
	    spacePos = minusPos;
         }
         if (spacePos == -1) nextEl = null;
         else {
            nextEl = el.splitText(spacePos); 
            str = str.substr(spacePos);
            // now nextEl begins with space(s), remove them:
	//    if (spacePos != minusPos) {
               spacePos = 1;
               while (str[spacePos] == ' ') spacePos++;
               if (spacePos >= str.length-1) nextEl = null;
               else {
                  nextEl = nextEl.splitText(spacePos);
                  str = str.substr(spacePos);
               }
        //    } 
         }
         // wrap <u> around this textNode:
         var u = this.createElement('u');
         el.parentNode.replaceChild(u, el);
         u.appendChild(el);
         if (u.offsetWidth > 0) { // yes, this can happen and will fuck things up
            block.push(u);
         }
         // proceed with sibling:
      } while ((el = nextEl));
      blocks.push(block);
   }
   // now get information about the words:
   var chunks = [];
   this.realHeight = this.body ? this.body.offsetHeight : 0;
   this.realWidth = this.body ? this.body.offsetWidth : 0;
   for (var i=0; i<blocks.length; i++) {
      var el = blocks[i][0];
      // get font information:
      try { // crashes on http://www.d.umn.edu/~dcole/sense5.html
         var style = this.defaultView.getComputedStyle(el, null);
         var fontFamily = style && style.getPropertyValue('font-family');
         var fontSize = style && parseInt(style.getPropertyValue('font-size'));
         var fontColor = style && style.getPropertyValue('color');
      }
      catch(e) {
         continue;
      }
      if (!this.fonts[fontFamily]) this.fonts[fontFamily] = [];
      if (!this.fonts[fontFamily][fontSize]) this.fonts[fontFamily][fontSize] = [];
      if (!this.fonts[fontFamily][fontSize][fontColor]) {
         if (!this._fontCounter) this._fontCounter = 0;
         this._fontCounter++;
         this.fonts[fontFamily][fontSize][fontColor] = this._fontCounter;
      }
      // merge words as long as they are on the same line:
      var w = 0;
      var coords = absCoords(el);
      do {
         var chunk = {
            left : coords[0],
            top : coords[1],
            width : el.offsetWidth,
            height : el.offsetHeight,
            text : el.firstChild.nodeValue,
            font : this.fonts[fontFamily][fontSize][fontColor]
         };
         while ((el = blocks[i][++w]) && (coords = absCoords(el)) && (coords[1] == chunk.top)) {
            chunk.width += el.offsetWidth;
            if (el.offsetHeight > chunk.height) chunk.height = el.offsetHeight;
            chunk.text += ' '+el.firstChild.nodeValue;
if (DEBUG) dump(chunk.text + ':' + chunk.left + '/' + chunk.width);
         }
         // if font is italic or bold, add the tags to the nodeValue (as pdftohtml does):
         if (style && style.getPropertyValue('font-weight') == 'bold') {
            chunk.text = '<b>'+chunk.text+'</b>';
         }
         if (style && style.getPropertyValue('font-style') == 'italic') {
            chunk.text = '<i>'+chunk.text+'</i>';
         }
         chunk.text = chunk.text.replace(/\s/g, ' ');
         if (chunk.height > 0) {
            chunks.push(chunk);
            if (this.realHeight < chunk.top + chunk.height) {
	       this.realHeight = chunk.top + chunk.height;
            }
            if (this.realWidth < chunk.left + chunk.width) {
               this.realWidth = chunk.left + chunk.width;
               //dump('this.realWidth = '+ chunk.left + '+' + chunk.width);
            }
         }
      } while (el);
   }
   return chunks;
}

function getTextNodes(el, arr) {
   if (!arr) arr = [];
   if (el.nodeType != 3) {
      for (var i=0; i<el.childNodes.length; i++) {
         getTextNodes(el.childNodes[i], arr);
      }
   }
   else {
      // skip empty nodes (e.g. linebreak nodes between HTML elements),
      // skip elements with height 0 (comments, <title>):
      if (!(/^\s*$/.test(el.nodeValue)) && el.parentNode.offsetHeight > 0) {
         arr.push(el);
      }
   }
   return arr;
}

function absCoords(el) {
   var ret = [0,0];
   do {
      ret[0] += el.offsetLeft;
      ret[1] += el.offsetTop;
   }
   while ((el = el.offsetParent)); 
   return ret;
}



function getTextChunks_old(el) {

   // recursion:
   if (el.nodeType != 3) {
      // while traversing the DOM tree, we add absLeft, absTop, absWidth, absHeight properties:
      el.absLeft = el.offsetLeft;
      el.absTop = el.offsetTop;
      el.absWidth = el.offsetWidth;
      el.absHeight = el.offsetHeight;
      if (el.offsetParent) {
         el.absLeft += el.offsetParent.absLeft;
         el.absTop += el.offsetParent.absTop;
      }
      // merge adjactent text child nodes:
      el.normalize();
      for (var i=0; i<el.childNodes.length; i++) {
         this.getTextChunks(el.childNodes[i]);
      }
      if (el.offsetParent) {
         if (el.offsetParent.absWidth < el.offsetLeft + el.absWidth) 
            el.offsetParent.absWidth = el.offsetLeft + el.absWidth;
         if (el.offsetParent.absHeight < el.offsetTop + el.absHeight)
            el.offsetParent.absHeight = el.offsetTop + el.absHeight;
      }
      return;
   }
   // skip linebreak nodes between HTML elements:
   if (el.nodeValue == '\n') return;
   // skip nodes with width 0, like comments and <title> text: 
   if (el.parentNode.absWidth == 0) return;

   var chunk = {
      left : el.parentNode.absLeft,
      top : el.parentNode.absTop,
      width : el.parentNode.absWidth,
      height : el.parentNode.absHeight
   };
   // get font information:
   var style = this.defaultView.getComputedStyle(el.parentNode, null);
   var fontFamily = style && style.getPropertyValue('font-family');
   var fontSize = style && parseInt(style.getPropertyValue('font-size'));
   var fontColor = style && style.getPropertyValue('color');
   if (!this.fonts[fontFamily]) this.fonts[fontFamily] = [];
   if (!this.fonts[fontFamily][fontSize]) this.fonts[fontFamily][fontSize] = [];
   if (!this.fonts[fontFamily][fontSize][fontColor]) {
      if (!this._fontCounter) this._fontCounter = 0;
      this._fontCounter++;
      this.fonts[fontFamily][fontSize][fontColor] = this._fontCounter;
   }
   chunk.font = this.fonts[fontFamily][fontSize][fontColor];

   chunk.text = el.nodeValue;
   // if font is italic or bold, add the tags to the nodeValue (as pdftohtml does):
   if (style && style.getPropertyValue('font-weight') == 'bold') {
      chunk.text = '<b>'+chunk.text+'</b>';
   }
   if (style && style.getPropertyValue('font-style') == 'italic') {
      chunk.text = '<i>'+chunk.text+'</i>';
   }
   this.chunks.push(chunk);
}

function onload() {
  var browser = document.getElementById("browser");
  var nsCommandLine = window.arguments[0];
  nsCommandLine = nsCommandLine.QueryInterface(Components.interfaces.nsICommandLine);
  if (nsCommandLine.length == 0) {
    dump("File argument missing");
    window.close();
  }
  browser.loadURI(nsCommandLine.getArgument(0), null, null);
  var listener = new WebProgressListener();
  browser.addProgressListener(listener,
    Components.interfaces.nsIWebProgress.NOTIFY_ALL);
}
