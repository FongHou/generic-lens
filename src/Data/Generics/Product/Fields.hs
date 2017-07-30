{-# LANGUAGE AllowAmbiguousTypes    #-}
{-# LANGUAGE DataKinds              #-}
{-# LANGUAGE FlexibleInstances      #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE KindSignatures         #-}
{-# LANGUAGE MultiParamTypeClasses  #-}
{-# LANGUAGE ScopedTypeVariables    #-}
{-# LANGUAGE TypeApplications       #-}
{-# LANGUAGE TypeFamilies           #-}
{-# LANGUAGE TypeOperators          #-}
{-# LANGUAGE UndecidableInstances   #-}

-----------------------------------------------------------------------------
-- |
-- Module      :  Data.Generics.Record.HasField
-- Copyright   :  (C) 2017 Csongor Kiss
-- License     :  BSD3
-- Maintainer  :  Csongor Kiss <kiss.csongor.kiss@gmail.com>
-- Stability   :  experimental
-- Portability :  non-portable
--
-- Derive record field getters and setters generically.
--
-----------------------------------------------------------------------------

module Data.Generics.Product.Fields
  ( -- *Lenses

    --  $example
    HasField (..)

    -- *Internals
  , GHasField (..)
  ) where

import Data.Generics.Internal.Families
import Data.Generics.Internal.Lens

import Data.Kind    (Constraint, Type)
import GHC.Generics
import GHC.TypeLits

--  $example
--  @
--    module Example where
--
--    import Data.Generics.Product
--    import GHC.Generics
--
--    data Human = Human
--      { name    :: String
--      , age     :: Int
--      , address :: String
--      }
--      deriving (Generic, Show)
--
--    human :: Human
--    human = Human \"Tunyasz\" 50 \"London\"
--  @

--  | Records that have a field with a given name.
class HasField (field :: Symbol) a s | s field -> a where
  -- |A lens that focuses on a field with a given name. Compatible with the
  --  lens package's 'Control.Lens.Lens' type.
  --
  --  >>> human ^. field @"age"
  --  50
  --  >>> human & field @"name" .~ "Tamas"
  --  Human {name = "Tamas", age = 50, address = "London"}
  field :: Lens' s a
  field f s
    = fmap (flip (setField @field) s) (f (getField @field s))

  -- | Get 'field'
  --
  -- >>> getField @"name" human
  -- "Tunyasz"
  getField :: s -> a
  getField s = s ^. field @field

  -- | Set 'field'
  --
  -- >>> setField @"age" (setField @"name" "Tamas" human) 30
  -- Human {name = "Tamas", age = 30, address = "London"}
  setField :: a -> s -> s
  setField = set (field @field)

  {-# MINIMAL field | setField, getField #-}

instance
  ( Generic s
  , ErrorUnlessJust field s (HasFieldP field (Rep s))
  , GHasField field (Rep s) a
  ) => HasField field a s where

  field = repIso . gfield @field

type family ErrorUnlessJust (field :: Symbol) (s :: Type) (contains :: Bool) :: Constraint where
  ErrorUnlessJust field s 'False
    = TypeError
        (     'Text "The type "
        ':<>: 'ShowType s
        ':<>: 'Text " does not contain a field named "
        ':<>: 'ShowType field
        )

  ErrorUnlessJust _ _ 'True
    = ()

-- |As 'HasField' but over generic representations as defined by
--  "GHC.Generics".
class GHasField (field :: Symbol) (f :: Type -> Type) a | field f -> a where
  gfield :: Lens' (f x) a

instance GProductHasField field l r a (HasFieldP field l)
      => GHasField field (l :*: r) a where

  gfield = gproductField @field @_ @_ @_ @(HasFieldP field l)

instance (GHasField field l a, GHasField field r a)
      =>  GHasField field (l :+: r) a where

  gfield = combine (gfield @field @l) (gfield @field @r)

instance GHasField field (S1 ('MetaSel ('Just field) upkd str infstr) (Rec0 a)) a where
  gfield = mIso . gfield @field

instance GHasField field (K1 R a) a where
  gfield f (K1 x) = fmap K1 (f x)

instance GHasField field f a => GHasField field (M1 D meta f) a where
  gfield = mIso . gfield @field

instance GHasField field f a => GHasField field (M1 C meta f) a where
  gfield = mIso . gfield @field

class GProductHasField (field :: Symbol) l r a (left :: Bool) | left field l r -> a where
  gproductField :: Lens' ((l :*: r) x) a

instance GHasField field l a => GProductHasField field l r a 'True where
  gproductField = first . gfield @field

instance GHasField field r a => GProductHasField field l r a 'False where
  gproductField = second . gfield @field