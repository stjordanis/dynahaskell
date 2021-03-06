{-# LANGUAGE TemplateHaskell #-}

module Sem.HoleInfo where

import Bag
import Control.Arrow
import Control.Lens
import GHC
import MarkerLenses
import MarkerUtils
import Polysemy
import Sem.Anns
import Sem.Fresh
import Sem.Typecheck
import Types hiding (Type)


-- TODO(sandy): This is absolutely terrible. We can just call `fmap exprType . dsExpr`
-- to get the type of a particular expression; no need to continually recompile
-- and typecheck the whole thing every time.
holeInfo
    :: Members '[Typecheck, Anno, Fresh Integer] r
    => Traversal' LModule LExpr
    -> Source
    -> Sem r [(Type, [(Name, Type)])]
holeInfo l t = do
  i <- fresh
  let hole = mkVar $ "_hole" ++ show i
  v <- typecheck =<< spliceTree l (noLoc hole) t
  pure $ case v of
    Nothing -> error "typechecking failed"
    Just tc -> holeInfoForName ("_hole" ++ show i) tc


holeInfoForName :: String -> TypecheckedModule -> [(Type, [(Name, Type)])]
holeInfoForName n tc
    = bagToList (tm_typechecked_source tc)
  ^.. locate (matchVar n)
    . _Ctor' @"HsVar"
    . to (id &&& id)
    . alongside (position @2 . loc . to idType)
                (position @1)

