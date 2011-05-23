use strict;
use warnings;
use DBI;
use POSIX;
use Cwd 'abs_path';
use File::Basename;
use View;

my $path = dirname(abs_path(__FILE__));
my %cfg = do "$path/../config.pl";

my $dbh = DBI->connect(
    'DBI:mysql:'.$cfg{'MYSQL_DB'}, $cfg{'MYSQL_USER'},
    $cfg{'MYSQL_PASS'}, { RaiseError => 1 }) 
    or die "Couldn't connect to database: " . DBI->errstr;


sub get_locations {
    my %arg = @_;
    $arg{limit} ||= 100;
    $arg{offset} ||= 0;
    my $select = $dbh->prepare(<<EOD);
         SELECT
            locations.*
            sources.url as source_url
         FROM
            locations L,
            sources S,
            links R
         WHERE
            L.location_id = R.location_id AND
            AND S.source_id = R.source_id
         ORDER BY locations.last_checked
         LIMIT ?
         OFFSET ?
EOD
    $select->execute($arg{limit}, $arg{offset})
        or die DBI->errstr;
    my @res;
    while (my $row = $select->fetchrow_hashref) {
        if ($row->{document_id}) {
            $row->{document} = get_document($row->{document_id});
        }
        push @res, $row;
    }
    return \@res;
}

sub get_document {
    my $id = shift;
    
}

# We're not retrieving locations here because a document can have many
# locations. 
my $select_documents = <<EOD;
         SELECT documents.*,
         FROM documents
         INNER JOIN locations
         ON documents.document_id = locations.document_id
         WHERE documents.meta_confidence >= ?
         AND MIN(locations.spamminess) <= ?
         AND MIN(locations.status) <= ?
         GROUP BY document_id
         ORDER BY documents.found_date
         LIMIT ?
         OFFSET ?
EOD

my $select_document_updates = <<EOD;
         SELECT documents.*,
         FROM documents
         INNER JOIN locations
         ON documents.document_id = locations.document_id
         WHERE documents.meta_confidence >= ?
         AND MIN(locations.spamminess) <= ?
         AND MIN(locations.status) <= ?
         AND last_modified > ?
         AND last_modified < ?
         GROUP BY document_id
         ORDER BY last_modified
         LIMIT ?
EOD


# This selects all <document, location, source> triples, for each
# document. 
my $select_documents = <<EOD;
         SELECT
            documents.*,
            locations.*,
            sources.url as source_url
         FROM
            documents D,
            locations L,
            sources S,
            links R
         WHERE
            D.document_id = L.location_id AND
            L.location_id = R.location_id AND
            AND S.source_id = R.source_id
            AND spamminess <= ?
            AND locations.status <= ?
            AND meta_confidence >= ?
         ORDER BY documents.found_date
         LIMIT ?
         OFFSET ?
EOD



$cfg{'CONFIDENCE_THRESHOLD'}
$cfg{'SPAM_THRESHOLD'}

$select->execute($max_spam, $until, $limit) or die DBI->errstr;
    my $where =

my $select = $dbh->prepare(<<SQL);
   SELECT documents.*, locations.url, locations.filetype
   FROM documents
   INNER JOIN locations ON documents.document_id = locations.document_id
   WHERE documents.found_date > ?
   AND documents.found_date < ?
   AND documents.meta_confidence > $cfg{'CONFIDENCE_THRESHOLD'}
   AND locations.spamminess < $cfg{'SPAM_THRESHOLD'}
   AND locations.status = 1
   GROUP BY documents.document_id
   LIMIT ?
SQL
$select->execute($since, $until, $limit) or die DBI->errstr;


my $offset = $cgi->param('offset') || 0;
if ($havemore) {
   print "<a href='".$address."offset=".($offset + $cfg{DOCS_PER_LOAD})."'>&lt; Older papers</a>\n";
}
if ($offset) {
   print "<a href='".$address."offset=".($offset - $cfg{DOCS_PER_LOAD})."'>Newer papers &gt;</a>\n";
}
print <<EOD;
</div>

</div>

<div id="loading">
<script type="text/javascript">
if (browserOK()) document.write([
"<h3>Loading...</h3>",
"<span>Use the <a href='?html=1'>alternative version</a>",
"if this doesn't work.</span>"
].join(" "));
</script>
</div>

</div>

<script type="text/javascript">
EOD
my $status = shift @docs;
print "state.status = ($status).msg;\n";
print "state.docs = [".join(",\n", @docs)."];\n";
print <<EOD;
</script>

</body>
</html>
EOD
}

sub content {
    print <<EOD;

while (my $doc = @docs) {
   print_doc($doc);
}

print <<EOD;
</ul>
EOD

sub print_doc {
    my $doc = shift;
    my $authors = dec($doc->{authors});
    my $title = dec($doc->{title});
    my $url = $doc->{url};
    my $abstract = dec($doc->{abstract});
    my $filetype = $doc->{filetype};
    my $id = $doc->{document_id};
    print <<EOD;

<li>
   <div class="title">
      $id. $authors: <a href="$url">$title</a>
   </div>
   <div class="abstract">
       $abstract
   </div>
   <div class="meta">
       <span>length: $doc->{length}</span>
       <span>found: $doc->{found_date}</span>
       <span>confidence: $doc->{meta_confidence}</span>
   </div>
</li>

EOD

}

sub dec {
   use Encode 'decode';
   return decode('utf8',shift());
}
