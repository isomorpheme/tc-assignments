module CSharpGram where

import Data.Maybe

import ParseLib.Abstract hiding (braced, bracketed, parenthesised, (<$), (*>), (<*))
import CSharpLex


data Class = Class Token [Member]
    deriving Show

data Member = MemberD Decl
            | MemberM Type Token [Decl] Stat
            deriving Show

data Stat = StatDecl   Decl
          | StatExpr   Expr
          | StatIf     Expr Stat Stat
          | StatWhile  Expr Stat
          | StatReturn Expr
          | StatBlock  [Stat]
          deriving Show

data Expr = ExprConst  Token
          | ExprVar    Token
          | ExprOper   Token Expr Expr
          | ExprCall   Token [Expr]
          deriving Show

data Decl = Decl Type Token
    deriving Show

data Type = TypeVoid
          | TypePrim  Token
          | TypeObj   Token
          | TypeArray Type
          deriving (Eq,Show)


parenthesised p = pack (symbol POpen) p (symbol PClose)
bracketed     p = pack (symbol SOpen) p (symbol SClose)
braced        p = pack (symbol COpen) p (symbol CClose)

pExprSimple :: Parser Token Expr
pExprSimple =  ExprConst <$> sConst
           <|> ExprVar   <$> sLowerId
           <|> pExprCall
           <|> pAdjustOne
           <|> parenthesised pExpr

pExprCall :: Parser Token Expr
pExprCall = ExprCall
    <$> sLowerId
    <*> parenthesised (listOf pExpr (symbol Comma) <|> succeed [])

pAdjustOne :: Parser Token Expr
pAdjustOne =  (adjust "+") <$> sLowerId <* symbol (Operator "++")
          <|> (adjust "-") <$> sLowerId <* symbol (Operator "--")
    where
        adjust op var =
            ExprOper (Operator "=") var' (ExprOper op' var' (ExprConst (ConstInt 1)))
            where
                var' = ExprVar var
                op' = Operator op

pExpr :: Parser Token Expr
pExpr = pOpers priorities
    where
        priorities = map (map Operator)
            [ ["=", "+=", "-=", "*=", "/=", "%=", "|=", "&=", "^="]
            , ["||"]
            , ["&&"]
            , ["==", "!="]
            , ["^"]
            , ["<", ">", "<=", ">="]
            , ["+", "-"]
            , ["*", "/", "%"]
            ]

pOpers :: [[Token]] -> Parser Token Expr
pOpers (ops:rest) =
    chainl (pOpers rest) (ExprOper <$> satisfy (`elem` ops))
pOpers [] =
    pExprSimple

pMember :: Parser Token Member
pMember =  MemberD <$> pDeclSemi
       <|> pMeth

pStatDecl :: Parser Token Stat
pStatDecl =  pStat
         <|> StatDecl <$> pDeclSemi

pStat :: Parser Token Stat
pStat =  StatExpr <$> pExpr <*  sSemi
     <|> StatIf     <$ symbol KeyIf     <*> parenthesised pExpr <*> pStat <*> optionalElse
     <|> StatWhile  <$ symbol KeyWhile  <*> parenthesised pExpr <*> pStat
     <|> pFor
     <|> StatReturn <$ symbol KeyReturn <*> pExpr               <*  sSemi
     <|> pBlock
     where optionalElse = option ((\_ x -> x) <$> symbol KeyElse <*> pStat) (StatBlock [])


pBlock :: Parser Token Stat
pBlock = StatBlock <$> braced (many pStatDecl)


pMeth :: Parser Token Member
pMeth = MemberM <$> methRetType <*> sLowerId <*> methArgList <*> pBlock
    where
        methRetType = pType <|> (const TypeVoid <$> symbol KeyVoid)
        methArgList = parenthesised (option (listOf pDecl (symbol Comma)) [])

pType0 :: Parser Token Type
pType0 =  TypePrim <$> sStdType
      <|> TypeObj  <$> sUpperId

pType :: Parser Token Type
pType = foldr (const TypeArray) <$> pType0 <*> many (bracketed (succeed ()))


pDecl :: Parser Token Decl
pDecl = Decl <$> pType <*> sLowerId

pDeclSemi :: Parser Token Decl
pDeclSemi = pDecl <* sSemi

pClass :: Parser Token Class
pClass = Class <$ symbol KeyClass <*> sUpperId <*> braced (many pMember)

pFor :: Parser Token Stat
pFor = forToWhile <$ symbol KeyFor <*> 
    parenthesised 
        ((,,) 
        <$> optional pDecl <* sSemi 
        <*> optional pExpr <* sSemi 
        <*> optional pExpr
        ) <*> pStat
    where
        forToWhile (init, condition, inc) body = 
            StatBlock $ addInit [StatWhile checkCondition body']
            where
                addInit = maybe id ((:) . StatDecl) init
                checkCondition = fromMaybe (ExprConst (ConstBool True)) condition
                body' = StatBlock (body : maybeToList (StatExpr <$> inc))