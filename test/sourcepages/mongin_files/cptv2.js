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
 */
function checkMaxPageItems(theForm){
	if ( document.searchpager && document.searchpager.maxPageItems
		&& document.searchpager.maxPageItems.selectedIndex != -1 ){
		theForm.maxPageItems.value = document.searchpager.maxPageItems.options[document.searchpager.maxPageItems.selectedIndex].value;
	}
}
function setFreeSearchInput(theForm){
	theForm.freeSearch.value=theForm.search.value;
}
function swithToEditMode(){
     var contextUrl = window.location.href;

     var pos = contextUrl.indexOf("/op/edit");
     if (pos == -1) {
        pos = contextUrl.indexOf("/op/");
        if ( pos == -1 ){
            pos = contextUrl.indexOf("/pid/");
            if ( pos != -1 ){
                contextUrl = contextUrl.substring( 0, pos ) + "/op/edit" + contextUrl.substring( pos );
            }
         } else {
            contextUrl = contextUrl.substring( 0, pos ) + "/op/edit/oldop/" + contextUrl.substring( pos + 4 );
         }
         //alert(contextUrl);
         window.location.href = contextUrl;
    }
}
function Browser() {

  var ua, s, i;

  this.isIE    = false;  // Internet Explorer
  this.isNS    = false;  // Netscape
  this.version = null;

  ua = navigator.userAgent;

  s = "MSIE";
  if ((i = ua.indexOf(s)) >= 0) {
    this.isIE = true;
    this.version = parseFloat(ua.substr(i + s.length));
    return;
  }

  s = "Netscape6/";
  if ((i = ua.indexOf(s)) >= 0) {
    this.isNS = true;
    this.version = parseFloat(ua.substr(i + s.length));
    return;
  }

  // Treat any other "Gecko" browser as NS 6.1.

  s = "Gecko";
  if ((i = ua.indexOf(s)) >= 0) {
    this.isNS = true;
    this.version = 6.1;
    return;
  }
}
var browser = new Browser();
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
function getX(e) {
    //var e = jahiaGetObject(id);
    x = getPageOffsetLeft(e);
    // adjust position for IE
    if (browser.isIE) {
        x += e.offsetParent.clientLeft;
    }
    return x;
}
function getY(e) {
    //var e = jahiaGetObject(id);
    y = getPageOffsetTop(e) + e.offsetHeight;
    // adjust position for IE
    if (browser.isIE) {
        y += e.offsetParent.clientTop;
    }
    return y;
}
function showDiv(id,element){
    var searchDiv = null;
    if (document.getElementById) {
        searchDiv = document.getElementById(id);
    } else if (document.all) {
        searchDiv = document.all[id];
    }
    if (searchDiv != null) {
        searchDiv.style.display="block";
        searchDiv.style.left=getX(element) + 'px';
        searchDiv.style.top=getY(element)-20 + 'px';
        document.searchForm.search.focus();
    }
}

function toggleVisibility(id) {
	var searchDiv = null;
    if (document.getElementById) {
        searchDiv = document.getElementById(id);
    } else if (document.all) {
        searchDiv = document.all[id];
    }

    if (searchDiv.style.display == "none") {

         searchDiv.style.display = "block";
        } else {

         searchDiv.style.display = "none";
}

}