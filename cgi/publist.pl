#!/usr/bin/perl -w -I/usr/local/eprints/perl_lib

#####################################################################
#
#  cgi/publist - generate list of published eprints, UZH project 16-012
#
#  - does some plausi-tests and syntax-checks on incoming parameters
#  - generates query against your repo
#  - returns publist-optimized XML-stream incl. errorhandling
#  - calls different export-plugins
#
#####################################################################
#
#  Copyright 2016-2017 University of Zurich. All Rights Reserved.
#
#  Jens Vieler
#  Zentrale Informatik
#  Universität Zürich
#  Stampfenbachstr. 73
#  CH-8006 Zürich
#
#####################################################################

=pod

=head1 NAME

B<publist> - Publication List (cgi)

=head1 SYNOPSIS

http://server/cgi/B<publist>?I<param=value>I<[&param=value[&param=value...]]>
 

=head1 DESCRIPTION

B<publist> generates a query against your repository and returns a reduced XML-stream (the "kiss" way), needed for building publication lists on the web. It I<can> be used by any WCMS or App, I<will> be used by UZHs WCMS magnolia.

A lot of parameters are used to build a simple list, or (optional) build a second list and combine the two ones with AND, OR or NOT operation.

The maximum output is 2000 items and sorted by publication date.

At least this script could offer a different output formats like "EndNote", "BibTeX", "CSV"  and "XML" - known from EPrints UI.


=head1 PARAMETERS to build a list (obligatory) 

=over 8

=item I<name> - e.g. name=Braendle, M

Name of an Author or Editor I<or>

=item I<orcid> - e.g. orcid=0000-0002-7752-6567

Orcid of an Author or Editor<or>

=item I<collection> - e.g. collection=11068

Number of a community or collection within our repo

=back

Call B<publist> by one or more of these parameters, or call it by useful combinations (name+collection|orcid+collection) - e.g. collection=11068&collection=12099 or name=Bisaz&Collection=11068

=head1 PARAMETERS to build a second list (optional)

used to combine with the first one.

=over 8

=item I<AU>

Autor - e.g. AU=Braendle, M

=item I<ED>

Editor - e.g. ED=Vieler, J

=item I<ES>

Editor Edited Scientific Work - e.g. ES=Forrer, J

=item I<KW>

Keywords - KW=music

=item I<CC>

Collection - e.g. CC=11068

=item I<TY>

Type - e.g. TY=article

=item I<EPID>

EPrint ID - - e.g. EPID=10282

=item I<STY>

Subtype - e.g. STY=original

=item I<PY>

Publication Year - e.g. PY=2008-2012

=item I<CS>

Chair Subject - e.g. CS=sSinologie0

=back

=head1 PARAMETER I<op> to combine the two lists (optional)

=over 8

=item I<AND>

Create a list containing only the items which are in both lists
				
=item I<OR>

Create a list from List1 with elements from List2 added.

=item I<NOT>

Create a list from List1 with elements from List2 removed.

=back

=head1 PARAMETER I<export> to use other output formats (optional)

=over 8

=item I<EndNote>

=item I<BibTeX>

=item I<CSV>

=item I<XML>
				
=back

=head1 RETRUN VALUE

CGI I<publist> returns a more or lesse complex XML datastream:

<?xml version="1.0" encoding="UTF-8"?>
 <publist xmlns="">
   <error code="{errorcode}" text="{errortext}" />
   <eprints count="{counter}"> 
         <eprint id="{eprintid}">
               <pubdate>{YYYYMMDD}</pubdate>
               <citation>{Citation}</citation> 
               <firstauthor>{FirstAuthor}</firstauthor>
               <type>{PubType}</type>
               <coins>{COinS}</coins>
          </eprint>  
          <eprint>
             [...]
          </eprint>
          [...]
   </eprints>
 </publist>

=over 4

=item Root element is <publist>

includes one <error> and one <eprints> element. 

=item <error> informs about the result: errorcode / errortext (like http://www.restapitutorial.com/httpstatuscodes.html)

200 Ok

204 No results

400 No such parameters / values

504 Search timeout

501 Not implemented yet

=item <eprints>

could have 1-n <eprint> elements (one per publication), if there are some.

=item <eprint>

includes data elements - useful to be printed in publicationlists (Citation, eprintid to build up links to your repo, etc.)

includes metadata elements - useful for sorting (pubdate, PubType, etc.) 

=item I<counter>

Number of results / elements in list.

=item I<eprintid>

Identifier, usefull to build up a link to your repo (http://yourrepo/eprintid)

=item <pubdate>I<YYYYMMDD></pubdate>

Useful to sort: Year, month, day

=item <citation>I<Citation></citation>

Citation incl. tagged titel (<title>, </title>), usefull as link-text.

=item <firstauthor>I<FirstAuthor></firstauthor>

First author, if there are more than one.

=item <type>I<PubType></type>

Type of publication.

=item <coins>I<COinS></coins>

ContextObjects in Spans, used by search engines.

=back

=head1 Full example

http://server/cgi/publist?name=Bisaz&op=AND&PY=2008-2012

=cut

use EPrints;
use LWP::Simple;
use FileHandle;
use POSIX qw(setlocale);
use Encode;
use CGI;
use Data::Dumper;

use strict;
use utf8;

## benchmark search / merge long lists
#use Benchmark qw(:all :hireswallclock);
#my ($t0, $t1, $td);
## benchmark example
#$t0 = Benchmark->new;
#some action
#$t1 = Benchmark->new;
#$td = timediff($t1,$t0);
#print "benchmark example\t\t",timestr($td),"\n";

###########################################################################
# the known parameters, advanced parameters and operators
use constant PARAMETERS =>
  qw( name orcid collection op export AU ED ES KW CC TY EPID STY PY CS );
use constant OP_VALUES     => qw( AND OR NOT );
use constant EXPORT_VALUES => qw( EndNote BibTeX CSV XML );
use constant TY_VALUES =>
  qw( article original book_section booksection conference_item dissertation edited_scientific_work habilitation monograph newspaper_article other published_research_report scientific_publication_in_electronic_form working_paper );
use constant STY_VALUES => qw( further original );

use constant MAX_ITEMS => 2000;

use constant ERROR_OK                      => 200;
use constant ERROR_NO_RESULT               => 204;
use constant ERROR_INVALID_PARAMETER_VALUE => 400;
use constant ERROR_REQUEST_TOO_LARGE       => 413;
use constant ERROR_NOT_IMPLEMENTED         => 501;
use constant ERROR_SEARCH_TIMEOUT          => 504;

###########################################################################
# the known universe
my $session = EPrints::Session->new();
exit(0) unless (defined $session);

my $dataset = $session->get_dataset("archive");

my $errorcode = "";
my $errortext = "";

my %form = parseURL();

###########################################################################
# Plausis

($errorcode, $errortext) = checkPlausis(\%form);

if ($errorcode ne ERROR_OK)
{
    print empty_result($errorcode, $errortext);
    undef %form;
    exit(1);
} ## end if ($errorcode ne ERROR_OK...)

###########################################################################
# set Export-Plugin
my $export = "PubList";    # default

if ($form{"export"}[0])
{
    $export = $form{"export"}[0];
}

#	- let EPID be a 4th alternative to name, orcid, collection
#	- let EPID stay in list2, so non need to change plausi checks etc.
#	- due to performance reasons let EPID list run against empty pseudolist instead of >100.000 eprints

if (   $form{"EPID"}[0]
    && (!defined $form{"name"}[0]       || $form{"name"}[0]       eq "")
    && (!defined $form{"orcid"}[0]      || $form{"orcid"}[0]      eq "")
    && (!defined $form{"collection"}[0] || $form{"collection"}[0] eq ""))
{
    $form{"op"}[0]   = "OR";
    $form{"name"}[0] = "pseudolist4EPID";
}

###########################################################################
# generate Publist
# List1 name, orcid or collection
#       or combinations name+collection, orcid+collection
# OP    op
# List2 AU,ED,ES,KW,CC,TY,EPID,STY,PY,CS
# sort  chronological
my $result;
if (   $form{"name"}[0]
    || $form{"orcid"}[0]
    || $form{"collection"}[0]
    || $form{"EPID"}[0])
{
    #######################################################
    # build List1
    my $search_expression1 = $dataset->prepare_search;
    buildList1($dataset, $search_expression1, \%form);
    $search_expression1->set_property('custom_order', "-date");
    my $result1 = $search_expression1->perform_search();

    if (   $form{"AU"}[0]
        || $form{"ED"}[0]
        || $form{"ES"}[0]
        || $form{"KW"}[0]
        || $form{"CC"}[0]
        || $form{"TY"}[0]
        || $form{"EPID"}[0]
        || $form{"STY"}[0]
        || $form{"PY"}[0]
        || $form{"CS"}[0])
    {

        my $operator = "AND";    # default
        if ($form{"op"}[0])
        {
            $operator = $form{"op"}[0];
        }

        #######################################################
        # build List2
        my $search_expression2 = $dataset->prepare_search;
        buildList2($dataset, $search_expression2, \%form);
        $search_expression2->set_property('custom_order', "-date");
        my $result2 = $search_expression2->perform_search();

        #######################################################
        # operate List1 vs List2
        if ($operator eq "NOT")
        {

            #Create a new list from List1 with elements from List2 removed.
            $result = $result1->remainder($result2, "-date");
        } ## end if ($operator eq "NOT"...)
        else
        {
            if ($operator eq "OR")
            {

                # Create new list from this one plus another one
                $result = $result1->union($result2, "-date");
            } ## end if ($operator eq "OR")
            else
            {

                # Create new list containing only items which are in both lists
                $result = $result1->intersect($result2, "-date");
            } ## end else [ if ($operator eq "OR")]
        } ## end else [ if ($operator eq "NOT"...)]
            # EPrints ticket UZH-131:
            # remainder/union/intersect 'order' parameter is buggy, so let's
            # do another search with custom_order (which works) :-(
        my @items;
        $result->map(
            sub {
                my ($session, $dataset, $eprint) = @_;
                push @items, $eprint->get_id;
            }
        );

        my $union_list_ordered =
          $dataset->search(
                           filters => [
                                       {
                                        meta_fields => [qw( eprintid )],
                                        value       => join(" ", @items),
                                        merge       => "ANY"
                                       }
                                      ],
                           custom_order => "-date",
                          );
        $result = $union_list_ordered;

        # EPrints ticket UZH-131 - END
    } ## end if ($form{"AU"}[0] || ...)
    else
    {
        $result = $result1;
    }

    if (($result->count > 0) && ($result->count <= MAX_ITEMS))
    {
        if ($export eq "PubList")
        {
            $session->get_request->headers_out->{'Content-Disposition'} =
              'attachment; filename="PubList.xml"';
            $session->send_http_header(
                            "content_type" => "application/xml; charset=utf-8");
        }
        elsif ($export eq "XML")
        {
            $session->get_request->headers_out->{'Content-Disposition'} =
              'attachment; filename="PubList.xml"';
            $session->send_http_header(
                            "content_type" => "application/xml; charset=utf-8");
        }
        elsif ($export eq "EndNote")
        {
            $session->get_request->headers_out->{'Content-Disposition'} =
              'attachment; filename="PubList.enz"';
            $session->send_http_header(
                                 "content_type" => "text/plain; charset=utf-8");
        }
        elsif ($export eq "BibTeX")
        {
            $session->get_request->headers_out->{'Content-Disposition'} =
              'attachment; filename="PubList.bib"';
            $session->send_http_header(
                                 "content_type" => "text/plain; charset=utf-8");
        }
        elsif ($export eq "CSV")
        {
            $session->get_request->headers_out->{'Content-Disposition'} =
              'attachment; filename="PubList.csv"';
            $session->send_http_header(
                                 "content_type" => "text/plain; charset=utf-8");
        }
        else
        {
            $session->send_http_header(
                                 "content_type" => "text/plain; charset=utf-8");
        }

        $result->export($export, fh => \*STDOUT,);
    } ## end if (($result->count > ...))
    elsif ($result->count > MAX_ITEMS)
    {
        print empty_result(ERROR_REQUEST_TOO_LARGE, "Too many results");
    }
    else
    {
        print empty_result(ERROR_NO_RESULT, "No results");
    }

} ## end if ($form{"name"}[0] ||...)
else
{
    print empty_result(
        ERROR_INVALID_PARAMETER_VALUE,
        "Invalid Parameter - need at least one of name, orcid, collection, EPID"
    );
} ## end else [ if ($form{"name"}[0] ||...)]

undef %form;
exit(0);

###########################################################################
# parse Query
sub parseURL
{
    my $q_query = CGI->new($ENV{'QUERY_STRING'});
    my %params = map { $_ => [$q_query->param($_)] } $q_query->param();

    # params is a hash on array of hashes on arrays and could handle
    # multiple, equal "param="
    #
    # URL:...?collection=11068&collection=11198&name=Vieler,%20J
    # params = {
    #          'name' => 		[
    #		                      'Vieler, J'
    #			        ],
    #          'collection' => 	[
    #              		      '11068',
    #		                      '11198'
    #        			]
    #          };

    return %params;
} ## end sub parseURL

###########################################################################
# list1: "name", "orcid", "collection"
sub buildList1
{
    my ($dataset, $search_expression, $form) = @_;

    my (@names, @orcids, @collections);

    # name
    if ($form->{'name'})
    {
        @names = @{$form->{'name'}};
        for (my $i = 0 ; $i < (scalar @names) ; $i++)
        {

            # put more than one name in quotes, see also advanced search help
            if ($names[$i] =~ m/\s(.*),/)
            {
                $names[$i] = "\"$names[$i]\"";
            }
            $search_expression->add_field(
                fields => [
                           $dataset->get_field("creators_name"),
                           $dataset->get_field("editors_name"),
                           $dataset->get_field(
                                          "editors_edited_scientific_work_name")
                          ],

                #value => $names[$i],
                value => decode('utf8', $names[$i]),
                match => "IN",
                merge => "ANY",
                                         );
        } ## end for (my $i = 0 ; $i < (...))
    } ## end if ($form->{'name'})

    # orcid
    if ($form->{'orcid'})
    {
        @orcids = @{$form->{'orcid'}};
        for (my $i = 0 ; $i < (scalar @orcids) ; $i++)
        {
            $search_expression->add_field(
                fields => [
                           $dataset->get_field("creators_orcid"),
                           $dataset->get_field("examiners_orcid"),
                           $dataset->get_field("editors_orcid"),
                           $dataset->get_field(
                                         "editors_edited_scientific_work_orcid")
                          ],
                value => join(" ", @orcids),

                #value => $orcids[$i],
                #value => decode('utf8', $orcids[$i]),
                match => "EQ",
                merge => "ANY",
                                         );
        } ## end for (my $i = 0 ; $i < (...))
    } ## end if ($form->{'orcids'})

    # collection
    if ($form->{'collection'})
    {
        @collections = @{$form->{'collection'}};
        $search_expression->add_field(
                                    fields => [$dataset->get_field("subjects")],
                                    value  => join(" ", @collections),
                                    match  => "EQ",
                                    merge  => "ANY",
        );
    } ## end if ($form->{'collection'...})

    return;
} ## end sub buildList1

###########################################################################
# list2: "AU", "ED", "ES", "KW", "CC" , "TY" , "EPID" , "STY" , "PY" , "CS"
sub buildList2
{
    my ($dataset, $search_expression, $form) = @_;

    my (@AUs, @EDs, @ESs, @KWs, @CCs, @TYs, @EPIDs, @STYs, @PYs, @CSs);

    # AU - Autor
    if ($form->{'AU'})
    {
        @AUs = @{$form->{'AU'}};

        # put more than one name in quotes, see also advanced search help
        for (my $i = 0 ; $i < (scalar @AUs) ; $i++)
        {
            if ($AUs[$i] =~ m/\s(.*),/)
            {
                $AUs[$i] = "\"$AUs[$i]\"";
            }
        }
        $search_expression->add_field(
            fields => [
                $dataset->get_field("creators_name"),

                #$dataset->get_field("editors_name"),
                #$dataset->get_field("editors_edited_scientific_work_name")
                      ],

            #value => join(" ", @AUs),
            value => decode('utf8', join(" ", @AUs)),
            match => "IN",
            merge => "ANY",
                                     );
    } ## end if ($form->{'AU'})

    # ED - Editor
    if ($form->{'ED'})
    {
        @EDs = @{$form->{'ED'}};

        # put more than one name in quotes, see also advanced search help
        for (my $i = 0 ; $i < (scalar @EDs) ; $i++)
        {
            if ($EDs[$i] =~ m/\s(.*),/)
            {
                $EDs[$i] = "\"$EDs[$i]\"";
            }
        }
        $search_expression->add_field(
            fields => [
                $dataset->get_field("editors_name"),

                #$dataset->get_field("editors_edited_scientific_work_name")
                      ],

            #value => join(" ", @EDs),
            value => decode('utf8', join(" ", @EDs)),
            match => "IN",
            merge => "ANY",
                                     );
    } ## end if ($form->{'ED'})

    # ES - Editor Edited Scientific Work
    if ($form->{'ES'})
    {
        @ESs = @{$form->{'ES'}};

        # put more than one name in quotes, see also advanced search help
        for (my $i = 0 ; $i < (scalar @ESs) ; $i++)
        {
            if ($ESs[$i] =~ m/\s(.*),/)
            {
                $ESs[$i] = "\"$ESs[$i]\"";
            }
        }
        $search_expression->add_field(
            fields =>
              [$dataset->get_field("editors_edited_scientific_work_name")],

            #value => join(" ", @ESs),
            value => decode('utf8', join(" ", @ESs)),
            match => "IN",
            merge => "ANY",
                                     );
    } ## end if ($form->{'ES'})

    # KW - Keywords
    if ($form->{'KW'})
    {
        @KWs = @{$form->{'KW'}};
        $search_expression->add_field(
                                    fields => [$dataset->get_field("keywords")],
                                    value  => join(" ", @KWs),
                                    match  => "IN",
                                    merge  => "ANY",
        );
    } ## end if ($form->{'KW'})

    # CC - Collection
    if ($form->{'CC'})
    {
        @CCs = @{$form->{'CC'}};
        $search_expression->add_field(
                                    fields => [$dataset->get_field("subjects")],
                                    value  => join(" ", @CCs),
                                    match  => "EQ",
                                    merge  => "ANY",
        );
    } ## end if ($form->{'CC'})

    # TY - Type
    if ($form->{'TY'})
    {
        @TYs = @{$form->{'TY'}};
        $search_expression->add_field(
                                      fields => [$dataset->get_field("type")],
                                      value  => join(" ", @TYs),
                                      match  => "EQ",
                                      merge  => "ANY",
                                     );
    } ## end if ($form->{'TY'})

    # EPID - EPrint ID
    if ($form->{'EPID'})
    {
        @EPIDs = @{$form->{'EPID'}};
        $search_expression->add_field(
                                    fields => [$dataset->get_field("eprintid")],
                                    value  => join(" ", @EPIDs),
                                    match  => "EQ",
                                    merge  => "ANY",
        );
    } ## end if ($form->{'EPID'})

    # STY - Subtype
    if ($form->{'STY'})
    {
        @STYs = @{$form->{'STY'}};
        $search_expression->add_field(
                                     fields => [$dataset->get_field("subtype")],
                                     value  => join(" ", @STYs),
                                     match  => "EQ",
                                     merge  => "ANY",
        );
    } ## end if ($form->{'STY'})

    # PY - Publication Year
    if ($form->{'PY'})
    {
        @PYs = @{$form->{'PY'}};
        $search_expression->add_field(
            fields =>
              [$dataset->get_field("date"), $dataset->get_field("event_end")],

            #value => join(" ",@PYs),
            value => $PYs[0],
            match => "IN",
            merge => "ANY",
                                     );
    } ## end if ($form->{'PY'})

    # CS - Chair Subject (custom field)
    if ($form->{'CS'})
    {
        @CSs = @{$form->{'CS'}};
        $search_expression->add_field(
                               fields => [$dataset->get_field("chair_subject")],
                               value  => join(" ", @CSs),
                               match  => "IN",
                               merge  => "ANY",
        );
    } ## end if ($form->{'CS'})

    return;
} ## end sub buildList2

###########################################################################
# check around parameters
sub checkPlausis
{
    my %form = %{shift()};

    # min / max parameters
    if ((keys %form) lt 1)
    {
        return (ERROR_INVALID_PARAMETER_VALUE,
                "Invalid Parameter - need at least one parameter");
    }

    # min one of name, orcid, collection, EPID
    if (
        not(   $form{"name"}[0]
            || $form{"orcid"}[0]
            || $form{"collection"}[0]
            || $form{"EPID"}[0])
       )
    {
        return (
            ERROR_INVALID_PARAMETER_VALUE,
            "Invalid Parameter - need at least one of name, orcid, collection, EPID"
        );
    } ## end if (not($form{"name"}[...]))

    foreach my $key (keys %form)
    {
        for (my $i = 0 ; $i < (scalar @{$form{$key}}) ; $i++)
        {
            my $value = $form{$key}[$i];

            #print "Plausi-Test: $key=$value\n"; # debug only
            # 1st check allowed parameters
            if (validParametersValues($key, PARAMETERS) == ERROR_OK)
            {

                # 2nd check content: alpha, num, orcid, element of list
                if (validValue($key, $value) != ERROR_OK)
                {
                    return (ERROR_INVALID_PARAMETER_VALUE,
                            "Invalid Value for $key");
                }
            } ## end if (validParametersValues...)
            else
            {
                return (ERROR_INVALID_PARAMETER_VALUE,
                        "Invalid Parameter $key");
            }
        } ## end for (my $i = 0 ; $i < (...))
    } ## end foreach my $key (keys %form...)

    return (ERROR_OK, "OK");
} ## end sub checkPlausis

###########################################################################
# check allowed params: validParametersValues(param, list of allowed params...)
sub validParametersValues
{
    my $vp  = shift;
    my @vps = @_;

    if (my @found = grep { $_ eq $vp } @vps)
    {
        return ERROR_OK;    # valid
    }

    return ERROR_INVALID_PARAMETER_VALUE;    # unknown parameter
} ## end sub validParametersValues

###########################################################################
# check param values: validValue(param, value)
sub validValue
{
    my ($vp, $vv) = @_;

    if (   ($vp eq "name")
        || ($vp eq "AU")
        || ($vp eq "ED")
        || ($vp eq "ES"))
    {

        #    if ($vv =~ m/[^a-zA-Z0-9,\s]/)
        #    {    # alphanum + komma + space
        #        return ERROR_INVALID_PARAMETER_VALUE;
        #    }
        return ERROR_OK;
    } ## end if (($vp eq "name") ||...)

    if ($vp eq "orcid")
    {

        # formal tests, Example: 1234-5678-9012-345X
        if (not($vv =~ m/^\d{4}\-\d{4}\-\d{4}\-\d{3}[0-9Xx]$/))
        {
            return ERROR_INVALID_PARAMETER_VALUE;
        }

        # Checksum-Test
        return checksumORCID($vv);
    } ## end if ($vp eq "orcid")

    if (   ($vp eq "collection")
        || ($vp eq "CC")
        || ($vp eq "EPID"))
    {
        if ($vv =~ m/[^0-9]/)
        {    # num
            return ERROR_INVALID_PARAMETER_VALUE;
        }
        return ERROR_OK;
    } ## end if (($vp eq "collection"...))

    if ($vp eq "TY")
    {
        return validParametersValues($vv, TY_VALUES);
    }

    if (   ($vp eq "CS")
        || ($vp eq "KW"))
    {
        if ($vv =~ m/[^a-zA-Z0-9,;\s]/)
        {    # alphanum + komma + space
            return ERROR_INVALID_PARAMETER_VALUE;
        }
        return ERROR_OK;
    } ## end if (($vp eq "CS") || (...))

    if ($vp eq "STY")
    {
        return validParametersValues($vv, STY_VALUES);
    }

    if ($vp eq "PY")
    {
        if ($vv =~ m/[^0-9\-]/)
        {    # alphanum + space
            return ERROR_INVALID_PARAMETER_VALUE;
        }
        return ERROR_OK;
    } ## end if ($vp eq "PY")

    if ($vp eq "op")
    {
        return validParametersValues($vv, OP_VALUES);
    }

    if ($vp eq "export")
    {
        return validParametersValues($vv, EXPORT_VALUES);
    }

    return ERROR_INVALID_PARAMETER_VALUE;    # unknown parameter
} ## end sub validValue

###########################################################################
# check correct format of orcid
sub checksumORCID
{

    # orcid comes in with this format: 1234-5678-9012-345X
    # checksum-test from http://support.orcid.org/knowledgebase/articles/116780-structure-of-the-orcid-identifier

    my $orcid = shift;

    my $total = 0;
    my $digit = 0;

    for (my $i = 0 ; $i < 18 ; $i++)
    {
        $digit = substr($orcid, $i, 1);
        next if ($digit eq "-");
        $total = ($total + $digit) * 2;
    } ## end for (my $i = 0 ; $i < 18...)

    my $result = (12 - ($total % 11)) % 11;
    if ($result eq "10")
    {
        $result = "X";
    }

    if (substr($orcid, 18, 1) eq $result)
    {

        # checksum is last digit, orcid seems to be ok
        return ERROR_OK;
    } ## end if (substr($orcid, 18,...))
    else
    {
        return ERROR_INVALID_PARAMETER_VALUE;    # wrong orcid
    }
} ## end sub checksumORCID

###########################################################################
# no result? answer in a short way: errorcode and -text
sub empty_result
{
    my ($ec, $et) = @_;

    use CGI qw(:cgi);

    #print header(-type => 'text/plain'); #Debug only
    print header(-type => "application/xml; charset=UTF-8");
    print '<?xml version="1.0" encoding="UTF-8"?>' . "\n";
    print
      '<publist xmlns="http://yourdomain/publist2" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://yourdomain/publist.xsd">'
      . "\n";

    print '   <error code="' . $ec . '" text="' . $et . '" />' . "\n";
    print '   <eprints count="0" />' . "\n";
    print '</publist>' . "\n";
    return;
} ## end sub empty_result

1;

