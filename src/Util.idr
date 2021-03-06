module Util

import Language.Reflection.TT
import Language.Reflection.TTImp

-- %language PostfixProjections

infixl 1 <&>
export
(<&>) : Functor f => f a -> (a -> b) -> f b
x <&> f = f <$> x

infixl 4 <$,$>

-- For when Lazy is causing type problems
infixr 4 &&|
export
(&&|) : Bool -> Bool -> Bool
(&&|) x y = x && y

export
zipWithSL : (a -> b -> c) -> Stream a -> List b -> List c
zipWithSL _ _ [] = []
zipWithSL f (x :: xs) (y :: ys) = f x y :: zipWithSL f xs ys

export
zipWithLS : (a -> b -> c) -> List a -> Stream b -> List c
zipWithLS _ [] _ = []
zipWithLS f (x :: xs) (y :: ys) = f x y :: zipWithLS f xs ys

export
%inline
zipSL : Stream a -> List b -> List (a,b)
zipSL = zipWithSL MkPair

export
%inline
zipLS : List a -> Stream b -> List (a,b)
zipLS = zipWithLS MkPair

export
catMaybes : List (Maybe a) -> List a
catMaybes z = foldr (\m,f => maybe f (\x => (x ::) . f) m) id z []

export
unzip : List (a,b) -> (List a, List b)
unzip = foldr (\(x,y),(xs,ys) => (x :: xs, y :: ys)) ([],[])

-- This is hiiiiiideously slow! maybe it's because I'm using it at elab-time
export
unzip3 : List (a,b,c) -> (List a, List b, List c)
unzip3 [] = ([],[],[])
unzip3 ((x, (y, z)) :: ls) = let (xs,ys,zs) = unzip3 ls
                             in (x :: xs, y:: ys, z :: zs)


export
isJust : Maybe a -> Bool
isJust (Just _ ) = True
isJust _ = False

export
unless : Applicative f => Bool -> Lazy (f ()) -> f ()
unless b act = if b then pure () else act

infixr 4 &&.
export
(&&) : (a -> Bool) -> Lazy (a -> Bool) -> a -> Bool
(&&) x y = \a => Prelude.(&&) (x a) (y a)


-- useful for working with TypeInfo cons without having a type just for that
-- Really we should just give cons its own type.
export
one : (a,b,c) -> a
one (x, (y, z)) = x

export
two : (a,b,c) -> b
two (x, (y, z)) = y

export
three : (a,b,c) -> c
three (x, (y, z)) = z

export
Range Char where
  rangeFromTo x y = map cast [cast x .. cast y] {a=Int}
  rangeFromThenTo x y z = map cast [cast x, cast y .. cast z] {a=Int}
  rangeFrom x = map cast [cast x ..] {a=Int}
  rangeFromThen x y = map cast [cast x, cast y..] {a=Int}
