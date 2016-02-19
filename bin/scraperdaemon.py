#!/usr/bin/env python3
import sys
import time
import logging
import findmodules
from config import config
import scraper
from daemon import Daemon

logger = logging.getLogger()
fh = logging.FileHandler(config['logfile'])
fh.setLevel(logging.DEBUG if config['loglevel'] > 1 else logging.INFO)
fh.setFormatter(logging.Formatter(fmt='%(asctime)s %(levelname)s %(message)s', 
                                  datefmt='%Y-%m-%d %H:%M:%S'))
logger.addHandler(fh)

PIDFILE = '/tmp/opp-scraper.pid' 

class ScraperDaemon(Daemon):

    def start(self):
        super().start()
        self.run()

    def run(self):
        while True:
#            source = scraper.next_source()
#            if source:
#                scraper.process_page(source)
#                time.sleep(1)
#            else:
                time.sleep(30)

    #def stop(self):
        # scraper.stop_browser()
    #    super().stop()

    def stop_browser(self):
        try:
            self.browser.close()
            self.display.stop()
        except e:
            pass

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

