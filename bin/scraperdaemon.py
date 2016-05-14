#!/usr/bin/env python3
import sys
import time
import logging
import findmodules
from opp.config import config
from opp import scraper
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

class ScraperDaemon(Daemon):

    def start(self):
        debuglevel(3)
        super().start()
        self.run()

    def run(self):
        while True:
            source = scraper.next_source()
            if source:
                scraper.scrape(source)
                time.sleep(60)
            else:
                time.sleep(60)

    def stop(self):
        # scraper.stop_browser()
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
            print ("Unknown command")
            sys.exit(2)
        sys.exit(0)
    else:
        print ("Usage: {} start|stop|restart|status".format(sys.argv[0]))
        sys.exit(2)

