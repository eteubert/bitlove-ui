{-# LANGUAGE FlexibleInstances, DeriveDataTypeable #-}
module Model (
  -- Model
  infoHashByName,
  Torrent (..),
  torrentByName,
  purgeTorrent,
  DirectoryEntry (..),
  getDirectory,
  -- Model.Query
  QueryPage (..),
  -- Model.Stats
  StatsValue (..),
  getCounter,
  addCounter,
  getGauge,
  -- Model.Download
  InfoHash (..),
  infoHashToHex,
  Download (..),
  recentDownloads,
  popularDownloads,
  mostDownloaded,
  userDownloads,
  enclosureDownloads,
  feedDownloads,
  -- Model.Item
  Item (..),
  groupDownloads,
  userItemImage,
  -- Model.User
  UserName (..),
  UserDetails (..),
  userDetailsByName,
  setUserDetails,
  UserSalt (..),
  userSalt,
  setUserSalted,
  registerUser,
  userByEmail,
  -- Model.Feed
  FeedXml (..),
  feedXml,
  feedEnclosures,
  enclosureErrors,
  FeedInfo (..),
  userFeed,
  userFeeds,
  userFeedInfo,
  addUserFeed,
  deleteUserFeed,
  FeedDetails (..),
  userFeedDetails,
  setUserFeedDetails,
  -- Model.Token
  Token (..),
  generateToken,
  validateToken,
  peekToken
  ) where

import Prelude
import Data.Convertible
import Data.Text (Text)
import Database.HDBC
import Data.Time
import Data.Data (Typeable)
import qualified Data.ByteString.Char8 as BC
import Control.Applicative

import Model.Query
import Model.Download
import Model.Item
import Model.Feed
import Model.User
import Model.Token
import Model.Stats                        


infoHashByName :: UserName -> Text -> Text -> Query InfoHash
infoHashByName user slug name =
  query "SELECT \"info_hash\" FROM user_feeds JOIN enclosures USING (feed) JOIN enclosure_torrents USING (url) JOIN torrents USING (info_hash) WHERE user_feeds.\"user\"=? AND user_feeds.\"slug\"=? AND torrents.\"name\"=?" [toSql user, toSql slug, toSql name]

data Torrent = Torrent {
  torrentInfoHash :: InfoHash,
  torrentName :: Text,
  torrentSize :: Integer,
  torrentTorrent :: BC.ByteString
} deriving (Show, Typeable)

instance Convertible [SqlValue] Torrent where
  safeConvert (info_hash:name:size:torrent:[]) =
    Torrent <$>
    safeFromSql info_hash <*>
    safeFromSql name <*>
    safeFromSql size <*>
    pure (fromBytea torrent)
  safeConvert vals = convError "Torrent" vals

torrentByName :: UserName -> Text -> Text -> Query Torrent
torrentByName user slug name =
  query "SELECT \"info_hash\", \"name\", \"size\", \"torrent\" FROM user_feeds JOIN enclosures USING (feed) JOIN enclosure_torrents USING (url) JOIN torrents USING (info_hash) WHERE user_feeds.\"user\"=? AND user_feeds.\"slug\"=? AND torrents.\"name\"=?" [toSql user, toSql slug, toSql name]
  
purgeTorrent :: IConnection conn => 
                UserName -> Text -> Text -> conn -> IO Int
purgeTorrent user slug name db =
  (fromSql . head . head) `fmap`
  quickQuery' db "SELECT * FROM purge_download(?, ?, ?)"
              [toSql user, toSql slug, toSql name]


data DirectoryEntry = DirectoryEntry
    { dirUser :: UserName
    , dirUserTitle :: Text
    , dirUserImage :: Text
    , dirFeedSlug :: Text
    , dirFeedTitle :: Text
    , dirFeedLang :: Text
    , dirFeedTypes :: Text
    } deriving (Show, Typeable)

instance Convertible [SqlValue] DirectoryEntry where
    safeConvert (user:userTitle:userImage:
                 feedSlug:feedTitle:feedLang:feedTypes:[]) = 
      DirectoryEntry <$>
      safeFromSql user <*>
      safeFromSql userTitle <*>
      safeFromSql userImage <*>
      safeFromSql feedSlug <*>
      safeFromSql feedTitle <*>
      safeFromSql feedLang <*>
      safeFromSql feedTypes
    safeConvert vals = convError "DirectoryEntry" vals
      
getDirectory :: Query DirectoryEntry
getDirectory =
  query "SELECT \"user\", COALESCE(\"title\", \"user\"), COALESCE(\"image\", ''), \"slug\", COALESCE(\"feed_title\", \"slug\"), COALESCE(\"lang\", ''), array_to_string(\"types\", ',') FROM directory" []

