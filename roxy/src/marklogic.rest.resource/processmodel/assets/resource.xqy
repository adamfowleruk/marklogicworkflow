xquery version "1.0-ml";

module namespace ext = "http://marklogic.com/rest-api/resource/processmodel";

import module namespace json = "http://marklogic.com/xdmp/json" at "/MarkLogic/json/json.xqy";

import module namespace wfi="http://marklogic.com/workflow-import" at "/app/models/workflow-import.xqy";
import module namespace wfu="http://marklogic.com/workflow-util" at "/app/models/workflow-util.xqy";

declare namespace wf="http://marklogic.com/workflow";

declare namespace roxy = "http://marklogic.com/roxy";


(:
 : Get the process model by exact name
 :  ?publishedId=name
 :)
declare
%roxy:params("")
function ext:get(
  $context as map:map,
  $params  as map:map
) as document-node()*
{
  let $preftype := "application/xml" (: if ("application/xml" = map:get($context,"accept-types")) then "application/xml" else "application/json" :)

  let $out := wfi:get-model-by-name(map:get($params,"publishedId"))
  return
  (
    map:put($context, "output-types", "text/xml"), (: TODO mime type from file name itself :)
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
 : Publish the process model
 :  ?[major=numeric[&minor=numeric]]&name=name[&enable=true]
 :)
declare
%roxy:params("")
function ext:put(
    $context as map:map,
    $params  as map:map,
    $input   as document-node()*
) as document-node()?
{
  let $preftype := if ("application/xml" = map:get($context,"accept-types")) then "application/xml" else "application/json"

  let $_ := xdmp:log("processmodel: PUT: name: " || map:get($params,"name") || ", major: " || map:get($params,"major") || ", minor: " || map:get($params,"minor"))
  let $_ := xdmp:log($params)
  let $_ := xdmp:log($context)
  let $_ := xdmp:log($input)

  let $enable := if (map:get($params,"enable") = "true") then fn:true() else fn:false()
  let $_ := xdmp:log("Enabled? : " || xs:string($enable))

  let $modelid := wfi:install-and-convert($input,map:get($params,"name"),(map:get($params,"major"),"1")[1],(map:get($params,"minor"),"0")[1], $enable )

  let $out := <ext:createResponse><ext:outcome>SUCCESS</ext:outcome><ext:modelId>{$modelid}</ext:modelId></ext:createResponse>

  return
  (
    map:put($context, "output-types", "application/json"),
    xdmp:set-response-code(200, "OK"),
    document {
      (: 1. Take the process model document and convert to a CPF pipeline document :)
      (: 2. Add a CPF pipeline by using a directory scope of /cpf/processes/ (<PROCURI>/<UUID.xml>) depth infinite :)
      (: 3. Optionally enable :)

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
 : Add a new process model version.
 : ?publishedId=myprocess__1__0
 :)
declare
%roxy:params("")
function ext:post(
    $context as map:map,
    $params  as map:map,
    $input   as document-node()*
) as document-node()*
{
  let $preftype := if ("application/xml" = map:get($context,"accept-types")) then "application/xml" else "application/json"

  let $_ := xdmp:log($params)
  let $_ := xdmp:log($context)
  let $_ := xdmp:log($input)

  let $published := xs:string(wfi:enable(map:get($params,"publishedId")))

  let $out := <ext:updateResponse><ext:outcome>SUCCESS</ext:outcome><ext:domainId>{$published}</ext:domainId></ext:updateResponse>

  return
  (
    map:put($context, "output-types", "application/json"),
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


(:)
(:
 : Remove the specified process model from execution
 :  ?[major=numeric[&minor=numeric]]&modelid=modelid
 :)
declare function ext:delete(
    $context as map:map,
    $params  as map:map
) as document-node()?
{
  let $preftype := if ("application/xml" = map:get($context,"accept-types")) then "application/xml" else "application/json"

  let $name := map:get($params,"something")
  let $l := xdmp:log("DELETE /v1/resources/processmodel CALLED")
  let $out := ()
  let $l := xdmp:log($params)
  let $l := xdmp:log($context)
  return (xdmp:set-response-code(200,"OK"),document {

            if ("application/xml" = $preftype) then
              $out
            else
              let $config := json:config("custom")
              let $cx := map:put($config, "text-value", "label" )
              let $cx := map:put($config , "camel-case", fn:true() )
              return
                json:transform-to-json($out, $config)


   })
};
:)
