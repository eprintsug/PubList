# PubList
Interface to build a list of publications for personal / organisational websites.

PubList generates a query against your local repository and returns a reduced XML stream (the "kiss" way), needed for building publication lists on the web. It can be used by any WCMS or App (we did it with Magnolia and Typo3).

## DESCRIPTION

- cgi script to search and merge different lists
- export plugin for XML output

A lot of parameters are used to build a simple list, or (optionally) build a second list and combine the two lists with AND, OR or NOT operation.

The maximum output is 2000 items (configurable) and sorted by publication date. This script can provide different output formats as well; by default if offers its own XML export.

## PARAMETERS to build a list (mandatory, at least one of the following parameters must be used)
       name - e.g. name=Braendle, M
               Name of an author or editor

       orcid - e.g. orcid=0000-0002-7752-6567
               Orcid of an author or editor

       collection - e.g. collection=11068
               Number of a community or collection within ZORA.

Call publist by one or more of these parameters, or call it by useful combinations (name+collection|orcid+collection) - e.g. collection=11068&collection=12099 or name=Bisaz&collection=11068

## PARAMETERS to build a second list (optional) used to combine with the first one.

       AU      Autor - e.g. AU=Braendle, M

       ED      Editor - e.g. ED=Vieler, J

       ES      Editor Edited Scientific Work - e.g. ES=Forrer, J

       KW      Keywords - KW=music

       CC      Collection - e.g. CC=11068

       TY      Type - e.g. TY=article

       EPID    EPrint ID - - e.g. EPID=10282

       STY     Subtype - e.g. STY=original

       PY      Publication Year - e.g. PY=2008-2012

       CS      Chair Subject - e.g. CS=sSinologie0

These parameters depend on the data model used in your repository. The ones listed here are
used by ZORA.


## PARAMETER op to combine the two lists (optional)
       AND     Create a list containing only the items which are in both lists

       OR      Create a list from list 1 with elements from list 2 added.

       NOT     Create a list from list 1 with elements from list 2 removed.

## PARAMETER export to use other output formats (optional) - change them to your needs
       EndNote
       BibTeX
       CSV
       XML

## RETURN VALUE
       CGI publist returns an easy to read and handle XML data stream:

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

Root element is &lt;publist>. It includes one &lt;error> and one &lt;eprints> element.

       <error> informs about the result: errorcode / errortext 
       (like http://www.restapitutorial.com/httpstatuscodes.html)
       
           200 Ok

           204 No results

           400 No such parameters / values

           504 Search timeout

           501 Not implemented yet

       <eprints>
           could have 1-n <eprint> elements (one per publication), if there are some.

       <eprint>
           includes data elements - useful to be printed in publicationlists (Citation, eprintid 
           to build up links to your repo, etc.)

           includes metadata elements - useful for sorting (pubdate, PubType, etc.)

       counter
           Number of results / elements in list.

       eprintid
           Identifier, useful to build up a link to your repository (http://www.yourrepo.com/eprintid)

       <pubdate>YYYYMMDD</pubdate>
           Useful for sorting: Year, month, day

       <citation>Citation</citation>
           Citation incl. tagged title (<title>, </title>), useful as link text.

       <firstauthor>FirstAuthor</firstauthor>
           First author, if there are more than one.

       <type>PubType</type>
           Type of publication.

       <coins>COinS</coins>
           ContextObjects in Span, used by search engines.

## Example
    
To get an XML stream with all publications from 2008 to 2012 of a person named "Bisaz" (author, creator, ...) use
http://server/cgi/publist?name=Bisaz&op=AND&PY=2008-2012

## Install
    
- put publist into your {eprints_root}/cgi directory
- put PubList.pm into your export plugin directory
- put publist.xsd into your {eprints_root}/archives/{archive}/html/{language}/ tree (for each language)
- change all "yourdomain" strings in scripts and configs to your belongings
