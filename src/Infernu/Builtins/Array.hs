{-# LANGUAGE TupleSections #-}
module Infernu.Builtins.Array
       (arrayRowType)
       where

import           Control.Monad             (foldM, forM)
import Infernu.Types
import Infernu.InferState
import           Infernu.Lib (safeLookup)
import Control.Applicative

func :: Type -> Type -> Type -> Type
func this x y = Fix $ TFunc [this, x] y

funcN :: [Fix FType] -> Fix FType -> Fix FType
funcN xs tres = Fix $ TFunc xs tres

string :: Type
string = Fix $ TBody TString

number :: Type
number = Fix $ TBody TNumber

undef :: Type
undef = Fix $ TBody TUndefined

array :: Type -> Type
array t = Fix $ TCons TArray [t]

boolean :: Fix FType
boolean = Fix $ TBody TBoolean

ts :: t -> TScheme t
ts t = TScheme [] $ qualEmpty t

tvar :: TVarName -> Type
tvar = Fix . TBody . TVar

arrayProps :: Type -> [(String, TypeScheme)]
arrayProps elemType = let aType = array elemType in
  [ ("length", ts number)
  , ("concat", ts $ func aType aType aType)
     -- TODO support thisArg (requires type variables)
  , ("every", ts $ func aType (funcN [undef, elemType, number, aType] boolean) boolean) -- missing thisArg
  , ("filter", ts $ func aType (funcN [undef, elemType, number, aType] boolean) aType) -- missing thisArg
    -- TODO support optional argument for fromIndex (last parameter)
  , ("indexOf", ts $ funcN [aType, elemType, number] number)
  , ("join", ts $ func aType string string)
  , ("lastIndexOf", ts $ func aType number number)
  , ("map", TScheme [0,1] $ qualEmpty (func (array $ tvar 0) (funcN [undef, tvar 0, number, array $ tvar 0] (tvar 1)) (array $ tvar 1)))
  , ("pop", ts $ funcN [aType] elemType)
  , ("push", ts $ funcN [aType, elemType] number)
  , ("reverse", ts $ funcN [aType] aType)
  , ("shift", ts $ funcN [aType] elemType)
  , ("slice", ts $ funcN [aType, number, number] aType)
  , ("some", ts $ func aType (funcN [undef, elemType, number, aType] boolean) aType) -- missing thisArg
  , ("sort", ts $ func aType (funcN [undef, elemType, elemType] number) aType)
  , ("splice", ts $ funcN [aType, number, number] aType)
  , ("unshift", ts $ funcN [aType] elemType)
  ]

-- TODO: when inserting builtin types, do fresh renaming of scheme qvars
arrayRowType :: Type -> Infer (TRowList Type)
arrayRowType elemType = TRowProp TPropSetIndex (ts $ funcN [aType, number, elemType] undef)
                        . TRowProp TPropGetIndex (ts $ func aType number elemType)
                        <$> (foldM addProp (TRowEnd Nothing) $ arrayProps elemType)
  where aType = array elemType
        addProp rowlist (name, propTS) =
          do allocNames <- forM (schemeVars propTS) $ \tvName -> (fresh >>= return . (tvName,))
             let ts' = mapVarNames (safeLookup allocNames) propTS
             return $ TRowProp (TPropName name) ts' rowlist
