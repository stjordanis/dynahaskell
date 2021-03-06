{-# LANGUAGE RankNTypes #-}

module MarkerUtils where

import Polysemy
import Sem.Fresh
import Generics.SYB hiding (Generic)
import Control.Lens
import Data.Data.Lens
import Types
import Name hiding (varName)
import Var
import MarkerLenses
import GenericOrphans ()


pattern Todo :: Integer -> LExpr
pattern Todo n <- L _ (HsApp _ (L _ (HsVar _ (L _ (Unqual (occNameString -> "todo")))))
                               (IntLiteral n))
  where
    Todo n =
      noLoc (HsApp noExt
                   (noLoc (HsVar noExt (noLoc (Unqual (mkVarOcc "todo")))))
                   (IntLiteral n))


pattern Underway :: Integer -> LExpr -> LExpr
pattern Underway n e
  <- L _ (OpApp _ (L _ (HsApp _ (L _ (HsVar _ (L _ (Unqual (occNameString -> "underway")))))
                                     (IntLiteral n)))
                  _ e)
  where
    Underway n e =
      noLoc
      $ OpApp noExt
              (noLoc
               $ HsApp noExt
                       (noLoc $ HsVar noExt $ noLoc $ Unqual $ mkVarOcc "underway")
                       (IntLiteral n))
              (noLoc $ HsVar noExt $ noLoc $ Unqual $ mkVarOcc "$")
              e


pattern IntLiteral :: Integer -> LExpr
pattern IntLiteral n <- L _ (HsOverLit _ (OverLit _ (HsIntegral (IL _ _ n)) _))
  where
    IntLiteral n = noLoc
                 $ HsOverLit noExt
                 $ OverLit noExt (HsIntegral i)
                 $ HsLit noExt
                 $ HsInt noExt i
      where
        i = IL (SourceText $ show n) False n


matchOcc :: String -> LExpr -> Bool
matchOcc occ (L _ (HsVar _ (L _ (Unqual occ')))) = mkVarOcc occ == occ'
matchOcc _ _ = False

matchVar :: String -> HsExpr GhcTc -> Bool
matchVar occ (HsVar _ (L _ var)) = occNameString (nameOccName (varName var)) == occ
matchVar _ _ = False

locate :: (Data a, Data b) => (b -> Bool) -> Traversal' a b
locate f = biplate . deepOf uniplate (taking 1 $ filtered f)

nextSolve :: Data a => Traversal' a LExpr
nextSolve = locate $ matchOcc "solve"

todo :: Data a => Integer -> Traversal' a LExpr
todo n = locate \case
  Todo n' | n == n' -> True
  _ -> False

anyTodo :: Data a => Traversal' a LExpr
anyTodo = locate \case
  Todo _ -> True
  _ -> False

anyUnderway :: Data a => Traversal' a LExpr
anyUnderway = locate \case
  Underway _ _ -> True
  _ -> False

underwayStmts :: Traversal' LExpr [ExprLStmt GhcPs]
underwayStmts = anyUnderway . loc . _Ctor' @"OpApp" . _4 . loc . _Ctor' @"HsDo" . _3 . loc


mkVar :: String -> Expr
mkVar = HsVar NoExt . noLoc . Unqual . mkVarOcc

newTodo :: Member (Fresh Integer) r => Sem r LExpr
newTodo = do
  i <- fresh
  pure $ Todo i

