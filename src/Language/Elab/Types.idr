module Language.Elab.Types

import Language.Elab.Syntax

import Language.Reflection

import Util

%language ElabReflection

-- Helper types for deriving more cleanly

-- traverseE beats the shit out of traverse for Elab for compile-time work
-- I'm not sure why, as giving traverse a more specific type alone doens't help,
-- I think maybe it's just that we're not using concatMap
export
-- %inline
traverseE : (a -> Elab b) -> List a -> Elab (List b)
traverseE f [] = pure []
traverseE f (x :: xs) = f x >>= \b => (b ::) <$> traverseE f xs

export
-- %inline
forE : List a -> (a -> Elab b) -> Elab (List b)
forE xs f = traverseE f xs


-- A argument to a constructor along with additional relation data like whether it's an index of the type
public export
record ArgInfo where
  constructor MkArgInfo
  count  : Count
  piInfo : PiInfo TTImp
  name   : Name
  type   : TTImp
  isIndex : Bool -- as in not a parameter
  -- An index has its name in the return type and is not a basic %type
  -- Nat is an index in MkFoo : Foo a Z
  -- (n : Nat) is an index in Foo a n
  --------------
  -- meta : Maybe MetaArgInfo
  -- position : Nat
  -- Do I need the position if I can establish it's an index anyway?

export
Show ArgInfo where
  show (MkArgInfo count piInfo name type ind)
    = "MkArgInfo " ++ show count ++ " " ++ show piInfo ++ " " ++ showPrec App name ++ " " ++ "tyttimp " ++ show ind

export
logArgInfo : Nat -> ArgInfo -> Elab ()
logArgInfo n (MkArgInfo count piInfo name type isIndex) = do
  logMsg n $ "MkArgInfo " ++ show count ++ " " ++ show piInfo ++ " " ++ showPrec App name
  logTerm n "argimp: " type

-- Fully qualified Name
-- `type` is our fully applied type, e.g. given args a,b,c: Foo a b c
public export
record TypeInfo where
  constructor MkTypeInfo
  name : Name
  args : List ArgInfo
  cons : List (Name, List ArgInfo, TTImp)
  type : TTImp


-- This seems to be fairly slow, not sure why
infix 8 `indexOf`
private
total
indexOf : Name -> TTImp -> Bool
indexOf n1 (IVar _ n2) = n1 == n2
indexOf l (IApp _ z w) = indexOf l z || indexOf l w
indexOf _ _ = False

-- workhorse of the module, though you'll tend to use it through makeTypeInfo
-- If an argument doesn't have a name we generate one for it, this simplifies
-- use of names. That being said idris (with PR 337) should have already
-- generated names for everything so this shouldn't come up often.
-- TODO: revisit this decision
export
getConType : Name -> Elab (List ArgInfo, TTImp)
getConType qn = go (snd !(lookupName qn))
  where
    go : TTImp -> Elab (List ArgInfo, TTImp)
    go (IPi _ c i n0 argTy retTy0) = do
      (xs,retTy1) <- go retTy0
      let n1 = maybe !(genSym "arg") id n0
      logMsg 1 "compute"
      let b = not (isType argTy) && maybe False (`indexOf`retTy1) n0
      pure $ (MkArgInfo c i n1 argTy b :: xs, retTy1)
    go retTy = pure ([],retTy)

-- makes them unique for now
export
genArgs : Name -> Elab (List ArgInfo)
genArgs qn = do (_,tyimp) <- lookupName qn
                go tyimp
  where
    go : TTImp -> Elab (List ArgInfo)
    go (IPi _ c i n argTy retTy)
      = let isIndex = not (isType argTy) -- && isExplicitPi i
        in [| pure (MkArgInfo c i !(readableGenSym "arg") argTy isIndex) :: go retTy |]
    go _ = pure []


-- TODO try making this explicitly to reduce quoting
-- Takes String so that you can process the names as you like
-- NB: Likely to change
export
appTyCon : List String -> Name -> TTImp
appTyCon ns n = foldl (\tt,v => `( ~(tt) ~(iBindVar v) )) (iVar n) ns

export
pullExplicits : TypeInfo -> List ArgInfo
pullExplicits x = filter (isExplicitPi . piInfo) (args x)

export
pullImplicits : TypeInfo -> List ArgInfo
pullImplicits x = filter (isImplicitPi . piInfo) (args x)

argnam : ArgInfo -> Name
argnam (MkArgInfo count piInfo name type isIndex) = name

-- not bad start, we might try not renaming here, make names at use-site?
export
makeTypeInfo : Name -> Elab TypeInfo
makeTypeInfo n = do
  (tyname,tyimp) <- lookupName n
  args <- genArgs n
  connames <- getCons tyname
  conlist <- traverse getConType connames
  logMsg 1 "I'm being computed"
  let tyargs = filter (isExplicitPi . piInfo) args
      ty = appTyCon (map (\arg => extractNameStr  arg.name) tyargs) tyname
  pure $ MkTypeInfo tyname args (zip connames conlist) ty



-----------------------------
-- Testing Area
-----------------------------
-- {-
data MyNat' : Type where
  MZ' : MyNat'
  MS' : MyNat' -> MyNat'

-- Time making this is directly related to arg count
data Foo6'' : Type -> Type -> Type -> Nat -> Type where
  Zor6'' : a -> b -> Foo6'' a b c Z
  Gor6'' : b -> Foo6'' a b c (S k)
  Nor6A'' : a -> b -> c -> c -> c -> c -> (n : Nat) -> Foo6'' a b c n
  Nor6B'' : a -> (0 _ : b) -> c -> Foo6'' a b c n -- NB: 0 Use arg
  Bor6'' : Foo6'' a b c n
  Wah6'' : a -> (n : Nat) -> Foo6'' a b c n

-- This is an issue because elaboration on datatypes requires many traverersals,
-- of the types, the constructors, building up results etc.
-- logMsg is set to 12 because we're not interested in executing it, it's just
-- an easy placeholder
faf : Elab ()
faf = do
  -- Each additional line is exponentially slower than the last
  -- this happens with a simpler line like
  -- traverse (logMsg 12 . show) [the Int 1..10]
  -- but these double traversals take less lines to demonstrate it.
  traverse (traverse (logMsg 12 . show)) [[the Int 1..10]] -- minor difference
  traverse (traverse (logMsg 12 . show)) [[the Int 1..10]] -- minor difference
  traverse (traverse (logMsg 12 . show)) [[the Int 1..10]] -- minor difference
  traverse (traverse (logMsg 12 . show)) [[the Int 1..10]] -- minor difference
  traverse (traverse (logMsg 12 . show)) [[the Int 1..10]] -- minor difference
  traverse (traverse (logMsg 12 . show)) [[the Int 1..10]] -- minor difference
  traverse (traverse (logMsg 12 . show)) [[the Int 1..10]] -- 0.3s
  traverse (traverse (logMsg 12 . show)) [[the Int 1..10]] -- 0.4s
  traverse (traverse (logMsg 12 . show)) [[the Int 1..10]] -- 0.5s
  
  -- Traversal time appreciatbly accelerates
  traverse (traverse (logMsg 12 . show)) [[the Int 1..10]] -- 1.5s
  traverse (traverse (logMsg 12 . show)) [[the Int 1..10]] -- 4s
  traverse (traverse (logMsg 12 . show)) [[the Int 1..10]] -- 13s
  
  -- Gets out of hand here
  -- traverse (traverse (logMsg 12 . show)) [[the Int 1..10]]
  
  pure ()
  
%runElab faf
 
-- possible clock error
-- logtimerecord' should accrue but logtime should not
  

-- I need a minimal example of reflected OrderedSet failing
-- I also need to see if Elab, or Reflect/Reify, is left biased
-- -}
