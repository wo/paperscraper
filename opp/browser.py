#!/usr/bin/env python3
import os
import time
import logging
from selenium.webdriver import Firefox
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.firefox.firefox_binary import FirefoxBinary
from selenium.common.exceptions import *
if __name__ == '__main__':
    import sys
    curpath = os.path.abspath(os.path.dirname(__file__))
    libpath = os.path.join(curpath, os.path.pardir)
    sys.path.insert(0, libpath)
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
        os.system('killall -9 firefox')
        os.system('killall -9 geckodriver')
    except Exception as e:
        logger.debug(e)
 
class ActualBrowser(Firefox):
    
    def __init__(self):
        logger.debug('initializing browser')
        options = Options()
        options.headless = True
        binarypath = '/home/wo/install/firefox/firefox'
        options.binary_location = binarypath
        #binary = FirefoxBinary('/home/wo/install/firefox/firefox-bin') 
        geckodriverpath = '/home/wo/install/geckodriver'
        super().__init__(executable_path=geckodriverpath,
                         #firefox_binary=binary,
                         options=options,
                         log_path='/tmp/selenium.log')
    
    def goto(self, url, timeout=30):
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
            if 'Timeout' in e.msg:
                self.status = 408
                raise PageLoadException(e.msg)
            if 'about:neterror' in e.msg:
                # happens e.g. when selenium has no internet access
                self.status = 905
                raise PageLoadException(e.msg)
            if 'run command without establishing a connection' in e.msg:
                # no working browser instance; unfortunately we can't simply
                # restart the browser because this would destroy self. But we
                # can kill all running browsers, which should make sure a restart
                # happens.
                logger.debug('browser looks dead; killing processes')
                try:
                    stop_browser()
                    kill_all_browsers()
                except Exception:
                    pass
                self.status = 906
                raise PageLoadException(e.msg)
            logger.debug("uncaught webdriver exception: {}".format(e.msg))
            print("xxx uncaught webdriver exception: {}".format(e.msg))
            self.status = get_http_status(url)
            if self.status == 200:
                self.status = 901
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
    import os.path
    import sys
    curpath = os.path.abspath(os.path.dirname(__file__))
    libpath = os.path.join(curpath, os.path.pardir)
    sys.path.insert(0, libpath)
    print('starting browser')
    browser = Browser()
    urls = [
        'https://www.umsu.de/',
        'https://warwick.ac.uk/fac/soc/philosophy/people/brewer/',
        'http://www.johncottingham.co.uk/',
        'https://vivo.brown.edu/display/jdreier',
    ]
    for url in urls:
        print('fetching {}'.format(url))
        browser.goto(url)
        print(browser.status)
        time.sleep(1)
    print('reusing browser')
    browser2 = Browser()
    if browser != browser2:
        print('failed!!!')
    for url in urls:
        print('fetching {}'.format(url))
        browser2.goto(url)
        print(browser2.status)
        time.sleep(1)
    print('closing browser')
    stop_browser()
    print('please check that no browser is running')
