/*
    html2xml.js
    Version 0.1 -- 2006-12-10
    Wolfgang Schwarz <wo@umsu.de> 
*/

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
    if (status == 0) html2xml();
  },

  onSecurityChange: function(webProgress, request, state) {
  }
};

function html2xml() {
     try {
        // var Tstart = new Date().getTime();
        var browser = document.getElementById("browser");
        var doc = browser.contentWindow.document;
        doc.chunks = [];
        doc.fonts = [];
        doc.getTextChunks = getTextChunks;
        doc.getTextChunks(doc);
        var xml  = [
           '<?xml version="1.0" encoding="ISO-8859-1"?>',
           '<!DOCTYPE html2xml SYSTEM "html2xml.dtd">',
           '',
           '<html2xml>',
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
        for (var i=0; i<doc.chunks.length; i++) {
           var chunk = doc.chunks[i];
           xml.push('<text top="'+chunk.top+'" left="'+chunk.left+'" width="'+chunk.width
                   +'" height="'+chunk.height+'" font="'+chunk.font+'">'+chunk.text+'</text>');
        }
        xml.push('</page>');
        xml.push('</html2xml>');
        dump(xml.join('\n')+'\n');
     } catch (e) { 
	 dump(e+'\n'); 
     }
     // var Tend = new Date().getTime();
     // dump("html2xml finished: "+(Tend-Tstart));
     window.close();
};


function getTextChunks(el) {

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
