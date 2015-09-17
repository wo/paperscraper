import re
from os.path import abspath, dirname, join

# access perl config file 'config.pl'
config_cache = {}
config_file = join(abspath(dirname(__file__)), 'config.pl')
def config(key):
    if key not in config_cache:
        if 'perlstr' not in config_cache:
            config_cache['_perlstr'] = open(config_file).read()
        m = re.search(key+"\s+=>\s'?(.+?)'?,", config_cache['_perlstr'])
        if m:
            config_cache[key] = m.group(1)
        else:
            config_cache[key] = ''
    return config_cache[key]

