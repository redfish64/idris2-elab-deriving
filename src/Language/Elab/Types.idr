module Language.Elab.Types

import Language.Elab.Syntax

import Language.Reflection
import Data.SortedSet

import Util

%language ElabReflection

-- Helper types for deriving cleaner


-- traverseE beats the shit out of traverse for Elab for compile-time work
-- I'm not sure why, as giving traverse a more specific type alone doens't help,
-- I think maybe it's just that we're not using concatMap
export
traverseE : (a -> Elab b) -> List a -> Elab (List b)
traverseE f [] = pure []
traverseE f (x :: xs) = f x >>= \b => (b ::) <$> traverseE f xs


-- not exactly stable
public export -- setting this to private breaks SortedSet
Ord Name where
  compare n1 n2 = compare (extractNameStr n1) (extractNameStr n2)

data MyNat' : Type where
  MZ' : MyNat'
  MS' : MyNat' -> MyNat'

-- data Foo6' : Type -> Type -> Type -> MyNat -> Type where
--   Zor6'  : a -> b -> Foo6' a b c MZ
--   Gor6'  : b -> Foo6' a b c (MS k)
--   Nor6A' : a -> b -> c -> Foo6' a b c n
--   Nor6B' : a -> (0 _ : b) -> c -> Foo6' a b c n
--   Bor6'  : Foo6' a b c n
--   Wah6'  : a -> (n : MyNat) -> Foo6' a b c n
--   Kah6'  : a -> (n : MyNat) -> (0 _ : c) -> Foo6' a b c n
--   Pah6'  : a -> (n : MyNat) -> MyNat -> (0 _ : c) -> Foo6' a b c n
--   Gah6'  : {1 _ : a} -> (n : MyNat) -> MyNat -> (0 _ : c) -> Foo6' a b c n
--   Hah6'  : {1 _ : a} -> (n : MyNat) -> MyNat -> (0 _ : c) -> Foo6' a b a n

-- data Foo5 : Type -> Type -> Type -> Type where
--   Bor5 : a -> b -> c -> Foo5 a b c


-- A argument to a constructor along with additional relation data like its
-- position in the type it came from
public export
record ArgInfo where
  constructor MkArgInfo
  count  : Count
  piInfo : PiInfo TTImp
  name   : Name
  type   : TTImp
  isIndex : Bool -- as in not a parameter, Nat is an index in MkFoo : Foo a Z
  --------------
  -- meta : Maybe MetaArgInfo
  -- position : Nat
  -- Do I need the position if I can establish it's an index anyway?

export
Show ArgInfo where
  show (MkArgInfo count piInfo name type ind)
    = "MkArgInfo " ++ show count ++ " " ++ show piInfo ++ " " ++ showPrec App name ++ " " ++ "tyttimp " ++ show ind

-- Fully qualified Name
-- `type` is our fully applied type, e.g. given args a,b,c: Foo a b c
public export
record TypeInfo where
  constructor MkTypeInfo
  name : Name
  args : List ArgInfo
  cons : List (Name, List ArgInfo, TTImp)
  type : TTImp

-- An index has its name in the return type and is not a basic %type

-- Why why why is this so much of a fucking hog!? I'm not even reflecting!

-- This seems to be pretty slow, not sure why
infix 8 `indexOf`
private
total
indexOf : Name -> TTImp -> Bool
indexOf n1 (IVar _ n2) = n1 == n2
indexOf l (IApp _ z w) = indexOf l z || indexOf l w
indexOf _ _ = False

-- workhorse of the module, though you'll tend to use it through makeTypeInfo
-- If an argument doesn't have a name we generate one for it, this simplifies
-- use of names. TODO: revisit this decision
export
getConType : Name -> Elab (List ArgInfo, TTImp)
getConType qn = do
    (arginfos,retty) <- go (snd !(lookupName qn))
    pure $ (arginfos,retty)
  where
    go : TTImp -> Elab (List ArgInfo, TTImp)
    go (IPi _ c i n0 argTy retTy0) = do
      (xs,retTy1) <- go retTy0
      let n1 = maybe !(readableGenSym "arg") id n0
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

-- not bad start, we might try not renaming here, make names at use-site?
export
makeTypeInfo : Name -> Elab TypeInfo
makeTypeInfo n = do
  (tyname,tyimp) <- lookupName n
  args <- genArgs n
  connames <- getCons tyname
  conlist <- traverse getConType connames
  let tyargs = filter (isExplicitPi . piInfo) args
      ty = appTyCon (map (\arg => extractNameStr  arg.name) tyargs) tyname
  pure $ MkTypeInfo n args (zip connames conlist) ty




-----------------------------
-- Testing Area
-----------------------------

-- data FooN' : MyNat' -> Type -> Type where
--   BorZ' : b -> FooN' MZ' b
--   BorS' : b -> FooN' (MS' MZ') b
--   BorNA' : (k : MyNat') -> b -> FooN' MZ' b -- n is index
--   BorNB' : (k : MyNat') -> b -> FooN' j b
--   BorNC' : (k : MyNat') -> b -> FooN' (MS' k) b -- k is index, and arg 1
--   BorND' : (k : MyNat') -> b -> FooN' k b -- k is index and arg 1
-- 
-- 
-- -- Time making this is directly related to arg count
-- -- what the fuck why, why does this loop
-- data Foo6 : Type -> Type -> Type -> Nat -> Type where
--   Zor6 : a -> b -> Foo6 a b c Z
--   Gor6 : b -> Foo6 a b c (S k)
--   Nor6A : a -> b -> c -> c -> c -> c -> (n : Nat) -> Foo6 a b c n
--   Nor6B : a -> (0 _ : b) -> c -> Foo6 a b c n -- NB: 0 Use arg
--   Bor6 : Foo6 a b c n
--   Wah6 : a -> (n : Nat) -> Foo6 a b c n
-- 
-- export
-- data Foo2 : Type -> Type where
--   Bor2 : a -> Foo2 a
--   -- Bor2 : a -> Foo2 a

faf : Name -> Elab ()
faf n = do
  tyinfo <- makeTypeInfo n
  -- nested traverse seems real slow
  let conargs = pullExplicits tyinfo
  let params = map (extractNameStr . name) $ filter (not . isIndex) conargs
  let params' = map (extractNameStr . name) $ conargs
  logMsg 1 "indexes"
  traverseE (\(n,a,imp) => traverseE (logMsg 1 . show) . filter (isIndex) $ a) tyinfo.cons
  logMsg 1 $ show params
  logMsg 1 $ show params'

  -- traverseE (\(n,a,imp) => traverseE (logMsg 1 . show) $ a) tyinfo.cons
  -- traverseE (\(n,a,imp) => traverseE (logMsg 1 . show) $ a) tyinfo.cons
  pure ()

-- %runElab faf `{{Foo6}}

-- I need a minimal example of reflected OrderedSet failing
-- I also need to see if Elab, or Reflect/Reify, is left biased