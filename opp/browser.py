#!/usr/bin/env python3
import os
import time
import logging
from selenium import webdriver
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.firefox.firefox_binary import FirefoxBinary
from selenium.common.exceptions import *
from opp.util import get_http_status
from opp.exceptions import PageLoadException

logger = logging.getLogger('opp')

_browser = None

# use only one instance:
def Browser():
    global _browser
    if not _browser:
        try:
            _browser = ActualBrowser()
        except Exception as e:
            logger.debug('failed to start browser: %s', e)
            stop_browser()
            kill_all_browsers()
            logger.debug('waiting then retrying')
            time.sleep(100)
            _browser = ActualBrowser()
    return _browser

def stop_browser():
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
        _browser = None

def kill_all_browsers():
    logger.info('killing all firefox processes!')
    try: 
        os.system('killall -9 firefox-bin')
        os.system('killall -9 geckodriver')
    except Exception as e:
        logger.debug(e)
 
class ActualBrowser(webdriver.Firefox):
    
    def __init__(self):
        logger.debug('initializing browser')
        options = Options()
        options.set_headless(headless=True)
        binary = FirefoxBinary('/home/wo/install/firefox/firefox-bin') 
        geckodriverpath = '/usr/local/bin/geckodriver'
        super().__init__(executable_path=geckodriverpath,
                         firefox_binary=binary,
                         firefox_options=options,
                         log_path='/tmp/selenium.log')

    def goto(self, url, timeout=10):
        """
        sends browser to <url>, sets self.status to (guessed) HTTP status
   
        This function attempts to throw a PageLoadException whenever
        <url> can't be loaded, i.e. whenever self.status is not 200 or
        301.
        """
        self.status = 900
        self.set_page_load_timeout(timeout)
        try:
            self.get(url)
        except WebDriverException as e:
            if 'Tried to run command without establishing a connection' in e.msg:
                # no working browser instance
                try:
                    stop_browser()
                    kill_all_browsers()
                self.status = 906
                raise PageLoadException(e.msg)
            if 'about:neterror' in e.msg:
                # happens e.g. when selenium has no internet access
                self.status = 905
                raise PageLoadException(e.msg)
            print("xxx uncaught webdriver exception: {}".format(e.msg))
            self.status = get_http_status(url)
            raise PageLoadException(e.msg)
        self.status = 200
        # selenium doesn't raise exceptions for 404/500/etc. errors,
        # so we need to catch these manually:
        try:
            ff_error = self.find_element_by_id('errorTitleText')
        except Exception:
            ff_error = None
        if ff_error or "not found" in self.title.lower():
            self.status = get_http_status(self.current_url)
            if self.status != 200:
                raise PageLoadException('HTTP status {}'.format(self.status))
        if self.current_url != url:
            self.status = 301

if __name__ == '__main__':
    # test
    print('starting browser')
    browser = Browser()
    print('fetching umsu.de')
    browser.goto('https://www.umsu.de')
    print(browser.status)
    print('reusing browser')
    browser2 = Browser()
    print(browser == browser2)
    print('closing browser')
    stop_browser()
    print('please check that no browser is running')
