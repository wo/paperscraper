/*
 * Copyright 2002-2006 Jahia Ltd
 *
 * Licensed under the JAHIA COMMON DEVELOPMENT AND DISTRIBUTION LICENSE (JCDDL),
 * Version 1.0 (the "License"), or (at your option) any later version; you may
 * not use this file except in compliance with the License. You should have
 * received a copy of the License along with this program; if not, you may obtain
 * a copy of the License at
 *
 *  http://www.jahia.org/license/
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *///  NK      14.05.2001   Close global engine popup when opening a new one!
//  NK      14.05.2001  Within a same site, append each window name with the session id
//                      to resolve session conflict between different sites  !
//  NK      22.05.2001  If a popup is already opened ( check if its name is equal with the one to open),
//                      give it the focus instead of close and reopen it.
//  NK      30.01.2002  yO ! another subtil bug found.
//                      Added closeEngineWin(), this function should be set on the "onUnload" and "onClose()" event
//                      of any page from which engine popup can be launched.
//                      This ensure that when the page is closed or unloaded,any engine popup that is left open is closed !!!!
//                      Whitout that, more than one engine can be left open and this means -> possible engine session conflict !!!!
//  MC       30.08.2005 Removed matrix param
//
// $Id: jahia.js 20702 2008-05-20 13:27:58Z xlawrence $


// global popup
var myEngineWin = null;
var pickerlist = null;
var workInProgress = null;
var GlobalCallbackCount = 0;
var GlobalCallback = new Array();
var GlobalListenerCount = 0;
var GlobalCommands = new Array();
// OpenJahiaWindow
function OpenJahiaWindow(url, name, width, height) {
    var params;
    // check for veryvery small screens
    if (screen.availHeight <= 720 || screen.availWidth <= 950) {
        width = screen.availWidth;
        height = screen.availHeight;
        params = "width=" + width + ",height=" + height + ",left=10,top=10,resizable=yes,scrollbars=yes,status=no";
    } else {
        params = "width=" + width + ",height=" + height + ",left=10,top=10,resizable=yes,scrollbars=no,status=no";
    }

    // Hollis : check if the popup is alread opened, if so, give it the focus
    if (myEngineWin != null) {
      try {    
        if (myEngineWin.closed) { // need to test it first...
            myEngineWin = null;
            myEngineWin = window.open(url, name, params);
        } else {
            if (myEngineWin.name != name) {
                myEngineWin.close();
                myEngineWin = null;
                myEngineWin = window.open(url, name, params);
            } else {
                myEngineWin.focus();
            }
        }
      } catch (ex) {
        // suppress exception
      }        
    } else {
        myEngineWin = window.open(url, name, params);
    }

}
// end OpenJahiaWindow


// OpenJahiaScrollableWindow
function OpenJahiaScrollableWindow(url, name, width, height) {

    // check for veryvery small screens
    if (screen.availHeight <= 720 || screen.availWidth <= 950) {
        width = screen.availWidth;
        height = screen.availHeight;
    }

    var params = "width=" + width + ",height=" + height + ",left=10,top=10,resizable=yes,scrollbars=yes,status=no";
    // Check if the popup is alread opened, if so, give it the focus
    if (myEngineWin != null) {
      try {
        if (myEngineWin.closed) { // need to test it first...
            myEngineWin = null;
            myEngineWin = window.open(url, name, params);
        } else {
            if (myEngineWin.name != name) {
                myEngineWin.close();
                myEngineWin = null;
                myEngineWin = window.open(url, name, params);
            } else {
                myEngineWin.focus();
            }
        }
      } catch (ex) {
        // suppress exception
      }        
    } else {
        myEngineWin = window.open(url, name, params);
    }
}
// end OpenJahiaScrollableWindow

// ReloadEngine
function ReloadEngine(params) {
    var oldurl = location.href;
    var pos = oldurl.indexOf("&engine_params");
    if (pos != -1) {
        oldurl = oldurl.substring(0, pos);
    }
    var newurl = oldurl + "&engine_params=" + params;
    location.href = newurl;

}

// end ReloadEngine
function closeEngineWin() {
    document.body.style.cursor = "default";
    if (myEngineWin != null) {
      try {       
        if (myEngineWin.closed) { // need to test it first...
            purge(myEngineWin.document);
            myEngineWin = null;
        } else {
            myEngineWin.close();
            purge(myEngineWin.document);
            myEngineWin = null;
        }
      } catch (ex) {
        // suppress exception
      }              
    }else{
        // it's not an engine window
        purge(document.body);
        
    }
}

function closeEngineWinAllPopups() {
    document.body.style.cursor = "default";
    try {
    if (myEngineWin != null) {
        if (myEngineWin.closed) { // need to test it first...
            if (myEngineWin.myWin && !myEngineWin.myWin.closed) {
                myEngineWin.myWin.close();
                purge(myEngineWin.myWin.document);
            }
            purge(myEngineWin.document);
            myEngineWin.myWin = null;
            myEngineWin = null;
        } else {
            if (myEngineWin.myWin && !myEngineWin.myWin.closed) {
                myEngineWin.myWin.close();
                purge(myEngineWin.myWin.document);
            }
            myEngineWin.close();
            purge(myEngineWin.document);
            myEngineWin.myWin = null;
            myEngineWin = null;
        }
    }
    } catch (e) {}
}

// Open "Work in progress window"
// param httpserverpath should be http://<servername>:<port>
function openWorkInProgressWindow(httpServerPath) {
    var params = "width=200,height=200,left=0,top=0,resizable=no,scrollbars=no,status=no";
    var theUrl = httpServerPath;
    theUrl += "/jsp/jahia/administration/work_in_progress.html";
    //var workInProgressWin = window.open( theUrl, "workInProgressWin", params );
    workInProgress = window.open(theUrl, "workInProgressWin", params);

}
// openWorkInProgressWindow

var oldLoc = "";

// CloseJahiaWindow
function CloseJahiaWindow(refreshOpener) {
    var params = "";
    if (CloseJahiaWindow.arguments.length > 1) {
        params = CloseJahiaWindow.arguments[1];
    }

    if (! window.opener) {
        window.close();
        delete window;
        if (myEngineWin != null) purge(myEngineWin.document);
        myEngineWin = null;
        return;
    }

    var oldUrl = window.opener.location.href;
    var pos = oldUrl.indexOf("&engine_params");
    if (pos != -1) {
        oldUrl = oldUrl.substring(0, pos);
    }

    var pos2 = oldUrl.indexOf("#");
    var anchorVal = oldUrl.substring(pos2, oldUrl.length);

    if (pos2 != -1) {
        oldUrl = oldUrl.substring(0, pos2);
    }

    var newUrl = "";

    if (oldUrl.indexOf("?") != -1) {
        newUrl = oldUrl;
    } else {
        newUrl = oldUrl;
        if (pos2 != -1) {
            newUrl = newUrl + anchorVal;
        }
    }
    if (params != "") {
        newUrl += params;
        if (pos2 != -1) {
            newUrl = newUrl + anchorVal;
        }
    }

    //alert( "Refreshing window with url :\n" + newUrl +"\n params: "+params+ "refreshOpener = "+refreshOpener);
    if(newUrl.charAt(newUrl.length -1) == '#') {
    	newUrl = newUrl.substring(0, newUrl.length -1);
    }
    try {
        if (params.indexOf("submit") != -1) {
            if (refreshOpener.indexOf("yes") != -1) {
                if (window.opener != null) {
                    window.opener.document.forms[0].submit();
                }
            } else {
                window.opener.refreshMonitor();
            }
        } else {
            if (refreshOpener.indexOf("yes") != -1) {
                window.opener.location.href = newUrl;
            } else {
                window.opener.refreshMonitor();
            }
            oldLoc = window.opener.location;
            WaitForRefresh();
        }
        window.close();
        if (myEngineWin != null) purge(myEngineWin.document);
        purge(window.document);
        delete window;
        myEngineWin = null;
    } catch (ex) {
        window.close();
        if (myEngineWin != null) purge(myEngineWin.document);
        purge(window.document);
        myEngineWin = null;
        delete window;
    }
}
// end CloseJahiaWindow


    // CloseJahiaWindow - added for deleting current site to display parentsite after delete
    function CloseJahiaWindowWithUrl(newUrl) {
        //alert( "Rereshing window with url :\n" + newUrl );
        window.opener.location.href = newUrl;
        oldLoc = window.opener.location;
        WaitForRefresh();
    } // end CloseJahiaWindow

// saveAndAddNew
function saveAndAddNew(url, refreshOpener) {
    var engineWin = window.opener.myEngineWin;
    if (window.opener.myEngineWin != null) purge(window.opener.myEngineWin.document);
    window.opener.myEngineWin = null;
    window.location.href = url;
    //if ( refreshOpener == "yes" ){
    //window.opener.location.href = defineMatrixParam(window.opener.location.href);
    //}
    oldLoc = window.opener.location;
    while (window.opener.location != null
            && (oldLoc != window.opener.location)) {
        setTimeout("", 1000);
    }
    window.opener.myEngineWin = engineWin;
}

// applyJahiaWindow
function applyJahiaWindow(url) {
    window.location.href = url;
}

// closePopupWindow
function closePopupWindow() {
    var params = "";
    if (closePopupWindow.arguments.length > 0) {
        params = closePopupWindow.arguments[0];
    }
    if (closePopupWindow.arguments.length > 1) {
        var refreshOpener = closePopupWindow.arguments[1];
        if (refreshOpener == "yes") {
            var theUrl = window.opener.location.href;
            if (theUrl.indexOf("?") != -1) {
                if (params.charAt(0) == "&") {
                    theUrl += params;
                } else {
                    theUrl += "&" + params;
                }
            } else {
                if (params.charAt(0) == "&") {
                    theUrl += "?" + params.substring(1, params.length);
                } else {
                    theUrl += "?" + params;
                }
            }
            window.opener.location.href = theUrl;
        }
    }
    window.close();
    if (myEngineWin != null) purge(myEngineWin.document);
    purge(window.document);
    myEngineWin = null;
    delete window;
}

// applyPopupWindow
function applyPopupWindow(popupNewUrl, openerUrlParams, refreshOpener) {
    if (refreshOpener == "yes") {
        var theUrl = window.opener.location.href;
        if (theUrl.indexOf("?") != -1) {
            if (openerUrlParams.charAt(0) == "&") {
                theUrl += openerUrlParams;
            } else {
                theUrl += "&" + openerUrlParams;
            }
        } else {
            if (openerUrlParams.charAt(0) == "&") {
                theUrl += "?" + openerUrlParams.substring(1, openerUrlParams.length);
            } else {
                theUrl += "?" + openerUrlParams;
            }
        }
        window.opener.location.href = theUrl;
        WaitForRefresh();
    }
    window.location.href = popupNewUrl;
}

// WaitForRefresh (called by CloseJahiaWindow)
function WaitForRefresh()
{
    // alert( "Trying to close" );
    var newLoc = window.opener.location
    if (newLoc != oldLoc) {
        var timer = setTimeout("WaitForRefresh()", 100);
    } else {
        window.close();
    }
}
// end WaitForRefresh


function MM_preloadImages() { //v3.0
    var d = document;
    if (d.images) {
        if (!d.MM_p) d.MM_p = new Array();
        var i,j = d.MM_p.length,a = MM_preloadImages.arguments;
        for (i = 0; i < a.length; i++)
            if (a[i].indexOf("#") != 0) {
                d.MM_p[j] = new Image;
                d.MM_p[j++].src = a[i];
            }
    }
}

function MM_swapImgRestore() { //v3.0
    var i,x,a = document.MM_sr;
    for (i = 0; a && i < a.length && (x = a[i]) && x.oSrc; i++) x.src = x.oSrc;
}

function MM_findObj(n, d) { //v3.0
    var p,i,x;
    if (!d) d = document;
    if ((p = n.indexOf("?")) > 0 && parent.frames.length) {
        d = parent.frames[n.substring(p + 1)].document;
        n = n.substring(0, p);
    }
    if (!(x = d[n]) && d.all) x = d.all[n];
    for (i = 0; !x && i < d.forms.length; i++) x = d.forms[i][n];
    for (i = 0; !x && d.layers && i < d.layers.length; i++) x = MM_findObj(n, d.layers[i].document);
    return x;
}

function MM_swapImage() { //v3.0
    var i,j = 0,x,a = MM_swapImage.arguments;
    document.MM_sr = new Array;
    for (i = 0; i < (a.length - 2); i += 3)
        if ((x = MM_findObj(a[i])) != null) {
            document.MM_sr[j++] = x;
            if (!x.oSrc) x.oSrc = x.src;
            x.src = a[i + 2];
        }
}


function setfocus() {
}
// This function has to be on the body tag (onLoad) but the declaration isn't on all includes.

// Used with container list pagination
// Set
function changePage(whatForm, scrollingInput, val) {
    scrollingInput.value = val;
    var ctnListname = scrollingInput.name.substring(10,scrollingInput.name.length);
    whatForm.elements['ctnlistpagination_' + ctnListname].value='true';
    whatForm.submit();
}

/**
 * This method removes a query parameter from an URL, very practical
 * when we want to update a value or just remove the param altogether.
 *
 * @param paramURL the URL to remove the query parameter from
 * @param the key name of the parameter in the query string
 * @return the modified URL.
 */
function removeQueryParam(paramURL, key) {
    var queryPos = paramURL.indexOf('?');
    if (queryPos < 0) {
        return paramURL;
    }
    var pairs = paramURL.substring(queryPos + 1).split("&");
    var newURL = paramURL.substring(0, queryPos + 1);
    var nbPairs = 0;

    for (var i = 0; i < pairs.length; i++) {
        var pos = pairs[i].indexOf('=');
        if (pos >= 0) {
            var argname = pairs[i].substring(0, pos);
            var value = pairs[i].substring(pos + 1);
            if (argname != key) {
                nbPairs++;
                if (nbPairs > 1) {
                    newURL += "&";
                }
                newURL += pairs[i];
            }
        }
    }
    return newURL;
}

// just display pickers straight ahead
function displayPickers(ctx, id, width, height) {
    params = "width=" + width + ",height=" + height + ",top=0,left=0,resizable=yes,scrollbars=yes,status=yes";
    url = ctx + "/jsp/jahia/engines/importexport/dispPickers.jsp?id=" + id;
    if (pickerlist) pickerlist.close();
    pickerlist = window.open(url, "jwin", params);
}

function resizeZimbraShell() {
    try {
        DwtShell.getShell(window)
    } catch (ex) {
        return;
    }
    try {
      if (DwtShell.getShell(window)) {
          var shellSize = DwtShell.getShell(window).getSize();
        var y = 0;
        if (document.all || document.compatMode) {
            if (document.compatMode &&
                document.compatMode != 'BackCompat') {
                y = document.documentElement.scrollHeight;
            } else {
                y = document.body.scrollHeight;
            }
        } else if (document.layers) {
            y = document.body.document.height;
        } else if (document.height) {
            y = document.height;
        }
          DwtShell.getShell(window).setSize(shellSize.x, y);
      }
    } catch (ex) {}
}

/**
 * Create zimbra shell
 * @param className         [string]*       CSS class name
 * @param docBodyScrollable [boolean]*      if true, then the document body is set to be scrollable
 * @param confirmExitMethod [function]*     method which is called when the user attempts to navigate away from
 *                                          the application or close the browser window. If this method return a string that
 *                                          is displayed as part of the alert that is presented to the user. If this method
 *                                          returns null, then no alert is popped up this parameter may be null
 * @param  userShell            [Element]*      an HTML element that will be reparented into an absolutely
 *                                          postioned container in this shell. This is useful in the situation where you have an HTML
 *                                          template and want to use this in context of Dwt.
 * @param useCurtain            [boolean]*      if true, a curtain overlay is created to be used between hidden and viewable elements
 *                                          using z-index. See Dwt.js for various layering constants
 * @param debug, if true will use the debug level by looking for a query string parameter named 'debug'.
 * @param backgroundColor, used to override the one defined in CSS, should be the same as <body>
 */
function initZimbraShell(className, docBodyScrollable, confirmExitMethod, userShell, useCurtain,
                         debug, backgroundColor) {
    try {
        DBG = new AjxDebug(AjxDebug.NONE, null, false);
        if (debug) {
            if (location.search && (location.search.indexOf("debug=") != -1)) {
                var m = location.search.match(/debug=(\\d+)/);
                if (m.length) {
                    var num = parseInt(m[1]);
                    var level = AjxDebug.DBG[num];
                    if (level) {
                        DBG.setDebugLevel(level);
                    }
                }
            }
        }
    } catch (ex) {
        return;
    }
    var theShell = DwtShell.getShell(window);
    if (!theShell || theShell == 'undefined') {
        var userShellElement = null;
        if (userShell) {
            userShellElement = document.getElementById(userShell);
        }
        //constructor DwtShell(className, docBodyScrollable, confirmExitMethod, userShell, useCurtain)
        theShell = new DwtShell(className, docBodyScrollable, confirmExitMethod, userShellElement, useCurtain);
        theShell.setSize(0, 0);
        Dwt.setVisibility(theShell.getHtmlElement(), 'visible');
        if (backgroundColor) {
            theShell.getHtmlElement().style.backgroundColor = backgroundColor;
        }
        resizeZimbraShell();
        delete userShellElement;
    }
    theShell = null;
    //window.onresize = resizeZimbraShell;
}

function removeAll() {
    for (i = 0; i < GlobalListenerCount; i++) {
        GlobalCommands[i].removeAllInvokeListeners();
        GlobalCommands[i].commandXmlDoc = null;
        GlobalCommands[i]._responseXmlDoc = null;
        GlobalCommands[i]._st = null;
        GlobalCommands[i]._en = null;
        GlobalCommands[i] = null;
    }
    GlobalListenerCount = 0;
    for (i = 0; i < GlobalCallbackCount; i++){
        GlobalCallback[i].obj = null;
        GlobalCallback[i].func = null;
        GlobalCallback[i]._args = null;
        GlobalCallback[i] = null;
    }
    GlobalCallbackCount = 0;

    window.currentValue = null;
    var treeKeys = window["treeItems"];
    if (treeKeys) {
        var keys = treeKeys.split(",");
        for (var i = 0; i < keys.length; i++) {
            window["treeItem" + keys[i]] = null;
        }
        delete keys;
        window["treeItems"] = null;
    }
    delete treeKeys;
    var theTree = window["complexTree_tree1"];
    if (theTree) theTree.clear();
    delete theTree;
    window["complexTree_tree1"] = null;
    if ((typeof AjxCore != 'undefined') && AjxCore._objectIds) {
        for (var i = 0; i < AjxCore._objectIds.length; i++) {
            var obj = AjxCore._objectIds[i];
            if (obj) {
                try {
                    obj.dispose();
                    obj = null;
                    AjxCore._objectIds[i] = null;
                } catch (ex) {
                    obj = null;
                    AjxCore._objectIds[i] = null;
                }
            }
        }
        AjxCore._objectIds = null;
    }
    window._dwtShell = null;
    if (typeof unloadZimbra == 'function')
        unloadZimbra();

    window.onbeforeunload = null;
    var el = document.getElementById("tree1");
    if ( el ){
      el.innerHTML = "";
    }
    el = null;
    document.close();
    document.clear();
    purge(document);
    if (typeof DBG != 'undefined') DBG = null;
    if (typeof AjxRpc != 'undefined' && AjxRpc._rpcCache) {
        for (i = 0; i < AjxRpc._rpcCache.length; i++) {
            if (AjxRpc._rpcCache[i]) {
                AjxRpc._rpcCache[i].req._httpReq = null;
                AjxRpc._rpcCache[i].id = null;
                AjxRpc._rpcCache[i].req.ctxt = null;
                AjxRpc._rpcCache[i].req = null;
            }
            AjxRpc._rpcCache[i] = null;
        }
        AjxRpc._rpcCache = null;
        AjxRpcRequest._msxmlVers = null;
        AjxRpcRequest._inited = null;
    }
    delete window;
}
function addIframeElement(replaceObjectID, srcVal, widthVal, heightVal, idVal, frameborderVal, scrollingVal, alignVal, className) {
    if (document.getElementById(idVal)) {
        return;
        // already added
    }
    var newIframeElement = document.createElement('iframe');
    newIframeElement.setAttribute('width', widthVal);
    newIframeElement.setAttribute('height', heightVal);
    newIframeElement.setAttribute('frameborder', frameborderVal);
    newIframeElement.setAttribute('scrolling', scrollingVal);
    newIframeElement.setAttribute('align', alignVal);
    newIframeElement.setAttribute('id', idVal);
    newIframeElement.setAttribute('name', idVal);
    newIframeElement.className = className;
    var replaceObject = document.getElementById(replaceObjectID);
    if (replaceObject) {
        replaceObject.parentNode.replaceChild(newIframeElement, replaceObject);
        top[idVal].location.href = srcVal;
    }
    top[idVal].name = idVal;
}


function adjustIFrameSize(iframeWindow) {
    if (iframeWindow.document.height) {
        var iframeElement = parent.document.getElementById(iframeWindow.name);
        iframeElement.style.height = iframeWindow.document.height + 'px';
        iframeElement.style.width = iframeWindow.document.width + 'px';
    }
    else if (document.all) {

        var iframeElement = parent.document.all[iframeWindow.name];
        if (iframeWindow.document.compatMode &&
            iframeWindow.document.compatMode != 'BackCompat')
        {
            iframeElement.style.height =
            iframeWindow.document.documentElement.scrollHeight + 5 + 'px';
            iframeElement.style.width =
            iframeWindow.document.documentElement.scrollWidth + 5 + 'px';
        }
        else {
            iframeElement.style.height = iframeWindow.document.body.scrollHeight + 5 + 'px';
            iframeElement.style.width = iframeWindow.document.body.scrollWidth + 5 + 'px';
        }
    }
}
function handleTimeBasedPublishing(event, serverURL, objectKey, params, dialogTitle) {
    //alert("timeBasedPub : objecKey=" + objectKey + ", params=" + params);
    var tbpStatus = new TimeBasedPublishingStatus();
    tbpStatus.run(event, serverURL, objectKey, params, dialogTitle);
}

function fixPNG(myImage) {
    var arVersion = navigator.appVersion.split("MSIE")
    var version = parseFloat(arVersion[1])

    if ((version >= 5.5) && (version < 7) && (document.body.filters)) {
        var imgID = (myImage.id) ? "id='" + myImage.id + "' " : ""
        var imgClass = (myImage.className) ? "class='" + myImage.className + "' " : ""
        var imgTitle = (myImage.title) ?
                       "title='" + myImage.title + "' " : "title='" + myImage.alt + "' "
        var imgStyle = "display:inline-block;" + myImage.style.cssText
        var strNewHTML = "<span " + imgID + imgClass + imgTitle
                + " style=\"" + "width:" + myImage.width
                + "px; height:" + myImage.height
                + "px;" + imgStyle + ";"
                + "filter:progid:DXImageTransform.Microsoft.AlphaImageLoader"
                + "(src=\'" + myImage.src + "\', sizingMethod='scale');\"></span>"
        myImage.outerHTML = strNewHTML
    }
}

/*
The purge function takes a reference to a DOM element as an argument. It loops through the element's attributes.
If it finds any functions, it nulls them out. This breaks the cycle, allowing memory to be reclaimed. It will also look
at all of the element's descendent elements, and clear out all of their cycles as well. The purge function is harmless
on Mozilla and Opera. It is essential on IE. The purge function should be called before removing any element, either by
the removeChild method, or by setting the innerHTML property.
*/
function purge(d) {
      if (!d) return;
    //alert ("purge: " + d.attributes + ", " + d);
    try {
    var a = d.attributes, i, l, n;
    if (a) {
        l = a.length;
        for (i = 0; i < l; i += 1) {
            n = a[i].name;
            if (typeof d[n] === 'function') {
                d[n] = null;
            }
        }
    }
    a = d.childNodes;
    if (a) {
        l = a.length;
        for (i = 0; i < l; i += 1) {
            purge(d.childNodes[i]);
        }
    }
    } catch (e) {}
    a = null;
    n = null;
    d = null;
}

function getPageOffsetLeft(el) {

  var x;

  // Return the x coordinate of an element relative to the page.

  x = el.offsetLeft;
  if (el.offsetParent != null)
    x += getPageOffsetLeft(el.offsetParent);

  return x;
}

function getPageOffsetTop(el) {

  var y;

  // Return the x coordinate of an element relative to the page.

  y = el.offsetTop;
  if (el.offsetParent != null)
    y += getPageOffsetTop(el.offsetParent);

  return y;
}

window.onunload = closeEngineWinAllPopups;
