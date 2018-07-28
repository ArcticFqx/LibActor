# LibActor
A framework for modded charts in NotITG.

It adds a localized scope for all Commands and Messages for all Actors on both the foreground and background sharing the same Lua script.

This works by tagging your XML with references to functions in scripts instead of writing your functions directly in the XML.

A dev mode is available which should prevent your game from crashing if your script errors. This only works for calls done through LibActor, `%function` calls will still crash if they contain an error.

# How to install
## Just for your chart
First, place the lib folder with the default.xml and libactor.lua files into your chart folder,  
then add `0.000=lib=1.000=0=0=0=====,` to your `#BGCHANGES` in your simfile.  
Modded `#BGCHANGES` must start at 0.001 or use `#BETTERBGCHANGES` instead.

## As a theme script
Just save the Lua file in your theme's Scripts folder
