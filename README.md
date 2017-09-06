# PubList
Interface to build list of publications for personal / organisational websites.

publist generates a query against your local repository and returns a reduced XML-stream (the "kiss" way), needed for building publication lists on the web. It can be used by any WCMS or App (we did it with magniloa and typo3).

## DESCRIPTION

- cgi script to search and merge different lists
- export plugin for XML output

A lot of parameters are used to build a simple list, or (optional) build a second list and combine the two ones with AND, OR or NOT operation.

The maximum output is 2000 items (configure) and sorted by publication date. At least this script could offer a different output formats; by default it's own XML export.

## PARAMETERS to build a list (obligatory)
       name - e.g. name=Braendle, M
               Name of an Author or Editor or

       orcid - e.g. orcid=0000-0002-7752-6567
               Orcid of an Author or Editor<or>

       collection - e.g. collection=11068
               Number of a community or collection within ZORA.

Call publist by one or more of these parameters, or call it by useful combinations (name+collection|orcid+collection) - e.g. collection=11068&collection=12099 or name=Bisaz&Collection=11068

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

## PARAMETER op to combine the two lists (optional)
       AND     Create a list containing only the items which are in both lists

       OR      Create a list from List1 with elements from List2 added.

       NOT     Create a list from List1 with elements from List2 removed.

## PARAMETER export to use other output formats (optional) - change them to your needs
       EndNote
       BibTeX
       CSV
       XML

## RETRUN VALUE
       CGI publist returns an easy to read and handle XML datastream:

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

Root element is <publist>. It includes one <error> and one <eprints> element.

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
           Identifier, usefull to build up a link to ZORA (http://www.zora.uzh.ch/eprintid)

       <pubdate>YYYYMMDD</pubdate>
           Useful to sort: Year, month, day

       <citation>Citation</citation>
           Citation incl. tagged titel (<title>, </title>), usefull as link-text.

       <firstauthor>FirstAuthor</firstauthor>
           First author, if there are more than one.

       <type>PubType</type>
           Type of publication.

       <coins>COinS</coins>
           ContextObjects in Spans, used by search engines.

## Example
    
To get a XML straem with all publications from 2008 to 2012 of a person named "Bisaz" (author, creator, ...) use
http://server/cgi/publist?name=Bisaz&op=AND&PY=2008-2012

