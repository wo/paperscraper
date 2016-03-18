#!/usr/bin/env python3
from collections import defaultdict

"""
Errors are stored as status codes in the database (sources, links,
docs); here two dictionaries are defined to translate between error
codes and their meaning: 

error.code['unsupported filetype'] => 5
error.message[5] => 'unsupported filetype'
"""

message = {

    0: 'unprocessed',
    1: 'OK',
    5: 'unsupported filetype',
   
    # 10-99: processing errors 
    # TODO: tidy
    10: 'processing error',

    42: 'cannot read local file',
    43: 'cannot save local file',
    49: 'Cannot allocate memory',

    50: 'unknown parser failure',

    57: 'pdfinfo failed',
    58: 'OCR failed',
    59: 'gs failed',
    60: 'pdftohtml produced garbage',
    61: 'pdftohtml failed',
    62: 'no text found in converted document',
    63: 'rtf2pdf failed',
    64: 'pdfcut failed',
    65: 'htmldoc failed',
    66: 'wkhtmltopdf failed',
    67: 'ps2pdf failed',
    68: 'html2xml failed',
    69: 'pdf conversion failed',
    70: 'parser error',
    71: 'non-UTF8 characters in metadata',

    92: 'database error',

    # 100-999: connection errors
    100: 'Continue',
    101: 'Switching Protocols',
    102: 'Processing',
    200: 'OK',
    201: 'Created',
    202: 'Accepted',
    203: 'Non-Authoritative Information',
    204: 'No Content',
    205: 'Reset Content',
    206: 'Partial Content',
    207: 'Multi-Status',
    300: 'Multiple Choices',
    301: 'Moved Permanently',
    302: 'Moved Temporarily',
    303: 'See Other',
    304: 'Not Modified',
    305: 'Use Proxy',
    307: 'Temporary Redirect',
    400: 'Bad Request',
    401: 'Unauthorized',
    402: 'Payment Required',
    403: 'Forbidden',
    404: 'Not Found',
    405: 'Method Not Allowed',
    406: 'Not Acceptable',
    407: 'Proxy Authentication Required',
    408: 'Request Timeout',
    409: 'Conflict',
    410: 'Gone',
    411: 'Length Required',
    412: 'Precondition Failed',
    413: 'Request Entity Too Large',
    414: 'Request-URI Too Large',
    415: 'Unsupported Media Type',
    416: 'Request Range Not Satisfiable',
    417: 'Expectation Failed',
    422: 'Unprocessable Entity',
    423: 'Locked',
    424: 'Failed Dependency',
    451: 'Unavailable For Legal Reasons',
    500: 'Internal Server Error',
    501: 'Not Implemented',
    502: 'Bad Gateway',
    503: 'Service Unavailable',
    504 : 'Gateway Timeout',
    505 : 'HTTP Version Not Supported',
    507 : 'Insufficient Storage',

    900 : 'connection failed',
    901: 'document is empty',
    902: 'too many redirects',

}

#code = defaultdict(lambda x: 99, { v:k for k,v in message.items() })

code = { v:k for k,v in message.items() }

