
# Database connection:
MYSQL_DB    => 'database',
MYSQL_USER  => 'user',
MYSQL_PASS  => 'pass',

# Process papers with these filetypes:
FILETYPES   => ['pdf', 'ps', 'doc', 'rtf', 'html', 'txt'],

# Software:
PS2PDF       => '/usr/bin/ps2pdf',
UNOCONV      => '/usr/bin/unoconv',
WKHTMLTOPDF  => '/usr/bin/wkhtmltopdf',

# Maximum spamminess score for entries in the RSS feed:
SPAM_THRESHOLD        => 0.4,

# Minimum parser confidence for entries in the RSS feed:
CONFIDENCE_THRESHOLD  => 0.6,

# CGI access to update_sources is restricted to IP addresses matching
# the following pattern (regexp):
ALLOWED_IPS  => '127.0.0.1',

# For superfeedr api:
SUPERFEEDR_USER => 'opp',
SUPERFEEDR_TOKEN => 'abcdefg',
