xquery version "1.0-ml";

module namespace wth = "http://marklogic.com/roxy/test-models/workflow-test-helper";

import module namespace cfg = "http://marklogic.com/roxy/config"     at "/app/config/config.xqy";
import module namespace w   = "http://marklogic.com/workflow/lib"    at "/app/models/workflow-lib.xqy";
import module namespace wfs = "http://marklogic.com/workflow/search" at "/app/models/search-workflow.xqy";

declare namespace e = "http://www.gov.uk/dclg/eclaims";
declare namespace wf = "http://marklogic.com/workflow";

declare function wth:wf-process($id as xs:string, $type as xs:string, $payload as item()){
   xdmp:http-post(
      $cfg:TEST-SERVICE-ADDRESS || "/esif/workflow/process/" || $type || "/" || $id, 
      <options xmlns="xdmp:http">
        <authentication method="digest">
             <username>{$cfg:TEST-SERVICE-USERNAME}</username>
             <password>{$cfg:TEST-SERVICE-PASSWORD}</password>
        </authentication>
        <data>{xdmp:quote($payload)}</data>
        <headers>
             <content-type>application/xml</content-type>
             <accept>application/xml</accept>
        </headers>
      </options>
   )
};

declare function wth:wf-process-doc-uri($id as xs:string, $type as xs:string) as xs:string* {
    fn:base-uri(
        fn:collection()/wf:process[@title = $w:PROCESSES/process[type eq $type]/xs:string(name) and fn:exists(wf:data/*[. = $id])]
    )
};

declare function wth:release-held-for-retention-claims($id as xs:string, $request as item()){
 xdmp:http-put(
      $cfg:TEST-SERVICE-ADDRESS || "/esif/project/" || $id || "/held-for-retention-claims", 
      <options xmlns="xdmp:http">
        <authentication method="digest">
             <username>{$cfg:TEST-SERVICE-USERNAME}</username>
             <password>{$cfg:TEST-SERVICE-PASSWORD}</password>
        </authentication>
        <data>{xdmp:quote($request)}</data>
        <headers>
             <content-type>application/json</content-type>
             <accept>application/json</accept>
        </headers>
      </options>
   )
};

(: essentially make the same call as search controller's search-tasks :)
declare function wth:search-tasks($request as element(request))
{
    wfs:task-search(
            $request/search,
            $request/filter,
            $request/view,
            $request/sort-string,
            $request/start/xs:int(.),
            $request/length/xs:int(.))
};
