\begin{code}
module IAParse where

import Control.Applicative
import Control.Arrow
import qualified Control.Category as C
import Control.Monad
import Data.Char
import Data.Maybe
import Data.Monoid
import Data.Tree

import IADataBase
import IAData
import IAPath
import IASyn
import IAUtil

\end{code}

NB Parsers have been modified/commented out to accomadate the new Data structure.
This brings up the question of our reliance on large parts of the world and related functions
Really this either ought to be a more syntactic process
Or else we need extract the base action functions to a parent file










These parsers seem to be working alright. Currently though we consider a single word as a single sign
That is, if we have a multi word phrase each word has to be considered sepereatly
This mostly works, especially if we can anticipate common multi-word constructs, get in vs get apple or similar
The main problem arises in multi-word names. i.e. Green Purse or Mark Thompson.
In both cases we will trying parsing the two words as names but seperatly.

The first Solution I can think of involves keeping a list of all the used names, and checking every combination of input on it.
Though this seems like it would increase in difficulty factorially, We, however, do not anticipate more than 3-5 words of input at a time.

So this is fine if we can ever parse based on a single word
The next step is to allow for partially parsed things
I.e. to allow for parsers to return parsers
Ok, having done some reading, this does seem to be an Arrow thing
Particularly it is apparently a special case of circuit.

\begin{code}
parseIntentSum :: Object a => World -> a -> [String] -> [(World -> a -> [String] -> Maybe Intent)] -> Maybe Intent
parseIntentSum wrld peep [] parsers    = Nothing
parseIntentSum wrld peep input parsers = msum $ parsers <*> pure wrld <*> pure peep <*> pure input
\end{code}


Circuit def adapted from:http://en.wikibooks.org/wiki/Haskell/Arrow_tutorial

We have modified the Circuit definition to better fit our use case, 
i.e. to return a list of circuits instead of a single one.
And also the importance of the multiple ways of combining parsers

\begin{code}
type Parser = Circuit String (Maybe Intent)

pZero :: Parser
pZero = Circuit $ \a -> ([],Nothing)

\end{code}

There should be some way to construct higher order lifts in general.
liftCir3b :: MonadPlus m => (a -> a -> a ->  (m b)) -> Circuit a (m b)
liftCir3b f  = $ flip (unCircuit . liftCir2) $ f

\begin{code}
\end{code}

Instance Arrow Circuit where
	arr = liftCir
The issue is that I do not understand the place of the other function.
There are so many differant ways to chain circuits and I am not sure what the requirements are precessily for a >>>

--sequenceCir' :: Circuit a [b] -> Circuit [a] [b]
--sequenceCir' cir = Circuit $ \a -> (map sequenceCir' $ a >>= (fst . (unCircuit cir)) ,a >>= (snd . (unCircuit cir)))
--unCircuit cir :: a -> ([Circuit a [b]],[b])



\begin{code}

\end{code}

Some functions to format parsers.

\begin{code}

makeParser :: Object a =>(World -> a -> b -> c) -> (World -> a -> Circuit b c)
makeParser f = \wrld obj -> liftCir (f wrld obj)

makeParser2 :: Object a =>(World -> a -> String -> ([Parser],Maybe Intent)) -> (World -> a -> Parser)
makeParser2 f = \wrld obj -> Circuit $ f wrld obj

\end{code}






\begin{code}

--What this does is go through all the possible combinations of input, where two words may refer to a single target
--this will obviously start to choke on large input, we expect only 4-5 words max
parseIntentCombination :: Object a => World -> a -> [String] -> Maybe Intent 
parseIntentCombination wrld a input = msum $ map (parseIntent wrld a) (combInput input)


combInput :: [String] -> [[String]]
combInput [] = []
combInput input = foldr fn [[last input]] (init input)
	where
		fn :: String -> [[String]] -> [[String]]
		fn x xs = (map ([x] ++) xs) ++ ( map (appHead ((x ++) . (" " ++) )) xs)


-- [a,b,c,d] -> [[abcd],[abc,d],[ab,cd],[a,bcd],[ab,c,d],[a,bc,d],[a,b,cd],[a,b,c,d]]
-- [a] -> [[a]]
-- [a,b] -> [[a,b],[ab]]
-- [a,b,c] -> [[a,b,c],[a,bc],[ab,c],[abc]]

-- [a,b,c] -> [[a]] -> [[ba]],[[b,a]]-> [[cba],[c,ba],[cb,a],[c,b,a]]

parseIntent :: Object a => World -> a -> [String] -> Maybe Intent
parseIntent wrld a input = parseIntentArrow input ( preParsers <*> pure wrld <*> pure a ) []

--this will pick the deepest parser path.
parseIntentArrow :: [String] -> [Parser] -> [Intent] -> Maybe Intent
parseIntentArrow [] _ intents = listToMaybe intents
parseIntentArrow _ [] intents = listToMaybe intents
parseIntentArrow input parsers intents =
	let (newParsers, mayIntent) = applyCircuits parsers (head input) in
		parseIntentArrow (tail input) newParsers (maybeToList mayIntent ++ intents)

preParsers ::Object a => [(World -> a -> Parser)]
--preParsers = map makeParser2 $ pickSys : []
preParsers = parseSys : parseGet : parseMove : parseLook : []


--

parseSys = eat2Arg $ liftCir pickSys

pickSys :: String -> Maybe Intent
pickSys str 
	| elem str quitSyn = Just $ SysCom Quit
	| elem str helpSyn = Just $ SysCom Help
	| otherwise = Nothing
--

--liftCir2 :: MonadPlus m => (a -> a -> (m b)) -> Circuit a (m b)

parseMove :: Object a => World -> a -> Parser
parseMove = makeParser2 pickMove

pickMove :: Object a => World -> a -> String -> ([Parser],Maybe Intent)
pickMove wrld obj str
	| elem str moveSyn = ([parser],Nothing)
	| elem str dirSyn  = unCircuit parser $ str
	| otherwise        = ([],Nothing)
		where
			parser = combineNCir --note we have to use doubles of parsers with defaults to avoid unexpected termination of the input string.
				[liftCir $ \str -> pickDirection str >>= \a -> Just $ Move $ Tar (Just a) (idn obj)
				,liftCir $ \str -> pickDirRel str >>= \a -> Just $ Move $ Tar (Just $ Rel a) (idn obj)
				,liftCir $ \str -> (parseNameId wrld obj str) >>= (\a -> Just $ Move $ Tar Nothing a)
				,liftCir2 $ \str1 str2 -> parseNameId wrld obj str2 >>= \a -> pickDirection str1 >>= \b -> Just $ Move $ Tar (Just b) a
				,liftCir2 $ \str1 str2 -> parseNameId wrld obj str2 >>= \a -> pickDirRel str1 >>= \b -> Just $ Move $ Tar (Just $ Rel b) a
				] --Also be carful of parsers that always succeed, they should never be used.
--}
parseLook :: Object a => World -> a -> Parser
parseLook = makeParser2 pickLook

pickLook :: Object a => World -> a -> String -> ([Parser],Maybe Intent)
pickLook wrld obj str =
	if elem str lookSyn
		then 
			( --note the order of these parsers does matter, this is the order they are evaluated in
			 [liftCir $ \str -> pickDirection str >>= \a -> Just $ Look $ Tar (Just a) (idn obj) --nb, this is slightly different than the above.
			 ,liftCir $ \str -> pickDirRel str >>= \a -> Just $ Look $ Tar (Just $ Rel a) (idn obj)
			 ,liftCir $ \str -> parseNameId wrld obj str >>= \a -> Just $ Look $ Tar Nothing a
			 ,liftCir2 $ \str1 str2 -> parseNameId wrld obj str2 >>= \a -> pickDirection str1 >>= \b -> Just $ Look $ Tar (Just b) a
			 ,liftCir2 $ \str1 str2 -> parseNameId wrld obj str2 >>= \a -> pickDirRel str1 >>= \b -> Just $ Look $ Tar (Just $ Rel b) a
			 ,liftCir2 $ \str1 str2 -> parseNameId wrld obj str2 >>= (\a -> checkInv wrld a str1) >>= Just . Look . (Tar (Just $ Rel In))
			 ]
			, Just $ Look $ Tar Nothing (idn obj)
			)
		else (join [ fst $ unCircuit (liftCir2 $ \str1 str2 -> parseNameId wrld obj str2 >>= (\a -> checkInv wrld a str1) >>= Just . Look . (Tar (Just $ Rel In))) $ str
			], parseNameId wrld obj str >>= Just . Look . (Tar Nothing) )
--}


--for use in move and 
--targParsers :: Object a => World -> a (Target -> Intent) -> [Parser]
--targParsers wrld obj f =

--
parseGet :: Object a => World -> a -> Parser
parseGet = makeParser2 pickGet

--form, Just $ Get Id
pickGet :: Object a => World -> a -> String -> ([Parser],Maybe Intent)
pickGet wrld obj str =
	if elem str getSyn
		then
			(
			 [liftCir $ (Just . Get) <=< (parseNameId wrld obj)
			 ,liftCir2 $ \str1 str2 -> parseNameId wrld obj str2 >>= (\a -> checkInv wrld a str1) >>= Just . Get
			 ,liftCir2 $ \str1 str2 -> parseNameId wrld obj str1 >>= (\a -> checkInv wrld a str2) >>= Just . Get
			 ,liftCir3 $ \str1 str2 str3 -> if elem str2 inSyn then parseNameId wrld obj str3 >>= (\a -> checkInv wrld a str1) >>= Just . Get else Nothing
			 --,liftCir3 $ \str1 str2 str3 -> if elem str2 onSyn then parseNameId wrld obj str3 >>= (\a -> checkSurf wrld a str1) >>= Just . Get else Nothing
			 ,liftCir3 $ \str1 str2 str3 -> if elem str2 inSyn then parseNameId wrld obj str1 >>= (\a -> checkInv wrld a str3) >>= Just . Get else Nothing
			 --,liftCir3 $ \str1 str2 str3 -> if elem str2 onSyn then parseNameId wrld obj str1 >>= (\a -> checkSurf wrld a str3) >>= Just . Get else Nothing
			 ]
			, Nothing
			)
		else ([],Nothing)
--}




--

--worldAppContainer :: World -> Id -> (forall a. (Container a) => a -> b) -> Maybe b
--returns the id of a thing matching the string inside the the target's inventory
checkInv :: World -> Id -> String -> Maybe Id
checkInv wrld tar str = (join $ worldAppId wrld f tar) >>= (Just . fst)
	where
		f :: ContainerA -> Maybe (Id,Int)
		f con = foldr (checkfoldfn wrld str) Nothing (inventory con)

checkfoldfn :: World -> String -> Id -> Maybe (Id,Int) -> Maybe (Id,Int)
checkfoldfn wrld str id mayId = join $ worldAppId wrld fn id 
	where 
		fn :: ObjectA -> Maybe (Id,Int)
		fn obj = 
			mOrdPair mayId $ foldr (\name may -> 
				if str == (fst name) 
					then Just $ (id,snd name) 
					else may
				) Nothing (names obj)
--

mOrdPair :: (MonadPlus m,Ord b) => m (a,b) -> m (a,b) -> m (a,b)
mOrdPair thing1 thing2 = do
	a <- thing1
	b <- thing2
	if snd a < snd b then return b else return a

{--
checkSurf :: World -> Id -> String -> Maybe Id
checkSurf wrld tar str = (join $ worldAppSurface wrld tar f) >>= (Just . fst)
	where
		f :: Surface a => a -> Maybe (Id,Int)
		f con = foldr (checkfoldfn wrld str) Nothing (surface con)
--}


--
parseDirection :: (Maybe Direction -> Maybe Intent) -> Parser
parseDirection f = liftCir $ f . pickDirection

pickDirection :: String -> Maybe Direction
pickDirection str
	| elem str northSyn = Just $ Abs North
	| elem str southSyn = Just $ Abs South
	| elem str westSyn  = Just $ Abs West
	| elem str eastSyn  = Just $ Abs East
	| elem str hereSyn  = Just $ Abs Here
	| elem str upSyn    = Just $ Abs Up
	| elem str downSyn  = Just $ Abs Down
	| otherwise         = Nothing

parseDirRel :: (Maybe RelDirection -> Maybe Intent) -> Parser
parseDirRel f = liftCir $ f . pickDirRel

pickDirRel :: String -> Maybe RelDirection
pickDirRel str
	| elem str inSyn = Just In
	| elem str outSyn = Just Out
	| elem str onSyn = Just On
	| elem str belowSyn = Just Below
	| otherwise = Nothing
--
--}

parseNameCoor :: Object a => World -> a -> String -> Maybe Coord
parseNameCoor wrld peep str
	| elem str hereSyn = Just $ loc peep
	| otherwise = parseName wrld peep str >>= (Just . snd)

parseNameId :: Object a => World -> a -> String -> Maybe Id
parseNameId wrld peep str = parseName wrld peep str >>= (Just . fst)

parseName ::Object a => World -> a -> String -> Maybe (Id,Coord)
parseName wrld peep str
	| null str = Nothing
	| elem str selfSyn = Just (idn peep,loc peep)
	| otherwise = worldFold wrld foldFn Nothing
		where
			foldFn :: ObjectA -> Maybe (Id,Coord) -> Maybe (Id,Coord)
			foldFn thing mayPair
				| not $ elem str ( map fst (names thing) ) = mayPair
				| mayPair == Nothing = Just (idn thing, loc thing)
				| eucDistSqrd (loc thing) (loc peep) < eucDistSqrd (snd . fromJust $ mayPair) (loc peep) = Just (idn thing, loc thing)
				| otherwise = mayPair
\end{code}




