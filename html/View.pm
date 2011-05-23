package View;
use strict;
use warnings;
use Exporter;
our @ISA = ('Exporter');
our @EXPORT_OK = qw/&render/;

my $template_page = <<EOD;

<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN"
"http://www.w3.org/TR/html4/DTD/strict.dtd">
<html>
<head>
  <title>Online Papers in Philosophy</title>
  <link rel="stylesheet" type="text/css" href="opp.css">
</head>
<body>

<div id="wrap">

  <div id="title">
    <h1><a href="./">Online Papers in <span>Philosophy</span></a></h1>
  </div>

  <div id="sidebar">

    <h3>Site Controls</h3>

    <div class='sidebox'>
      <form action='./' method='GET'>
      <div>
        <input type="checkbox" checked="checked" id="toggleAbstracts"
         class="pref" onclick="state.set('abstracts', this.checked)">
        Show Abstracts<br>
        <input type="checkbox" checked="checked" id="toggleJunk"
         class="pref" onclick="state.set('junk', this.checked)">
        Show Junk<br>
      </div>
      </form>
    </div>

    <h3>RSS Feeds:</h3>

    <div class='sidebox'>
      <a href="rss.xml">Daily Updates</a>
    </div>

  </div>

  <div id="content" class="html">
  <%content>
  </div>

</div>

</body>
</html>
EOD

my $template_doc = << EOD;

<div class='i' id='<%id>'>
<div class='iIcon'>
   <img src='<%filetype>.png' alt='<%filetype>'><br>
   <%filesize>
</div>
<div class='iWrapper'>
  <div class='iHeader'>
    <span class='iAu'><a href='<%source_url>'><%author></a></span>:
    <span class='iTi'><a href='<%url>'><%title></a></span>
    <%error>
  </div>
  <div class='iAb'><%abstract></div>
  <div class='iFooter'>
    <span class='iEdit' onclick='edit(\"$id\")'>Edit</span>
    <a class='iUr' href='<%url>'><%url2></a>
    - <span class='iInfo'>found <%found_date></span>
  </div>
</div>

EOD

sub compose {
    my ($str, $obj) = @_;
    while (my ($key, $val) = each $obj) {
        $str =~ s/<%$key>/$val/g;
    }
    return $str;
}

sub render {
    my ($docs, $prevlink, $nextlink) = @_;

    my $res = { content => '' };

    foreach my $doc (@$docs) {
        my $doc->{url2} = $doc->{url};
        if (length($url2) > 60) {
            substr($url2,0,28).'...'.substr($url2,-28);
        }
        if ($doc->{error}) {
            $doc->{error} = "<br><span class='iEr'>$doc->{error}</span>";
        }
        my $div = compose($template_doc, $doc);
        $res->{content} .= $div;
    }

    if ($prevlink || $nextlink) {
        $res->{content} .= '<div id="prevnext" class="html">';
        if ($prevlink) {
            $res->{content} .=
                '<a href='$prevlink'>&lt; Older papers</a>';
        }
        if ($nextlink) {
            $res->{content} .=
                '<a href='$nextlink'>Newer papers &gt;</a>';
        }
        $res->{content} .= "</div>\n";
    }

    return compose($template_page, $res);
}

1;
