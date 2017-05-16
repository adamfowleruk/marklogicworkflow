xquery version "1.0-ml";

module namespace m="http://marklogic.com/workflow-admin";

import module namespace wfu="http://marklogic.com/workflow-util" at "/app/models/workflow-util.xqy";

import module namespace cpf = "http://marklogic.com/cpf" at "/MarkLogic/cpf/cpf.xqy";

declare namespace prop = "http://marklogic.com/xdmp/property";
declare namespace wf="http://marklogic.com/workflow";
declare namespace p="http://marklogic.com/cpf/pipelines";
declare namespace error="http://marklogic.com/xdmp/error";


(:
 : Lists all processes currently running in MarkLogic. (Does not included those in error by default.)
 :)
declare function m:processes($username as xs:string?) as element(wf:processes) {
  <wf:processes>
  {
    for $process in cts:search(fn:collection("http://marklogic.com/workflow/processes"),
      ),("unfiltered") (: TODO ordering, prioritisation support, and so on :)
    )/wf:process
    return
      <wf:process-details id="{xs:string($process/@id)}">
        <wf:process-data>
        {$process}
        </wf:process-data>
        <wf:process-properties>
        {xdmp:properties-document(fn:base-uri($process))}
        </wf:process-properties>
      </wf:process-details>
  }
  </wf:processes>
};

declare function m:terminate($processIds as xs:string*) as element(wf:processes) {
  <wf:processes>
  {
      for $process-uri in cts:search(fn:collection("http://marklogic.com/workflow/processes"),
        cts:and-query(
          cts:properties-query(
            cts:or-query(
              (
                cts:element-value-query(xs:QName("wf:status"),"INITIALISING"),
                cts:element-value-query(xs:QName("wf:status"),"RUNNING"),
                cts:element-value-query(xs:QName("wf:status"),"WAITING")
              )
            )
          ),
        if (fn:empty($processIds)) then () else
          cts:or-query(
              for $pid in $processIds
              return cts:element-attribute-value-query(xs:QName("wf:process"),xs:QName("wf:pid"),$pid)
          )
        ),("unfiltered") (: TODO ordering, prioritisation support, and so on :)
      )/wf:process/fn:base-uri(.)
      let $term := fn:node-replace(xdmp:properties-document($process-uri)/prop:properties/wf:status,
        <wf:status by="{xdmp:get-current-user()}" when="{fn:current-dateTime()}">TERMINATED</wf:status>)
      return
        <wf:process-summary id="{xs:string(fn:doc($process-uri)/wf:process/@id)}" />
  }
  </wf:processes>
};
