#####################################################################
#
#  Export::PubList plugin - generate list of published eprints
#
#####################################################################
#
#  Copyright 2016, 2017 University of Zurich. All Rights Reserved.
#
#  Jens Vieler
#  Zentrale Informatik
#  Universität Zürich
#  Stampfenbachstr. 73
#  CH-8006 Zürich
#
#####################################################################

=head1 NAME

EPrints::Plugin::Export::PubList

=cut

package EPrints::Plugin::Export::PubList;

use EPrints::Plugin::Export::XMLFile;

@ISA = ( "EPrints::Plugin::Export::XMLFile" );

use strict;
use warnings;

use utf8;
use Encode;
use XML::LibXML;

sub new
{
	my( $class, %opts ) = @_;

	my( $self ) = $class->SUPER::new( %opts );

	$self->{name} = "PubList";
	$self->{accept} = [ 'list/*' ];
	$self->{visible} = "all";
	$self->{qs} = 0.8;
	$self->{xmlns} = "http://yourdomain/publist2"; ### config here !!!
	$self->{mimetype} = 'text/xml; charset=utf-8';
	$self->{arguments}->{hide_volatile} = 1;

	return $self;
}

sub output_list
{
        my( $plugin, %opts ) = @_;
        my $r = []; 
        my $xmldoc = XML::LibXML::Document->new('1.0','utf-8');
	my $counter = $opts{list}->count;

	my $session = new EPrints::Session;
	exit( 0 ) unless( defined $session );

	my $publist = $xmldoc->createElement( "publist" );
        $publist->setAttribute( "xmlns", "http://yourdomain/publist2" ); ### config here !!!
        $publist->setAttribute( "xmlns:xsi", "http://www.w3.org/2001/XMLSchema-instance" );
        $publist->setAttribute( "xsi:schemaLocation", "http://yourdomain/publist.xsd" ); ### config here !!!

	my $error = $xmldoc->createElement( "error" );
        $error->setAttribute( "code", "200" );
        $error->setAttribute( "text", "OK" );
        $publist->appendChild( $error );

	my $eprints = $xmldoc->createElement( "eprints" );
        $eprints->setAttribute( "count", $counter );
        $publist->appendChild( $eprints );

        foreach my $dataobj ( $opts{list}->get_records )
        {
           # single eprint with id
           my $eprintid = $dataobj->get_value( "eprintid" );
	   my $eprint = $xmldoc->createElement( "eprint" );
           $eprint->setAttribute( "id", $eprintid );
           $eprints->appendChild( $eprint );

	   # pubdate
	       my $tmp_date = $dataobj->get_value( "date" );
           my $tmp_year = "0000";
           my $tmp_month = "00";
           my $tmp_day = "00";

           if (length($tmp_date) >= 4)
           {
              $tmp_year = sprintf("%04s",substr( $tmp_date , 0, 4 ));
	   }
           if (length($tmp_date) >= 7)
           {
              $tmp_month = sprintf("%02s",substr( $tmp_date , 5, 2 ));
	   }
           if (length($tmp_date) == 10)
           {
              $tmp_day = sprintf("%02s",substr( $tmp_date , 8, 2 ));
	   }
           my $pubdate_value = $tmp_year.$tmp_month.$tmp_day;

	   my $pubdate = $xmldoc->createElement( "pubdate" );
           $pubdate->appendTextNode( $pubdate_value ) if defined $pubdate_value;
           $eprint->appendChild( $pubdate );

	   # title (trim, otherwise title & citation dont fit)
           my $title_value = $dataobj->get_value( "title" );
           $title_value =~ s/^\s+|\s+$//g; 
           $title_value =~ s/  / /g; 
           $title_value =~ s/[\t\r\n\f]//g;
	   my $title = $xmldoc->createElement( "title" );
           $title->appendTextNode( $title_value ) if defined $title_value;
           $title->appendTextNode( "." ) if defined $title_value;
           # title is part of citation (!)
	   
	   # citation (strip author- and other links, insert title tag)
 	   my $citation_value = $dataobj->get_value( "citation" );
	   my $citation = $xmldoc->createElement( "citation" );
	   $citation_value =~ s/<http:\/\/www[.][^ ]*>//g;
	   $citation_value =~ s/ ;/;/g;
	   $citation_value =~ s/ \./\./g;
           my $pos = index($citation_value,$title_value);
           if ( $pos ge "0" ) {
              $citation->appendTextNode( substr($citation_value, 0, $pos) ) if defined $citation_value;
              $citation->appendChild( $title );
              $citation->appendTextNode( substr($citation_value, $pos+length($title_value)+1 ) ) if defined $citation_value;
	   } else {
              $citation->appendTextNode( $citation_value ) if defined $citation_value;
	   }
           $eprint->appendChild( $citation );

	   # firstautor (depends on type)
	   my $firstauthor_value = "";
           if ($dataobj->get_value("type") eq "edited_scientific_work")
           {
	      if ($dataobj->exists_and_set("editors_name"))
              {
    	         my ( $tmpauthor, $rest )  =  (@{$dataobj->get_value("editors_name")});
    	   	 $firstauthor_value  =  EPrints::Utils::make_name_string( $tmpauthor );
              }
           } else {
	         if ($dataobj->exists_and_set("creators_name"))
           	 {
    	   	    my ( $tmpauthor, $rest )  =  (@{$dataobj->get_value("creators_name")});
    	   	    $firstauthor_value  =  EPrints::Utils::make_name_string( $tmpauthor );
           	 }
	   }
	   my $firstauthor = $xmldoc->createElement( "firstauthor" );
           $firstauthor->appendTextNode( $firstauthor_value ) if defined $firstauthor_value;
           $eprint->appendChild( $firstauthor );

	   # type
           my $type_value = $dataobj->get_value( "type" );
	   my $type = $xmldoc->createElement( "type" );
           $type->appendTextNode( $type_value ) if defined $type_value;
           $eprint->appendChild( $type );

	   # coins
           my $coins_value = $dataobj->get_value( "coins" );
	   my $coins = $xmldoc->createElement( "coins" );
           $coins->appendTextNode( $coins_value ) if defined $coins_value;
           $eprint->appendChild( $coins );

        }

        $xmldoc->setDocumentElement( $publist );
        my $xmldoc_string = $xmldoc->toString(1);

        print {$opts{fh}} $xmldoc_string;
        return;
}
 
1;
