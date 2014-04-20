{-#LANGUAGE MultiParamTypeClasses #-}
{-#LANGUAGE OverloadedStrings #-}

module Twilio.Call
  ( calls
  , Call(..)
  , CallSID
  , Calls(..)
  ) where

import Twilio.Account
import Twilio.Client as Client
import Twilio.PhoneNumber
import Twilio.Types

import Control.Monad (mzero)
import Control.Applicative ((<$>), (<*>), Const(..))
import Data.Aeson
import Data.Aeson.Types (Parser)
import Data.Char (isLower, isNumber)
import Data.Maybe
import Data.Text (unpack)
import Data.Time.Clock (UTCTime)
import Network.HTTP.Client
import Network.URI (URI, parseRelativeReference)

calls :: Client -> IO Calls
calls client = runRequest client "/Calls.json"

data Call = Call
  { sid            :: !CallSID
  , parentCallSID  :: !(Maybe CallSID)
  , dateCreated    :: !UTCTime
  , dateUpdated    :: !UTCTime
  , accountSID     :: !AccountSID
  , to             :: !(Maybe String)
  , from           :: !String
  , phoneNumberSID :: !(Maybe PhoneNumberSID)
  , status         :: !Status
  , startTime      :: !UTCTime
  , endTime        :: !(Maybe UTCTime)
  , duration       :: !(Maybe Int)
  , price          :: !(Maybe Double)
  , priceUnit      :: !(Maybe PriceUnit)
  , direction      :: !Direction
  , answeredBy     :: !(Maybe AnsweredBy)
  , forwardedFrom  :: !(Maybe String)
  , callerName     :: !(Maybe String)
  , uri            :: !URI
  , apiVersion     :: !APIVersion
  } deriving (Show, Eq)

instance FromJSON Call where
  parseJSON (Object v)
    =  Call
   <$>  v .: "sid"
   <*>  v .: "parent_call_sid"
   <*> (v .: "date_created"     >>= parseDateTime)
   <*> (v .: "date_updated"     >>= parseDateTime)
   <*>  v .: "account_sid"
   <*>  v .: "to"               <&> filterEmpty
   <*>  v .: "from"
   <*> (v .: "phone_number_sid" <&> filterEmpty
                                <&> (=<<) parseStringToSID)
   <*>  v .: "status"
   <*> (v .: "start_time"       >>= parseDateTime)
   <*> (v .: "end_time"         <&> (=<<) parseDateTime)
   <*> (v .: "duration"         <&> fmap safeRead
                                >>= maybeReturn')
   <*> (v .: "price"            <&> fmap safeRead
                                >>= maybeReturn')
   <*>  v .: "price_unit"
   <*>  v .: "direction"
   <*>  v .: "answered_by"
   <*>  v .: "forwarded_from"   <&> filterEmpty
   <*>  v .: "caller_name"
   <*> (v .: "uri"              <&> parseRelativeReference
                                >>= maybeReturn)
   <*>  v .: "api_version"
  parseJSON _ = mzero

-- | Call 'SID's are 34 characters long and begin with \"CA\".
newtype CallSID = CallSID { getCallSID :: String }
  deriving (Show, Eq)

instance SID CallSID where
  getSIDWrapper = wrap CallSID
  getPrefix = Const ('C', 'A')
  getSID = getCallSID

instance FromJSON CallSID where
  parseJSON = parseJSONToSID

data Calls = Calls
  { callsPagingInformation :: PagingInformation
  , callList :: [Call]
  } deriving (Show, Eq)

instance List Calls Call where
  getListWrapper = wrap Calls
  getPagingInformation = callsPagingInformation
  getItems = callList
  getPlural = Const "calls"

instance FromJSON Calls where
  parseJSON = parseJSONToList