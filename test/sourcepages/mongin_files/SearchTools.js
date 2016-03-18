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
 *//**
 * Utility class to manage search engine
 */
function SearchTools() {
}

SearchTools.showHitDetails = 
function (frameHtmlElementId,labelHtmlElementId,onMsg,offMsg){
  var htmlEl = document.getElementById(labelHtmlElementId);
  if ( htmlEl ){
    if ( !htmlEl.labelMsg ){
      htmlEl.labelMsg = "on";
    }
    if ( htmlEl.labelMsg == "on" ){
      htmlEl.innerHTML = offMsg;
      htmlEl.labelMsg = "off";
    } else {
      htmlEl.innerHTML = onMsg;
      htmlEl.labelMsg = "on";
    }
  }
  var frameHtmlEl = document.getElementById(frameHtmlElementId);
  if ( frameHtmlEl ){
    if ( htmlEl.labelMsg == "off" ){
      frameHtmlEl.style.display = "block";
    } else {
      frameHtmlEl.style.display = "none";
    }
  }
}

SearchTools.resetSearchRefine =
function (formName){
  var searchForm = document.forms[formName];
  searchForm.elements["searchRefineAttribute"].value = 'reset';
  searchForm.submit();
}
