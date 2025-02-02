(:~ 
 : Conveniences for assembling SVRL output. 
 :)
module namespace output = 'http://www.andrewsales.com/ns/xqs-output';

declare namespace sch = "http://purl.oclc.org/dsdl/schematron";
declare namespace svrl = "http://purl.oclc.org/dsdl/svrl";

declare function output:schema-title($title as element(sch:title)?)
as attribute(title)?
{
  if($title) then attribute{'title'}{$title} else ()
};

declare function output:namespace-decls-as-svrl($nss as element(sch:ns)*)
as element(svrl:ns-prefix-in-attribute-values)*
{
  for $ns in $nss 
  return 
  <svrl:ns-prefix-in-attribute-values>
  {$ns/@prefix, $ns/@uri}
  </svrl:ns-prefix-in-attribute-values>
};

(:~ Outputs a failed-assert or successful-report element. :)
declare function output:assertion-message(
  $assertion as element(),
  $prolog as xs:string?,
  $rule-context as node(),
  $context as map(*)
)
{
  element{
    QName("http://purl.oclc.org/dsdl/svrl", 
    if($assertion/self::sch:assert) then 'failed-assert' else 'successful-report')}
    {
      attribute{'location'}{path($rule-context)},
      $assertion/(@id, @role, @flag, @test),
      output:diagnostics(
        $context?diagnostics[@id = tokenize($assertion/@diagnostics)],
        $prolog,
        $rule-context,
        $context
      ),
      output:properties(
        $context?properties[@id = tokenize($assertion/@properties)],
        $prolog,
        $rule-context,
        $context
      ),
      output:assertion-message-content(
        $assertion/node(), 
        $prolog, 
        $rule-context,
        $context
      )
    }
};

(:~ Transforms SCH namespace to SVRL. (Not attempting to address inconsistencies
 : between schema and SVRL elements and attributes.)
 :)
declare function output:assertion-child-elements($element as element())
as element()
{
  element{QName("http://purl.oclc.org/dsdl/svrl", local-name($element))}
  {$element/@*, $element/node()}
};

declare function output:diagnostics(
  $diagnostics as element(sch:diagnostic)*,
  $prolog as xs:string?,
  $rule-context as node(),
  $context as map(*)
)
as element(svrl:diagnostic-reference)*
{
  $diagnostics ! 
  <svrl:diagnostic-reference diagnostic='{@id}'>
  {output:assertion-message-content(node(), $prolog, $rule-context, $context)}
  </svrl:diagnostic-reference>
};

declare function output:properties(
  $properties as element(sch:property)*,
  $prolog as xs:string?,
  $rule-context as node(),
  $context as map(*)
)
as element(svrl:property-reference)*
{
  $properties ! 
  <svrl:property-reference property='{@id}'>
  {@role, @scheme, 
  output:assertion-message-content(node(), $prolog, $rule-context, $context)}
  </svrl:property-reference>
};

(:~ Outputs svrl:text, which corresponds to the model <code>human-text</code>
 : in the SVRL schema.
 : @see ISO2020, Annex D
 :)
declare function output:assertion-message-content(
  $content as node()*,
  $prolog as xs:string?,
  $rule-context as node(),
  $context as map(*)
)
{
  <svrl:text>{(:TODO attributes:)
  for $node in $content
    return
    typeswitch($node)
      case element(sch:name)
        return if($node/@path) 
          then xquery:eval(
            $prolog || $node/@path, 
            map:merge((map{'':$rule-context}, $context?globals))
          ) 
          else name($rule-context)
      case element(sch:value-of)
        return xquery:eval(
          $prolog || $node/@select, 
          map:merge((map{'':$rule-context}, $context?globals))
        ) 
        => string()
      case element(sch:emph)
        return output:assertion-child-elements($node)
      case element(sch:dir)
        return output:assertion-child-elements($node)
      case element(sch:span)
        return output:assertion-child-elements($node)      
    default return $node
  }</svrl:text>
};