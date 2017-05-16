xquery version "1.0-ml";

module namespace stack="http://marklogic.com/stack";

declare function stack:push($map as map:map,$obj as item()) as empty-sequence() {
  map:put($map,xs:string(map:count($map) + 1),$obj)
};

declare function stack:peek($map as map:map) {
  map:get($map,xs:string(map:count($map)))
};

declare function stack:previous($map as map:map) {
  map:get($map,xs:string(map:count($map) - 1))
};

declare function stack:pop($map as map:map) {
  let $count := xs:string(map:count($map))
  let $item := map:get($map,$count)
  let $remove := map:delete($map,$count)
  return $item
};

declare function stack:count($map as map:map) as xs:unsignedInt {
  map:count($map)
};
