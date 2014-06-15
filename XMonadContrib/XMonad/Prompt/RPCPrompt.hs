module XMonad.Prompt.RPCPrompt
    ( mkRPCPrompt
    , RPCPrompt(..)
    , rpcAction
    , rpcAction'
    , rpcComplFunc
    , splitArg
    , isCmdPrefixOf
    ) where

import XMonad.Prompt
import XMonad.Core
import Data.Char
import Data.List 
import Data.List.Split
import qualified Data.Text as T
import XMonad.Util.Run
import XMonad.Hooks.DynamicLog (trim)
import XMonad.Hooks.OnWindowsInserted

---- constant
rpcSetch = "setch"
--- added bitrate command to set the bitrate more conveniently (at the cost of restarting the service)
rpcBitRate = "kbps"
rpcAllowedBitRates = [ "64", "128", "192" ]

--- renamed skip to next so as to increase difference between commands; added kill to reboot the service
rpcOtherCompletions = ["play", "pause", "toggle", "next", "rate", "unrate", "ban", "webpage", "launch", "end"]
rpcAllCompletions = rpcOtherCompletions++[rpcSetch,rpcBitRate]

data RPCPrompt = RPCPrompt

wordInside word s = isInfixOf (map toLower word) $ map toLower s

instance XPrompt RPCPrompt where
    showXPrompt _ = "rpc > "
    commandToComplete RPCPrompt = id
    nextCompletion RPCPrompt c l = if null l then c else compls
                                        where args = parseArgs c
                                              firstArg = head args
                                              tailArgs = tail args
                                              lastArg = if null tailArgs then "" else last tailArgs
                                              compls 
                                                | firstArg `isPrefixOf` rpcBitRate && (head l) `elem` rpcAllowedBitRates = "kbps " ++ (l !! exactMatchIndex)
                                                | firstArg `isPrefixOf` rpcSetch = "setch " ++ (head $ parseArgs (l !! nextChNumMatchIndex))
                                                | otherwise = skipLastWord c ++ (l !! exactMatchIndex)
                                              exactMatchIndex = case lastArg `elemIndex` l of
                                                                    Just i -> if i >= length l - 1 then 0 else i+1
                                                                    Nothing -> nextChFuzzyMatchIndex    
                                              nextChNumMatchIndex = case findIndex (\s -> lastArg == (head $ parseArgs s)) l of
                                                                        Just i -> if i >= length l - 1 then 0 else i+1
                                                                        Nothing -> nextChFuzzyMatchIndex    
                                              nextChFuzzyMatchIndex = case findIndex (wordInside lastArg) l of
                                                                           Just i -> i
                                                                           Nothing -> 0
    highlightPredicate RPCPrompt cl cmd = first == lastArg
                                        where first = fst $ splitArg cl
                                              args = parseArgs cmd
                                              lastArg = last args

splitArg s = case break isSpace s of
                  (a, _:b) -> (a, b)
                  (a, _) -> (a, "")
isCmdPrefixOf s c =  not (null s) && isPrefixOf s c

parseArgs = splitOn " "

rpcComplFunc s = 
    let (cmd, arg) = splitArg s
    in if cmd `isCmdPrefixOf` rpcSetch
          then fmap (fmap trim . tail . lines) $ runProcessWithInput "rpc" ["channels"] "" 
          else if cmd `isCmdPrefixOf` rpcBitRate
            then return rpcAllowedBitRates 
            else return $ filter (isPrefixOf cmd) rpcAllCompletions

rpcAction' immi final owi s = 
    let (cmd', arg) = splitArg s
        cmd = if cmd' `isCmdPrefixOf` rpcSetch then rpcSetch
                                            else if cmd' `isCmdPrefixOf` rpcBitRate then rpcBitRate
                                            else cmd'
        run = spawn $ "rpc " ++ cmd ++ " " ++ escapeQuery arg
    in if cmd == "webpage" then applyOnWindowsInserted owi {
                                      numberOfWindows = 1
                                    , logFinished = \a b -> do
                                        (logFinished owi) a b
                                        final
                                } >> run >> immi
                           else run >> immi >> final
rpcAction = rpcAction' (return ()) (return ()) def

mkRPCPrompt c = mkXPrompt RPCPrompt c rpcComplFunc rpcAction