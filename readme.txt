Build on IOS without developer certificate:
Firstly download and install sidestore to sideload the app
https://wiki.sidestore.io/guides/install.html
In case you run into the error "Can't create a proxy server" something along those lines,
try to install it the complex route via AltServer and manuall parring page
then after creating the parring page rename the *.mobiledevicepairing
to ALTPairingFile.mobiledevicepairing
Here is some additional information: https://github.com/SideStore/SideStore/issues/482
I had to use the nightly build not the latest stable one

compile the app: flutter bin ios --no-codesign --release
Install the app:
go to /build/ios/iphoneos/
Create a folder called "Payload" (case sensitive)
copy Runner.app into Payload
compress the Payload folder with default .zip format (right click "Compress Runner.app")
rename Payload.zip to Payload.ipa and send the .ipa file to your Iphone (e.g. via email, icloud, etc.)
If you use airdrop to send the file, don't rename it before sending otherwise the iphone will try to default install it.
Then open the SideStore app navigate to apps -> click the plus -> add the app.
Here the stackoverflow answer that helped me: https://stackoverflow.com/questions/63247510/is-it-possible-to-generate-ipa-file-for-ios-without-apple-developer-account-a


