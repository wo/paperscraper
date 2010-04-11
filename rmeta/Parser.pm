#! /usr/bin/perl
use strict;
use warnings;

package Parser;

sub new {
   my ($class, %args) = @_;
   my $self  = {
      error          => '',
      verbosity      => $args{verbosity} || 1,
      content_text   => undef,
      content_raw    => $args{content} || undef,
      filetype       => undef, 
      http_response  => $args{http_response} || undef
   };
   bless ($self, $class);
   return $self;
}

sub error {
   my $self = shift;
   $self->{error} = shift if (@_);
   return $self->{error};
}

sub verbosity {
   my $self = shift;
   $self->{verbosity} = shift if (@_);
   return $self->{verbosity};
}

sub filetype {
   my $self = shift;
   if (!defined($self->{filetype})) {
      if (defined($args{http_response})) {
         my $http = $args{http_response};
         ($http->content_type =~ /pdf/ || $http->request =~ /.pdf$/) && ($self->{filetype} = 'pdf');
      }
      if (!defined($self->{filetype})) {
         $self->error("unrecognized filetype");
      }
   }
   return $self->{filetype};
}

sub content_raw {
   my $self = shift;
   if (!defined($self->{content_raw})) {
      if (defined($args{http_response})) {
         $self->{content_raw} = $args{http_response}->content;
      }
      if (!defined($self->{content_raw})) {
         $self->error("no document content provided");
      }
   }
   return $self->{content_raw};
}

sub parse {
   my $self = shift;
   if ($self->filetype == 'pdf') {
      require Parser::PDF;
      return Parser::PDF::parse($self->content_raw);
   }
   error("cannot parse unrecognized filetype");
   return undef;
}

1;
