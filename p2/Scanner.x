{
module Scanner (Token, scan) where
}

%wrapper "basic"

$alphanum = [A-Za-z0-9]

tokens :-
    $white+     ;
    "--".*      ;
    "->"        { const RuleDef }
    "."         { const RuleEnd }
    ","         { const CmdSep }
    ";"         { const AltSep }
    go | take | mark | nothing
       | turn
       | case | of | end
                { Keyword }
    left | right | front
                { Direction }
    Empty | Lambda | Debris | Asteroid | Boundary | "_"
                { Pattern }
    [ $alphanum \+ \- ]+
                { Ident }
{
data Token
    = Def
    | End
    | CmdSep
    | AltSep
    | Keyword String
    | Direction String
    | Pattern String
    | Ident String
    deriving (Eq, Show)

scan = alexScanTokens
}
