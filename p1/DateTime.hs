import Prelude hiding ((<*), (*>), sequence)

import Data.List (find)
import Data.Maybe (isJust)
import Text.Printf (printf)

import ParseLib.Abstract

-- Starting Framework

-- | "Target" datatype for the DateTime parser, i.e, the parser should produce
--   elements of this type.
data DateTime = DateTime
    { date :: Date
    , time :: Time
    , utc :: Bool
    } deriving (Eq, Ord)

data Date = Date
    { year  :: Year
    , month :: Month
    , day   :: Day
    } deriving (Eq, Ord)

newtype Year = Year { unYear :: Int }
    deriving (Eq, Ord)

newtype Month = Month { unMonth :: Int }
    deriving (Eq, Ord)

newtype Day = Day { unDay :: Int }
    deriving (Eq, Ord)

data Time = Time
    { hour :: Hour
    , minute :: Minute
    , second :: Second
    } deriving (Eq, Ord)

newtype Hour = Hour { unHour :: Int }
    deriving (Eq, Ord)

newtype Minute = Minute { unMinute :: Int }
    deriving (Eq, Ord)

newtype Second = Second { unSecond :: Int }
    deriving (Eq, Ord)


-- | The main interaction function. Used for IO, do not edit.
data Result
    = SyntaxError
    | Invalid DateTime
    | Valid DateTime
    deriving (Eq, Ord)

instance Show DateTime where
    show = printDateTime

instance Show Result where
    show SyntaxError = "date/time with wrong syntax"
    show (Invalid _) = "good syntax, but invalid date or time values"
    show (Valid x) = "valid date: " ++ show x

main :: IO ()
main = interact (printOutput . processCheck . processInput)
    where
        processInput = map (run parseDateTime) . lines
        processCheck = map (maybe SyntaxError (\x -> if checkDateTime x then Valid x else Invalid x))
        printOutput = unlines . map show



-- Exercise 1

fromDigits :: [Int] -> Int
fromDigits = foldl (\r d -> r * 10 + d) 0

times :: Int -> Parser t a -> Parser t [a]
times n = sequence . replicate n

parseDigits :: Int -> Parser Char Int
parseDigits n = fromDigits <$> n `times` newdigit

parseDate :: Parser Char Date
parseDate = Date
    <$> (Year <$> parseDigits 4)
    <*> (Month <$> parseDigits 2)
    <*> (Day <$> parseDigits 2)

parseTime :: Parser Char Time
parseTime = Time
    <$> (Hour <$> parseDigits 2)
    <*> (Minute <$> parseDigits 2)
    <*> (Second <$> parseDigits 2)

parseDateTime :: Parser Char DateTime
parseDateTime = DateTime
    <$> parseDate
    <*  symbol 'T'
    <*> parseTime
    <*> (isJust <$> optional (symbol 'Z'))

-- Exercise 2

run :: Parser a b -> [a] -> Maybe b
run p = fmap fst . find (null . snd) . parse p

-- Exercise 3

printDigits :: Int -> Int -> String
printDigits n = printf $ "%0" ++ show n ++ "d"

printDate :: Date -> String
printDate (Date y m d) =
    concat
        [ printDigits 4 $ unYear y
        , printDigits 2 $ unMonth m
        , printDigits 2 $ unDay d
        ]

printTime :: Time -> String
printTime (Time h m s) =
    concat
        [ printDigits 2 $ unHour h
        , printDigits 2 $ unMinute m
        , printDigits 2 $ unSecond s
        ]

printDateTime :: DateTime -> String
printDateTime (DateTime d t u) =
    concat
        [ printDate d
        , "T"
        , printTime t
        , if u then "Z" else ""
        ]

-- Exercise 4
parsePrint s = fmap printDateTime $ run parseDateTime s

-- Exercise 5
checkDate :: Date -> Bool
checkDate (Date (Year y) (Month m) (Day d))
    =  m >= 1 && m <= 12
    && d >= 1 && d <= monthLength
        where
            monthLength = 
                [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31] !! (m - 1)
                + if leapYear && m == 2 then 1 else 0
            leapYear = divisible 4 && (not (divisible 100) || divisible 400)
            divisible n = y `mod` n == 0

checkTime :: Time -> Bool
checkTime (Time (Hour h) (Minute m) (Second s)) 
    =  h >= 0 && h < 24
    && m >= 0 && m < 60
    && s >= 0 && s < 60

checkDateTime :: DateTime -> Bool
checkDateTime (DateTime d t _) =
    checkDate d && checkTime t

-- Exercise 6

data Event = Event
    { timestamp :: DateTime
    , uid :: String
    , start :: DateTime
    , end :: DateTime
    , description :: Maybe String
    , summary :: Maybe String
    , location :: Maybe String
    }

data Calendar = Calendar
    { events :: [Event]
    , prodid :: String
    , version :: String
    }
