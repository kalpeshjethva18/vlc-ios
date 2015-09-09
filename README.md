#How to start development for VLC for iOS:

1. Run the compilescript with: sh compileVLCforiOS.sh

The first time around this will take roughly an hour and take up 6GB of free space

If it compiled and ran in your simulator throw confetti, celebrate or just cheers to that. 
You got further than a lot of people before you!

##Errors you might encounter on the way

###Ambiguous argument followed by some hash

If you look at the compilescript you see that VLCKit and Medialibrary are checkout out by hash references. 
These are repositories within the VLCiOS repo and if you encounter this error chances are you just need to go into the subfolder ImportedSource/MediaLibrarykit or ImportedSources/VLCKit and pull the latest commits
then go back and run the script again.
It just didn't know the hash because your repository was not up to date

###Connection timed out 

VLC has _many_ dependencies. It can happen that when you initially try to buid vlc that some libraries are temporarily unavailable.
You have two options:
 
1. either you wait until the library is available again (often the server is just down) and start the script again
or 
2. you try to figure out which file couldn't be downloaded and try to find that resource somewhere else and put in the right place. Looking at the compile scripts helps here :)

###Build errors in Xcode

Are you sure you opened the workspace ? 
We use cocopoads and it creates a workspace with all the integrated libraries. 
Chances are you opened the project file. 

If you have openend the workspace and still get errors you should check out the Notes section

##Submitting A Patch

So you added some code and are ready to contribute your commits but you don't see a way to make a Pullrequest?
Soo *cough* we work with patches and Mailinglists like any good open source project! 

you should take a look at this: https://wiki.videolan.org/Sending_Patches_VLC/ but at the end send the patch to  ios@videolan.org.

Also, if you haven't yet, you might want to subscribe to this mailinglist: https://mailman.videolan.org/listinfo/ios

##Notes

For everything else check: https://wiki.videolan.org/IOSCompile/
or look here http://www.videolan.org/support/
For fast replies the IRC is probably the best way.

We're happy to help! 