{-# LANGUAGE EmptyDataDecls             #-}
{-# LANGUAGE RankNTypes                 #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE FlexibleContexts           #-}
{-# LANGUAGE GADTs                      #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE OverloadedStrings          #-}
{-# LANGUAGE QuasiQuotes                #-}
{-# LANGUAGE TemplateHaskell            #-}
{-# LANGUAGE TypeFamilies               #-}
{-# LANGUAGE RecordWildCards            #-}
{-# LANGUAGE DeriveGeneric              #-}

module Models where

import Data.Aeson
import Control.Monad.Logger (runStderrLoggingT)
import GHC.Generics
import Control.Monad.Reader
import Database.Persist.Postgresql
import Database.Persist.TH
import Data.Aeson.TH
import qualified Data.Text as Text
import Data.Text (Text())
import Data.Char (toLower)
import Data.Time
import Web.Users.Types
import Web.Users.Persistent

import Config

share [mkPersist sqlSettings, mkMigrate "migrateAll"] [persistLowerCase|
Liftsession json
    text Text
    date UTCTime
    userId LoginId
    deriving Show

Profile json
    user LoginId
    deriving Show
|]

data Registration
    = Registration
    { regName :: Text
    , regEmail :: Text
    , regPassword :: Text
    , regConfirmation :: Text
    } deriving (Eq, Show)

deriveJSON defaultOptions { fieldLabelModifier = map toLower . Prelude.drop 3, constructorTagModifier = map toLower } ''Registration

data Auth
    = Auth
    { authEmail :: Text
    , authPassword :: Text
    , authConfirmation :: Text
    } deriving (Eq, Show)

deriveJSON defaultOptions { fieldLabelModifier = map toLower . Prelude.drop 4, constructorTagModifier = map toLower } ''Auth

doMigrations :: ReaderT SqlBackend IO ()
doMigrations = runMigration migrateAll

runDb :: (MonadIO m, MonadReader Config m) => SqlPersistT IO b -> m b
runDb query = asks getPool >>= liftIO . runSqlPool query

db query =
    runStderrLoggingT $
        withPostgresqlPool (connStr Development) 1 $
            liftIO . runSqlPersistMPool query


data Person = Person
    { name :: Text
    , email :: Text
    } deriving (Eq, Show, Generic)

instance ToJSON Person
instance FromJSON Person

type QLUser = User UserDetails
type UserDetails = ()

userToPerson :: QLUser -> Person
userToPerson User {..} =
    Person { name = u_name
           , email = u_email
           }

convertRegistration :: Registration -> QLUser
convertRegistration Registration{..} =
    User { u_name = regName
         , u_email = regEmail
         , u_password = makePassword . PasswordPlain $ regPassword
         , u_more = ()
         , u_active = True
         }


data AuthResponse
    = AuthResponse
    { sessionId :: SessionId
    , person :: Person
    } deriving (Eq, Show, Generic)

instance ToJSON AuthResponse
