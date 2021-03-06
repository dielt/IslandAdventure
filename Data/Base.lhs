
\begin{code}
{-# LANGUAGE ExistentialQuantification  #-}


module Data.Base where

import Data.Maybe
import Data.Tree

import Util.Base

\end{code}


Merged data types from previous version.

\begin{code}

data InterruptType 
	= Sight --the thing is visible
	| Touch Id --the thing is touching id.
	| Sound String --the thing is making noise, described by String. i.e. string can be used for speech or general sound descriptions.
	deriving (Eq,Show)

newtype Interrupt = InterruptType (Id,Integer)

data AbsDirection = North | South | East | West | Here | Up | Down deriving (Eq, Show)

data RelDirection = In | Out | On | Below deriving (Eq, Show)

data Direction = Rel RelDirection | Abs AbsDirection deriving (Eq, Show)

data SysIntent = Quit | Help | VerNum | Setting  deriving (Eq,Show)

data Settings = Volume | Difficulty deriving (Eq,Show) 

data SysSetting = SysSetting (Int,Settings)  deriving (Eq,Show)

checkSetting :: [SysSetting] -> Settings -> Int
checkSetting list s = foldr (\(SysSetting (b,c)) a -> if c == s then b else a ) (-1) list

getSetting = (\(SysSetting (b,c))-> c)

changeSetting :: [SysSetting] -> SysSetting -> [SysSetting]
changeSetting list sett =
	if elem (getSetting sett) $ map (\(SysSetting (b,c)) -> c) list 
		then  foldr (\a list' -> if (getSetting a) == (getSetting sett) then sett : list' else a : list' ) [] list
		else sett : list

data Intent = SysCom SysIntent | Move Target | Get Id | Look Target deriving (Eq,Show)

data Target = Target (Maybe Direction) Id deriving (Eq, Show)

\end{code}

Some basic Data types 

\begin{code}

newtype Id = Id Int deriving (Show,Eq) --idk if this should just be Ix

newtype Coord = Coord (Integer,Integer) deriving (Eq,Show)

newtype Ml = Ml Integer deriving (Eq, Ord) --millilitres

newtype Mm = Mm Integer deriving (Eq,Ord) --millimetres

newtype Gram = Gram Integer deriving (Eq,Ord)

eucDistSqrd (Coord (x,y)) (Coord (u,v)) = (x-u)^2 +(y-v)^2

eucDist = sqrt . fromIntegral .: eucDistSqrd

manAdj (Coord (x,y)) = [Coord (x - 1,y),Coord (x+1,y),Coord (x,y - 1),Coord (x,y+1)]

coordAdd (Coord (x,y)) (Coord (u,v)) = (Coord (x+u,y+v))

coordDir :: AbsDirection -> Coord -> Maybe Coord
coordDir dir coor = 
	case dir of
		North -> Just $ coordAdd coor (Coord (0,10))
		East  -> Just $ coordAdd coor (Coord (10,0))
		West  -> Just $ coordAdd coor (Coord (-10,0))
		South -> Just $ coordAdd coor (Coord (0,-10))
		otherwise -> Nothing

\end{code}



\begin{code}

--we should seriously consider removing the Action Token list as it makes parsing things weird.
data ActionToken = MoveT | GetT | LookT | SysComT SysIntent deriving (Eq,Show)

data Token = Affirm Bool | Name String | Action ActionToken | DirT Direction deriving (Eq,Show)

type TokenCollection = [Tree Token]

\end{code}


helpful classes

\begin{code}

--essentially a failure class, with behavior analagous to maybe.
class Zero a where
	iszero :: a -> Bool
	zero :: a
	
instance Zero [a] where
	iszero = null
	zero = []
	
instance Zero (Maybe a) where
	iszero = isNothing
	zero = Nothing

instance Zero Bool where
	iszero = not
	zero = False

instance Zero a => Zero (Tree a) where
	iszero (Node x xs) = iszero x && iszero xs
	zero = Node zero []

zeroOr :: Zero a => [a] -> a
zeroOr [] = zero 
zeroOr (x:xs) = 
	if iszero x
		then zeroOr xs
		else x

\end{code}


memory stuff, this can probably be moved to Data.ObjectClass
\begin{code}
data Memory = Memory {
	actTick :: Integer
	bodyMem :: Body
	namesMem :: [(Id,String,Integer)]
	}

\end{code}
