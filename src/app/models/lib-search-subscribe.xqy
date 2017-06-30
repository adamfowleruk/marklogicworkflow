xquery version "1.0-ml";

module namespace ss = "http://marklogic.com/search/subscribe";

import module namespace alert="http://marklogic.com/xdmp/alert" at "/MarkLogic/alert.xqy";
import module namespace dom = "http://marklogic.com/cpf/domains" at "/MarkLogic/cpf/domains.xqy";
import module namespace p="http://marklogic.com/cpf/pipelines" at "/MarkLogic/cpf/pipelines.xqy";

declare namespace my="http://marklogic.com/alerts";

import module namespace search = "http://marklogic.com/appservices/search"
    at "/MarkLogic/appservices/search/search.xqy";





(: Specific example methods for creating the search object to be saved :)

declare function ss:create-collection-search($collection as xs:string)  {
  cts:collection-query($collection)
};

(: Default search grammar :)
declare function ss:create-basic-search($query as xs:string)  {
  search:parse($query)
};

(: same as from lib-adhoc-alerts.xqy - lon/lat/radius :)
declare function ss:create-geo-near-search($ns as xs:string,$elname as xs:string, $latattr as xs:string,$lonattr as xs:string,
    $lat as xs:double,$lon as xs:double, $radiusmiles as xs:double)  {
  cts:element-geospatial-query(fn:QName($ns,$elname),cts:circle($radiusmiles, cts:point($lat, $lon)))
};








(: Search persisting functions :)

declare function ss:save-search($searchdoc, $searchname as xs:string) as xs:string {
  (: use current user on app server :)
  let $search-uri-user := fn:concat("/config/search/",xdmp:get-current-user(),"/",$searchname,".xml")
  let $l := xdmp:log($search-uri-user)
  let $result := xdmp:document-insert($search-uri-user,
    element ss:saved-search {
      attribute name {$searchname},
      attribute uri {$search-uri-user},
      $searchdoc
    }
    ,xdmp:default-permissions(),
    (xdmp:default-collections(),"saved-search")
  )
  return $search-uri-user
};

declare function ss:save-shared-search($searchdoc, $searchname as xs:string) as xs:string {
  let $search-uri-shared := fn:concat("/config/search/shared/",$searchname,".xml")
  let $result := xdmp:document-insert($search-uri-shared,
    element ss:saved-search {
      attribute name {$searchname},
      attribute uri {$search-uri-shared},
      $searchdoc
    }
    ,xdmp:default-permissions(),
    (xdmp:default-collections(),"saved-search")
  )
  return $search-uri-shared
};

declare function ss:get-saved-searches() {
  cts:search(fn:collection("saved-search"),cts:directory-query(fn:concat("/config/search/",xdmp:get-current-user(),"/"),"1"))/ss:saved-search
};

declare function ss:get-shared-searches() {
  cts:search(fn:collection("saved-search"),cts:directory-query("/config/search/shared/","1"))/ss:saved-search
};

declare function ss:delete-search($searchname) {
  let $search-uri-user := fn:concat("/config/search/",xdmp:get-current-user(),"/",$searchname,".xml")
  return xdmp:document-delete($search-uri-user)
};

declare function ss:delete-shared-search($searchname) {
  let $search-uri-shared := fn:concat("/config/search/shared/",$searchname,".xml")
  return xdmp:document-delete($search-uri-shared)
};





(: Utility functions :)

declare function ss:unsubscribe-and-delete-shared-search($searchname,$notificationurl) {
  (ss:unsubscribe($searchname,$notificationurl),ss:delete-shared-search($searchname))
};

declare function ss:unsubscribe-and-delete-search($searchname,$notificationurl) {
  (ss:unsubscribe($searchname,$notificationurl),ss:delete-search($searchname))
};

declare function ss:save-subscribe-search($searchdoc as cts:query,$searchname as xs:string,$notificationurl as xs:string,$alert-detail as xs:string?,$content-type as xs:string?) {
  (: use current user on app server :)
  ( 
    xdmp:invoke-function(
      function(){
        ss:do-save ($searchdoc, $searchname)
      }
      ,
      <options xmlns="xdmp:eval"><isolation>different-transaction</isolation></options>
    )
    ,ss:do-subscribe-check($notificationurl,$searchname,$alert-detail,$content-type)
  )
};

(: call the following from eval - different-transaction :)
declare function ss:do-save($searchdoc as cts:query,$searchname as xs:string) {
  xdmp:document-insert(fn:concat("/config/search/",xdmp:get-current-user(),"/",$searchname,".xml"),
    (:element ss:saved-search {
      attribute name {$searchname},
      (:attribute uri {$search-uri-user},:)
      $searchdoc
    }:) document {$searchdoc} (: why not just this search doc? :)
    ,xdmp:default-permissions(),
    (xdmp:default-collections(),"saved-search") )
};




(: subscription methods :)

declare function ss:subscribe($searchname as xs:string,$notificationurl as xs:string,$alert-detail as xs:string?,$content-type as xs:string?) as xs:boolean {
  ss:do-subscribe-check($notificationurl,$searchname,$alert-detail,$content-type)
};

declare function ss:unsubscribe($searchname,$notificationurl) as xs:boolean {
  (: NB supports multiple notification URLs. i.e. multiple UIs on same DB for same user :)
  ss:do-unsubscribe($notificationurl,$searchname)
};







(: internal functions - not to be called by anything outside of this module :)

(: This function intended to be called within a REST server - i.e. known DB
 : Alert detail can be 'full' or 'snippet' which means either the full doc within the alert info container, or just the snippet information within the alert info container.
 :)
declare function ss:do-subscribe-check($notificationurl as xs:string,$searchname as xs:string,$alert-detail as xs:string?,$content-type as xs:string?) as xs:boolean {
  ss:do-subscribe($notificationurl,"/modules/alert-generic-messaging.xqy",($alert-detail,"full")[1],($content-type,"application/json")[1],$searchname,"generic-alert-domain","rest-sitaware-modules",
    cts:query((fn:doc(fn:concat("/config/search/",xdmp:get-current-user(),"/",$searchname,".xml"))/element(),fn:doc(fn:concat("/config/search/shared/",$searchname,".xml"))/element())[1] )
  )
};

declare function ss:do-add-action-rule($alert-name as xs:string,$notificationurl as xs:string,$alert-module as xs:string?,$alert-detail as xs:string,$content-type as xs:string,$searchname as xs:string,$cpf-domain as xs:string,$dbname as xs:string,$searchdoc as cts:query?) as xs:boolean {

  let $e2 := xdmp:invoke-function(
    function(){
      ss:create-action($alert-name, $alert-module, $dbname, ())
    }
    ,
    <options xmlns="xdmp:eval"><isolation>different-transaction</isolation></options>
  )
  let $e3 := xdmp:invoke-function(
    function(){
      ss:create-rule-notify($alert-name, $alert-detail, $content-type, $notificationurl, $searchname, $searchdoc)
    }
    ,
    <options xmlns="xdmp:eval"><isolation>different-transaction</isolation></options>
  )
  return fn:true()
};

declare function ss:do-subscribe($notificationurl as xs:string,$alert-module as xs:string?,$alert-detail as xs:string,$content-type as xs:string,$searchname as xs:string,$cpf-domain as xs:string,$dbname as xs:string,$searchdoc as cts:query?) as xs:boolean {
  let $alert-name := xdmp:invoke-function(
    function(){
      (: WARN: this eval counterpart is invalid now:
       : ah:create-config($my:notificationurl,$my:searchname) 
       :)
      ss:create-config($notificationurl)
    }
    ,
    <options xmlns="xdmp:eval"><isolation>different-transaction</isolation></options>
  )
  
  let $e2 := ss:do-add-action-rule($alert-name,$notificationurl ,$alert-module,$alert-detail,$content-type,$searchname,$cpf-domain,$dbname,$searchdoc)
  let $e4 := xdmp:invoke-function(
    function(){
      ss:cpf-enable($alert-name,$cpf-domain)
    }
    ,
    <options xmlns="xdmp:eval"><isolation>different-transaction</isolation></options>
  )
  let $log := xdmp:log(fn:concat("SUBSCRIBE LOGS: ",$alert-name,$e2,$e4))
  return fn:true()
};

declare function ss:do-unsubscribe($notificationurl as xs:string,$searchname as xs:string) as xs:boolean {
  let $alert-name := fn:concat("/config/alerts/",xdmp:get-current-user(),"/",$searchname,"/",$notificationurl)

  let $rr :=
    for $rule in alert:get-all-rules($alert-name,cts:collection-query($alert-name))
    return
      alert:rule-remove($alert-name,$rule/@id)

  let $l := xdmp:invoke-function(
    function(){
      alert:config-set-cpf-domain-names(alert:config-get($alert-name), ())
    }
    ,
    <options xmlns="xdmp:eval"><isolation>different-transaction</isolation></options>
  )
  return fn:true()
};

declare function ss:create-rule-notify($alert-name as xs:string,$alert-detail as xs:string,$content-type as xs:string,
  $notificationurl as xs:string,$searchname as xs:string,$searchdoc as cts:query) {
    (:
  let $searchdoc := cts:search(fn:collection("saved-search"),cts:directory-query(fn:concat("/config/search/",xdmp:get-current-user(),"/"),"1"))/ss:saved-search
  let $searchdoc := if ($searchdoc) then $searchdoc else cts:search(fn:collection("saved-search"),cts:directory-query("/config/search/shared/","1"))/ss:saved-search
  :)

  ss:create-rule($alert-name,(:)$notificationurl,:) $searchdoc,(
    element notificationurl {$notificationurl},
    element searchname {$searchname},
    element detail {$alert-detail},
    element contenttype {$content-type}
  ))
};




(: GENERIC ALERTING FUNCTIONS BELOW THIS POINT :)





declare function ss:add-alert($shortname as xs:string,$query as cts:query,
  $ruleoptions as element()*,$module as xs:string,$moduledbname as xs:string?,$actionoptions as element()*) as xs:string {

  let $name := ss:do-create-config($shortname)
  let $_ := (
    ss:do-create-action($name,$module,$moduledbname,$actionoptions)
    ,
    ss:do-create-rule($name,$query,$ruleoptions)
  )
  return $name
};

declare function ss:get-alert($shortname as xs:string) as element(alert:config)? {
  alert:config-get($shortname)
};


declare function ss:do-create-config($shortname as xs:string) as xs:string {
  let $rem := ss:check-remove-config($shortname)
  return xdmp:invoke-function(
    function(){
      ss:create-config($shortname)
    }
    ,
    <options xmlns="xdmp:eval">
      <isolation>different-transaction</isolation>
      <transaction-mode>update-auto-commit</transaction-mode>
    </options>
  )
};

declare function ss:do-create-rule($alert-name as xs:string,$query as cts:query,$options as element()*) as empty-sequence() {
  xdmp:invoke-function(
    function(){
      ss:create-rule($alert-name, $query, ())
    }
    ,
    <options xmlns="xdmp:eval">
      <isolation>different-transaction</isolation>
      <transaction-mode>update-auto-commit</transaction-mode>
    </options>
  )
};

declare function ss:do-create-action($alert-name as xs:string,$alert-module as xs:string,$dbname as xs:string?,$options as element()*) {
  xdmp:invoke-function(
    function(){
      ss:create-action($alert-name, $alert-module, $dbname, $options)
    }
    ,
    <options xmlns="xdmp:eval">
      <isolation>different-transaction</isolation>
      <transaction-mode>update-auto-commit</transaction-mode>
    </options>
  )
};

declare function ss:check-remove-config($shortname as xs:string) {
  let $alert-name := "/config/alerts/" || $shortname
  let $config := xdmp:invoke-function(
    function(){
      alert:config-get($alert-name)
    }
    ,
    <options xmlns="xdmp:eval"><isolation>different-transaction</isolation></options>
  )
  return
    if (fn:not(fn:empty($config))) then
      (: Check if config used in a cpf domain, if so remove it from that domain :)
      let $unreg := xdmp:invoke-function(
        function(){
          alert:config-insert(
            alert:config-set-cpf-domain-names(alert:config-get($alert-name),())
          )
        }
        ,
        <options xmlns="xdmp:eval">
          <isolation>different-transaction</isolation>
          <transaction-mode>update-auto-commit</transaction-mode>
        </options>
      )
      (: Do this for each domain - NA all done in one hit:)
      (: Now remove the alert config :)
      return xdmp:invoke-function(
        function(){
          alert:config-delete($alert-name)
        }
        ,
        <options xmlns="xdmp:eval">
          <isolation>different-transaction</isolation>
          <transaction-mode>update-auto-commit</transaction-mode>
        </options>
      )
    else ()
};

declare function ss:create-config($shortname as xs:string) as xs:string {
  (: add alert :)
  let $alert-name := "/config/alerts/" || $shortname
  let $config := alert:make-config(
        $alert-name,
        $alert-name || " configuration",
        $alert-name || " configuration",
          <alert:options></alert:options> )
  let $config-out := alert:config-insert($config)
  return $alert-name
};

declare function ss:create-rule($alert-name as xs:string,$query as cts:query,$options as element()*) as empty-sequence() {

  let $rule := alert:make-rule(
      fn:concat($alert-name,"-rule"),
      $alert-name || " rule",
      0, (: equivalent to xdmp:user(xdmp:get-current-user()) :)
      $query,
      fn:concat($alert-name,"-action"),
      <alert:options>
        {
          $options
        }
      </alert:options> )
  return alert:rule-insert($alert-name, $rule)
};

declare function ss:create-action($alert-name as xs:string,$alert-module as xs:string,$dbname as xs:string?,$options as element()*) {
  let $action := alert:make-action(
      fn:concat($alert-name,"-action"),
      $alert-name || " action",
      (xdmp:database($dbname),xdmp:modules-database())[1],
      "/",
      $alert-module,
      <alert:options>{$options}</alert:options> )
  return alert:action-insert($alert-name, $action)
};





declare function ss:cpf-enable($alert-name as xs:string,$cpf-domain as xs:string) {
  alert:config-insert(
    alert:config-set-cpf-domain-names(
      alert:config-get($alert-name),
      ($cpf-domain)))
};

declare function ss:create-domain($domainname as xs:string,$domaintype as xs:string,$domainpath as xs:string,$domaindepth as xs:string,$pipeline-names as xs:string*,$modulesdb as xs:string) as xs:unsignedLong {

    (: check if domain already exists and recreate :)
    let $remove :=
      try {
        if (fn:not(fn:empty(
          xdmp:invoke-function(
            function(){
              dom:get($domainname)
            }
            ,
            <options xmlns="xdmp:eval">
              <database>{xdmp:triggers-database()}</database>
              <isolation>different-transaction</isolation>
            </options>
          )
        ))) then
          let $_ := xdmp:log(" GOT DOMAIN TO REMOVE")
          return 
            xdmp:invoke-function(
              function(){
                dom:remove($domainname)
              }
              ,
              <options xmlns="xdmp:eval">
                <database>{xdmp:triggers-database()}</database>
                <isolation>different-transaction</isolation>
                <transaction-mode>update-auto-commit</transaction-mode>
              </options>
            )
        else
          ()
      } catch ($e) { ( xdmp:log("Error trying to remove domain: " || $domainname),xdmp:log($e) ) } (: catching domain throwing error if it doesn't exist. We can safely ignore this :)


       (: Create domain :)

         (: Configure domain :)
    return
      xdmp:invoke-function(
        function(){
          let $pids := (xs:unsignedLong(p:pipelines()[p:pipeline-name = "Status Change Handling"]/p:pipeline-id),xs:unsignedLong(p:pipelines()[p:pipeline-name = $pipeline-names[2]]/p:pipeline-id))
          let $_ := xdmp:log("second point")
          let $ds := dom:domain-scope($domaintype, $domainpath, $domaindepth) 
          let $_ := xdmp:log("third point")
          let $ec := dom:evaluation-context(xdmp:database($modulesdb),"/")
          let $_ := xdmp:log("fourth point")
          let $dc := dom:create($domainname,"Domain for "||$domainname,
            $ds,$ec,$pids,())
          let $_ := xdmp:log("fifth point")
          return $dc
        }
        ,
        <options xmlns="xdmp:eval">
          <database>{xdmp:triggers-database()}</database>
          <transaction-mode>update-auto-commit</transaction-mode>
          <isolation>different-transaction</isolation>
        </options>
      )
};
