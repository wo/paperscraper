import re
import SocketServer
import json

# access perl config file 'config.pl'
config_cache = {}
def config(key):
    if key not in config_cache:
        if 'perlstr' not in config_cache:
            config_cache['_perlstr'] = open('config.pl').read()
        m = re.search(key+"\s+=>\s'?(.+?)'?,", config_cache['_perlstr'])
        if m:
            config_cache[key] = m.group(1)
        else:
            config_cache[key] = ''
    return config_cache[key]


class MyTCPServer(SocketServer.ThreadingTCPServer):
    allow_reuse_address = True

class MyTCPServerHandler(SocketServer.BaseRequestHandler):
    def handle(self):
        try:
            data = json.loads(self.request.recv(1024).strip())
            print data
            self.request.sendall(json.dumps({'return':'ok'}))
        except Exception, e:
            print "Exception wile receiving message: ", e

server = MyTCPServer(('127.0.0.1', 13373), MyTCPServerHandler)
server.serve_forever()
