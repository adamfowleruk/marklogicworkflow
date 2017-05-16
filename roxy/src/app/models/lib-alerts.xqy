xquery version "1.0-ml";

module namespace ss = "http://marklogic.com/alerts/alerts";

import module namespace alert="http://marklogic.com/xdmp/alert" at "/MarkLogic/alert.xqy";

declare namespace my="http://marklogic.com/alerts";


declare function ss:add-alert($shortname as xs:string,$query as schema-element(cts:query),
  $ruleoptions as element()*,$module as xs:string,$moduledb as xs:unsignedLong,$actionoptions as element()*) as xs:string {

  let $name := ss:do-create-config($shortname)
  return
    (
      ss:do-create-rule($name,$query,$ruleoptions),
      ss:do-create-action($name,$module,$moduledb,$actionoptions),
      $name
    )
};


declare function ss:do-create-config($shortname as xs:string) as xs:string {
  xdmp:eval(
    'xquery version "1.0-ml"; declare namespace my="http://marklogic.com/alerts"; ' ||
    'import module namespace ah = "http://marklogic.com/alerts/alerts" at "/app/models/lib-alerts.xqy";' ||
    'import module namespace alert="http://marklogic.com/xdmp/alert" at "/MarkLogic/alert.xqy";' ||
    'declare variable $my:shortname as xs:string external;' ||
    'ah:create-config($my:shortname)',
    (xs:QName("my:shortname"),$shortname),
    <options xmlns="xdmp:eval"><isolation>different-transaction</isolation></options>
  )
};

declare function ss:do-create-rule($alert-name as xs:string,$query as cts:query,$options as element()*) {
  xdmp:eval(
    'xquery version "1.0-ml"; declare namespace my="http://marklogic.com/alerts"; ' ||
    'import module namespace ah = "http://marklogic.com/alerts/alerts" at "/app/models/lib-alerts.xqy";' ||
    'import module namespace alert="http://marklogic.com/xdmp/alert" at "/MarkLogic/alert.xqy";' ||
    'declare variable $my:alert-name as xs:string external;' ||
    'declare variable $my:query as cts:query external;' ||
    'declare variable $my:options as element* external;' ||
    'ah:create-rule($my:alert-name,$my:query,$my:options)',
    (xs:QName("my:alert-name"),$alert-name,xs:QName("my:query"),$query,xs:QName("my:options"),$options),
    <options xmlns="xdmp:eval"><isolation>different-transaction</isolation></options>
  )
};

declare function ss:do-create-action($alert-name as xs:string,$alert-module as xs:string,$db as xs:unsignedLong,$options as element()*) {
  xdmp:eval(
    'xquery version "1.0-ml"; declare namespace my="http://marklogic.com/alerts"; ' ||
    'import module namespace ah = "http://marklogic.com/alerts/alerts" at "/app/models/lib-alerts.xqy";' ||
    'import module namespace alert="http://marklogic.com/xdmp/alert" at "/MarkLogic/alert.xqy";' ||
    'declare variable $my:alert-name as xs:string external;' ||
    'declare variable $my:alert-module as xs:string external;' ||
    'declare variable $my:db as xs:unsignedLong external;' ||
    'declare variable $my:options as element* external;' ||
    'ah:create-action($my:alert-name,$my:alert-module,$my:db,$my:options)',
    (xs:QName("my:alert-name"),$alert-name,xs:QName("my:alert-module"),$alert-module,xs:QName("my:db"),$db,xs:QName("my:options"),$options),
    <options xmlns="xdmp:eval"><isolation>different-transaction</isolation></options>
  )
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

declare function ss:create-rule($alert-name as xs:string,$query as cts:query,$options as element()*) {

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

declare function ss:create-action($alert-name as xs:string,$alert-module as xs:string,$db as xs:string,$options as element()*) {
  let $action := alert:make-action(
      fn:concat($alert-name,"-action"),
      $alert-name || " action",
      $db,
      "/",
      $alert-module,
      <alert:options>{$options}</alert:options> )
  return alert:action-insert($alert-name, $action)
};
