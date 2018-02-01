#!/usr/bin/env python3
import os
import time
import logging
from selenium import webdriver
from pyvirtualdisplay import Display

logger = logging.getLogger('opp')

_display = None
_browser = None

# allow using only one instance:
def Browser(use_virtual_display=False, reuse_browser=True):
    global _display
    global _browser
    if use_virtual_display and not _display:
        start_display()
    if not reuse_browser or not _browser:
        try:
            _browser = ActualBrowser()
        except Exception as e:
            logger.debug('failed to start browser: %s', e)
            stop_browser(use_force=True)
            logger.debug('retrying')
            time.sleep(10)
            if use_virtual_display:
                start_display()
            _browser = ActualBrowser()
    return _browser

def start_display():
    global _display
    logger.debug('initializing new virtual display')
    _display = Display(visible=0, size=(1366, 768))
    _display.start()

def stop_browser(use_force=False):
    '''quit current _browser and _display if running'''
    global _display
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
    if _display:
        time.sleep(1)
        logger.debug('stopping virtual display')
        try:
            _display.stop()
        except Exception as e:
            logger.debug(e)
        del _display
        _display = None
    if use_force:
        logger.info('killing all Xvfb and geckodriver processes!')
        os.system('killall -9 geckodriver')
        os.system('killall -9 Xvfb')
        
        
class ActualBrowser(webdriver.Firefox):
    
    def __init__(self):
        logger.debug('initializing browser')
        super().__init__(log_path='/tmp/selenium.log')

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
