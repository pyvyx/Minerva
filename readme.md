# Building and Installing an iOS App without a Developer Certificate

This guide will walk you through the steps to build and install an iOS app without the need for a developer certificate. Please follow these instructions carefully.

## Prerequisites

Before getting started, make sure you have the following:

1. [Sidestore](https://wiki.sidestore.io/guides/install.html): Download and install Sidestore to sideload the app.

2. If you encounter the error "Can't create a proxy server" when trying to add your app, follow these steps:

   - Uninstall Sidestore
  
   - Install Sidestore using the complex route via AltServer and manually create a pairing page.

   - After creating the pairing page, rename the `*.mobiledevicepairing` file to `ALTPairingFile.mobiledevicepairing`. (Refer to [SideStore/SideStore#482](https://github.com/SideStore/SideStore/issues/482))

   - Note: Using the nightly build of Sidestore may be required instead of the latest stable version.

## Compiling the App

1. Open your terminal and run the following command to compile the app:

   ```bash
   flutter build ios --no-codesign --release
   ```

## Installing the App

1. Go to `/build/ios/iphoneos/`. (Refer to [Stack Overflow answer]([https://github.com/SideStore/SideStore/issues/482](https://stackoverflow.com/questions/63247510/is-it-possible-to-generate-ipa-file-for-ios-without-apple-developer-account-a)))

2. Create a folder named "Payload" (case sensitive).

3. Copy the `Runner.app` into the "Payload" folder.

4. Compress the "Payload" folder using the default .zip format by right-clicking "Compress Runner.app."

5. Rename the compressed `Payload.zip` to `Payload.ipa`.

6. Send the `.ipa` file to your iPhone using a method like email or iCloud. If you use AirDrop, **do not** rename the file before sending.

7. Open the Sidestore app on your iPhone.

8. Navigate to "Apps," click the plus sign (+), and add the app using the provided `.ipa` file.
