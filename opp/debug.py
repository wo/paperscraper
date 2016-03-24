import logging

logger = logging.getLogger('opp')

# default:
_debuglevel = 1

def debuglevel(level=None):
    """read or set debugging level (0=none, 5=heaps)"""
    if level:
        global _debuglevel
        _debuglevel = level
    else:
        return _debuglevel

def debug(level, msg, *args):
    if _debuglevel >= level:
        logger.debug(str(msg), *args)

