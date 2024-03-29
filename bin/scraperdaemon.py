#!/usr/bin/env python3
import sys
import time
import signal
import logging
import findmodules
from opp.config import config
from opp import scraper, blogpostprocessor, browser
from opp.daemon import Daemon
from opp.debug import debug, debuglevel

logger = logging.getLogger('opp')
logger.setLevel(logging.DEBUG if config['loglevel'] > 1 else logging.INFO)
fh = logging.FileHandler(config['logfile'])
fh.setLevel(logging.DEBUG if config['loglevel'] > 1 else logging.INFO)
fh.setLevel(logging.DEBUG)
fh.setFormatter(logging.Formatter(fmt='%(asctime)s %(message)s', 
                                  datefmt='%Y-%m-%d %H:%M:%S'))
logger.addHandler(fh)

PIDFILE = '/tmp/opp-scraper.pid' 

class GracefulKiller:
    kill_now = False
    def __init__(self):
        signal.signal(signal.SIGINT, self.exit_gracefully)
        signal.signal(signal.SIGTERM, self.exit_gracefully)

    def exit_gracefully(self, signum, frame):
        self.kill_now = True

class ScraperDaemon(Daemon):

    def start(self):
        debuglevel(3)
        super().start()
        self.run()

    def run(self):
        killer = GracefulKiller()
        while True:
            for n in range(200):
                # one loop takes about 30 minutes (or 3 hours if
                # there's nothing to do)
                source = scraper.next_source()
                if source:
                    scraper.scrape(source)
                # wait:
                pause_secs = 10 if source else 60
                for sec in range(pause_secs):
                    if killer.kill_now:
                        browser.stop_browser()
                        return
                    time.sleep(1)
            # occasionally restart browser and check for blog posts:
            blogpostprocessor.run()
            browser.stop_browser()
            browser.kill_all_browsers()
            
    def stop(self):
        print("stopping...")
        # browser.stop_browser() doesn't work here because the daemon
        # doesn't have access to the relevant _browser instance; but
        # the function will be called in run() via killer.
        super().stop()

if __name__ == "__main__":

    daemon = ScraperDaemon(PIDFILE,
                           stderr=config['logfile'],
                           stdout=config['logfile'])

    if len(sys.argv) == 2:
        if 'start' == sys.argv[1]:
            daemon.start()
        elif 'stop' == sys.argv[1]:
            daemon.stop()
        elif 'restart' == sys.argv[1]:
            daemon.restart()
        elif 'status' == sys.argv[1]:
            daemon.status()
        else:
            print("Unknown command")
            sys.exit(2)
        sys.exit(0)
    else:
        print("Usage: {} start|stop|restart|status".format(sys.argv[0]))
        sys.exit(2)

