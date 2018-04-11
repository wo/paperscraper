#!/usr/bin/env python3
import os
import time
import logging
from selenium import webdriver
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.firefox.firefox_binary import FirefoxBinary

logger = logging.getLogger('opp')

_browser = None

# allow using only one instance:
def Browser(use_virtual_display=False, reuse_browser=True):
    global _browser
    if not reuse_browser or not _browser:
        try:
            _browser = ActualBrowser()
        except Exception as e:
            logger.debug('failed to start browser: %s', e)
            stop_browser(use_force=True)
            logger.debug('retrying')
            time.sleep(100)
            _browser = ActualBrowser()
    return _browser

def stop_browser(use_force=False):
    '''quit current _browser if running'''
    global _browser
    if not _browser:
        logger.debug('no browser running')
    else:
        logger.debug('stopping browser')
        try:
            _browser.quit()
        except Exception as e:
            logger.debug(e)
        del _browser
        _browser = None
    if use_force:
        logger.info('killing all geckodriver processes!')
        try: 
            os.system('killall -9 geckodriver')
        except Exception as e:
            logger.debug(e)
        
class ActualBrowser(webdriver.Firefox):
    
    def __init__(self):
        logger.debug('initializing browser')
        options = Options()
        options.set_headless(headless=True)
        binary = FirefoxBinary('/home/wo/install/firefox/firefox-bin') 
        super().__init__(firefox_binary=binary, firefox_options=options, log_path='/tmp/selenium.log')

    def goto(self, url, timeout=10):
        """sends browser to url, sets (guessed) status code"""
        self.set_page_load_timeout(timeout)
        self.get(url)
        self.status = 200
        # check for errors:
        if "not found" in self.title.lower():
            self.status = 404
        try:
            ff_error = self.find_element_by_id('errorTitleText')
            if 'not found' in ff_error.text:
                self.status = 404
        except Exception:
            pass
        if self.current_url != url:
            self.status = 301

