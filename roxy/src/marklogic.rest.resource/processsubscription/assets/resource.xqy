
xquery version "1.0-ml";

module namespace ext = "http://marklogic.com/rest-api/resource/processsubscription";

(: import module namespace config = "http://marklogic.com/roxy/config" at "/app/config/config.xqy"; :)
import module namespace json = "http://marklogic.com/xdmp/json" at "/MarkLogic/json/json.xqy";

import module namespace cpf = "http://marklogic.com/cpf" at "/MarkLogic/cpf/cpf.xqy";
import module namespace wfu="http://marklogic.com/workflow-util" at "/app/models/workflow-util.xqy";

declare namespace roxy = "http://marklogic.com/roxy";
declare namespace wf="http://marklogic.com/workflow";

 (:
  : Create a process subscription (saved content alert)
  : Expects:=
  : <ext:createRequest xmlns:ext="http://marklogic.com/rest-api/resource/processsubscription">
  :  <ext:processName>ProcessName__1__0</ext:processName>
  :  <ext:name>SubscriptionName</ext:name>
  :  <ext:domain>
  :   <ext:name>Some folder alerting domain</ext:name>
  :   <ext:type>directory</ext:type>
  :   <ext:path>/some/</ext:path>
  :   <ext:depth>0</ext:depth>
  :  </ext:domain>
  :  <ext:query>
  :   <cts:collection-query xmlns:cts="http://marklogic.com/cts"><cts:uri>/test/email/sub</cts:uri></cts:collection-query>
  :  </ext:query>
  : </ext:createRequest>
  :)
declare
%roxy:params("")
function ext:put(
   $context as map:map,
   $params  as map:map,
   $input   as document-node()*
) as document-node()? {

  let $preftype := if ("application/xml" = map:get($context,"accept-types")) then "application/xml" else "application/json"

  let $_ := xdmp:log($input)
  let $domainid := wfu:createAlertingDomain(
    xs:string($input/ext:createRequest/ext:domain/ext:name),
    xs:string($input/ext:createRequest/ext:domain/ext:type),
    xs:string($input/ext:createRequest/ext:domain/ext:path),
    xs:string($input/ext:createRequest/ext:domain/ext:depth)
  )
  let $subname := wfu:createSubscription(
    xs:string($input/ext:createRequest/ext:processName),
    xs:string($input/ext:createRequest/ext:name),
    xs:string($input/ext:createRequest/ext:domain/ext:name),
    cts:query($input/ext:createRequest/ext:query/element())
  )

  let $out := <ext:createResponse><ext:outcome>SUCCESS</ext:outcome><ext:subscriptionId>{$subname}</ext:subscriptionId></ext:createResponse>

  return
  (
    map:put($context, "output-types", $preftype),
    xdmp:set-response-code(200, "OK"),
    document {
      if ("application/xml" = $preftype) then
        $out
      else
        let $config := json:config("custom")
        let $cx := map:put($config, "text-value", "label" )
        let $cx := map:put($config , "camel-case", fn:true() )
        return
          json:transform-to-json($out, $config)
    }
  )
};

(:
 : Fetch a process subscription by its name
 : ?name = the string id used in POST v1/resources/processsubscription
 :)
declare
%roxy:params("name=xs:string")
function ext:get(
  $context as map:map,
  $params  as map:map
) as document-node()*
{
  let $preftype := if ("application/xml" = map:get($context,"accept-types")) then "application/xml" else "application/json"

  let $_ := xdmp:log($params)
  let $_ := xdmp:log($context)

  let $out :=
    if (fn:empty(map:get($params,"name"))) then
      <ext:readResponse><ext:outcome>FAILURE</ext:outcome><ext:details>name parameter is required</ext:details></ext:readResponse>
    else
      <ext:readResponse><ext:outcome>SUCCESS</ext:outcome>
        <ext:subscription>
          {wfu:getSubscription(map:get($params,"name"))}
        </ext:subscription>
      </ext:readResponse>

  return
  (
    xdmp:set-response-code(200, "OK"),
    document {
      if ("application/xml" = $preftype) then
        $out
      else
        let $config := json:config("custom")
        let $cx := map:put($config, "text-value", "label" )
        let $cx := map:put($config , "camel-case", fn:true() )
        return
          json:transform-to-json($out, $config)
    }
  )
};
